--!strict
-- In-game prompting: a player types a build request → we hand it to the AI builder
-- (AiBridge) → poll until it finishes → auto-reload everyone onto the new build.
--
-- Replaces the old manual "Update" button: the loop is now prompt → build → reload,
-- all from inside the game.
--
-- ⚠️ SECURITY: this lets a player drive an agent that edits & publishes your LIVE
-- game. Access is locked to an allowlist of Roblox UserIds. Add yours below — find
-- it at https://www.roblox.com/users/profile (the number in the URL). While the
-- list is empty, the feature is inert (every request is denied).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AiBridge = require(script.Parent.AiBridge)
local Reload = require(script.Parent.Reload)

-- Who may prompt the builder from in-game. Add UserIds here.
local ALLOWED_USER_IDS: { [number]: boolean } = {
	[3609872486] = true, -- ThatGirlMehtab
}

local POLL_EVERY = 5 -- seconds between status checks
local MAX_POLLS = 60 -- give up after ~5 minutes

local AiPrompt = {}

local function event(name: string): RemoteEvent
	local e = ReplicatedStorage:FindFirstChild(name)
	if not e then
		e = Instance.new("RemoteEvent")
		e.Name = name
		e.Parent = ReplicatedStorage
	end
	return e :: RemoteEvent
end

local busyWithRequest = false

local function tell(player: Player, message: string)
	event("BuildStatus"):FireClient(player, message)
end

-- Poll the session until the agent's turn finishes, then reload everyone.
local function watchAndReload(player: Player, sessionId: string)
	local sawBusy = false
	for _ = 1, MAX_POLLS do
		task.wait(POLL_EVERY)
		local status = AiBridge.status(sessionId)
		if status then
			-- Verified fields: `promptRunning` (bool) + `queueDepth`, and `status`
			-- transitions to "finished" when the agent's turn (incl. publish) is done.
			local running = status.promptRunning == true or (tonumber(status.queueDepth) or 0) > 0
			local finished = tostring(status.status or ""):lower() == "finished"
			if running then
				sawBusy = true
			elseif sawBusy or finished then
				tell(player, "Done! Updating the game now… 🚀")
				task.wait(2) -- small grace for the new version to start rolling out
				Reload.reloadAll()
				busyWithRequest = false
				return
			end
		end
	end
	tell(player, "Hmm, that took too long — try again? ⏳")
	busyWithRequest = false
end

local function onRequest(player: Player, prompt: any)
	if not ALLOWED_USER_IDS[player.UserId] then
		tell(player, "Only the builders can do that — ask the operator to add your UserId. 🔒")
		return
	end
	if type(prompt) ~= "string" or #prompt == 0 or #prompt > 500 then
		tell(player, "Type what you'd like me to build (a sentence or two). ✏️")
		return
	end
	if busyWithRequest then
		tell(player, "Still working on the last request — one sec! ⏳")
		return
	end
	busyWithRequest = true
	tell(player, "On it! Sending to the builder… 🔧")

	task.spawn(function()
		local sessionId = AiBridge.send(prompt)
		if not sessionId then
			tell(player, "Couldn't reach the builder. (Is HTTP on + the token set?) 😕")
			busyWithRequest = false
			return
		end
		tell(player, "Building it now… 🛠️")
		watchAndReload(player, sessionId)
	end)
end

function AiPrompt.start()
	event("RequestBuild").OnServerEvent:Connect(onRequest)
	event("BuildStatus") -- ensure it exists for the client
end

return AiPrompt
