#!/usr/bin/env bash
# Quick health check before publishing: formatting, linting, and a build.
# Run this after making changes:  ./scripts/check.sh
set -uo pipefail
export PATH="$HOME/.rokit/bin:$HOME/.cargo/bin:$PATH"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

fail=0

echo "==> 1/3 Formatting (StyLua)..."
if stylua --check src/ 2>/dev/null; then
	echo "    ✅ formatting looks good"
else
	echo "    ⚠️  some files need formatting — run: stylua src/"
	fail=1
fi

echo "==> 2/3 Linting (Selene)..."
if selene src/ 2>&1 | tail -1 | grep -q "0 errors"; then
	echo "    ✅ no lint errors"
else
	echo "    ⚠️  lint issues found (see above)"
fi

echo "==> 3/3 Building (Rojo)..."
if rojo build default.project.json -o /tmp/brookhaven_check.rbxl 2>/dev/null; then
	echo "    ✅ the game builds"
else
	echo "    ❌ build FAILED — the game has a code error, fix before publishing"
	fail=1
fi

echo
if [ "$fail" -eq 0 ]; then
	echo "🎉 All good! Safe to publish with ./scripts/publish.sh"
else
	echo "🔧 Some checks need attention before publishing (see above)."
fi
exit $fail
