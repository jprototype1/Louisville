#!/usr/bin/env bash
# Spin up an isolated build "lane" for a parallel worker — its own git worktree
# and branch, so two sessions can build at once WITHOUT clobbering each other.
#
# Usage:  ./scripts/worker-new.sh <name>        e.g.  ./scripts/worker-new.sh pool
#
# Then in Telegram, point a session at it:  /new claude <printed path>
set -euo pipefail

NAME="${1:?usage: worker-new.sh <name>   (e.g. pool, garden, cars)}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

BASE="nephew-playground"      # lanes branch off this
WT="$(cd "$ROOT/.." && pwd)/brookhaven-$NAME"
BR="play/$NAME"

if [ -d "$WT" ]; then
	echo "Lane '$NAME' already exists at $WT"
else
	git worktree add "$WT" -b "$BR" "$BASE" 2>/dev/null || git worktree add "$WT" "$BR"
fi

# Untracked-but-needed files don't come with a worktree — share them so publish works.
[ -f "$ROOT/.env" ] && ln -sf "$ROOT/.env" "$WT/.env"

echo
echo "✅ Lane '$NAME' ready"
echo "   folder: $WT"
echo "   branch: $BR (off $BASE)"
echo
echo "Start a Telegram session for this lane with:"
echo "    /new claude $WT"
echo
echo "When the worker is done, merge it back with:"
echo "    ./scripts/worker-merge.sh $NAME"
