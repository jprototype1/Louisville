# Brookhaven — Operator's Guide

Everything the **operator** (the adult running the Mac) needs to run the remote-build rig, watch what
the builder is doing, ship changes, control cost, and recover from problems.

> New here? Read **[ARCHITECTURE.md](ARCHITECTURE.md)** first for the big picture and roles.

All `openacp` / tool commands assume `~/.nvm/.../bin` and `~/.local/bin` are on `PATH`. If a fresh
terminal can't find `openacp`, it's at `~/.nvm/versions/node/<ver>/bin/openacp`.

---

## 1. Launch (the durable process)

The builder's side needs **nothing** — they just message the Telegram group. The rig lives on the Mac.
Run these (ideally in 3 panes); **keep the Mac plugged in**, sleep is disabled only while caffeinate runs.

```bash
# Pane 1 — keep the Mac awake (system sleep is short; this is essential)
caffeinate -dimsu

# Pane 2 — the OpenACP daemon (foreground = visible)
cd ~/roblox/brookhaven && openacp

# Pane 3 — live, interleaved feed of all sessions
cd ~/roblox/brookhaven && node scripts/review-sessions.mjs --watch
```

After a reboot, just re-run those three. (A LaunchAgent can auto-start the daemon untended, but
foreground keeps it visible and simple.)

### The builder's loop
In the Telegram group they send `/new claude`, then prompt in plain language. The agent edits the game,
runs `check.sh`, publishes, and they reload **Louiville** on the iPad. Sessions default to **Sonnet**.

---

## 2. Monitoring sessions

```bash
node scripts/review-sessions.mjs            # list sessions (who, status, # turns)
node scripts/review-sessions.mjs latest     # full transcript of the most recent
node scripts/review-sessions.mjs <id>       # a specific session (partial id ok)
node scripts/review-sessions.mjs --watch    # LIVE interleaved feed of all sessions
node scripts/review-sessions.mjs --all      # every transcript   (+ --thinking / --full)
```

Also useful:
```bash
openacp api status            # active sessions
openacp api session <id>      # one session's details (model, queue, prompt-active)
openacp logs                  # raw daemon log
```

---

## 3. Publishing

The agent normally publishes itself. To do it manually:
```bash
./scripts/publish.sh          # commit + push + build + publish LIVE to Louiville
./scripts/publish.sh --save   # build + upload a version WITHOUT going live (staging)
```
`publish.sh` **auto-saves** (commits the working tree + pushes to GitHub) before building, so every
publish is recoverable. A lock prevents two publishes from racing.

---

## 4. Parallel builders (worktree lanes)

Multiple sessions editing the **same file** in the shared tree will clobber each other. For true
parallel work, give each its own lane:

```bash
./scripts/worker-new.sh pool        # makes ../brookhaven-pool on branch play/pool, prints a /new command
# → in Telegram:  /new claude /Users/gnijor/roblox/brookhaven-pool
./scripts/worker-merge.sh pool      # merge the lane back into nephew-playground, clean up
```

Rule of thumb: workers on **different files/areas** (house vs world vs cars) are fine on one branch;
workers on the **same area** should each get a lane.

---

## 5. Cost control

Usage spikes come from two things:
1. **Model.** Default is Opus (expensive). Switch any session to Sonnet:
   ```bash
   openacp api session-config <id> set model sonnet
   ```
   New sessions already default to Sonnet (set via `ANTHROPIC_MODEL` on the agent).
2. **Parallel session count.** Each concurrent session multiplies spend. Encourage **1–2 at a time**,
   and `/cancel` (or `openacp api cancel <id>`) sessions when a feature is done.

---

## 6. Recovering lost work

Source lives only in the working tree until committed. If it's lost (bad reset, clobber), recover from
either source — **whichever is most recent and complete**:

- **Last published build:** `build/brookhaven.rbxl` contains valid script source. Extract with
  `lune run /tmp/extract.luau`-style scripts (read place → dump `ServerScriptService.Server.*` `.Source`).
  Caveat: only as fresh as the last `publish.sh`.
- **Agent transcripts:** `~/.claude/projects/-Users-gnijor-roblox-brookhaven/*.jsonl` record every
  `Read`/`Edit`/`Write`. The largest `Read` snapshot of a file is a clean full-content checkpoint.

Always **commit immediately** after recovering. Prevention: `publish.sh` now auto-commits, so published
work is always recoverable.

---

## 7. Security

- **`.openacp/` is gitignored and must stay that way** — it holds the **Telegram bot token**, OpenACP
  secrets, and the builder's chat media. Never `git add -A` it. If it ever gets committed: untrack it
  (`git rm -r --cached .openacp`), purge history, and **rotate the bot token**.
- **Rotate the bot token** via **@BotFather → `/mybots` → bot → API Token → Revoke**, then update
  `channels.telegram.botToken` and restart the daemon.
- The Roblox API key lives in gitignored `.env` (`ROBLOX_API_KEY`). Keep it out of git.

---

## 8. Troubleshooting

| Symptom | Fix |
|---|---|
| Builder's prompt "hangs" | A session may be waiting on a permission (check the 📋 Notifications topic) or two sessions share one. Use a fresh `/new claude` session; `/cancel` the stuck one. |
| Mac slept → connections dropped (`ECONNRESET`) | Keep `caffeinate -dimsu` running; system sleep is short. Re-send the dropped message. |
| Tool "command not found" (stylua/rojo) | Tools are symlinked in `~/.local/bin`; re-link with `ln -sf ~/.rokit/bin/<tool> ~/.local/bin/<tool>`. |
| Telegram "prerequisites NOT met" | Group needs **Topics enabled** + bot **admin with Manage Topics**. Set the bot's admin perms from the **phone app** (desktop Telegram drops this toggle), then send `/retry` in the group. |
| Daemon wedged / stale sessions | `openacp restart` (clears sessions; working-tree files are safe). |
| Want to publish from a clean state | Merge lanes first (`worker-merge.sh`), then `./scripts/publish.sh`. |
