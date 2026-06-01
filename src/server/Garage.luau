--!strict
-- Garage parking. Uses the storage pads the house build exposes at
-- Workspace.MainCharacterHouse.GarageStoragePads (parts with attribute
-- CarStoragePad=true and PadIndex=1/2).
--
-- Behaviour:
--   * Drive your car onto a free pad and come to a stop -> it auto-parks (snaps
--     onto the pad, you hop out, a "Take out" prompt appears on the car).
--   * Trigger that prompt -> the car unfreezes and you're seated, ready to drive.
--   * Best-effort: which car is on which pad is saved per player and restored on
--     rejoin (guarded so it's harmless if DataStores are unavailable).

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local CarFactory = require(script.Parent.CarFactory)
local CarModels = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("CarModels"))
local CarRegistry = require(script.Parent.CarRegistry)
type CarSpec = CarModels.CarSpec
type Entry = CarRegistry.Entry

local Garage = {}

local PARK_SPEED = 6 -- studs/s the car must be under to count as "stopped"
local PARK_DWELL = 0.5 -- seconds of sitting still on a pad before it parks

-- spec lookup by id, for restoring saved cars.
local specById: { [string]: CarSpec } = {}
for _, spec in CarModels do
	specById[spec.id] = spec
end

-- Which player has each pad taken.
local padOccupant: { [BasePart]: Player } = {}
-- Per-player time spent stopped on a pad this run.
local dwell: { [Player]: number } = {}

local store: DataStore? = nil
pcall(function()
	store = DataStoreService:GetDataStore("BrookhavenGarage")
end)

local cachedPads: { BasePart }? = nil

local function getPads(): { BasePart }
	if cachedPads and #cachedPads > 0 then
		return cachedPads
	end
	local pads: { BasePart } = {}
	local house = workspace:FindFirstChild("MainCharacterHouse")
	local folder = house and house:FindFirstChild("GarageStoragePads")
	if folder then
		for _, p in folder:GetChildren() do
			if p:IsA("BasePart") and p:GetAttribute("CarStoragePad") then
				table.insert(pads, p)
			end
		end
	end
	cachedPads = pads
	return pads
end

local function padByIndex(index: number): BasePart?
	for _, pad in getPads() do
		if pad:GetAttribute("PadIndex") == index then
			return pad
		end
	end
	return nil
end

-- Height to lift the car so its wheels rest on the pad surface.
local function parkLift(pad: BasePart, spec: CarSpec): number
	return pad.Size.Y / 2 + spec.bodySize.Y / 2 + spec.wheelDiameter / 2
end

-- ── persistence (best effort) ────────────────────────────────────────────────
local function savePark(player: Player, specId: string, padIndex: number)
	local s = store
	if not s then
		return
	end
	task.spawn(function()
		pcall(function()
			s:SetAsync("car_" .. player.UserId, { specId = specId, padIndex = padIndex })
		end)
	end)
end

local function clearPark(player: Player)
	local s = store
	if not s then
		return
	end
	task.spawn(function()
		pcall(function()
			s:RemoveAsync("car_" .. player.UserId)
		end)
	end)
end

-- ── core actions ─────────────────────────────────────────────────────────────
local retrieve -- forward declaration

local function addRetrievePrompt(player: Player, entry: Entry)
	local chassis = entry.model.PrimaryPart
	if not chassis then
		return
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "RetrievePrompt"
	prompt.ActionText = "Take out the " .. entry.spec.name
	prompt.ObjectText = "Garage"
	prompt.HoldDuration = 0.3
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.Parent = chassis
	prompt.Triggered:Connect(function(triggerer)
		if triggerer == player then
			retrieve(player, entry)
		end
	end)
end

-- Snap a (frozen) car onto a pad and mark it stored.
local function placeOnPad(model: Model, spec: CarSpec, pad: BasePart)
	model:SetAttribute("Stored", true)
	model:PivotTo(pad.CFrame * CFrame.new(0, parkLift(pad, spec), 0))
	CarFactory.freeze(model)
end

local function eject(player: Player, pad: BasePart, seat: VehicleSeat?)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	if seat then
		local weld = seat:FindFirstChild("SeatWeld")
		if weld then
			weld:Destroy()
		end
	end
	humanoid.Sit = false
	local root = humanoid.RootPart
	if root then
		root.CFrame = pad.CFrame * CFrame.new(0, 4, 9)
	end
end

local function park(player: Player, entry: Entry, pad: BasePart)
	local model = entry.model
	local chassis = model.PrimaryPart
	-- Take physics ownership back from the client before we reposition it.
	if chassis then
		pcall(function()
			chassis:SetNetworkOwner(nil)
		end)
	end

	eject(player, pad, model:FindFirstChild("VehicleSeat") :: VehicleSeat?)
	placeOnPad(model, entry.spec, pad)

	entry.stored = true
	entry.pad = pad
	padOccupant[pad] = player
	dwell[player] = nil

	addRetrievePrompt(player, entry)
	savePark(player, entry.spec.id, pad:GetAttribute("PadIndex") :: number)
end

function retrieve(player: Player, entry: Entry)
	local model = entry.model
	if entry.pad then
		padOccupant[entry.pad] = nil
	end
	entry.stored = false
	entry.pad = nil
	model:SetAttribute("Stored", false)

	local chassis = model.PrimaryPart
	local prompt = chassis and chassis:FindFirstChild("RetrievePrompt")
	if prompt then
		prompt:Destroy()
	end

	-- Unfreeze every part so physics resumes.
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = false
		end
	end

	-- Restored-from-save cars never had their drive loop started; safe to call
	-- because activate() is idempotent.
	CarFactory.activate(model, entry.spec)

	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local seat = model:FindFirstChild("VehicleSeat") :: VehicleSeat?
	if seat and humanoid then
		seat:Sit(humanoid)
	end

	clearPark(player)
end

-- ── restore on join ──────────────────────────────────────────────────────────
local function restoreSavedCar(player: Player)
	local s = store
	if not s then
		return
	end
	local data: any
	local ok = pcall(function()
		data = s:GetAsync("car_" .. player.UserId)
	end)
	if not ok or type(data) ~= "table" then
		return
	end
	local spec = specById[data.specId]
	local pad = padByIndex(data.padIndex)
	if not spec or not pad or padOccupant[pad] then
		return
	end

	local model = CarFactory.create(spec, pad.CFrame * CFrame.new(0, parkLift(pad, spec), 0))
	model.Parent = workspace
	local entry = CarRegistry.set(player, model, spec)
	placeOnPad(model, spec, pad)
	entry.stored = true
	entry.pad = pad
	padOccupant[pad] = player
	addRetrievePrompt(player, entry)
end

-- ── auto-park watcher ────────────────────────────────────────────────────────
local function isOverPad(chassis: BasePart, pad: BasePart): boolean
	local rel = pad.CFrame:PointToObjectSpace(chassis.Position)
	return math.abs(rel.X) < pad.Size.X / 2 and math.abs(rel.Z) < pad.Size.Z / 2
end

function Garage.start()
	RunService.Heartbeat:Connect(function(dt)
		local pads = getPads()
		if #pads == 0 then
			return
		end
		for _, player in Players:GetPlayers() do
			local entry = CarRegistry.get(player)
			if entry and not entry.stored and entry.model.Parent then
				local chassis = entry.model.PrimaryPart
				local parked = false
				if chassis and chassis.AssemblyLinearVelocity.Magnitude < PARK_SPEED then
					for _, pad in pads do
						if not padOccupant[pad] and isOverPad(chassis, pad) then
							dwell[player] = (dwell[player] or 0) + dt
							if dwell[player] >= PARK_DWELL then
								park(player, entry, pad)
							end
							parked = true
							break
						end
					end
				end
				if not parked then
					dwell[player] = nil
				end
			end
		end
	end)

	Players.PlayerAdded:Connect(restoreSavedCar)
	for _, player in Players:GetPlayers() do
		task.spawn(restoreSavedCar, player)
	end

	-- Free a pad if its owner leaves (the model is destroyed by the Dealership's
	-- PlayerRemoving handler).
	Players.PlayerRemoving:Connect(function(player)
		dwell[player] = nil
		for pad, owner in padOccupant do
			if owner == player then
				padOccupant[pad] = nil
			end
		end
	end)
end

return Garage
