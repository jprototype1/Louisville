--!strict
-- Builds the main character's home: a two-story villa with a pool,
-- garage storage, driveway, patio, and decorative lighting.

local MainHouse = {}

local HOUSE_ORIGIN = Vector3.new(-120, 0, 0)

local COLORS = {
	stucco = Color3.fromRGB(213, 197, 173),
	stone = Color3.fromRGB(145, 139, 130),
	stoneDark = Color3.fromRGB(96, 92, 86),
	roof = Color3.fromRGB(91, 47, 41),
	trim = Color3.fromRGB(56, 63, 70),
	glass = Color3.fromRGB(166, 220, 232),
	warmLight = Color3.fromRGB(255, 216, 150),
	garage = Color3.fromRGB(228, 221, 208),
	concrete = Color3.fromRGB(176, 171, 162),
	pool = Color3.fromRGB(37, 151, 205),
	waterGlow = Color3.fromRGB(97, 213, 255),
	grassEdge = Color3.fromRGB(57, 126, 68),
}

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

local function newWedge(props: { [string]: any }): WedgePart
	local part = Instance.new("WedgePart")
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth

	for key, value in props do
		(part :: any)[key] = value
	end

	return part
end

local function cf(offset: Vector3, yawDegrees: number?): CFrame
	return CFrame.new(HOUSE_ORIGIN + offset) * CFrame.Angles(0, math.rad(yawDegrees or 0), 0)
end

local function block(parent: Instance, name: string, size: Vector3, offset: Vector3, color: Color3, material: Enum.Material, yawDegrees: number?): Part
	local part = newPart({
		Name = name,
		Size = size,
		Color = color,
		Material = material,
		CFrame = cf(offset, yawDegrees),
	})
	part.Parent = parent
	return part
end

local function glass(parent: Instance, name: string, size: Vector3, offset: Vector3, yawDegrees: number?): Part
	local part = block(parent, name, size, offset, COLORS.glass, Enum.Material.Glass, yawDegrees)
	part.Transparency = 0.35
	part.Reflectance = 0.12
	return part
end

local function lightBlock(parent: Instance, name: string, size: Vector3, offset: Vector3, yawDegrees: number?): Part
	local part = block(parent, name, size, offset, COLORS.warmLight, Enum.Material.Neon, yawDegrees)
	part.Transparency = 0.08

	local light = Instance.new("PointLight")
	light.Name = "WarmGlow"
	light.Brightness = 0.9
	light.Range = 16
	light.Color = COLORS.warmLight
	light.Parent = part

	return part
end

local function makeWindow(parent: Instance, name: string, offset: Vector3, size: Vector3, yawDegrees: number)
	local frameDepth = 0.35
	local frame = block(parent, name .. "_Frame", size + Vector3.new(frameDepth, 0.9, 0.9), offset, COLORS.trim, Enum.Material.Metal, yawDegrees)
	frame.Parent = parent

	glass(parent, name .. "_Glass", size, offset + Vector3.new(0.08, 0, 0), yawDegrees)
	lightBlock(parent, name .. "_InteriorGlow", size - Vector3.new(0.15, 0.35, 0.35), offset + Vector3.new(0.16, 0, 0), yawDegrees)
end

local function makeRoof(parent: Instance, name: string, size: Vector3, offset: Vector3, yawDegrees: number?)
	block(parent, name .. "_TileCap", size + Vector3.new(3.5, 1.2, 3.5), offset, COLORS.roof, Enum.Material.Brick, yawDegrees)
	block(parent, name .. "_Ridge", Vector3.new(size.X + 5, 1.6, 2.1), offset + Vector3.new(0, 1.15, 0), COLORS.roof, Enum.Material.Brick, yawDegrees)
end

local function makePalm(parent: Instance, name: string, offset: Vector3, height: number)
	local palm = Instance.new("Model")
	palm.Name = name
	palm.Parent = parent

	local trunk = newPart({
		Name = "Trunk",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(height, 1.4, 1.4),
		Color = Color3.fromRGB(121, 88, 55),
		Material = Enum.Material.Wood,
		CFrame = cf(offset + Vector3.new(0, height / 2, 0)) * CFrame.Angles(0, 0, math.rad(90)),
	})
	trunk.Parent = palm

	for i = 1, 6 do
		local yaw = (i - 1) * 60
		local leaf = newWedge({
			Name = "PalmLeaf",
			Size = Vector3.new(2.2, 0.8, 12),
			Color = Color3.fromRGB(55, 139, 77),
			Material = Enum.Material.Grass,
			CFrame = cf(offset + Vector3.new(0, height + 1.2, 0), yaw) * CFrame.Angles(math.rad(-12), 0, 0),
		})
		leaf.Parent = palm
	end
end

local function makeGarageStoragePad(parent: Instance, index: number, offset: Vector3)
	local pad = block(parent, ("GarageCarPad%d"):format(index), Vector3.new(14, 0.18, 12), offset, Color3.fromRGB(95, 101, 106), Enum.Material.Metal)
	pad.Transparency = 0.25
	pad:SetAttribute("CarStoragePad", true)
	pad:SetAttribute("PadIndex", index)
end

function MainHouse.build(parent: Instance)
	local existing = parent:FindFirstChild("MainCharacterHouse")
	if existing then
		existing:Destroy()
	end

	local house = Instance.new("Model")
	house.Name = "MainCharacterHouse"
	house.Parent = parent

	local structure = Instance.new("Folder")
	structure.Name = "Structure"
	structure.Parent = house

	local details = Instance.new("Folder")
	details.Name = "Details"
	details.Parent = house

	local garagePads = Instance.new("Folder")
	garagePads.Name = "GarageStoragePads"
	garagePads.Parent = house

	block(structure, "VillaLot", Vector3.new(86, 0.25, 104), Vector3.new(0, 0.05, 0), COLORS.grassEdge, Enum.Material.Grass)
	block(structure, "StoneDriveway", Vector3.new(70, 0.22, 22), Vector3.new(38, 0.16, -24), COLORS.concrete, Enum.Material.Concrete)
	block(structure, "FrontWalk", Vector3.new(35, 0.18, 7), Vector3.new(29, 0.22, 13), COLORS.concrete, Enum.Material.Concrete)
	block(structure, "PoolPatio", Vector3.new(44, 0.22, 54), Vector3.new(-37, 0.2, 27), COLORS.concrete, Enum.Material.Concrete)

	block(structure, "FirstFloorStucco", Vector3.new(42, 18, 56), Vector3.new(0, 9, 0), COLORS.stucco, Enum.Material.SmoothPlastic)
	block(structure, "SecondFloorStucco", Vector3.new(34, 16, 42), Vector3.new(-5, 26, 0), COLORS.stucco, Enum.Material.SmoothPlastic)
	block(structure, "StoneEntryTower", Vector3.new(19, 31, 19), Vector3.new(18, 15.5, 17), COLORS.stone, Enum.Material.Cobblestone)
	block(structure, "GarageWing", Vector3.new(26, 14, 28), Vector3.new(14, 7, -24), COLORS.stucco, Enum.Material.SmoothPlastic)

	makeRoof(structure, "MainRoof", Vector3.new(47, 2.4, 61), Vector3.new(0, 19.8, 0))
	makeRoof(structure, "UpperRoof", Vector3.new(39, 2.4, 47), Vector3.new(-5, 35.2, 0))
	makeRoof(structure, "GarageRoof", Vector3.new(30, 2.2, 32), Vector3.new(14, 15.8, -24))
	block(structure, "TowerRoof", Vector3.new(23, 3.4, 23), Vector3.new(18, 32.4, 17), COLORS.roof, Enum.Material.Brick)

	block(details, "FrontDoor", Vector3.new(1, 10, 7), Vector3.new(21.15, 5, 13), Color3.fromRGB(91, 54, 35), Enum.Material.Wood)
	block(details, "FrontDoorArch", Vector3.new(1.1, 2.6, 9), Vector3.new(21.2, 10.9, 13), COLORS.stoneDark, Enum.Material.Cobblestone)
	lightBlock(details, "EntryLanternLeft", Vector3.new(0.65, 2.3, 0.65), Vector3.new(21.75, 8, 7.7))
	lightBlock(details, "EntryLanternRight", Vector3.new(0.65, 2.3, 0.65), Vector3.new(21.75, 8, 18.3))

	block(details, "GarageDoorLeft", Vector3.new(1, 9, 10), Vector3.new(27.4, 4.6, -30.5), COLORS.garage, Enum.Material.WoodPlanks)
	block(details, "GarageDoorRight", Vector3.new(1, 9, 10), Vector3.new(27.4, 4.6, -17.5), COLORS.garage, Enum.Material.WoodPlanks)
	block(details, "GarageDoorLeftTrim", Vector3.new(1.2, 10.2, 11.2), Vector3.new(27.05, 5.1, -30.5), COLORS.trim, Enum.Material.Metal)
	block(details, "GarageDoorRightTrim", Vector3.new(1.2, 10.2, 11.2), Vector3.new(27.05, 5.1, -17.5), COLORS.trim, Enum.Material.Metal)
	lightBlock(details, "GarageSconceLeft", Vector3.new(0.6, 2.1, 0.6), Vector3.new(28.1, 7.8, -37.5))
	lightBlock(details, "GarageSconceRight", Vector3.new(0.6, 2.1, 0.6), Vector3.new(28.1, 7.8, -10.5))

	makeGarageStoragePad(garagePads, 1, Vector3.new(12, 0.34, -30.5))
	makeGarageStoragePad(garagePads, 2, Vector3.new(12, 0.34, -17.5))

	makeWindow(details, "KitchenWindow", Vector3.new(21.2, 8, -4), Vector3.new(0.5, 6, 8), 0)
	makeWindow(details, "LivingRoomWindow", Vector3.new(21.2, 8, -12), Vector3.new(0.5, 6, 6), 0)
	makeWindow(details, "TowerWindowUpper", Vector3.new(27.8, 23, 17), Vector3.new(0.5, 7, 6), 0)
	makeWindow(details, "BedroomWindowLeft", Vector3.new(12.4, 26, 22.1), Vector3.new(7, 6, 0.5), 90)
	makeWindow(details, "BedroomWindowRight", Vector3.new(-16.5, 26, 22.1), Vector3.new(7, 6, 0.5), 90)
	makeWindow(details, "SideWindowLeft", Vector3.new(-22.2, 24, -11), Vector3.new(0.5, 6, 8), 180)
	makeWindow(details, "SideWindowRight", Vector3.new(-22.2, 9, 10), Vector3.new(0.5, 6, 8), 180)

	block(details, "SecondFloorBalcony", Vector3.new(12, 0.8, 14), Vector3.new(18, 20, 2), COLORS.concrete, Enum.Material.Concrete)
	for z = -4, 8, 3 do
		block(details, "BalconyRailPost", Vector3.new(0.45, 5, 0.45), Vector3.new(24.2, 22.3, z), COLORS.trim, Enum.Material.Metal)
	end
	block(details, "BalconyRailFront", Vector3.new(0.5, 1.1, 14.5), Vector3.new(24.2, 24.8, 2), COLORS.trim, Enum.Material.Metal)

	block(details, "PoolBasin", Vector3.new(28, 1, 38), Vector3.new(-40, 0.55, 28), Color3.fromRGB(42, 88, 109), Enum.Material.Slate)
	local poolWater = block(details, "PoolWater", Vector3.new(26, 0.45, 36), Vector3.new(-40, 1.15, 28), COLORS.pool, Enum.Material.Glass)
	poolWater.Transparency = 0.28
	poolWater.Reflectance = 0.08
	local poolGlow = lightBlock(details, "PoolGlow", Vector3.new(23, 0.16, 33), Vector3.new(-40, 1.22, 28))
	poolGlow.Color = COLORS.waterGlow
	local poolLight = poolGlow:FindFirstChild("WarmGlow")
	if poolLight and poolLight:IsA("PointLight") then
		poolLight.Color = COLORS.waterGlow
	end
	block(details, "PoolSteps", Vector3.new(8, 0.35, 7), Vector3.new(-27, 1.4, 11.5), COLORS.concrete, Enum.Material.Concrete)

	block(details, "OutdoorSofa", Vector3.new(4, 2, 14), Vector3.new(-13, 1.2, 36), Color3.fromRGB(76, 83, 88), Enum.Material.SmoothPlastic)
	block(details, "OutdoorTable", Vector3.new(7, 1.1, 4), Vector3.new(-23, 1, 36), Color3.fromRGB(94, 63, 43), Enum.Material.Wood)
	block(details, "FireBowl", Vector3.new(5, 1, 5), Vector3.new(-23, 1.6, 27), COLORS.stoneDark, Enum.Material.Slate)
	lightBlock(details, "FireGlow", Vector3.new(3.2, 0.7, 3.2), Vector3.new(-23, 2.2, 27))

	makePalm(details, "PoolPalmLeft", Vector3.new(-61, 0, 4), 17)
	makePalm(details, "PoolPalmRight", Vector3.new(-58, 0, 52), 15)
	makePalm(details, "DrivewayPalm", Vector3.new(43, 0, -43), 16)

	print("[MainHouse] built main character house at X=-120, Z=0")
end

return MainHouse
