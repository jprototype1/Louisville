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
local buildLog = ReplicatedStorage:WaitForChild("BuildLog", 30) :: RemoteEvent?
if not (request and status and buildLog) then
	return
end

local gui = Instance.new("ScreenGui")
gui.Name = "BuilderGui"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Parent = player:WaitForChild("PlayerGui")

-- Live progress feed: streamed transcript lines from the builder appear here.
local logPanel = Instance.new("ScrollingFrame")
logPanel.Name = "Log"
logPanel.Size = UDim2.fromOffset(460, 176)
logPanel.Position = UDim2.new(0.5, -230, 1, -280)
logPanel.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
logPanel.BackgroundTransparency = 0.25
logPanel.BorderSizePixel = 0
logPanel.ScrollBarThickness = 4
logPanel.AutomaticCanvasSize = Enum.AutomaticSize.Y
logPanel.CanvasSize = UDim2.new()
logPanel.Visible = false
logPanel.Parent = gui

local logCorner = Instance.new("UICorner")
logCorner.CornerRadius = UDim.new(0, 10)
logCorner.Parent = logPanel

local logLayout = Instance.new("UIListLayout")
logLayout.SortOrder = Enum.SortOrder.LayoutOrder
logLayout.Padding = UDim.new(0, 2)
logLayout.Parent = logPanel

local logPad = Instance.new("UIPadding")
logPad.PaddingLeft = UDim.new(0, 10)
logPad.PaddingRight = UDim.new(0, 10)
logPad.PaddingTop = UDim.new(0, 6)
logPad.PaddingBottom = UDim.new(0, 6)
logPad.Parent = logPanel

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

local MAX_LINES = 40
local lineOrder = 0

local function appendLog(text: string)
	logPanel.Visible = true
	lineOrder += 1
	local label = Instance.new("TextLabel")
	label.Name = "L" .. lineOrder
	label.LayoutOrder = lineOrder
	label.Size = UDim2.new(1, 0, 0, 18)
	label.AutomaticSize = Enum.AutomaticSize.Y
	label.BackgroundTransparency = 1
	label.TextColor3 = Color3.fromRGB(225, 225, 230)
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextWrapped = true
	label.Font = Enum.Font.Gotham
	label.TextSize = 14
	label.Text = text
	label.Parent = logPanel
	-- Trim oldest lines so the feed doesn't grow forever.
	local labels = {}
	for _, c in logPanel:GetChildren() do
		if c:IsA("TextLabel") then
			table.insert(labels, c)
		end
	end
	if #labels > MAX_LINES then
		table.sort(labels, function(a, b)
			return a.LayoutOrder < b.LayoutOrder
		end)
		labels[1]:Destroy()
	end
	logPanel.CanvasPosition = Vector2.new(0, logPanel.AbsoluteCanvasSize.Y)
end

local function clearLog()
	for _, c in logPanel:GetChildren() do
		if c:IsA("TextLabel") then
			c:Destroy()
		end
	end
end

local function submit()
	local text = box.Text:gsub("^%s+", ""):gsub("%s+$", "")
	if #text == 0 then
		return
	end
	clearLog()
	logPanel.Visible = true
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

buildLog.OnClientEvent:Connect(function(line: string)
	appendLog(line)
end)
