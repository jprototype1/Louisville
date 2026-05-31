--!strict
-- Procedurally builds a grassy world to explore: trees, rocks, and gentle hills.
-- Runs on the server when the game starts. Everything is parented under a single
-- "World" folder so it's easy to clear and rebuild.

local WorldBuilder = {}

local WORLD_RADIUS = 220 -- how far out scenery scatters from spawn
local SPAWN_CLEARANCE = 24 -- keep this radius around spawn empty

-- A fixed seed makes the layout reproducible run-to-run. Change it for a new world.
local rng = Random.new(20260531)

local function newPart(props: { [string]: any }): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		(part :: any)[key] = value
	end
	return part
end

-- A simple low-poly tree: a trunk with a couple of leafy blobs on top.
local function makeTree(position: Vector3): Model
	local tree = Instance.new("Model")
	tree.Name = "Tree"

	local height = rng:NextNumber(8, 16)
	local trunk = newPart({
		Name = "Trunk",
		Shape = Enum.PartType.Cylinder,
		Material = Enum.Material.Wood,
		Color = Color3.fromRGB(102, 67, 41),
		Size = Vector3.new(height, 2, 2),
		-- Cylinders point along X, so rotate to stand upright.
		CFrame = CFrame.new(position + Vector3.new(0, height / 2, 0)) * CFrame.Angles(0, 0, math.rad(90)),
	})
	trunk.Parent = tree

	local leafColor = Color3.fromRGB(56, 122 + rng:NextInteger(-20, 20), 49)
	for i = 1, 3 do
		local size = rng:NextNumber(9, 14) - i * 2
		local leaves = newPart({
			Name = "Leaves",
			Shape = Enum.PartType.Ball,
			Material = Enum.Material.Grass,
			Color = leafColor,
			Size = Vector3.new(size, size, size),
			Position = position + Vector3.new(
				rng:NextNumber(-2, 2),
				height + i * 2.5,
				rng:NextNumber(-2, 2)
			),
		})
		leaves.Parent = tree
	end

	tree.PrimaryPart = trunk
	return tree
end

local function makeRock(position: Vector3): Part
	local size = rng:NextNumber(3, 8)
	return newPart({
		Name = "Rock",
		Shape = Enum.PartType.Ball,
		Material = Enum.Material.Slate,
		Color = Color3.fromRGB(120, 120, 125),
		Size = Vector3.new(size, size * 0.7, size),
		Position = position + Vector3.new(0, size * 0.2, 0),
	})
end

-- Big flattened grass spheres half-sunk into the ground read as gentle hills.
local function makeHill(position: Vector3): Part
	local width = rng:NextNumber(40, 80)
	local tall = rng:NextNumber(10, 22)
	return newPart({
		Name = "Hill",
		Shape = Enum.PartType.Ball,
		Material = Enum.Material.Grass,
		Color = Color3.fromRGB(106, 166, 77),
		Size = Vector3.new(width, tall, width),
		Position = position + Vector3.new(0, tall / 2 - 6, 0),
	})
end

-- Pick a random spot on the ground, outside the spawn clearance.
local function scatterPoint(): Vector3
	for _ = 1, 10 do
		local x = rng:NextNumber(-WORLD_RADIUS, WORLD_RADIUS)
		local z = rng:NextNumber(-WORLD_RADIUS, WORLD_RADIUS)
		if math.sqrt(x * x + z * z) > SPAWN_CLEARANCE then
			return Vector3.new(x, 0, z)
		end
	end
	return Vector3.new(WORLD_RADIUS, 0, WORLD_RADIUS)
end

function WorldBuilder.build(parent: Instance)
	-- Clear any previous build so live-edits don't stack worlds.
	local existing = parent:FindFirstChild("World")
	if existing then
		existing:Destroy()
	end

	local world = Instance.new("Folder")
	world.Name = "World"

	for _ = 1, 6 do
		makeHill(scatterPoint()).Parent = world
	end
	-- for _ = 1, 70 do
	-- 	makeTree(scatterPoint()).Parent = world
	-- end
	-- for _ = 1, 40 do
	-- 	makeRock(scatterPoint()).Parent = world
	-- end

	world.Parent = parent
	print(("[WorldBuilder] built world with %d objects"):format(#world:GetChildren()))
end

return WorldBuilder
