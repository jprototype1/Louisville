# Brookhaven — Handoff (start here)

A Roblox game (**Louiville**) that a kid builds by chatting with an AI agent over Telegram and testing
on an iPad, while an operator runs the rig on a Mac. This is the "current state + where to look" page;
deep docs are linked throughout.

- Architecture & roles → [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)
- Operator runbook → [docs/OPERATING.md](docs/OPERATING.md)
- In-Studio dev → [docs/STUDIO.md](docs/STUDIO.md)
- Agent behavior rules → [CLAUDE.md](CLAUDE.md)

## Key facts
| | |
|---|---|
| Live game | **Louiville** — https://www.roblox.com/games/96742556424847/Louiville (place `96742556424847`, universe `10253814602`) |
| GitHub | `jprototype1/Louisville` (**public**) — this repo pushes/commits as `jprototype1` via an isolated SSH key |
| Repo layout | `~/roblox/brookhaven` → **`nephew-playground`** (agent works here; the OpenACP daemon lives here). `~/roblox/brookhaven-main` → **`main`** (operator/production). |
| Remote build | OpenACP daemon ↔ Telegram group "Louisville Group Brookhaven Dev" (bot `@louisvilleengineerbot`) ↔ a Claude agent. New sessions default to **Sonnet** and **`nephew-playground`**. |
| Secrets (gitignored) | `.env` → `ROBLOX_API_KEY`; `.openacp/` → Telegram bot token + chat history. **Never commit these.** |

## Run it
```bash
./scripts/launch-rig.sh    # cmux workspace: caffeinate | openacp daemon | live session watch
```
The builder sends `/new claude` in the Telegram group and prompts. Or drive sessions from the terminal:
```bash
./scripts/chat             # friendly local CLI: menu, pick-by-number, streaming, slash commands
```
In-Studio development instead:
```bash
./scripts/studio.sh        # regenerate sourcemap + rojo serve (connect via the Rojo plugin)
```

## The build loop
Prompt → agent edits `src/` → `./scripts/check.sh` (auto-format + lint + build) → `./scripts/publish.sh`
(auto-commits + backs up to GitHub, then ships to the live game via Open Cloud). In-game, tap the
**🔄 Update** button to reload to the latest version *and land back where you were*.

## Scripts
`launch-rig.sh` · `chat` / `chat.mjs` · `check.sh` · `publish.sh` · `studio.sh` ·
`review-sessions.mjs` (`--watch` = live interleaved feed) · `worker-new.sh` / `worker-merge.sh`
(per-session worktree lanes for parallel builders). All covered in
[docs/OPERATING.md](docs/OPERATING.md) / [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

## What's built
Procedural world (hills + trees/rocks), car dealership with drivable cars (physics + chase camera),
a house with interior + garage parking, super-jump, and the in-game Update button.
Map convention: **house at X=-120, dealership at X=+120**, spawn at origin.
**Not yet verified:** the full drive → park → retrieve loop. (System details in
[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).)

## ⚠️ Open items
1. **Rotate the Telegram bot token.** It was briefly committed to the public repo (purged from history),
   so treat it as compromised: @BotFather → `/mybots` → bot → **Revoke**, set the new
   `channels.telegram.botToken` in `.openacp/config.json`, restart the daemon. (The Roblox API key was *not* leaked.)
2. **Promote to `main` intentionally** — the agent only edits `nephew-playground`:
   `git -C ~/roblox/brookhaven-main merge nephew-playground && git -C ~/roblox/brookhaven-main push`.
3. **Cost** — keep sessions on **Sonnet** and limit concurrent sessions (each multiplies usage).
4. **Verify the garage loop** (drive → park → retrieve) — still untested.

## Gotchas (learned the hard way)
- `.openacp/` holds secrets — **never `git add -A` it** (it leaked once; gitignored now).
- The Studio MCP **works** (enable via Assistant → `…` → Manage MCP Servers → "Enable Studio as MCP
  server"; tools push over port 13469). Don't spawn the proxy by hand — let Claude Code manage it.
- Mac must stay **awake** (caffeinate) and **plugged in**; sleep drops connections.
- OpenACP's `config set` rejects nested keys (channels/tts/defaultWorkspace) — edit
  `.openacp/config.json` directly, then `openacp restart`.
- Avoid fragile material enums (e.g. `Enum.Material.RoofTiles`); prefer common ones like `Brick`.
