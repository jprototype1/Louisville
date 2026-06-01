#!/usr/bin/env bash
# Studio live-sync dev workflow (the in-Studio developer path).
# Regenerates the LSP sourcemap, then starts Rojo's live-sync server so edits to
# src/ stream into an open Roblox Studio session.
#
# Usage:  ./scripts/studio.sh
# First-time setup is printed below.
set -euo pipefail
export PATH="$HOME/.rokit/bin:$HOME/.cargo/bin:$PATH"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

echo "==> Regenerating sourcemap.json (Luau LSP autocomplete + types)..."
rojo sourcemap default.project.json -o sourcemap.json

echo
echo "First time only:"
echo "    rojo build -o brookhaven.rbxlx && open brookhaven.rbxlx   # build + open the place"
echo "    rojo plugin install                                       # install the Rojo Studio plugin"
echo
echo "==> Starting Rojo live-sync on localhost:34872."
echo "    In Studio: Plugins tab → Rojo → Connect. Then edits to src/ sync live."
echo "    Press Play (F5) to test (runtime scenery only appears in Play/Run mode)."
echo
exec rojo serve
