#!/usr/bin/env bash
# Launch the Brookhaven remote-build rig in a dedicated cmux workspace, three panes:
#   pane 1: caffeinate -dimsu                  (keep the Mac awake)
#   pane 2: openacp daemon                     (Telegram ⇄ agent bridge)
#   pane 3: review-sessions.mjs --watch        (live, interleaved session feed)
#
# Usage:  ./scripts/launch-rig.sh
# Requires the `cmux` CLI (https://cmux.com).
set -euo pipefail

REPO="$HOME/roblox/brookhaven"
command -v cmux >/dev/null || { echo "cmux not found — install it first (https://cmux.com)" >&2; exit 1; }

# Pull a "<kind>:<n>" ref out of cmux command output.
ref() { grep -oE "$1:[0-9]+" | head -1; }

# Surfaces in another workspace must be addressed with BOTH --workspace and --surface.
run_in() { # <workspace> <surface> <command...>
	local ws="$1" sf="$2"; shift 2
	cmux send --workspace "$ws" --surface "$sf" "$*"
	cmux send-key --workspace "$ws" --surface "$sf" Enter
}

# 1. New workspace; pane 1 keeps the Mac awake.
WS=$(cmux new-workspace --name "brookhaven-rig" --cwd "$REPO" --command "caffeinate -dimsu" | ref workspace)
[ -n "$WS" ] || { echo "failed to create workspace" >&2; exit 1; }
S1=$(cmux list-pane-surfaces --workspace "$WS" | ref surface)

# 2. Split right -> pane 2: the OpenACP daemon (attach if already running, else start).
S2=$(cmux new-split right --workspace "$WS" --surface "$S1" | ref surface)
run_in "$WS" "$S2" "cd $REPO && (openacp attach 2>/dev/null || openacp)"

# 3. Split that pane down -> pane 3: the live session watcher.
S3=$(cmux new-split down --workspace "$WS" --surface "$S2" | ref surface)
run_in "$WS" "$S3" "cd $REPO && node scripts/review-sessions.mjs --watch"

echo "✅ Rig up in cmux $WS (brookhaven-rig): [caffeinate] | [openacp] | [watch]"
echo "   Builder: send '/new claude' in the Telegram group and start prompting."
