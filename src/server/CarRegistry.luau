--!strict
-- Tracks the single car each player currently owns, so the Dealership (which
-- hands out cars) and the Garage (which parks/retrieves them) share one source of
-- truth. A player has at most one car at a time.

local CarModels = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("CarModels"))
type CarSpec = CarModels.CarSpec

export type Entry = {
	model: Model,
	spec: CarSpec,
	stored: boolean, -- true while parked on a garage pad
	pad: BasePart?, -- the pad it's parked on, if any
}

local CarRegistry = {}

local entries: { [Player]: Entry } = {}

function CarRegistry.set(player: Player, model: Model, spec: CarSpec): Entry
	local entry: Entry = { model = model, spec = spec, stored = false, pad = nil }
	entries[player] = entry
	return entry
end

function CarRegistry.get(player: Player): Entry?
	return entries[player]
end

function CarRegistry.clear(player: Player)
	entries[player] = nil
end

return CarRegistry
