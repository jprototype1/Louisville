--!strict
-- Builds the main character's home: a two-story villa with a pool,
-- garage storage, driveway, patio, and decorative lighting.

local TweenService = game:GetService("TweenService")

local MainHouse = {}

local HOUSE_ORIGIN = Vector3.new(-120, 0, 0)
local DOOR_TWEEN = TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)

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

local function block(
	parent: Instance,
	name: string,
	size: Vector3,
	offset: Vector3,
	color: Color3,
	material: Enum.Material,
	yawDegrees: number?
): Part
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
	local frame = block(
		parent,
		name .. "_Frame",
		size + Vector3.new(frameDepth, 0.9, 0.9),
		offset,
		COLORS.trim,
		Enum.Material.Metal,
		yawDegrees
	)
	frame.Parent = parent

	glass(parent, name .. "_Glass", size, offset + Vector3.new(0.08, 0, 0), yawDegrees)
	lightBlock(
		parent,
		name .. "_InteriorGlow",
		size - Vector3.new(0.15, 0.35, 0.35),
		offset + Vector3.new(0.16, 0, 0),
		yawDegrees
	)
end

local function makeRoof(parent: Instance, name: string, size: Vector3, offset: Vector3, yawDegrees: number?)
	block(
		parent,
		name .. "_TileCap",
		size + Vector3.new(3.5, 1.2, 3.5),
		offset,
		COLORS.roof,
		Enum.Material.Brick,
		yawDegrees
	)
	block(
		parent,
		name .. "_Ridge",
		Vector3.new(size.X + 5, 1.6, 2.1),
		offset + Vector3.new(0, 1.15, 0),
		COLORS.roof,
		Enum.Material.Brick,
		yawDegrees
	)
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
	local pad = block(
		parent,
		("GarageCarPad%d"):format(index),
		Vector3.new(14, 0.18, 12),
		offset,
		Color3.fromRGB(95, 101, 106),
		Enum.Material.Metal
	)
	pad.Transparency = 0.25
	pad:SetAttribute("CarStoragePad", true)
	pad:SetAttribute("PadIndex", index)
end

local function makeDoor(
	parent: Instance,
	name: string,
	size: Vector3,
	offset: Vector3,
	hingeSide: string,
	swingAngle: number,
	yawDegrees: number?
)
	local closedCF = cf(offset, yawDegrees)
	local halfW = size.Z / 2
	local hingeLocalZ = (hingeSide == "right") and halfW or -halfW
	local hingeCF = closedCF * CFrame.new(0, 0, hingeLocalZ)
	local openCF = hingeCF * CFrame.Angles(0, math.rad(swingAngle), 0) * CFrame.new(0, 0, -hingeLocalZ)

	local door = newPart({
		Name = name,
		Size = size,
		Color = Color3.fromRGB(91, 54, 35),
		Material = Enum.Material.Wood,
		CFrame = closedCF,
	})
	door.Parent = parent

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Open Door"
	prompt.ObjectText = ""
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = door

	local isOpen = false
	prompt.Triggered:Connect(function()
		isOpen = not isOpen
		TweenService:Create(door, DOOR_TWEEN, { CFrame = isOpen and openCF or closedCF }):Play()
		prompt.ActionText = isOpen and "Close Door" or "Open Door"
	end)

	return door
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

	block(
		structure,
		"VillaLot",
		Vector3.new(86, 0.25, 104),
		Vector3.new(0, 0.05, 0),
		COLORS.grassEdge,
		Enum.Material.Grass
	)
	block(
		structure,
		"StoneDriveway",
		Vector3.new(70, 0.22, 22),
		Vector3.new(38, 0.16, -24),
		COLORS.concrete,
		Enum.Material.Concrete
	)
	block(
		structure,
		"FrontWalk",
		Vector3.new(35, 0.18, 7),
		Vector3.new(29, 0.22, 13),
		COLORS.concrete,
		Enum.Material.Concrete
	)
	block(
		structure,
		"PoolPatio",
		Vector3.new(44, 0.22, 54),
		Vector3.new(-37, 0.2, 27),
		COLORS.concrete,
		Enum.Material.Concrete
	)

	-- First floor: thin walls with door openings instead of solid block
	-- Front wall (X=21 face) — split around front door at Z=13, door is 7 wide, 10 tall
	block(
		structure,
		"FrontWallLeft",
		Vector3.new(1, 18, 37.5),
		Vector3.new(20.5, 9, -9.25),
		COLORS.stucco,
		Enum.Material.SmoothPlastic
	)
	block(
		structure,
		"FrontWallRight",
		Vector3.new(1, 18, 11.5),
		Vector3.new(20.5, 9, 22.25),
		COLORS.stucco,
		Enum.Material.SmoothPlastic
	)
	block(
		structure,
		"FrontWallAboveDoor",
		Vector3.new(1, 8, 7),
		Vector3.new(20.5, 14, 13),
		COLORS.stucco,
		Enum.Material.SmoothPlastic
	)
	-- Back wall (X=-21 face) — split around back door at Z=20, door is 6 wide, 10 tall
	block(
		structure,
		"BackWallLeft",
		Vector3.new(1, 18, 45),
		Vector3.new(-20.5, 9, -5.5),
		COLORS.stucco,
		Enum.Material.SmoothPlastic
	)
	block(
		structure,
		"BackWallRight",
		Vector3.new(1, 18, 5),
		Vector3.new(-20.5, 9, 25.5),
		COLORS.stucco,
		Enum.Material.SmoothPlastic
	)
	block(
		structure,
		"BackWallAboveDoor",
		Vector3.new(1, 8, 6),
		Vector3.new(-20.5, 14, 20),
		COLORS.stucco,
		Enum.Material.SmoothPlastic
	)
	-- Side walls
	block(
		structure,
		"SideWallLeft",
		Vector3.new(42, 18, 1),
		Vector3.new(0, 9, 27.5),
		COLORS.stucco,
		Enum.Material.SmoothPlastic
	)
	block(
		structure,
		"SideWallRight",
		Vector3.new(42, 18, 1),
		Vector3.new(0, 9, -27.5),
		COLORS.stucco,
		Enum.Material.SmoothPlastic
	)

	-- Second floor: thin walls (hollow)
	block(
		structure,
		"UpperFrontWall",
		Vector3.new(1, 16, 42),
		Vector3.new(12, 26, 0),
		COLORS.stucco,
		Enum.Material.SmoothPlastic
	)
	block(
		structure,
		"UpperBackWall",
		Vector3.new(1, 16, 42),
		Vector3.new(-22, 26, 0),
		COLORS.stucco,
		Enum.Material.SmoothPlastic
	)
	block(
		structure,
		"UpperSideWallLeft",
		Vector3.new(34, 16, 1),
		Vector3.new(-5, 26, 20.5),
		COLORS.stucco,
		Enum.Material.SmoothPlastic
	)
	block(
		structure,
		"UpperSideWallRight",
		Vector3.new(34, 16, 1),
		Vector3.new(-5, 26, -20.5),
		COLORS.stucco,
		Enum.Material.SmoothPlastic
	)

	-- Entry tower: hollow walls instead of solid
	block(
		structure,
		"TowerFront",
		Vector3.new(1, 31, 19),
		Vector3.new(27.5, 15.5, 17),
		COLORS.stone,
		Enum.Material.Cobblestone
	)
	block(
		structure,
		"TowerLeft",
		Vector3.new(19, 31, 1),
		Vector3.new(18, 15.5, 26.5),
		COLORS.stone,
		Enum.Material.Cobblestone
	)
	block(
		structure,
		"TowerRight",
		Vector3.new(19, 31, 1),
		Vector3.new(18, 15.5, 7.5),
		COLORS.stone,
		Enum.Material.Cobblestone
	)
	block(
		structure,
		"GarageWing",
		Vector3.new(26, 14, 28),
		Vector3.new(14, 7, -24),
		COLORS.stucco,
		Enum.Material.SmoothPlastic
	)

	makeRoof(structure, "MainRoof", Vector3.new(47, 2.4, 61), Vector3.new(0, 19.8, 0))
	makeRoof(structure, "UpperRoof", Vector3.new(39, 2.4, 47), Vector3.new(-5, 35.2, 0))
	makeRoof(structure, "GarageRoof", Vector3.new(30, 2.2, 32), Vector3.new(14, 15.8, -24))
	block(structure, "TowerRoof", Vector3.new(23, 3.4, 23), Vector3.new(18, 32.4, 17), COLORS.roof, Enum.Material.Brick)

	makeDoor(details, "FrontDoor", Vector3.new(1, 10, 7), Vector3.new(21.15, 5, 13), "left", -90)
	makeDoor(details, "BackDoor", Vector3.new(1, 10, 6), Vector3.new(-21.15, 5, 20), "left", 90)
	block(
		details,
		"FrontDoorArch",
		Vector3.new(1.1, 2.6, 9),
		Vector3.new(21.2, 10.9, 13),
		COLORS.stoneDark,
		Enum.Material.Cobblestone
	)
	lightBlock(details, "EntryLanternLeft", Vector3.new(0.65, 2.3, 0.65), Vector3.new(21.75, 8, 7.7))
	lightBlock(details, "EntryLanternRight", Vector3.new(0.65, 2.3, 0.65), Vector3.new(21.75, 8, 18.3))

	block(
		details,
		"GarageDoorLeft",
		Vector3.new(1, 9, 10),
		Vector3.new(27.4, 4.6, -30.5),
		COLORS.garage,
		Enum.Material.WoodPlanks
	)
	block(
		details,
		"GarageDoorRight",
		Vector3.new(1, 9, 10),
		Vector3.new(27.4, 4.6, -17.5),
		COLORS.garage,
		Enum.Material.WoodPlanks
	)
	block(
		details,
		"GarageDoorLeftTrim",
		Vector3.new(1.2, 10.2, 11.2),
		Vector3.new(27.05, 5.1, -30.5),
		COLORS.trim,
		Enum.Material.Metal
	)
	block(
		details,
		"GarageDoorRightTrim",
		Vector3.new(1.2, 10.2, 11.2),
		Vector3.new(27.05, 5.1, -17.5),
		COLORS.trim,
		Enum.Material.Metal
	)
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

	block(
		details,
		"SecondFloorBalcony",
		Vector3.new(12, 0.8, 14),
		Vector3.new(18, 20, 2),
		COLORS.concrete,
		Enum.Material.Concrete
	)
	for z = -4, 8, 3 do
		block(
			details,
			"BalconyRailPost",
			Vector3.new(0.45, 5, 0.45),
			Vector3.new(24.2, 22.3, z),
			COLORS.trim,
			Enum.Material.Metal
		)
	end
	block(
		details,
		"BalconyRailFront",
		Vector3.new(0.5, 1.1, 14.5),
		Vector3.new(24.2, 24.8, 2),
		COLORS.trim,
		Enum.Material.Metal
	)

	block(
		details,
		"PoolBasin",
		Vector3.new(28, 1, 38),
		Vector3.new(-40, 0.55, 28),
		Color3.fromRGB(42, 88, 109),
		Enum.Material.Slate
	)
	local poolWater = block(
		details,
		"PoolWater",
		Vector3.new(26, 0.45, 36),
		Vector3.new(-40, 1.15, 28),
		COLORS.pool,
		Enum.Material.Glass
	)
	poolWater.Transparency = 0.28
	poolWater.Reflectance = 0.08
	local poolGlow = lightBlock(details, "PoolGlow", Vector3.new(23, 0.16, 33), Vector3.new(-40, 1.22, 28))
	poolGlow.Color = COLORS.waterGlow
	local poolLight = poolGlow:FindFirstChild("WarmGlow")
	if poolLight and poolLight:IsA("PointLight") then
		poolLight.Color = COLORS.waterGlow
	end
	block(
		details,
		"PoolSteps",
		Vector3.new(8, 0.35, 7),
		Vector3.new(-27, 1.4, 11.5),
		COLORS.concrete,
		Enum.Material.Concrete
	)

	block(
		details,
		"OutdoorSofa",
		Vector3.new(4, 2, 14),
		Vector3.new(-13, 1.2, 36),
		Color3.fromRGB(76, 83, 88),
		Enum.Material.SmoothPlastic
	)
	block(
		details,
		"OutdoorTable",
		Vector3.new(7, 1.1, 4),
		Vector3.new(-23, 1, 36),
		Color3.fromRGB(94, 63, 43),
		Enum.Material.Wood
	)
	block(details, "FireBowl", Vector3.new(5, 1, 5), Vector3.new(-23, 1.6, 27), COLORS.stoneDark, Enum.Material.Slate)
	lightBlock(details, "FireGlow", Vector3.new(3.2, 0.7, 3.2), Vector3.new(-23, 2.2, 27))

	makePalm(details, "PoolPalmLeft", Vector3.new(-61, 0, 4), 17)
	makePalm(details, "PoolPalmRight", Vector3.new(-58, 0, 52), 15)
	makePalm(details, "DrivewayPalm", Vector3.new(43, 0, -43), 16)

	-- ═══════════════════════════════════════════════════
	-- BACKYARD WATERFALL
	-- ═══════════════════════════════════════════════════

	local waterfall = Instance.new("Folder")
	waterfall.Name = "Waterfall"
	waterfall.Parent = house

	-- Stone wall the water flows down
	block(
		waterfall,
		"WaterfallWall",
		Vector3.new(14, 20, 3),
		Vector3.new(-45, 10, 50),
		COLORS.stoneDark,
		Enum.Material.Slate
	)
	-- Flowing water (glass with glow)
	local waterFlow = block(
		waterfall,
		"WaterFlow",
		Vector3.new(10, 19, 1),
		Vector3.new(-45, 10, 49),
		Color3.fromRGB(80, 180, 230),
		Enum.Material.Glass
	)
	waterFlow.Transparency = 0.3
	waterFlow.Reflectance = 0.15
	-- Water glow
	local wfGlow = lightBlock(waterfall, "WaterGlow", Vector3.new(8, 18, 0.5), Vector3.new(-45, 10, 48.5))
	wfGlow.Color = Color3.fromRGB(100, 200, 245)
	local wfLight = wfGlow:FindFirstChild("WarmGlow")
	if wfLight and wfLight:IsA("PointLight") then
		wfLight.Color = Color3.fromRGB(100, 200, 245)
		wfLight.Range = 24
	end
	-- Catch basin at bottom
	block(
		waterfall,
		"CatchBasin",
		Vector3.new(18, 1.2, 10),
		Vector3.new(-45, 0.6, 46),
		Color3.fromRGB(42, 88, 109),
		Enum.Material.Slate
	)
	local catchWater = block(
		waterfall,
		"CatchWater",
		Vector3.new(16, 0.5, 8),
		Vector3.new(-45, 1.1, 46),
		Color3.fromRGB(60, 165, 215),
		Enum.Material.Glass
	)
	catchWater.Transparency = 0.25
	catchWater.Reflectance = 0.1
	-- Decorative rocks around waterfall
	block(
		waterfall,
		"WaterfallRockL",
		Vector3.new(4, 6, 5),
		Vector3.new(-53, 3, 48),
		COLORS.stoneDark,
		Enum.Material.Slate
	)
	block(
		waterfall,
		"WaterfallRockR",
		Vector3.new(3, 4, 4),
		Vector3.new(-37, 2, 49),
		COLORS.stoneDark,
		Enum.Material.Slate
	)

	-- ═══════════════════════════════════════════════════
	-- BACKYARD TRAMPOLINE
	-- ═══════════════════════════════════════════════════

	local trampoline = Instance.new("Folder")
	trampoline.Name = "Trampoline"
	trampoline.Parent = house

	-- Circular frame (dark metal ring) — right next to the house so you land on the roof!
	local trampolinePos = Vector3.new(-24, 2, 0) -- beside the back wall
	local trampolineFrame = newPart({
		Name = "TrampolineFrame",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(1.2, 14, 14),
		Color = Color3.fromRGB(50, 50, 55),
		Material = Enum.Material.Metal,
		CFrame = CFrame.new(HOUSE_ORIGIN + trampolinePos) * CFrame.Angles(0, 0, math.rad(90)),
	})
	trampolineFrame.Parent = trampoline

	-- Legs (4 short metal posts)
	for li, legOff in { Vector3.new(5, 0, 5), Vector3.new(-5, 0, 5), Vector3.new(5, 0, -5), Vector3.new(-5, 0, -5) } do
		local leg = newPart({
			Name = ("TrampolineLeg%d"):format(li),
			Size = Vector3.new(1, 2.2, 1),
			Color = Color3.fromRGB(60, 60, 65),
			Material = Enum.Material.Metal,
			Position = HOUSE_ORIGIN + Vector3.new(trampolinePos.X + legOff.X, 1.1, trampolinePos.Z + legOff.Z),
		})
		leg.Parent = trampoline
	end

	-- Bouncy pad (the part players jump on)
	local bouncePad = newPart({
		Name = "BouncePad",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.5, 12, 12),
		Color = Color3.fromRGB(30, 30, 35),
		Material = Enum.Material.Fabric,
		CFrame = CFrame.new(HOUSE_ORIGIN + trampolinePos + Vector3.new(0, 0.3, 0)) * CFrame.Angles(0, 0, math.rad(90)),
	})
	bouncePad.Parent = trampoline

	-- Bounce logic: launch the player UP and slightly toward the roof center
	local BOUNCE_FORCE = 140
	local PUSH_TOWARD_ROOF = 20 -- gentle push so you arc onto the roof
	local debounce: { [Player]: boolean } = {}

	bouncePad.Touched:Connect(function(hit)
		local character = hit.Parent :: Model
		if not character then
			return
		end
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		local rootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not humanoid or not rootPart then
			return
		end

		local player = game:GetService("Players"):GetPlayerFromCharacter(character)
		if not player or debounce[player] then
			return
		end

		debounce[player] = true
		-- Launch up + push toward the house roof (positive X = toward the house)
		rootPart.AssemblyLinearVelocity = Vector3.new(PUSH_TOWARD_ROOF, BOUNCE_FORCE, 0)
		task.delay(0.5, function()
			debounce[player] = nil
		end)
	end)

	-- ═══════════════════════════════════════════════════
	-- INTERIOR — modern contemporary
	-- ═══════════════════════════════════════════════════

	local interior = Instance.new("Folder")
	interior.Name = "Interior"
	interior.Parent = house

	-- Ground floor — dark polished marble (no grass!)
	block(
		interior,
		"GroundFloor",
		Vector3.new(40, 0.5, 54),
		Vector3.new(0, 0.3, 0),
		Color3.fromRGB(45, 42, 40),
		Enum.Material.Marble
	)

	-- Second-floor slab — light hardwood
	block(
		interior,
		"SecondFloorSlab",
		Vector3.new(40, 0.8, 54),
		Vector3.new(0, 18, 0),
		Color3.fromRGB(180, 155, 125),
		Enum.Material.Wood
	)

	-- Ceiling (top of first floor) — white
	block(
		interior,
		"FirstFloorCeiling",
		Vector3.new(40, 0.3, 54),
		Vector3.new(0, 17.85, 0),
		Color3.fromRGB(245, 245, 245),
		Enum.Material.SmoothPlastic
	)

	-- ── First-floor walls (modern white) ──
	block(
		interior,
		"KitchenDivider",
		Vector3.new(0.8, 17, 26),
		Vector3.new(0, 9, -13),
		Color3.fromRGB(240, 240, 240),
		Enum.Material.SmoothPlastic
	)
	block(
		interior,
		"HallwayBackWall",
		Vector3.new(20, 17, 0.8),
		Vector3.new(-10, 9, 0),
		Color3.fromRGB(240, 240, 240),
		Enum.Material.SmoothPlastic
	)

	-- ── Stairs — floating modern style ──
	local stairCount = 12
	local stairHeight = 17.2 / stairCount
	local stairDepth = 3
	for i = 0, stairCount - 1 do
		block(
			interior,
			("Stair%d"):format(i + 1),
			Vector3.new(6, stairHeight * 0.6, stairDepth),
			Vector3.new(12, 0.6 + stairHeight * i + stairHeight / 2, -22 + stairDepth * i),
			Color3.fromRGB(60, 55, 50),
			Enum.Material.Marble
		)
	end
	-- Glass railing
	local stairRail = block(
		interior,
		"StairRail",
		Vector3.new(0.3, 4, stairDepth * stairCount),
		Vector3.new(15, 12, -22 + (stairDepth * stairCount) / 2),
		Color3.fromRGB(200, 220, 235),
		Enum.Material.Glass
	)
	stairRail.Transparency = 0.4

	-- ── Second-floor walls ──
	block(
		interior,
		"BedroomDivider",
		Vector3.new(0.8, 15, 40),
		Vector3.new(-5, 26, 0),
		Color3.fromRGB(240, 240, 240),
		Enum.Material.SmoothPlastic
	)
	makeDoor(interior, "BedroomDoor", Vector3.new(0.8, 9, 5), Vector3.new(-5, 22.5, 10), "left", -90)

	-- ═══════════════════════════════════════════════════
	-- FIRST-FLOOR FURNITURE — modern contemporary
	-- ═══════════════════════════════════════════════════

	-- ── Living room ──
	-- L-shaped sectional sofa (charcoal)
	block(
		interior,
		"SofaMain",
		Vector3.new(12, 2.8, 4.5),
		Vector3.new(-10, 2, 16),
		Color3.fromRGB(55, 55, 58),
		Enum.Material.Fabric
	)
	block(
		interior,
		"SofaBack",
		Vector3.new(12, 1.8, 0.6),
		Vector3.new(-10, 3.5, 18.2),
		Color3.fromRGB(45, 45, 48),
		Enum.Material.Fabric
	)
	block(
		interior,
		"SofaCorner",
		Vector3.new(4.5, 2.8, 8),
		Vector3.new(-15.5, 2, 12),
		Color3.fromRGB(55, 55, 58),
		Enum.Material.Fabric
	)
	-- Accent pillows
	block(
		interior,
		"AccentPillow1",
		Vector3.new(2.5, 1.5, 2),
		Vector3.new(-7, 3.5, 16),
		Color3.fromRGB(200, 160, 60),
		Enum.Material.Fabric
	)
	block(
		interior,
		"AccentPillow2",
		Vector3.new(2.5, 1.5, 2),
		Vector3.new(-13, 3.5, 16),
		Color3.fromRGB(180, 70, 50),
		Enum.Material.Fabric
	)

	-- Glass + marble coffee table
	block(
		interior,
		"CoffeeTableBase",
		Vector3.new(3, 1.2, 2),
		Vector3.new(-10, 0.9, 12),
		Color3.fromRGB(45, 42, 40),
		Enum.Material.Marble
	)
	local coffeeTop = block(
		interior,
		"CoffeeTableTop",
		Vector3.new(7, 0.3, 4),
		Vector3.new(-10, 1.65, 12),
		Color3.fromRGB(190, 215, 225),
		Enum.Material.Glass
	)
	coffeeTop.Transparency = 0.3

	-- Modern TV wall
	block(
		interior,
		"TVConsole",
		Vector3.new(14, 2, 1.5),
		Vector3.new(-10, 1.3, 7),
		Color3.fromRGB(35, 33, 32),
		Enum.Material.SmoothPlastic
	)
	local tvScreen = block(
		interior,
		"TVScreen",
		Vector3.new(12, 7, 0.4),
		Vector3.new(-10, 6, 7),
		Color3.fromRGB(15, 15, 18),
		Enum.Material.SmoothPlastic
	)

	-- ── Interactive TV — browse & jump into popular Roblox games ──
	local TV_CHANNELS = {
		{ name = "Adopt Me!", placeId = 920587237 },
		{ name = "Blox Fruits", placeId = 2753915549 },
		{ name = "Royale High", placeId = 735030788 },
		{ name = "Tower of Hell", placeId = 1962086868 },
		{ name = "Murder Mystery 2", placeId = 142823291 },
	}
	local tvChannel = 1

	-- Surface GUI displayed on the screen face that faces the sofa (+Z = Back)
	local tvGui = Instance.new("SurfaceGui")
	tvGui.Name = "TVGui"
	tvGui.Face = Enum.NormalId.Back
	tvGui.PixelsPerStud = 20
	tvGui.Parent = tvScreen

	local tvBg = Instance.new("Frame")
	tvBg.Size = UDim2.fromScale(1, 1)
	tvBg.BackgroundColor3 = Color3.fromRGB(10, 10, 15)
	tvBg.BorderSizePixel = 0
	tvBg.Parent = tvGui

	local tvThumbnail = Instance.new("ImageLabel")
	tvThumbnail.Name = "Thumbnail"
	tvThumbnail.Size = UDim2.new(1, 0, 0.83, 0)
	tvThumbnail.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
	tvThumbnail.BorderSizePixel = 0
	tvThumbnail.Image = string.format("rbxthumb://type=GameIcon&id=%d&w=512&h=512", TV_CHANNELS[1].placeId)
	tvThumbnail.ScaleType = Enum.ScaleType.Fit
	tvThumbnail.Parent = tvBg

	local tvLabel = Instance.new("TextLabel")
	tvLabel.Size = UDim2.new(1, 0, 0.17, 0)
	tvLabel.Position = UDim2.new(0, 0, 0.83, 0)
	tvLabel.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	tvLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	tvLabel.Text = "📺  " .. TV_CHANNELS[1].name
	tvLabel.Font = Enum.Font.GothamBold
	tvLabel.TextScaled = true
	tvLabel.Parent = tvBg

	-- Press E to change the channel
	local tvChangePrompt = Instance.new("ProximityPrompt")
	tvChangePrompt.ActionText = "Change Channel"
	tvChangePrompt.ObjectText = "TV"
	tvChangePrompt.HoldDuration = 0
	tvChangePrompt.MaxActivationDistance = 10
	tvChangePrompt.RequiresLineOfSight = false
	tvChangePrompt.Parent = tvScreen

	tvChangePrompt.Triggered:Connect(function(_player: Player)
		tvChannel = (tvChannel % #TV_CHANNELS) + 1
		tvThumbnail.Image = string.format("rbxthumb://type=GameIcon&id=%d&w=512&h=512", TV_CHANNELS[tvChannel].placeId)
		tvLabel.Text = "📺  " .. TV_CHANNELS[tvChannel].name
	end)

	-- Hold F to teleport into whatever game is on screen
	local tvJoinPrompt = Instance.new("ProximityPrompt")
	tvJoinPrompt.ActionText = "Join Game"
	tvJoinPrompt.ObjectText = ""
	tvJoinPrompt.HoldDuration = 1.5
	tvJoinPrompt.MaxActivationDistance = 10
	tvJoinPrompt.RequiresLineOfSight = false
	tvJoinPrompt.KeyboardKeyCode = Enum.KeyCode.F
	tvJoinPrompt.Parent = tvScreen

	tvJoinPrompt.Triggered:Connect(function(player: Player)
		task.spawn(function()
			pcall(function()
				game:GetService("TeleportService"):TeleportAsync(TV_CHANNELS[tvChannel].placeId, { player })
			end)
		end)
	end)

	-- Floor lamp
	block(
		interior,
		"FloorLampPole",
		Vector3.new(0.4, 7, 0.4),
		Vector3.new(-3, 4, 18),
		Color3.fromRGB(180, 155, 100),
		Enum.Material.Metal
	)
	lightBlock(interior, "FloorLampShade", Vector3.new(2.5, 2, 2.5), Vector3.new(-3, 8, 18))

	-- ── Kitchen (modern white + marble) ──
	-- Island counter
	block(
		interior,
		"KitchenIsland",
		Vector3.new(12, 3.8, 4),
		Vector3.new(8, 2.2, -16),
		Color3.fromRGB(240, 238, 235),
		Enum.Material.SmoothPlastic
	)
	block(
		interior,
		"IslandTop",
		Vector3.new(12.4, 0.4, 4.4),
		Vector3.new(8, 4.3, -16),
		Color3.fromRGB(220, 215, 210),
		Enum.Material.Marble
	)
	-- Bar stools (3)
	for si = 0, 2 do
		block(
			interior,
			("BarStool%d"):format(si + 1),
			Vector3.new(1.8, 3.2, 1.8),
			Vector3.new(4 + si * 4, 1.9, -12.5),
			Color3.fromRGB(50, 50, 52),
			Enum.Material.Metal
		)
	end

	-- Wall cabinets
	block(
		interior,
		"WallCabinets",
		Vector3.new(16, 4, 1.5),
		Vector3.new(10, 13, -26.5),
		Color3.fromRGB(240, 238, 235),
		Enum.Material.SmoothPlastic
	)
	-- Fridge (stainless steel)
	block(
		interior,
		"Fridge",
		Vector3.new(4, 9, 3.5),
		Vector3.new(18, 5, -25),
		Color3.fromRGB(195, 200, 205),
		Enum.Material.Metal
	)
	-- Fridge handle
	block(
		interior,
		"FridgeHandle",
		Vector3.new(0.2, 5, 0.3),
		Vector3.new(16, 5.5, -23.3),
		Color3.fromRGB(160, 165, 170),
		Enum.Material.Metal
	)

	-- ── Dining area ──
	-- Marble dining table
	block(
		interior,
		"DiningTable",
		Vector3.new(10, 0.5, 5),
		Vector3.new(-10, 3.2, -10),
		Color3.fromRGB(230, 225, 218),
		Enum.Material.Marble
	)
	block(
		interior,
		"DiningTableLeg1",
		Vector3.new(1, 2.7, 1),
		Vector3.new(-14, 1.5, -12),
		Color3.fromRGB(180, 155, 100),
		Enum.Material.Metal
	)
	block(
		interior,
		"DiningTableLeg2",
		Vector3.new(1, 2.7, 1),
		Vector3.new(-6, 1.5, -12),
		Color3.fromRGB(180, 155, 100),
		Enum.Material.Metal
	)
	-- Modern dining chairs (4)
	for ci, chairOff in
		{
			Vector3.new(-6, 0, 0),
			Vector3.new(6, 0, 0),
			Vector3.new(0, 0, -3.5),
			Vector3.new(0, 0, 3.5),
		}
	do
		block(
			interior,
			("DiningChair%d"):format(ci),
			Vector3.new(2, 3.2, 2),
			Vector3.new(-10 + chairOff.X, 1.9, -10 + chairOff.Z),
			Color3.fromRGB(55, 55, 58),
			Enum.Material.SmoothPlastic
		)
	end

	-- ── Accent wall art (first floor) ──
	block(
		interior,
		"WallArt1",
		Vector3.new(0.3, 5, 8),
		Vector3.new(-19.8, 9, 16),
		Color3.fromRGB(40, 80, 120),
		Enum.Material.SmoothPlastic
	)
	block(
		interior,
		"WallArt2",
		Vector3.new(0.3, 4, 4),
		Vector3.new(-19.8, 10, 6),
		Color3.fromRGB(180, 100, 50),
		Enum.Material.SmoothPlastic
	)

	-- ═══════════════════════════════════════════════════
	-- SECOND-FLOOR FURNITURE — modern bedroom + office
	-- ═══════════════════════════════════════════════════

	-- ── Master bedroom ──
	-- Platform bed (low profile, dark wood)
	block(
		interior,
		"BedPlatform",
		Vector3.new(10, 1.2, 11),
		Vector3.new(-14, 19, 12),
		Color3.fromRGB(50, 42, 38),
		Enum.Material.Wood
	)
	block(
		interior,
		"Mattress",
		Vector3.new(8, 1.5, 9.5),
		Vector3.new(-14, 20.1, 12),
		Color3.fromRGB(240, 238, 235),
		Enum.Material.Fabric
	)
	-- Pillows
	block(
		interior,
		"PillowL",
		Vector3.new(3, 0.8, 2.5),
		Vector3.new(-16, 21.1, 16),
		Color3.fromRGB(235, 235, 240),
		Enum.Material.Fabric
	)
	block(
		interior,
		"PillowR",
		Vector3.new(3, 0.8, 2.5),
		Vector3.new(-12, 21.1, 16),
		Color3.fromRGB(235, 235, 240),
		Enum.Material.Fabric
	)
	-- Headboard
	block(
		interior,
		"Headboard",
		Vector3.new(10, 4, 0.6),
		Vector3.new(-14, 21.5, 17.2),
		Color3.fromRGB(65, 55, 48),
		Enum.Material.Wood
	)
	-- Nightstands
	block(
		interior,
		"NightstandL",
		Vector3.new(2.5, 2, 2),
		Vector3.new(-19.5, 19.5, 15),
		Color3.fromRGB(55, 48, 42),
		Enum.Material.Wood
	)
	block(
		interior,
		"NightstandR",
		Vector3.new(2.5, 2, 2),
		Vector3.new(-8.5, 19.5, 15),
		Color3.fromRGB(55, 48, 42),
		Enum.Material.Wood
	)
	-- Bedside lamps
	lightBlock(interior, "BedsideLampL", Vector3.new(1.2, 1.8, 1.2), Vector3.new(-19.5, 21, 15))
	lightBlock(interior, "BedsideLampR", Vector3.new(1.2, 1.8, 1.2), Vector3.new(-8.5, 21, 15))

	-- ── Office / study ──
	-- Sleek desk (white + metal legs)
	block(
		interior,
		"DeskTop",
		Vector3.new(10, 0.4, 4),
		Vector3.new(6, 20.4, 16),
		Color3.fromRGB(240, 238, 235),
		Enum.Material.SmoothPlastic
	)
	block(
		interior,
		"DeskLegL",
		Vector3.new(0.5, 2, 3.5),
		Vector3.new(1.5, 19.2, 16),
		Color3.fromRGB(180, 155, 100),
		Enum.Material.Metal
	)
	block(
		interior,
		"DeskLegR",
		Vector3.new(0.5, 2, 3.5),
		Vector3.new(10.5, 19.2, 16),
		Color3.fromRGB(180, 155, 100),
		Enum.Material.Metal
	)
	-- Monitor
	block(
		interior,
		"Monitor",
		Vector3.new(6, 4, 0.3),
		Vector3.new(6, 23, 17.5),
		Color3.fromRGB(20, 20, 22),
		Enum.Material.SmoothPlastic
	)
	-- Office chair
	block(
		interior,
		"OfficeChair",
		Vector3.new(2.5, 3.5, 2.5),
		Vector3.new(6, 20, 12),
		Color3.fromRGB(40, 40, 42),
		Enum.Material.Fabric
	)

	-- Modern bookshelf (open cubes style)
	block(
		interior,
		"BookshelfFrame",
		Vector3.new(8, 9, 2),
		Vector3.new(7, 23, 20),
		Color3.fromRGB(240, 238, 235),
		Enum.Material.SmoothPlastic
	)
	-- Colored book blocks inside
	block(
		interior,
		"Books1",
		Vector3.new(3, 2, 1.5),
		Vector3.new(5, 20, 20),
		Color3.fromRGB(60, 90, 140),
		Enum.Material.SmoothPlastic
	)
	block(
		interior,
		"Books2",
		Vector3.new(3, 2, 1.5),
		Vector3.new(9, 22, 20),
		Color3.fromRGB(140, 60, 50),
		Enum.Material.SmoothPlastic
	)
	block(
		interior,
		"Books3",
		Vector3.new(2.5, 2, 1.5),
		Vector3.new(5, 24, 20),
		Color3.fromRGB(50, 120, 70),
		Enum.Material.SmoothPlastic
	)

	print("[MainHouse] built main character house at X=-120, Z=0")
end

return MainHouse
