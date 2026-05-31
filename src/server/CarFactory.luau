--!strict
-- Builds drivable cars from a CarSpec. Each car is a physics assembly:
--   * a chassis with a VehicleSeat (the driver sits here)
--   * 2 rear wheels on HingeConstraint MOTORS  -> drive (forward/reverse)
--   * 2 front wheels on a steering knuckle:
--         vertical Servo hinge -> steering, plus a free Hinge -> rolling
--
-- Driving is force-based and physical: real acceleration, momentum, and grip.
-- A Heartbeat loop reads the seat's Throttle/Steer (which works with keyboard AND
-- the iPad touch thumbstick) and feeds the constraints.

local PhysicsService = game:GetService("PhysicsService")
local RunService = game:GetService("RunService")

local CarModels = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("CarModels"))
type CarSpec = CarModels.CarSpec

local CarFactory = {}

local COLLISION_GROUP = "BrookhavenCar"
-- Register a collision group so a car's own parts don't collide with each other
-- (wheels would otherwise jam against the chassis). Guarded so the live-sync
-- re-running this module never errors.
pcall(function()
	PhysicsService:RegisterCollisionGroup(COLLISION_GROUP)
	PhysicsService:CollisionGroupSetCollidable(COLLISION_GROUP, COLLISION_GROUP, false)
end)

local WHEEL_PHYSICS = PhysicalProperties.new(2, 2, 0, 100, 1) -- grippy
local CHASSIS_PHYSICS = PhysicalProperties.new(3.5, 0.3, 0, 1, 1) -- heavy, slick

local function newPart(props: { [string]: any }): Part
	local part = Instance.new("Part")
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.CollisionGroup = COLLISION_GROUP
	for key, value in props do
		(part :: any)[key] = value
	end
	return part
end

local function weld(a: BasePart, b: BasePart)
	local w = Instance.new("WeldConstraint")
	w.Part0 = a
	w.Part1 = b
	w.Parent = a
end

local function attachment(parent: BasePart, cframe: CFrame): Attachment
	local att = Instance.new("Attachment")
	att.CFrame = cframe
	att.Parent = parent
	return att
end

-- Build one wheel + its constraints. Rear wheels are powered; front wheels steer.
local function buildWheel(model: Model, chassis: Part, spec: CarSpec, lateral: number, longitudinal: number, isFront: boolean)
	local radius = spec.wheelDiameter
	-- Local mount point on the chassis: out to the side, at the chassis bottom.
	local offset = Vector3.new(lateral, -spec.bodySize.Y / 2, longitudinal)
	local wheelCFrame = chassis.CFrame * CFrame.new(offset)

	local wheel = newPart({
		Name = "Wheel",
		Shape = Enum.PartType.Cylinder, -- long axis is local X = the axle
		Size = Vector3.new(spec.wheelWidth, radius, radius),
		Color = Color3.fromRGB(25, 25, 25),
		Material = Enum.Material.SmoothPlastic,
		CanCollide = true,
		CustomPhysicalProperties = WHEEL_PHYSICS,
		CFrame = wheelCFrame,
	})
	wheel.Parent = model

	if not isFront then
		-- Rear: single motor hinge spinning about the car's left-right (X) axis.
		local chassisAtt = attachment(chassis, CFrame.new(offset))
		local wheelAtt = attachment(wheel, CFrame.new())
		local hinge = Instance.new("HingeConstraint")
		hinge.Attachment0 = chassisAtt
		hinge.Attachment1 = wheelAtt
		hinge.ActuatorType = Enum.ActuatorType.Motor
		hinge.MotorMaxTorque = spec.torque
		hinge.MotorMaxAcceleration = math.huge
		hinge.AngularVelocity = 0
		hinge:SetAttribute("Role", "Drive")
		hinge.Parent = chassis
		return
	end

	-- Front: a small steering knuckle held to the chassis by a vertical Servo hinge.
	local knuckle = newPart({
		Name = "Knuckle",
		Size = Vector3.new(0.6, 0.6, 0.6),
		Transparency = 1,
		CanCollide = false,
		Massless = true,
		CFrame = wheelCFrame,
	})
	knuckle.Parent = model

	-- Steering hinge: primary axis pointing UP (rotate local X onto Y with a 90° roll).
	local upAxis = CFrame.Angles(0, 0, math.rad(90))
	local chassisSteer = attachment(chassis, CFrame.new(offset) * upAxis)
	local knuckleSteer = attachment(knuckle, upAxis)
	local servo = Instance.new("HingeConstraint")
	servo.Attachment0 = chassisSteer
	servo.Attachment1 = knuckleSteer
	servo.ActuatorType = Enum.ActuatorType.Servo
	servo.ServoMaxTorque = spec.torque
	servo.AngularSpeed = 8
	servo.TargetAngle = 0
	servo:SetAttribute("Role", "Steer")
	servo.Parent = chassis

	-- Rolling hinge: knuckle <-> wheel, free-spinning about X.
	local knuckleRoll = attachment(knuckle, CFrame.new())
	local wheelRoll = attachment(wheel, CFrame.new())
	local roll = Instance.new("HingeConstraint")
	roll.Attachment0 = knuckleRoll
	roll.Attachment1 = wheelRoll
	roll.ActuatorType = Enum.ActuatorType.None
	roll.Parent = knuckle
end

-- Create a car at the given CFrame (positions the chassis center). The car is NOT
-- driveable until you call CarFactory.activate on it.
function CarFactory.create(spec: CarSpec, cframe: CFrame): Model
	local model = Instance.new("Model")
	model.Name = "Car_" .. spec.id

	local chassis = newPart({
		Name = "Chassis",
		Size = spec.bodySize,
		Color = spec.color,
		Material = Enum.Material.SmoothPlastic,
		CanCollide = true,
		CustomPhysicalProperties = CHASSIS_PHYSICS,
		CFrame = cframe,
	})
	chassis.Parent = model
	model.PrimaryPart = chassis

	-- A cabin block on top so it reads as a car, not a brick.
	local cabin = newPart({
		Name = "Cabin",
		Size = Vector3.new(spec.bodySize.X - 1, spec.bodySize.Y * 0.9, spec.bodySize.Z * 0.45),
		Color = spec.color:Lerp(Color3.new(0, 0, 0), 0.25),
		Material = Enum.Material.SmoothPlastic,
		CanCollide = false,
		CFrame = cframe * CFrame.new(0, spec.bodySize.Y * 0.85, -spec.bodySize.Z * 0.05),
	})
	cabin.Parent = model
	weld(chassis, cabin)

	local seat = Instance.new("VehicleSeat")
	seat.Name = "VehicleSeat"
	seat.Size = Vector3.new(2, 0.4, 3)
	seat.CollisionGroup = COLLISION_GROUP
	seat.CanCollide = false
	seat.MaxSpeed = 200
	seat.Torque = 0 -- we drive the wheels ourselves; stop the seat fighting us
	seat.TurnSpeed = 0
	seat.CFrame = cframe * CFrame.new(0, spec.bodySize.Y / 2 + 0.2, 0)
	seat.Parent = model
	weld(chassis, seat)

	local halfW = spec.bodySize.X / 2 + spec.wheelWidth / 2
	local halfL = spec.bodySize.Z / 2 - spec.wheelDiameter / 2
	buildWheel(model, chassis, spec, -halfW, halfL, true) -- front-left
	buildWheel(model, chassis, spec, halfW, halfL, true) -- front-right
	buildWheel(model, chassis, spec, -halfW, -halfL, false) -- rear-left
	buildWheel(model, chassis, spec, halfW, -halfL, false) -- rear-right

	return model
end

-- Turn a created car into a live, driveable one: a loop maps the seat input onto
-- the drive motors and steering servos. Cleans itself up when the car is removed.
function CarFactory.activate(model: Model, spec: CarSpec)
	-- Idempotent: safe to call again (e.g. when a car is retrieved from the garage).
	if model:GetAttribute("Active") then
		return
	end
	model:SetAttribute("Active", true)

	local seat = model:FindFirstChild("VehicleSeat") :: VehicleSeat
	if not seat then
		return
	end

	local driveHinges = {}
	local steerHinges = {}
	for _, d in model:GetDescendants() do
		local role = d:GetAttribute("Role")
		if role == "Drive" then
			table.insert(driveHinges, d)
		elseif role == "Steer" then
			table.insert(steerHinges, d)
		end
	end

	local conn
	conn = RunService.Heartbeat:Connect(function()
		if not model.Parent then
			conn:Disconnect()
			return
		end
		-- Parked in the garage: hold still until retrieved.
		if model:GetAttribute("Stored") then
			return
		end
		local throttle = seat.ThrottleFloat -- -1 .. 1
		local steer = seat.SteerFloat -- -1 .. 1
		for _, hinge in driveHinges do
			-- Negative so "up / W" drives forward; flip the sign here if reversed.
			hinge.AngularVelocity = -throttle * spec.maxSpinSpeed
		end
		for _, servo in steerHinges do
			servo.TargetAngle = steer * spec.maxSteerAngle
		end
	end)
end

-- Lock every part in place so a car can sit on display without rolling away.
function CarFactory.freeze(model: Model)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
		end
	end
end

return CarFactory
