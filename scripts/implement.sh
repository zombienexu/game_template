#!/usr/bin/env bash
# implement.sh — hand a task to the LOCAL executor (OpenCode → Qwen) and loop
# until the test contract passes. Claude is intentionally NOT in this loop:
# the executor self-checks against ./scripts/test.sh, so no Claude tokens are
# spent while it iterates. Use Claude only to write the spec and review the diff.
#
# Usage:
#   ./scripts/implement.sh "Implement src/score.gd so the Score tests pass"
#
# Env overrides:
#   OPENCODE_MODEL    model id          (default: litellm/brain — Qwen3-Coder 30B / 5080)
#   MAX_ATTEMPTS      retry budget      (default: 4)
#   OPENCODE_TIMEOUT  per-attempt secs  (optional; needs the `timeout` command)
#
# Note: --dangerously-skip-permissions lets the executor edit files and run the
# test command without interactive prompts. The prompt restricts edits to src/.
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

TASK="$*"
[ -n "$TASK" ] || { echo "usage: ./scripts/implement.sh \"<task description>\"" >&2; exit 2; }

MODEL="${OPENCODE_MODEL:-litellm/brain}"
MAX_ATTEMPTS="${MAX_ATTEMPTS:-4}"
LOG_DIR="$(mktemp -d)"
trap 'rm -rf "$LOG_DIR"' EXIT

RULES=$(cat <<'EOF'
You are the EXECUTOR in a planner/executor workflow. Implement the task by editing files only.

Definition of done: `./scripts/test.sh` exits 0 AND the run is memory-clean.

Rules:
- Run ./scripts/test.sh yourself, read the failures, and iterate until it passes.
- Exit 0 is necessary but NOT sufficient. The run must also report `0 orphans` and
  show NO "ObjectDB instances were leaked" or "resources still in use" warnings at exit.
  Those mean a memory-model bug (e.g. extends Object/Node instead of RefCounted) even
  though tests pass — fix the cause, do not ignore them. Any non-zero exit is a failure;
  never assume an exit code like 101 is "normal".
- Only create/edit files under src/ (and project.godot if strictly required). NEVER edit files under test/.
- Follow CLAUDE.md GDScript style: static typing everywhere, tabs, one class per file, minimal changes.
- Do not add unrelated files or features beyond what the tests require.
EOF
)

strip_ansi() { sed -E 's/\x1b\[[0-9;]*[mK]//g'; }

opencode_run() {
	# $1 = continue flag ("" or "-c"); $2 = prompt
	if [ -n "${OPENCODE_TIMEOUT:-}" ] && command -v timeout >/dev/null 2>&1; then
		timeout "$OPENCODE_TIMEOUT" opencode run $1 --dangerously-skip-permissions -m "$MODEL" "$2"
	else
		opencode run $1 --dangerously-skip-permissions -m "$MODEL" "$2"
	fi
}

cont=""
attempt=1
while [ "$attempt" -le "$MAX_ATTEMPTS" ]; do
	echo "──────── executor attempt ${attempt}/${MAX_ATTEMPTS}  (model: ${MODEL}) ────────"

	if [ "$attempt" -eq 1 ]; then
		prompt="${RULES}

TASK:
${TASK}"
	else
		fail="$(strip_ansi < "$LOG_DIR/test.out" | tail -n 40)"
		prompt="./scripts/test.sh still fails. Tail of its output:

${fail}

Fix the implementation (files under src/ only) until ./scripts/test.sh exits 0."
	fi

	opencode_run "$cont" "$prompt" 2>&1 | tee "$LOG_DIR/executor.out"
	cont="-c"  # continue the same executor session on subsequent attempts

	# Source of truth: WE run the contract, not the model's self-report.
	if ./scripts/test.sh > "$LOG_DIR/test.out" 2>&1; then
		echo
		echo "✅ GREEN on attempt ${attempt} — ./scripts/test.sh exits 0"
		echo "Changed files:"
		git status --short
		exit 0
	fi

	echo "❌ still red after attempt ${attempt}"
	attempt=$((attempt + 1))
done

echo
echo "⛔ executor did not reach green in ${MAX_ATTEMPTS} attempts."
echo "Last test output:"
strip_ansi < "$LOG_DIR/test.out" | tail -n 30
exit 1
