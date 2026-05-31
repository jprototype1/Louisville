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
}

return CarModels
