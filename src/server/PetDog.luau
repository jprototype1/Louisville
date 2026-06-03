-- PetDog.luau
-- A fluffy white dog that follows its owner around the map.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local PetDog = {}

local FOLLOW_DISTANCE = 4 -- studs behind the player
local STOP_DISTANCE = 3 -- stop chasing when this close
local DOG_HEIGHT = 1.5 -- height above the ground
local LERP_SPEED = 8 -- higher = snappier, lower = lazier

local function weld(parent: Part, child: Part, offset: CFrame)
	child.CFrame = parent.CFrame * offset
	local w = Instance.new("WeldConstraint")
	w.Part0 = parent
	w.Part1 = child
	w.Parent = parent
end

local function makePart(dog: Model, name: string, size: Vector3, color: BrickColor): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.BrickColor = color
	p.Material = Enum.Material.SmoothPlastic
	p.CanCollide = false
	p.Anchored = false
	p.CastShadow = false
	p.Parent = dog
	return p
end

local function buildDog(parent: Instance): Model
	local dog = Instance.new("Model")
	dog.Name = "FluffyDog"

	local white = BrickColor.new("White")
	local black = BrickColor.new("Really black")

	-- Body — anchored so WE control movement, no physics fighting
	local body = makePart(dog, "Body", Vector3.new(1.8, 1.0, 2.8), white)
	body.Anchored = true
	local bodyMesh = Instance.new("SpecialMesh")
	bodyMesh.MeshType = Enum.MeshType.Sphere
	bodyMesh.Scale = Vector3.new(1, 0.85, 1)
	bodyMesh.Parent = body

	-- Head
	local head = makePart(dog, "Head", Vector3.new(1.2, 1.1, 1.1), white)
	local headMesh = Instance.new("SpecialMesh")
	headMesh.MeshType = Enum.MeshType.Sphere
	headMesh.Parent = head
	weld(body, head, CFrame.new(0, 0.5, -1.15))

	-- Ears
	local function makeEar(xOff: number)
		local ear = makePart(dog, "Ear", Vector3.new(0.45, 0.65, 0.2), white)
		local earMesh = Instance.new("SpecialMesh")
		earMesh.MeshType = Enum.MeshType.Sphere
		earMesh.Parent = ear
		weld(head, ear, CFrame.new(xOff, 0.5, 0.1) * CFrame.Angles(0, 0, math.rad(xOff < 0 and 20 or -20)))
	end
	makeEar(-0.48)
	makeEar(0.48)

	-- Snout
	local snout = makePart(dog, "Snout", Vector3.new(0.6, 0.42, 0.5), white)
	weld(head, snout, CFrame.new(0, -0.18, -0.65))

	-- Nose
	local nose = makePart(dog, "Nose", Vector3.new(0.28, 0.2, 0.14), black)
	weld(snout, nose, CFrame.new(0, 0.06, -0.31))

	-- Eyes
	local function makeEye(xOff: number)
		local eye = makePart(dog, "Eye", Vector3.new(0.22, 0.22, 0.12), black)
		weld(head, eye, CFrame.new(xOff, 0.1, -0.58))
	end
	makeEye(-0.32)
	makeEye(0.32)

	-- Tail
	local tail = makePart(dog, "Tail", Vector3.new(0.32, 0.85, 0.32), white)
	local tailMesh = Instance.new("SpecialMesh")
	tailMesh.MeshType = Enum.MeshType.Sphere
	tailMesh.Scale = Vector3.new(1, 1, 1)
	tailMesh.Parent = tail
	weld(body, tail, CFrame.new(0, 0.65, 1.2) * CFrame.Angles(math.rad(-35), 0, 0))

	-- Legs x4
	local legPositions = {
		CFrame.new(-0.62, -0.72, -0.82),
		CFrame.new(0.62, -0.72, -0.82),
		CFrame.new(-0.62, -0.72, 0.82),
		CFrame.new(0.62, -0.72, 0.82),
	}
	for _, cf in ipairs(legPositions) do
		local leg = makePart(dog, "Leg", Vector3.new(0.38, 0.68, 0.38), white)
		weld(body, leg, cf)
	end

	dog.PrimaryPart = body
	dog.Parent = parent
	return dog
end

local function spawnDogForPlayer(player: Player)
	local conn: RBXScriptConnection? = nil

	local function startDog(character: Model)
		-- Disconnect any previous follow loop
		if conn then
			conn:Disconnect()
			conn = nil
		end
		-- Remove any old dog
		local old = Workspace:FindFirstChild("Dog_" .. player.UserId)
		if old then
			old:Destroy()
		end

		local hrp = character:WaitForChild("HumanoidRootPart", 10)
		if not hrp then
			return
		end

		local dog = buildDog(Workspace)
		dog.Name = "Dog_" .. player.UserId

		-- Spawn beside the player
		dog:SetPrimaryPartCFrame(hrp.CFrame * CFrame.new(FOLLOW_DISTANCE, 0, 0))

		local dogBody = dog.PrimaryPart :: Part
		local dogTail = dog:FindFirstChild("Tail") :: Part?
		local currentCF = dogBody.CFrame

		conn = RunService.Heartbeat:Connect(function(dt)
			if not dog.Parent then
				conn:Disconnect()
				conn = nil
				return
			end
			local char = player.Character
			if not char then
				return
			end
			local root = char:FindFirstChild("HumanoidRootPart") :: BasePart?
			if not root then
				return
			end

			-- Target: slightly behind and beside the player
			local targetCF = root.CFrame * CFrame.new(1.5, 0, FOLLOW_DISTANCE)
			local targetPos = targetCF.Position

			local flatDelta = Vector3.new(targetPos.X - currentCF.Position.X, 0, targetPos.Z - currentCF.Position.Z)
			local dist = flatDelta.Magnitude

			if dist > STOP_DISTANCE then
				local dir = flatDelta.Unit
				local newPos = Vector3.new(
					currentCF.Position.X + dir.X * dist,
					root.Position.Y + DOG_HEIGHT,
					currentCF.Position.Z + dir.Z * dist
				)
				local goalCF = CFrame.lookAt(newPos, newPos + dir)
				-- Smooth lerp so no teleporting/glitching
				currentCF = currentCF:Lerp(goalCF, math.min(LERP_SPEED * dt, 1))
				dogBody.CFrame = currentCF

				-- Wag tail while moving
				if dogTail then
					local wag = math.sin(tick() * 9) * math.rad(28)
					dogTail.CFrame = dogBody.CFrame * CFrame.new(0, 0.65, 1.2) * CFrame.Angles(math.rad(-35), wag, 0)
				end
			end
		end)
	end

	player.CharacterAdded:Connect(startDog)
	if player.Character then
		startDog(player.Character)
	end
end

function PetDog.start()
	for _, player in ipairs(Players:GetPlayers()) do
		spawnDogForPlayer(player)
	end
	Players.PlayerAdded:Connect(spawnDogForPlayer)

	Players.PlayerRemoving:Connect(function(player)
		local dog = Workspace:FindFirstChild("Dog_" .. player.UserId)
		if dog then
			dog:Destroy()
		end
	end)
end

return PetDog
