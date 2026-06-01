# Brookhaven Roblox Handoff

Last updated: 2026-05-31

## Current State

This is a Rojo-based Roblox Studio project at:

```text
/Users/gnijor/roblox/brookhaven
```

The game is published as:

```text
https://www.roblox.com/games/96742556424847/Louiville
```

Roblox Studio is connected through Rojo on:

```text
localhost:34872
```

The latest publish succeeded in Studio with the toast:

```text
Published. Eligible players can play now.
```

## How To Run

Start Rojo if it is not already running:

```bash
rojo serve
```

In Roblox Studio:

1. Open the place.
2. Connect the Rojo plugin to `localhost:34872`.
3. Press Play or Run.
4. Watch Studio Output for these messages:

```text
[WorldBuilder] built world with 6 objects
[MainHouse] built main character house at X=-120, Z=0
[Dealership] showroom ready with 3 cars
```

The server entry point is intentionally a thin orchestrator with per-system `pcall` wrappers:

```text
src/server/init.server.luau
```

If one system fails, the others should still build and Output will show:

```text
[Server] <SystemName> failed: <error>
```

## Main Systems

### World

File:

```text
src/server/WorldBuilder.luau
```

Builds the base procedural world. Trees and rocks are currently commented out; hills are enabled.

### Main House

File:

```text
src/server/MainHouse.luau
```

Builds `Workspace.MainCharacterHouse` around:

```text
X = -120, Z = 0
```

Features:

- Two-story villa
- Pool and patio
- Balcony
- Garage and driveway
- Decorative palms, windows, lights
- Garage storage pads:

```text
Workspace.MainCharacterHouse.GarageStoragePads.GarageCarPad1
Workspace.MainCharacterHouse.GarageStoragePads.GarageCarPad2
```

Each garage pad has attributes:

```text
CarStoragePad = true
PadIndex = 1 or 2
```

### Dealership

Files:

```text
src/server/Dealership.luau
src/server/CarFactory.luau
src/server/CarRegistry.luau
src/shared/CarModels.luau
```

Builds `Workspace.Dealership` around:

```text
X = +120, Z = 0
```

Current intent:

- Three display cars
- Walk up to a display car and use the ProximityPrompt
- A drivable car spawns outside the showroom

### Garage

File:

```text
src/server/Garage.luau
```

Uses the house garage pads to auto-park/retrieve the player car.

Intended behavior:

- Drive a car slowly onto a garage pad
- It parks/snaps onto the pad
- A retrieve prompt appears
- Prompt restores the car and seats the player

Persistence is best-effort via DataStore and should not be assumed to work in every local Studio test.

## Coordinates

Spawn is at origin:

```text
0, 0, 0
```

Major areas:

```text
House:      X=-120, Z=0
Dealership: X=+120, Z=0
```

In Studio Explorer during Play, select either:

```text
Workspace.MainCharacterHouse
Workspace.Dealership
```

Then press `F` to frame it.

## iPad Testing

The iPad does not receive Rojo live-sync changes. The loop is:

1. Edit files locally.
2. Test in Roblox Studio.
3. Publish from Studio with `Cmd+P`.
4. Launch on iPad.

Direct game URL:

```text
https://www.roblox.com/games/96742556424847/Louiville
```

Deep link to try on iPad Safari:

```text
roblox://placeId=96742556424847
```

If Safari redirects to the App Store:

- Open the Roblox app manually first.
- Confirm the same Roblox account is logged in.
- Try the deep link again.
- If the App Store shows `Get` or a cloud icon, reinstall Roblox on the iPad.

## MCP Status

Codex and Claude were configured with Roblox Studio MCP:

```text
/Applications/RobloxStudio.app/Contents/MacOS/StudioMCP
```

Codex config:

```text
~/.codex/config.toml
```

Claude config:

```text
~/.claude.json
```

Current known issue:

```text
RobloxStudio MCP connects but shows Tools: (none)
```

Direct `StudioMCP --verbose` probing showed:

```text
No tools available, waiting for ws_server to push tools...
```

That means the stdio proxy starts, but Roblox Studio has not pushed the Studio tool list into it.

Do not install the archived GitHub MCP repo unless Roblox docs explicitly require it again. Roblox now bundles `StudioMCP` in the app. The likely missing step is enabling the built-in Studio MCP bridge from Roblox Studio Assistant:

1. Open Assistant in Roblox Studio.
2. Open its `...` menu.
3. Choose Manage MCP Servers.
4. Enable Studio as MCP server.
5. Restart Codex/Claude.

Useful checks:

```bash
codex mcp list
claude mcp get RobloxStudio
```

Expected once fixed: RobloxStudio should list tools instead of `(none)`.

## Billing / Usage Context

The user upgraded to ChatGPT Pro 5x during this session. After refresh, Codex `/status` showed:

```text
Account: nijor22@gmail.com (Pro)
5h limit: 100% left
Weekly limit: 100% left
Credits: 2496 credits
```

For the next coding session, start fresh to avoid carrying this long context:

```bash
codex -C /Users/gnijor/roblox/brookhaven
```

## Collaboration Notes

Claude was working on the car dealership/garage side while Codex worked on the house side.

Boundaries used:

- House/Home files are Codex-owned.
- Dealership/CarFactory/CarModels/Garage/CarRegistry files are Claude-owned.
- `src/server/init.server.luau` is shared and should stay a thin orchestrator.

If both agents are running again, coordinate before changing:

```text
src/server/init.server.luau
src/server/Dealership.luau
src/server/Garage.luau
src/server/MainHouse.luau
```

## Gotchas

- Rojo sync can be partial for a few seconds. If Play only shows hills, check Explorer under `ServerScriptService > Server` and Studio Output.
- The house and dealership are far from spawn. They may exist even if not visible from the starting camera.
- Avoid fragile Roblox material enum values. `Enum.Material.RoofTiles` caused compatibility risk and was replaced with `Brick`.
- Publish from Studio after successful local testing; the iPad only sees published versions.
