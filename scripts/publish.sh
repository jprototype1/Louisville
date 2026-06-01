#!/usr/bin/env bash
# Publish the latest build to the live Roblox experience via Open Cloud.
#
# Usage:  ./scripts/publish.sh            # publishes LIVE (versionType=Published)
#         ./scripts/publish.sh --save     # uploads a version without going live
#
# Requires a Roblox Open Cloud API key (scope: universe-places:write) in a
# gitignored .env file at the repo root:  ROBLOX_API_KEY=...
set -euo pipefail

# Make rokit/cargo tools findable regardless of how this is launched.
export PATH="$HOME/.rokit/bin:$HOME/.cargo/bin:$PATH"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

# Prevent two publishes from racing (parallel workers). mkdir is atomic on macOS.
LOCKDIR="/tmp/brookhaven-publish.lock"
if ! mkdir "$LOCKDIR" 2>/dev/null; then
	echo "⏳ Another publish is in progress — wait a few seconds and try again." >&2
	exit 1
fi
trap 'rmdir "$LOCKDIR" 2>/dev/null' EXIT

# Load the API key from .env (kept out of git).
if [ -f .env ]; then
	set -a
	# shellcheck disable=SC1091
	source .env
	set +a
fi

if [ -z "${ROBLOX_API_KEY:-}" ]; then
	echo "ERROR: ROBLOX_API_KEY is not set. Add it to $ROOT/.env" >&2
	echo "       Create a key at https://create.roblox.com/dashboard/credentials" >&2
	echo "       with the 'universe-places:write' scope for this experience." >&2
	exit 1
fi

UNIVERSE_ID=10253814602
PLACE_ID=96742556424847
VERSION_TYPE="Published"
if [ "${1:-}" = "--save" ]; then
	VERSION_TYPE="Saved"
fi

OUT="build/brookhaven.rbxl"
mkdir -p build

echo "==> Building place with Rojo..."
rojo build default.project.json -o "$OUT"

echo "==> Publishing ($VERSION_TYPE) to universe $UNIVERSE_ID / place $PLACE_ID..."
HTTP_BODY="$(mktemp)"
HTTP_CODE="$(curl -sS -w '%{http_code}' -o "$HTTP_BODY" \
	-X POST \
	"https://apis.roblox.com/universes/v1/${UNIVERSE_ID}/places/${PLACE_ID}/versions?versionType=${VERSION_TYPE}" \
	-H "x-api-key: ${ROBLOX_API_KEY}" \
	-H "Content-Type: application/octet-stream" \
	--data-binary @"$OUT")"

echo "HTTP $HTTP_CODE"
cat "$HTTP_BODY"; echo
rm -f "$HTTP_BODY"

if [ "$HTTP_CODE" = "200" ]; then
	echo "==> ✅ Published. Reload in the Roblox app / iPad to see it."
else
	echo "==> ❌ Publish failed (see response above)." >&2
	exit 1
fi
