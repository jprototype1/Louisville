-- PetDog.luau
-- A fluffy white dog that follows its owner around the map.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local PetDog = {}

local FOLLOW_DISTANCE = 4 -- studs behind the player
local STOP_DISTANCE = 2.5 -- stop chasing when this close
local DOG_HEIGHT_ABOVE_GROUND = 0.85 -- how high the body sits off the terrain
local ACCEL = 14 -- how fast the dog speeds up (studs/s²)
local MAX_SPEED = 20 -- top running speed
local DRAG = 6 -- how fast it slows down when close
local ROTATE_SPEED = 12 -- how fast it turns (lerp factor)
local RAY_LENGTH = 12 -- how far down to probe for the ground

-- Raycast params — ignore the dog itself
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

local function weld(parent: Part, child: Part, offset: CFrame)
	child.CFrame = parent.CFrame * offset
	local w = Instance.new("WeldConstraint")
	w.Part0 = parent
	w.Part1 = child
	w.Parent = parent
end

local function makePart(dog: Model, name: string, size: Vector3, color: BrickColor, fur: boolean): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.BrickColor = color
	-- Fabric gives a soft woven/fur appearance on all parts
	p.Material = fur and Enum.Material.Fabric or Enum.Material.SmoothPlastic
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

	-- Body — anchored so WE control movement via CFrame
	local body = makePart(dog, "Body", Vector3.new(1.8, 1.0, 2.8), white, true)
	body.Anchored = true
	local bodyMesh = Instance.new("SpecialMesh")
	bodyMesh.MeshType = Enum.MeshType.Sphere
	bodyMesh.Scale = Vector3.new(1, 0.85, 1)
	bodyMesh.Parent = body

	-- Head
	local head = makePart(dog, "Head", Vector3.new(1.2, 1.1, 1.1), white, true)
	local headMesh = Instance.new("SpecialMesh")
	headMesh.MeshType = Enum.MeshType.Sphere
	headMesh.Parent = head
	weld(body, head, CFrame.new(0, 0.5, -1.15))

	-- Ears — floppy, slightly tilted out
	local function makeEar(xOff: number)
		local ear = makePart(dog, "Ear", Vector3.new(0.45, 0.72, 0.25), white, true)
		local earMesh = Instance.new("SpecialMesh")
		earMesh.MeshType = Enum.MeshType.Sphere
		earMesh.Scale = Vector3.new(1, 1, 0.6)
		earMesh.Parent = ear
		local tilt = xOff < 0 and 25 or -25
		weld(head, ear, CFrame.new(xOff, 0.42, 0.15) * CFrame.Angles(0, 0, math.rad(tilt)))
	end
	makeEar(-0.5)
	makeEar(0.5)

	-- Snout
	local snout = makePart(dog, "Snout", Vector3.new(0.6, 0.42, 0.5), white, true)
	weld(head, snout, CFrame.new(0, -0.18, -0.65))

	-- Nose
	local nose = makePart(dog, "Nose", Vector3.new(0.28, 0.2, 0.14), black, false)
	weld(snout, nose, CFrame.new(0, 0.06, -0.31))

	-- Eyes
	local function makeEye(xOff: number)
		local eye = makePart(dog, "Eye", Vector3.new(0.22, 0.22, 0.12), black, false)
		weld(head, eye, CFrame.new(xOff, 0.1, -0.58))
	end
	makeEye(-0.32)
	makeEye(0.32)

	-- Tail — fluffy pom-pom
	local tail = makePart(dog, "Tail", Vector3.new(0.42, 0.95, 0.42), white, true)
	local tailMesh = Instance.new("SpecialMesh")
	tailMesh.MeshType = Enum.MeshType.Sphere
	tailMesh.Scale = Vector3.new(1.1, 1, 1.1)
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
		local leg = makePart(dog, "Leg", Vector3.new(0.38, 0.68, 0.38), white, true)
		weld(body, leg, cf)
	end

	dog.PrimaryPart = body
	dog.Parent = parent
	return dog
end

-- Cast a ray straight down to find the ground Y under a position
local function groundY(pos: Vector3, excludeList: { Instance }): number
	rayParams.FilterDescendantsInstances = excludeList
	local result = Workspace:Raycast(pos + Vector3.new(0, 4, 0), Vector3.new(0, -RAY_LENGTH, 0), rayParams)
	if result then
		return result.Position.Y
	end
	-- Fallback: use the position's own Y (flat ground)
	return pos.Y - DOG_HEIGHT_ABOVE_GROUND
end

local function spawnDogForPlayer(player: Player)
	local conn: RBXScriptConnection? = nil

	local function startDog(character: Model)
		if conn then
			conn:Disconnect()
			conn = nil
		end
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

		local dogBody = dog.PrimaryPart :: Part
		local dogTail = dog:FindFirstChild("Tail") :: Part?

		-- Collect all dog parts for ground-raycast exclusion
		local dogParts: { Instance } = dog:GetDescendants()
		table.insert(dogParts, dog)

		-- Spawn beside the player
		local spawnPos = hrp.Position + hrp.CFrame.RightVector * FOLLOW_DISTANCE
		local gY = groundY(spawnPos, dogParts)
		dogBody.CFrame = CFrame.new(spawnPos.X, gY + DOG_HEIGHT_ABOVE_GROUND, spawnPos.Z)

		-- Physics state
		local velocity = Vector3.zero -- horizontal velocity in studs/s
		local facing = dogBody.CFrame.LookVector -- current facing direction

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

			-- Target spot: behind and slightly to the right of the player
			local targetPos = (root.CFrame * CFrame.new(1.5, 0, FOLLOW_DISTANCE)).Position
			local currentPos = dogBody.Position
			local flat = Vector3.new(targetPos.X - currentPos.X, 0, targetPos.Z - currentPos.Z)
			local dist = flat.Magnitude

			if dist > STOP_DISTANCE then
				local desiredDir = flat.Unit
				-- Accelerate toward target
				velocity = velocity + desiredDir * ACCEL * dt
				-- Cap speed
				local speed = velocity.Magnitude
				if speed > MAX_SPEED then
					velocity = velocity.Unit * MAX_SPEED
				end
			else
				-- Apply drag to slow to a stop
				local speed = velocity.Magnitude
				local slowDown = math.min(DRAG * dt, speed)
				if speed > 0 then
					velocity = velocity - velocity.Unit * slowDown
				end
			end

			-- Move the dog
			local newXZ = Vector3.new(currentPos.X + velocity.X * dt, 0, currentPos.Z + velocity.Z * dt)

			-- Raycast for ground under new position
			local gY2 = groundY(newXZ, dogParts)
			local newPos = Vector3.new(newXZ.X, gY2 + DOG_HEIGHT_ABOVE_GROUND, newXZ.Z)

			-- Smoothly rotate to face direction of travel
			if velocity.Magnitude > 0.5 then
				local desiredFacing = velocity.Unit
				facing = facing:Lerp(desiredFacing, math.min(ROTATE_SPEED * dt, 1))
			end

			local newCF = CFrame.lookAt(newPos, newPos + facing)
			dogBody.CFrame = newCF

			-- Tail wag while moving
			if dogTail and velocity.Magnitude > 0.5 then
				local wag = math.sin(tick() * 10) * math.rad(30)
				dogTail.CFrame = newCF * CFrame.new(0, 0.65, 1.2) * CFrame.Angles(math.rad(-35), wag, 0)
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
