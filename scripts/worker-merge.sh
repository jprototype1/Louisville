#!/usr/bin/env bash
# Merge a worker lane back into nephew-playground and clean up its worktree.
# Run this when the worker for that lane is DONE building.
#
# Usage:  ./scripts/worker-merge.sh <name>      e.g.  ./scripts/worker-merge.sh pool
set -euo pipefail

NAME="${1:?usage: worker-merge.sh <name>}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

BASE="nephew-playground"
BR="play/$NAME"
WT="$(cd "$ROOT/.." && pwd)/brookhaven-$NAME"

# 1. Commit any pending work in the lane so nothing is lost.
if [ -d "$WT" ]; then
	if [ -n "$(git -C "$WT" status --porcelain)" ]; then
		git -C "$WT" add -A
		git -C "$WT" commit -q -m "lane $NAME: save work before merge"
		echo "committed pending work in lane '$NAME'"
	fi
fi

# 2. Merge the lane into the base branch.
git checkout "$BASE"
if git merge --no-edit "$BR"; then
	echo "✅ merged $BR into $BASE"
else
	echo "⚠️  merge hit a conflict — resolve in $ROOT, then: git commit" >&2
	exit 1
fi

# 3. Remove the worktree + branch.
git worktree remove "$WT" --force 2>/dev/null || true
git branch -d "$BR" 2>/dev/null || true
git worktree prune

echo "Lane '$NAME' merged and cleaned up."
echo "Publish the combined result with:  ./scripts/publish.sh"
echo "Back up with:                      git push origin $BASE"
