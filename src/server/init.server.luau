-- Server entry point. Builds the explorable world on startup.
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local function runSystem(name: string, callback: () -> ())
	local ok, err = pcall(callback)
	if not ok then
		warn(("[Server] %s failed: %s"):format(name, tostring(err)))
	end
end

runSystem("WorldBuilder", function()
	require(script.WorldBuilder).build(Workspace)
end)

runSystem("MainHouse", function()
	require(script.MainHouse).build(Workspace)
end)

runSystem("Dealership", function()
	require(script.Dealership).build(Workspace)
end)

runSystem("Garage", function()
	require(script.Garage).start()
end)

-- Super jump! Crank up jump power so you can reach space 🚀
local SUPER_JUMP_POWER = 300

local function boostJump(character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10)
	if humanoid and humanoid:IsA("Humanoid") then
		humanoid.UseJumpPower = true
		humanoid.JumpPower = SUPER_JUMP_POWER
	end
end

Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(boostJump)
	if player.Character then
		boostJump(player.Character)
	end
end)
