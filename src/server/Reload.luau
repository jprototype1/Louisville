--!strict
-- Tighter test loop: jump to the latest published version in one tap, landing
-- back where you were.
--   * The "🔄 Update" button fires RequestReload → we teleport the player to THIS
--     same place, which loads the newest published build, carrying their position
--     in teleport data; on arrival we drop them right back there.
--   * Position is also saved to a DataStore on leave, so a normal rejoin (closing
--     and reopening the app) also restores where they were.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")

local Reload = {}

local store: DataStore? = nil
pcall(function()
	store = DataStoreService:GetDataStore("BrookhavenLastPosition")
end)

local function remote(): RemoteEvent
	local r = ReplicatedStorage:FindFirstChild("RequestReload")
	if not r then
		r = Instance.new("RemoteEvent")
		r.Name = "RequestReload"
		r.Parent = ReplicatedStorage
	end
	return r :: RemoteEvent
end

local function rootOf(player: Player): BasePart?
	local char = player.Character
	return char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
end

-- Tap Update → reload into the freshest published server, keeping position.
local function reload(player: Player)
	local hrp = rootOf(player)
	local pos = hrp and hrp.Position
	local opts = Instance.new("TeleportOptions")
	opts:SetTeleportData({ pos = pos and { pos.X, pos.Y, pos.Z } or nil })
	local ok, err = pcall(function()
		TeleportService:TeleportAsync(game.PlaceId, { player }, opts)
	end)
	if not ok then
		warn("[Reload] teleport failed (works only in the published game): " .. tostring(err))
	end
end

local function placePlayer(character: Model, pos: { number })
	local hrp = character:WaitForChild("HumanoidRootPart", 5) :: BasePart?
	if hrp then
		hrp.CFrame = CFrame.new(pos[1], pos[2] + 3, pos[3])
	end
end

local function onCharacter(player: Player, character: Model)
	-- Prefer fresh teleport data (Update button); else fall back to saved position.
	local data = player:GetJoinData().TeleportData
	if type(data) == "table" and type((data :: any).pos) == "table" then
		placePlayer(character, (data :: any).pos)
		return
	end
	if store then
		task.spawn(function()
			local saved
			local ok = pcall(function()
				saved = (store :: DataStore):GetAsync("pos_" .. player.UserId)
			end)
			if ok and type(saved) == "table" then
				placePlayer(character, saved)
			end
		end)
	end
end

function Reload.start()
	remote().OnServerEvent:Connect(reload)

	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function(char)
			onCharacter(player, char)
		end)
		if player.Character then
			onCharacter(player, player.Character)
		end
	end)

	-- Save position on leave for normal rejoins.
	Players.PlayerRemoving:Connect(function(player)
		local hrp = rootOf(player)
		if hrp and store then
			local p = hrp.Position
			pcall(function()
				(store :: DataStore):SetAsync("pos_" .. player.UserId, { p.X, p.Y, p.Z })
			end)
		end
	end)
end

return Reload
