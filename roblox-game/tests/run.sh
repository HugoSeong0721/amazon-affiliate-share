#!/usr/bin/env bash
# Headless playtest: assembles the game scripts against the mock engine and
# runs a full session. Usage: tests/run.sh [path-to-luau]
set -euo pipefail
cd "$(dirname "$0")/.."
LUAU="${1:-luau}"
for file in src/shared/Config.luau src/server/*.luau src/client/*.luau; do
  "${LUAU/luau/luau-compile}" --binary "$file" > /dev/null
done
python3 tests/build_test.py
"$LUAU" tests/run.luau
