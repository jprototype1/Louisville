--!strict
-- A floating "🔄 Update" button (top-right). Tap it to load the latest published
-- version of the game and land right back where you are now — no leaving/rejoining.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local remote = ReplicatedStorage:WaitForChild("RequestReload", 30) :: RemoteEvent?
if not remote then
	return
end

local gui = Instance.new("ScreenGui")
gui.Name = "UpdateGui"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Parent = player:WaitForChild("PlayerGui")

local btn = Instance.new("TextButton")
btn.Name = "UpdateButton"
btn.Size = UDim2.fromOffset(150, 52)
btn.Position = UDim2.new(1, -162, 0, 12)
btn.BackgroundColor3 = Color3.fromRGB(40, 140, 240)
btn.AutoButtonColor = true
btn.Text = "🔄 Update"
btn.TextColor3 = Color3.new(1, 1, 1)
btn.Font = Enum.Font.GothamBold
btn.TextScaled = true
btn.Parent = gui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 12)
corner.Parent = btn

btn.Activated:Connect(function()
	btn.Text = "Updating…"
	btn.BackgroundColor3 = Color3.fromRGB(90, 90, 95)
	remote:FireServer()
end)
