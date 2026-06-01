--!strict
-- Auto-reload: jump everyone onto the freshest published build in one hop, landing
-- back where they were. There is no in-place hot-reload in published Roblox games,
-- so "reload" = teleport to this same place (which loads the newest build) carrying
-- each player's position across.
--
--   * AiPrompt calls Reload.reloadAll() once the AI builder has published a change.
--   * We stamp the CURRENT build sha into the teleport data. On arrival the new
--     server compares its own BuildInfo.sha: if it's the SAME, Roblox dropped us
--     back onto a stale server (a known matchmaking quirk) — so we re-hop, up to a
--     few tries. If it DIFFERS, we got the new build → settle and restore position.
--   * Position is also saved to a DataStore on leave, so a normal rejoin restores it.
--
-- (The old manual "🔄 Update" button was removed in favor of this automatic flow.)

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")

local BuildInfo = require(ReplicatedStorage.Shared.BuildInfo)

local MAX_REHOPS = 3 -- give up after this many stale-server landings (avoids loops)
local REHOP_DELAY = 4 -- seconds to wait before re-hopping (lets the new build roll out)

local Reload = {}

local store: DataStore? = nil
pcall(function()
	store = DataStoreService:GetDataStore("BrookhavenLastPosition")
end)

local function rootOf(player: Player): BasePart?
	local char = player.Character
	return char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function teleport(player: Player, attempt: number)
	local hrp = rootOf(player)
	local pos = hrp and hrp.Position
	local opts = Instance.new("TeleportOptions")
	opts:SetTeleportData({
		pos = pos and { pos.X, pos.Y, pos.Z } or nil,
		fromSha = BuildInfo.sha,
		attempt = attempt,
	})
	local ok, err = pcall(function()
		TeleportService:TeleportAsync(game.PlaceId, { player }, opts)
	end)
	if not ok then
		warn("[Reload] teleport failed (works only in the published game): " .. tostring(err))
	end
end

-- Reload every player onto the newest build. Called after the AI builder publishes.
function Reload.reloadAll()
	for _, player in Players:GetPlayers() do
		teleport(player, 1)
	end
end

local function placePlayer(character: Model, pos: { number })
	local hrp = character:WaitForChild("HumanoidRootPart", 5) :: BasePart?
	if hrp then
		hrp.CFrame = CFrame.new(pos[1], pos[2] + 3, pos[3])
	end
end

local function onCharacter(player: Player, character: Model)
	local data = player:GetJoinData().TeleportData

	-- Arrived from an auto-reload hop?
	if type(data) == "table" then
		local d = data :: any
		if type(d.pos) == "table" then
			placePlayer(character, d.pos)
		end
		-- Same build as we left → stale server, re-hop (bounded).
		if d.fromSha and d.fromSha == BuildInfo.sha and (d.attempt or 1) < MAX_REHOPS then
			task.delay(REHOP_DELAY, function()
				if player.Parent then
					teleport(player, (d.attempt or 1) + 1)
				end
			end)
		end
		return
	end

	-- Normal join: restore last saved position.
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
