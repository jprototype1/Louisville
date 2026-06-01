--!strict
-- Client camera controller.
-- Walking uses Roblox's default camera. Driving switches to a smooth chase camera
-- so spawned dealership cars are easier to control on keyboard and iPad.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer

local CAMERA_BIND = "BrookhavenVehicleCamera"
local CAMERA_PRIORITY = Enum.RenderPriority.Camera.Value + 1

local CHASE_DISTANCE = 22
local CHASE_HEIGHT = 9
local LOOK_AHEAD = 18
local MIN_FOV = 70
local MAX_FOV = 82
local POSITION_SMOOTHNESS = 10
local FOV_SMOOTHNESS = 8

local activeSeat: VehicleSeat? = nil
local activeRoot: BasePart? = nil
local smoothedCFrame: CFrame? = nil
local smoothedFov = MIN_FOV

local function getCamera(): Camera?
	return workspace.CurrentCamera
end

local function isBrookhavenVehicleSeat(part: BasePart?): boolean
	if not part or not part:IsA("VehicleSeat") then
		return false
	end

	local model = part:FindFirstAncestorOfClass("Model")
	return model ~= nil and string.sub(model.Name, 1, 4) == "Car_"
end

local function resolveVehicleRoot(seat: VehicleSeat): BasePart
	local model = seat:FindFirstAncestorOfClass("Model")
	if model and model.PrimaryPart then
		return model.PrimaryPart
	end

	return seat
end

local function resetDefaultCamera()
	RunService:UnbindFromRenderStep(CAMERA_BIND)

	activeSeat = nil
	activeRoot = nil
	smoothedCFrame = nil
	smoothedFov = MIN_FOV

	local camera = getCamera()
	if not camera then
		return
	end

	camera.CameraType = Enum.CameraType.Custom
	camera.FieldOfView = MIN_FOV

	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		camera.CameraSubject = humanoid
	end
end

local function updateVehicleCamera(dt: number)
	local seat = activeSeat
	local root = activeRoot
	local camera = getCamera()
	if not seat or not root or not seat.Parent or not root.Parent or not camera then
		resetDefaultCamera()
		return
	end

	local occupant = seat.Occupant
	if not occupant or occupant.Parent ~= player.Character then
		resetDefaultCamera()
		return
	end

	camera.CameraType = Enum.CameraType.Scriptable

	local rootCFrame = root.CFrame
	local speed = root.AssemblyLinearVelocity.Magnitude
	local speedScale = math.clamp(speed / 85, 0, 1)
	local distance = CHASE_DISTANCE + speedScale * 6
	local height = CHASE_HEIGHT + speedScale * 3

	local targetPosition = rootCFrame.Position - rootCFrame.LookVector * distance + Vector3.new(0, height, 0)
	local lookAt = rootCFrame.Position + rootCFrame.LookVector * LOOK_AHEAD + Vector3.new(0, 3, 0)
	local targetCFrame = CFrame.lookAt(targetPosition, lookAt)

	local positionAlpha = 1 - math.exp(-POSITION_SMOOTHNESS * dt)
	if smoothedCFrame then
		smoothedCFrame = smoothedCFrame:Lerp(targetCFrame, positionAlpha)
	else
		smoothedCFrame = targetCFrame
	end

	local fovAlpha = 1 - math.exp(-FOV_SMOOTHNESS * dt)
	smoothedFov += ((MIN_FOV + (MAX_FOV - MIN_FOV) * speedScale) - smoothedFov) * fovAlpha

	camera.CFrame = smoothedCFrame
	camera.FieldOfView = smoothedFov
end

local function setVehicleCamera(seat: VehicleSeat)
	RunService:UnbindFromRenderStep(CAMERA_BIND)

	activeSeat = seat
	activeRoot = resolveVehicleRoot(seat)
	smoothedCFrame = nil
	smoothedFov = MIN_FOV

	local camera = getCamera()
	if camera then
		camera.CameraType = Enum.CameraType.Scriptable
	end

	RunService:BindToRenderStep(CAMERA_BIND, CAMERA_PRIORITY, updateVehicleCamera)
end

local function bindCharacter(character: Model)
	resetDefaultCamera()

	local humanoid = character:WaitForChild("Humanoid", 10)
	if not humanoid or not humanoid:IsA("Humanoid") then
		return
	end

	humanoid.Seated:Connect(function(isSeated: boolean, seatPart: BasePart?)
		if isSeated and isBrookhavenVehicleSeat(seatPart) then
			setVehicleCamera(seatPart :: VehicleSeat)
		else
			resetDefaultCamera()
		end
	end)
end

if player.Character then
	task.spawn(bindCharacter, player.Character)
end

player.CharacterAdded:Connect(bindCharacter)
