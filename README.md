# Brookhaven 🚗🏠

A Roblox town/roleplay game (live as **Louiville**) — with a twist: it can be built by a non-developer
(a kid) who just **chats with an AI agent over Telegram and tests on an iPad**, while an operator runs
the rig on a Mac.

## What's here
- **The game** — Luau, built with [Rojo](https://rojo.space). Cars + dealership, a house with a garage,
  a procedural world. Source in `src/` (`server` / `client` / `shared`).
- **A remote-build rig** — [OpenACP](https://github.com/Open-ACP/OpenACP) bridges a Telegram group to a
  Claude agent running in this repo; the agent edits code, validates, and publishes to the live game.
- **Operator tooling** — one-command publish (Open Cloud), auto-format/lint/build checks, isolated
  worktree lanes for parallel builders, and live/replayable session transcripts.

## Docs
- **[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)** — the game systems, the remote-build rig, system roles, data flow.
- **[docs/OPERATING.md](docs/OPERATING.md)** — operator's guide: launch, monitor, publish, parallel lanes, cost, recovery, security, troubleshooting.
- **[CLAUDE.md](CLAUDE.md)** — how the AI agent should behave (kid-friendly tone + the safe build/publish loop).

## Quick start (operator)
```bash
# keep the Mac awake + run the daemon + watch sessions (3 panes)
caffeinate -dimsu
cd ~/roblox/brookhaven && openacp
cd ~/roblox/brookhaven && node scripts/review-sessions.mjs --watch
```
The builder just sends `/new claude` in the Telegram group and starts prompting. Full details in
[docs/OPERATING.md](docs/OPERATING.md).

## Quick start (developer, in Studio)
```bash
rojo build -o brookhaven.rbxlx   # build a place file, open it in Studio
rojo serve                       # live-sync src/ into Studio (connect via the Rojo plugin)
./scripts/check.sh               # auto-format + lint + build
./scripts/publish.sh             # commit + publish live (needs .env with ROBLOX_API_KEY)
```

## Branches
- `main` — production (what's intended to be live)
- `nephew-playground` — the builder's working branch
- `play/<name>` — isolated worktree lanes for parallel building
