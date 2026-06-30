#!/usr/bin/env sh
# THE canonical test command for this project.
# The planner writes acceptance tests; the executor must make this exit 0.
#
# Usage:  ./scripts/test.sh [extra gdUnit4 args]
#   ./scripts/test.sh                       # run everything in res://test
#   ./scripts/test.sh -a res://test/foo.gd  # run a single suite
set -e

# Resolve repo root regardless of where this is invoked from.
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

# Locate the Godot binary (PATH symlink, or override with GODOT_BIN).
: "${GODOT_BIN:=$(command -v godot || echo "$HOME/.local/bin/godot")}"
export GODOT_BIN

# Avoid false negatives from leak/orphan logs during headless runs.
export GODOT_DISABLE_LEAK_CHECKS=1

# 1) Warm-up import so resources/scripts resolve before tests run.
"$GODOT_BIN" --headless --path . --import >/dev/null 2>&1 || true

# 2) Run the suite. Default target is res://test; callers may override args.
if [ "$#" -eq 0 ]; then
	set -- -a res://test
fi
exec ./addons/gdUnit4/runtest.sh "$@"
