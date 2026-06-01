# Brookhaven — Architecture

Brookhaven is a Roblox town/roleplay game built with [Rojo](https://rojo.space) (filesystem ↔ Studio),
**plus** a remote-build rig that lets a non-developer (e.g. a kid) build the game by chatting with an
AI agent over Telegram and testing on an iPad. This doc covers both halves.

---

## 1. The game (Roblox / Luau)

Source lives in `src/`, mapped into the Roblox DataModel by `default.project.json`:

| Path | Roblox location | Role |
|---|---|---|
| `src/server/` | `ServerScriptService.Server` | server-authoritative game logic |
| `src/client/` | `StarterPlayer.StarterPlayerScripts.Client` | per-player client logic |
| `src/shared/` | `ReplicatedStorage.Shared` | code/data shared by both |

### Server systems (`src/server/`)
`init.server.luau` is a **thin, fault-isolated orchestrator** — it `pcall`-wraps each system so one
failure can't take down the others, then calls them in order:

| Module | What it builds / does |
|---|---|
| `WorldBuilder.luau` | Procedural grassy world — hills (trees/rocks available, currently commented out). Built at runtime. |
| `MainHouse.luau` | The main character's house at **X = −120**, including its interior, and **garage storage pads** (`Workspace.MainCharacterHouse.GarageStoragePads.GarageCarPad1/2`, tagged `CarStoragePad=true`, `PadIndex=1/2`). |
| `Dealership.luau` | "Brookhaven Motors" showroom at **X = +120** with 3 lit display cars + walk-up ProximityPrompts that spawn a drivable car. |
| `CarFactory.luau` | Assembles a physics car (chassis + VehicleSeat + rear-drive motor wheels + front steering knuckles). `activate()` is idempotent; pauses when the `Stored` attribute is set. |
| `CarRegistry.luau` | Shared "current car per player" state, so Dealership + Garage agree. |
| `Garage.luau` | Drive a car onto a house pad → it auto-parks; a prompt retrieves it. Best-effort DataStore save across sessions. |

Spawn is at the origin `(0,0,0)`. Map convention: **house on −X, dealership on +X**, kept apart so they
don't overlap (a contract honored when two agents built them in parallel).

### Client (`src/client/init.client.luau`)
A **vehicle chase camera** — default camera while walking; switches to a smooth chase camera when the
local player sits in a `Car_*` VehicleSeat. **Naming contract:** it keys off models named `Car_<id>`
(produced by `CarFactory`) and ignores `Display_<id>` showroom cars. Don't rename the `Car_` prefix.

### Shared (`src/shared/`)
`CarModels.luau` — the **car specs** (name, color, size, speed, torque). Easiest place to tune cars.

---

## 2. The remote-build rig (how a kid builds from an iPad)

```
  iPad (Telegram)                 Mac (this repo)                       Roblox cloud
 ┌───────────────┐   message   ┌──────────────────────────────┐      ┌──────────────┐
 │ Builder types │────────────▶│ OpenACP daemon (.openacp/)   │      │  Louiville   │
 │ in TG group   │             │   Telegram adapter ⇄ agent   │      │  experience  │
 │  /new claude  │◀────────────│   claude-agent-acp (Claude)  │      │ place 9674…  │
 └───────────────┘  replies    │     edits src/, runs scripts │      └──────▲───────┘
        │                      └───────────────┬──────────────┘             │
        │                                      │ ./scripts/publish.sh       │ Open Cloud
        │  plays / tests  ◀────────────────────┼────────────────────────────┘  (rbxl upload)
        └──────────────────────────────────────┘
```

- **OpenACP** (`@openacp/cli`) runs a local daemon that bridges a **Telegram group** (Topics enabled)
  to an **ACP agent**. The agent is `claude-agent-acp` — Claude Code under the hood — running with its
  working directory set to **this repo**.
- The builder sends `/new claude` in the group → a new session/topic spins up. They prompt in plain
  language; the agent edits `src/`, validates, and publishes.
- The agent's behavior is shaped by **`CLAUDE.md`** (kid-friendly tone, the save/publish loop, safety
  rules). Each session reads it on start.
- Publishing uses **`./scripts/publish.sh`** → Roblox **Open Cloud** → the live game. The builder reloads
  **Louiville** on their iPad to see changes.
- OpenACP state (incl. **secrets**: bot token, history, media) lives in `.openacp/` — **gitignored**.

Identifiers (Open Cloud target): **Universe `10253814602`**, **Place `96742556424847`** (experience
"Louiville"). Roblox API key is in a gitignored `.env` as `ROBLOX_API_KEY` (scope `universe-places:write`).

---

## 3. System roles

| Role | Who/what | Responsibilities |
|---|---|---|
| **Operator** | the adult running the Mac | Keep the Mac awake + daemon up, monitor sessions, manage publishes/merges, control cost, rotate secrets, recover lost work. See [OPERATING.md](OPERATING.md). |
| **Builder** | the kid (Telegram) | Sends prompts, tests on iPad. No setup on their end. |
| **Agent** | Claude via OpenACP | Edits code, runs `check.sh` (auto-format + lint + build), publishes, talks per `CLAUDE.md`. |
| **OpenACP daemon** | local process | Bridges Telegram ⇄ agent; manages sessions, permissions, media. |
| **Repo / branches** | git | `main` = production; `nephew-playground` = the builder's branch; `play/<name>` = isolated parallel worktrees (see worker scripts). |

---

## 4. Toolchain

Pinned by **Rokit** (`rokit.toml`): `rojo`, `stylua`, `selene`, `luau-lsp`, `lune`, `wally`. The binaries
are symlinked into `~/.local/bin` so the agent's shell (and any shell) finds them.

| Script | Purpose |
|---|---|
| `scripts/check.sh` | **Auto-formats** (StyLua) + lints (Selene) + builds (Rojo). Run after changes. |
| `scripts/publish.sh` | Auto-commits + pushes to GitHub, then builds + publishes to the live game via Open Cloud. `--save` uploads without going live. Has a lock against concurrent publishes. |
| `scripts/worker-new.sh <name>` | Creates an isolated git-worktree lane for a parallel session. |
| `scripts/worker-merge.sh <name>` | Merges a lane back into `nephew-playground` and cleans it up. |
| `scripts/chat.mjs` | Local CLI to drive/multiplex OpenACP conversations from the terminal (no Telegram needed). |
| `scripts/review-sessions.mjs` | Review session transcripts; `--watch` streams all sessions live, interleaved. |
| `scripts/studio.sh` | Studio live-sync dev loop: regenerate the LSP sourcemap + start `rojo serve`. See [STUDIO.md](STUDIO.md). |
| `scripts/launch-rig.sh` | Launches the whole rig in a 3-pane **cmux** workspace (caffeinate · openacp · live watch). |

Editor: `.zed/` provides Luau LSP (autocomplete/type-check), format-on-save, and one-click tasks.

See **[OPERATING.md](OPERATING.md)** for how to actually run, monitor, publish, recover, and troubleshoot.
