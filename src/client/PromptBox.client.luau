--!strict
-- A friendly "Ask the builder" box (bottom of the screen). Type what you want —
-- "make the cars red", "add a jetpack" — and it goes to the AI builder, which
-- changes the game and then auto-reloads you onto the new version.
--
-- Replaces the old "🔄 Update" button: now you just ask, and it updates itself.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local request = ReplicatedStorage:WaitForChild("RequestBuild", 30) :: RemoteEvent?
local status = ReplicatedStorage:WaitForChild("BuildStatus", 30) :: RemoteEvent?
if not (request and status) then
	return
end

local gui = Instance.new("ScreenGui")
gui.Name = "BuilderGui"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Parent = player:WaitForChild("PlayerGui")

local statusLabel = Instance.new("TextLabel")
statusLabel.Name = "Status"
statusLabel.Size = UDim2.fromOffset(460, 28)
statusLabel.Position = UDim2.new(0.5, -230, 1, -92)
statusLabel.BackgroundTransparency = 1
statusLabel.TextColor3 = Color3.new(1, 1, 1)
statusLabel.TextStrokeTransparency = 0.4
statusLabel.Font = Enum.Font.GothamMedium
statusLabel.TextScaled = true
statusLabel.Text = ""
statusLabel.Parent = gui

local box = Instance.new("TextBox")
box.Name = "Ask"
box.Size = UDim2.fromOffset(380, 44)
box.Position = UDim2.new(0.5, -230, 1, -56)
box.BackgroundColor3 = Color3.fromRGB(30, 30, 36)
box.BackgroundTransparency = 0.1
box.TextColor3 = Color3.new(1, 1, 1)
box.PlaceholderText = "Ask the builder… (e.g. make the cars red)"
box.PlaceholderColor3 = Color3.fromRGB(170, 170, 180)
box.Font = Enum.Font.Gotham
box.TextScaled = true
box.ClearTextOnFocus = false
box.Text = ""
box.Parent = gui

local boxCorner = Instance.new("UICorner")
boxCorner.CornerRadius = UDim.new(0, 10)
boxCorner.Parent = box

local send = Instance.new("TextButton")
send.Name = "Send"
send.Size = UDim2.fromOffset(70, 44)
send.Position = UDim2.new(0.5, 158, 1, -56)
send.BackgroundColor3 = Color3.fromRGB(40, 140, 240)
send.TextColor3 = Color3.new(1, 1, 1)
send.Font = Enum.Font.GothamBold
send.TextScaled = true
send.Text = "Build"
send.Parent = gui

local sendCorner = Instance.new("UICorner")
sendCorner.CornerRadius = UDim.new(0, 10)
sendCorner.Parent = send

local function submit()
	local text = box.Text:gsub("^%s+", ""):gsub("%s+$", "")
	if #text == 0 then
		return
	end
	request:FireServer(text)
	box.Text = ""
end

send.Activated:Connect(submit)
box.FocusLost:Connect(function(enterPressed)
	if enterPressed then
		submit()
	end
end)

status.OnClientEvent:Connect(function(message: string)
	statusLabel.Text = message
end)
