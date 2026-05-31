-- Server entry point. Builds the explorable world on startup.
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
