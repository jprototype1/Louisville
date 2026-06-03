-- PetDog.luau
-- A fluffy white dog that follows its owner around the map.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local PetDog = {}

-- How far behind the player the dog walks
local FOLLOW_DISTANCE = 4
-- How fast the dog moves (studs/sec)
local WALK_SPEED = 16
-- How close the dog gets before it stops chasing
local STOP_DISTANCE = 3
-- How high to place the dog above the ground
local DOG_HEIGHT = 1.2

local function buildDog(parent: Workspace): Model
	local dog = Instance.new("Model")
	dog.Name = "FluffyDog"

	-- Body (a rounded white box)
	local body = Instance.new("Part")
	body.Name = "Body"
	body.Size = Vector3.new(1.8, 1.0, 2.8)
	body.BrickColor = BrickColor.new("White")
	body.Material = Enum.Material.SmoothPlastic
	body.CastShadow = true
	body.Anchored = false
	body.CanCollide = false
	body.Parent = dog

	-- Head
	local head = Instance.new("Part")
	head.Name = "Head"
	head.Size = Vector3.new(1.2, 1.1, 1.1)
	head.BrickColor = BrickColor.new("White")
	head.Material = Enum.Material.SmoothPlastic
	head.CanCollide = false
	head.Anchored = false
	head.Parent = dog

	local headWeld = Instance.new("WeldConstraint")
	headWeld.Part0 = body
	headWeld.Part1 = head
	headWeld.Parent = body
	-- Position head at the front-top of the body
	head.CFrame = body.CFrame * CFrame.new(0, 0.5, -1.2)

	-- Snout
	local snout = Instance.new("Part")
	snout.Name = "Snout"
	snout.Size = Vector3.new(0.6, 0.45, 0.5)
	snout.BrickColor = BrickColor.new("White")
	snout.Material = Enum.Material.SmoothPlastic
	snout.CanCollide = false
	snout.Anchored = false
	snout.Parent = dog

	local snoutWeld = Instance.new("WeldConstraint")
	snoutWeld.Part0 = head
	snoutWeld.Part1 = snout
	snoutWeld.Parent = head
	snout.CFrame = head.CFrame * CFrame.new(0, -0.15, -0.7)

	-- Nose (dark)
	local nose = Instance.new("Part")
	nose.Name = "Nose"
	nose.Size = Vector3.new(0.3, 0.2, 0.15)
	nose.BrickColor = BrickColor.new("Really black")
	nose.Material = Enum.Material.SmoothPlastic
	nose.CanCollide = false
	nose.Anchored = false
	nose.Parent = dog

	local noseWeld = Instance.new("WeldConstraint")
	noseWeld.Part0 = snout
	noseWeld.Part1 = nose
	noseWeld.Parent = snout
	nose.CFrame = snout.CFrame * CFrame.new(0, 0.05, -0.3)

	-- Eyes (dark)
	local function makeEye(xOffset: number): Part
		local eye = Instance.new("Part")
		eye.Name = "Eye"
		eye.Size = Vector3.new(0.22, 0.22, 0.12)
		eye.BrickColor = BrickColor.new("Really black")
		eye.Material = Enum.Material.SmoothPlastic
		eye.CanCollide = false
		eye.Anchored = false
		eye.Parent = dog

		local weld = Instance.new("WeldConstraint")
		weld.Part0 = head
		weld.Part1 = eye
		weld.Parent = head
		eye.CFrame = head.CFrame * CFrame.new(xOffset, 0.1, -0.6)
		return eye
	end
	makeEye(-0.32)
	makeEye(0.32)

	-- Tail (sticking up and back)
	local tail = Instance.new("Part")
	tail.Name = "Tail"
	tail.Size = Vector3.new(0.35, 0.9, 0.35)
	tail.BrickColor = BrickColor.new("White")
	tail.Material = Enum.Material.SmoothPlastic
	tail.CanCollide = false
	tail.Anchored = false
	tail.Parent = dog

	local tailWeld = Instance.new("WeldConstraint")
	tailWeld.Part0 = body
	tailWeld.Part1 = tail
	tailWeld.Parent = body
	tail.CFrame = body.CFrame * CFrame.new(0, 0.7, 1.2) * CFrame.Angles(math.rad(-30), 0, 0)

	-- Legs x4
	local legOffsets = {
		Vector3.new(-0.65, -0.7, -0.85),
		Vector3.new(0.65, -0.7, -0.85),
		Vector3.new(-0.65, -0.7, 0.85),
		Vector3.new(0.65, -0.7, 0.85),
	}
	for _, offset in ipairs(legOffsets) do
		local leg = Instance.new("Part")
		leg.Name = "Leg"
		leg.Size = Vector3.new(0.4, 0.65, 0.4)
		leg.BrickColor = BrickColor.new("White")
		leg.Material = Enum.Material.SmoothPlastic
		leg.CanCollide = false
		leg.Anchored = false
		leg.Parent = dog

		local weld = Instance.new("WeldConstraint")
		weld.Part0 = body
		weld.Part1 = leg
		weld.Parent = body
		leg.CFrame = body.CFrame * CFrame.new(offset)
	end

	-- Fluffy texture via speckling (small bumps on body/head)
	-- We use a SurfaceAppearance with a white rough look
	local sa = Instance.new("SpecialMesh")
	sa.MeshType = Enum.MeshType.Sphere
	sa.Scale = Vector3.new(1, 0.8, 1)
	sa.Parent = body

	local hsa = Instance.new("SpecialMesh")
	hsa.MeshType = Enum.MeshType.Sphere
	hsa.Scale = Vector3.new(1, 1, 1)
	hsa.Parent = head

	-- Root attachment for movement
	local rootAtt = Instance.new("Attachment")
	rootAtt.Name = "RootAttachment"
	rootAtt.Parent = body

	dog.PrimaryPart = body
	dog.Parent = parent
	return dog
end

-- Smoothly move the dog toward the target position each frame
local function moveDog(dog: Model, targetPos: Vector3, dt: number)
	local body = dog.PrimaryPart
	if not body then
		return
	end

	local currentPos = body.Position
	local delta = targetPos - currentPos
	delta = Vector3.new(delta.X, 0, delta.Z) -- only horizontal

	local dist = delta.Magnitude
	if dist < STOP_DISTANCE then
		return
	end

	local dir = delta.Unit
	local step = math.min(WALK_SPEED * dt, dist - STOP_DISTANCE)
	local newPos = currentPos + dir * step
	newPos = Vector3.new(newPos.X, targetPos.Y + DOG_HEIGHT, newPos.Z)

	-- Face the direction of travel
	local lookCF = CFrame.lookAt(newPos, newPos + dir)
	body.CFrame = lookCF

	-- Wag tail a little (rotate slightly back and forth)
	local tail = dog:FindFirstChild("Tail")
	if tail then
		local wagAngle = math.sin(tick() * 8) * math.rad(25)
		tail.CFrame = body.CFrame * CFrame.new(0, 0.7, 1.2) * CFrame.Angles(math.rad(-30), wagAngle, 0)
	end
end

-- Spawn one dog per player and follow them
local function spawnDogForPlayer(player: Player)
	local function onCharacterAdded(character: Model)
		-- Remove any old dog first
		local old = Workspace:FindFirstChild("Dog_" .. player.UserId)
		if old then
			old:Destroy()
		end

		local dog = buildDog(Workspace)
		dog.Name = "Dog_" .. player.UserId

		-- Place it next to the character spawn
		local hrp = character:WaitForChild("HumanoidRootPart", 10)
		if not hrp then
			return
		end
		local spawnCF = hrp.CFrame * CFrame.new(FOLLOW_DISTANCE, 0, 0)
		dog:SetPrimaryPartCFrame(spawnCF)

		-- Follow loop
		local conn
		conn = RunService.Heartbeat:Connect(function(dt)
			-- If dog or player gone, stop
			if not dog or not dog.Parent then
				conn:Disconnect()
				return
			end
			local char = player.Character
			if not char then
				return
			end
			local root = char:FindFirstChild("HumanoidRootPart")
			if not root then
				return
			end

			-- Target = slightly behind and to the side of the player
			local behindOffset = root.CFrame * CFrame.new(1.5, 0, FOLLOW_DISTANCE)
			moveDog(dog, behindOffset.Position, dt)
		end)

		-- Clean up when character leaves
		character.AncestryChanged:Connect(function()
			if not character.Parent then
				conn:Disconnect()
				if dog and dog.Parent then
					dog:Destroy()
				end
			end
		end)
	end

	player.CharacterAdded:Connect(onCharacterAdded)
	if player.Character then
		onCharacterAdded(player.Character)
	end
end

function PetDog.start()
	-- Spawn dog for anyone already in the game
	for _, player in ipairs(Players:GetPlayers()) do
		spawnDogForPlayer(player)
	end
	-- And for anyone who joins later
	Players.PlayerAdded:Connect(spawnDogForPlayer)

	-- Clean up when players leave
	Players.PlayerRemoving:Connect(function(player)
		local dog = Workspace:FindFirstChild("Dog_" .. player.UserId)
		if dog then
			dog:Destroy()
		end
	end)
end

return PetDog
