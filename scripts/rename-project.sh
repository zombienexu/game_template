#!/usr/bin/env bash
# rename-project.sh — set this template's project name in one shot.
# Updates the Godot display name (project.godot) and the CLAUDE.md / README.md H1 titles.
#
# Usage:  ./scripts/rename-project.sh "My New Game"
set -euo pipefail

NEW="$*"
[ -n "$NEW" ] || { echo "usage: ./scripts/rename-project.sh \"My New Game\"" >&2; exit 2; }
case "$NEW" in *'|'*) echo "error: project name cannot contain '|'" >&2; exit 2 ;; esac

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

OLD="$(grep -oE 'config/name="[^"]*"' project.godot | sed -E 's/config\/name="(.*)"/\1/')"

# Escape backslash and & so they are literal in the sed replacement.
ESC="$(printf '%s' "$NEW" | sed -e 's/[\\&]/\\&/g')"

# Godot display name
sed -i -E "s|^config/name=\".*\"|config/name=\"${ESC}\"|" project.godot

# First-line H1 titles
sed -i -E "1s|^# .*\$|# ${ESC} — project conventions|" CLAUDE.md
[ -f README.md ] && sed -i -E "1s|^# .*\$|# ${ESC}|" README.md

echo "✓ Project renamed: '${OLD}' → '${NEW}'"
echo "  Updated: project.godot, CLAUDE.md$([ -f README.md ] && echo ', README.md')"
echo
echo "Next steps:"
echo "  • Delete the worked example if you don't need it:"
echo "      git rm src/score.gd src/score.gd.uid test/score_test.gd test/score_test.gd.uid"
echo "  • Rename your clone directory and point the git remote at your own repo."
