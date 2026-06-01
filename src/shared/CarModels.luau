--!strict
-- Car specs for the dealership. Tweak these numbers to tune how each car looks
-- and drives, then re-test in Studio (and re-publish for iPad). All sizes are in
-- studs. `bodySize` is (width X, height Y, length Z).

export type CarSpec = {
	id: string,
	name: string,
	color: Color3,
	bodySize: Vector3,
	wheelDiameter: number,
	wheelWidth: number,
	maxSpinSpeed: number, -- wheel angular velocity at full throttle (higher = faster)
	torque: number, -- drive + steering strength
	maxSteerAngle: number, -- degrees the front wheels turn at full steer
}

local CarModels: { CarSpec } = {
	{
		id = "sedan",
		name = "City Sedan",
		color = Color3.fromRGB(40, 90, 200),
		bodySize = Vector3.new(6, 1.6, 12),
		wheelDiameter = 3,
		wheelWidth = 1.2,
		maxSpinSpeed = 48,
		torque = 45000,
		maxSteerAngle = 28,
	},
	{
		id = "sports",
		name = "Roadster",
		color = Color3.fromRGB(220, 40, 40),
		bodySize = Vector3.new(6, 1.2, 11),
		wheelDiameter = 2.8,
		wheelWidth = 1.2,
		maxSpinSpeed = 72,
		torque = 55000,
		maxSteerAngle = 30,
	},
	{
		id = "truck",
		name = "Pickup Truck",
		color = Color3.fromRGB(55, 55, 60),
		bodySize = Vector3.new(7, 2.2, 14),
		wheelDiameter = 3.6,
		wheelWidth = 1.6,
		maxSpinSpeed = 40,
		torque = 70000,
		maxSteerAngle = 26,
	},
	{
		id = "police",
		name = "Police Car",
		color = Color3.fromRGB(30, 30, 140),
		bodySize = Vector3.new(6, 1.6, 12),
		wheelDiameter = 3,
		wheelWidth = 1.2,
		maxSpinSpeed = 60,
		torque = 50000,
		maxSteerAngle = 32,
	},
	{
		id = "icecream",
		name = "Ice Cream Truck",
		color = Color3.fromRGB(255, 200, 220),
		bodySize = Vector3.new(7, 3.0, 14),
		wheelDiameter = 3.4,
		wheelWidth = 1.4,
		maxSpinSpeed = 30,
		torque = 55000,
		maxSteerAngle = 24,
	},
	{
		id = "schoolbus",
		name = "School Bus",
		color = Color3.fromRGB(255, 200, 0),
		bodySize = Vector3.new(8, 3.2, 20),
		wheelDiameter = 4,
		wheelWidth = 1.8,
		maxSpinSpeed = 28,
		torque = 80000,
		maxSteerAngle = 22,
	},
}

return CarModels
