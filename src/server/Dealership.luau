--!strict
-- Builds the car dealership: a showroom on the +X side of the map with the lineup
-- on display. Each display car has a ProximityPrompt (shows a tap button on iPad);
-- triggering it spawns a fresh drivable copy outside and seats the player in it.

local Players = game:GetService("Players")

local CarFactory = require(script.Parent.CarFactory)
local CarModels = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("CarModels"))
local CarRegistry = require(script.Parent.CarRegistry)
type CarSpec = CarModels.CarSpec

local Dealership = {}

-- Showroom sits off to the +X side so it never overlaps spawn (origin) or the
-- house (which the other build owns, on the -X side).
local SHOWROOM_CENTER = Vector3.new(120, 0, 0)
local FLOOR_SIZE = Vector3.new(46, 1, 64)
local DELIVERY_POINT = Vector3.new(120, 0, 44) -- in front of the showroom

local function newPart(name: string, props: { [string]: any }): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		(part :: any)[key] = value
	end
	return part
end

local function chassisHeight(spec: CarSpec): number
	return spec.bodySize.Y / 2 + spec.wheelDiameter / 2
end

local function giveCar(player: Player, spec: CarSpec)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end

	-- Replace any car this player already has out (driving or parked).
	local existing = CarRegistry.get(player)
	if existing then
		existing.model:Destroy()
		CarRegistry.clear(player)
	end

	local spawnPos = DELIVERY_POINT + Vector3.new(0, chassisHeight(spec) + 1, 0)
	-- Face the car toward the middle of the map so the player drives out into it.
	local facing = CFrame.lookAt(spawnPos, spawnPos - Vector3.new(0, 0, 1))
	local car = CarFactory.create(spec, facing)
	car.Parent = workspace
	CarFactory.activate(car, spec)
	CarRegistry.set(player, car, spec)

	local seat = car:FindFirstChild("VehicleSeat") :: VehicleSeat
	if seat then
		seat:Sit(humanoid)
	end
end

local function buildShowroom(): Folder
	local folder = Instance.new("Folder")
	folder.Name = "Dealership"

	local floor = newPart("Floor", {
		Size = FLOOR_SIZE,
		Material = Enum.Material.SmoothPlastic,
		Color = Color3.fromRGB(235, 235, 240),
		Position = SHOWROOM_CENTER + Vector3.new(0, 0.5, 0),
	})
	floor.Parent = folder

	-- Four corner pillars + a back wall, just enough to read as a building.
	local hx, hz = FLOOR_SIZE.X / 2, FLOOR_SIZE.Z / 2
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			local pillar = newPart("Pillar", {
				Size = Vector3.new(2, 18, 2),
				Material = Enum.Material.Concrete,
				Color = Color3.fromRGB(200, 200, 205),
				Position = SHOWROOM_CENTER + Vector3.new(sx * (hx - 1), 9, sz * (hz - 1)),
			})
			pillar.Parent = folder
		end
	end

	local backWall = newPart("BackWall", {
		Size = Vector3.new(FLOOR_SIZE.X, 18, 1),
		Material = Enum.Material.Brick,
		Color = Color3.fromRGB(150, 80, 60),
		Position = SHOWROOM_CENTER + Vector3.new(0, 9, -hz),
	})
	backWall.Parent = folder

	local roof = newPart("Roof", {
		Size = Vector3.new(FLOOR_SIZE.X + 2, 1, FLOOR_SIZE.Z + 2),
		Material = Enum.Material.Metal,
		Color = Color3.fromRGB(90, 90, 95),
		Position = SHOWROOM_CENTER + Vector3.new(0, 18, 0),
	})
	roof.Parent = folder

	-- Lit sign across the front.
	local sign = newPart("Sign", {
		Size = Vector3.new(FLOOR_SIZE.X, 5, 1),
		Material = Enum.Material.SmoothPlastic,
		Color = Color3.fromRGB(20, 20, 25),
		Position = SHOWROOM_CENTER + Vector3.new(0, 20.5, hz),
	})
	sign.Parent = folder

	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.Parent = sign
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = "BROOKHAVEN MOTORS"
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = Color3.fromRGB(255, 220, 120)
	label.Parent = gui

	return folder
end

local function addDisplayCar(folder: Folder, spec: CarSpec, slot: number, total: number)
	-- Spread the lineup left-to-right across the back of the showroom.
	local spacing = FLOOR_SIZE.X / (total + 1)
	local x = SHOWROOM_CENTER.X - FLOOR_SIZE.X / 2 + spacing * slot
	local z = SHOWROOM_CENTER.Z - FLOOR_SIZE.Z / 4
	local base = Vector3.new(x, chassisHeight(spec), z)

	-- Pedestal under the car.
	local pedestal = newPart("Pedestal", {
		Size = Vector3.new(spec.bodySize.X + 3, 1, spec.bodySize.Z + 3),
		Material = Enum.Material.Marble,
		Color = Color3.fromRGB(230, 230, 235),
		Position = Vector3.new(x, 1.5, z),
	})
	pedestal.Parent = folder

	-- Showroom spotlight above each car. The place has black ambient, so without
	-- this the cars sit in pure shadow under the roof.
	local lamp = newPart("Lamp", {
		Size = Vector3.new(3, 0.4, 3),
		Material = Enum.Material.Neon,
		Color = Color3.fromRGB(255, 250, 235),
		Position = Vector3.new(x, 15.5, z),
	})
	lamp.Parent = folder
	local spot = Instance.new("SpotLight")
	spot.Face = Enum.NormalId.Bottom
	spot.Angle = 100
	spot.Brightness = 6
	spot.Range = 28
	spot.Color = Color3.fromRGB(255, 250, 235)
	spot.Parent = lamp
	-- A little omnidirectional fill so the sides aren't black.
	local fill = Instance.new("PointLight")
	fill.Brightness = 2.5
	fill.Range = 24
	fill.Color = Color3.fromRGB(255, 250, 235)
	fill.Parent = lamp

	-- A static display copy, frozen so it can't roll off. Face it toward the front.
	local display = CarFactory.create(spec, CFrame.lookAt(base, base + Vector3.new(0, 0, 1)))
	CarFactory.freeze(display)
	display.Name = "Display_" .. spec.id
	display.Parent = folder

	-- Floating name above the car.
	local nameLabel = Instance.new("Part")
	nameLabel.Name = "NameAnchor"
	nameLabel.Size = Vector3.new(1, 1, 1)
	nameLabel.Transparency = 1
	nameLabel.CanCollide = false
	nameLabel.Anchored = true
	nameLabel.Position = base + Vector3.new(0, 6, 0)
	nameLabel.Parent = folder

	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromScale(8, 2)
	billboard.AlwaysOnTop = true
	billboard.Parent = nameLabel
	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.Text = spec.name
	text.TextScaled = true
	text.Font = Enum.Font.GothamBold
	text.TextColor3 = Color3.fromRGB(255, 255, 255)
	text.TextStrokeTransparency = 0
	text.Parent = billboard

	-- ProximityPrompt: walk up and tap/hold to get the car. Works on iPad.
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Drive the " .. spec.name
	prompt.ObjectText = "Brookhaven Motors"
	prompt.HoldDuration = 0.3
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.Parent = display.PrimaryPart

	prompt.Triggered:Connect(function(player)
		giveCar(player, spec)
	end)
end

function Dealership.build(parent: Instance)
	local existing = parent:FindFirstChild("Dealership")
	if existing then
		existing:Destroy()
	end

	local folder = buildShowroom()
	for slot, spec in CarModels do
		addDisplayCar(folder, spec, slot, #CarModels)
	end
	folder.Parent = parent

	print(("[Dealership] showroom ready with %d cars"):format(#CarModels))
end

-- Clean up a player's car when they leave so wrecks don't pile up.
Players.PlayerRemoving:Connect(function(player)
	local entry = CarRegistry.get(player)
	if entry then
		entry.model:Destroy()
	end
	CarRegistry.clear(player)
end)

return Dealership
