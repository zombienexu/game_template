# Game Template — project conventions

Godot 4.7 (standard build, GDScript). Planner/executor workflow per the global
CLAUDE.md. See `PLAN.md` for the environment setup and `PLAN.md` hand-offs for tasks.

## The test command (the contract)
- **`./scripts/test.sh`** is THE test command. It must exit `0`.
- Tests are gdUnit4 suites in `res://test/` (`extends GdUnitTestSuite`, `test_*` methods).
- Acceptance criteria for any task are written as tests the executor must make pass.
- **Exit 0 is necessary but not sufficient.** A clean run also shows `0 orphans` and
  NO `ObjectDB instances were leaked` / `resources still in use` warnings. Those mean a
  memory-model bug (e.g. `extends Object`/`Node` where `RefCounted` was wanted) even when
  tests pass. Never treat a non-zero exit (e.g. 101) as "normal".

## The executor loop (how work gets done — read this)
Two-tier loop (see global CLAUDE.md). **Claude = planner/reviewer. It does NOT implement
in the normal flow.** The local model implements.
- **Executor:** OpenCode → `litellm/brain` (Qwen3-Coder 30B on the 5080, via LiteLLM at
  `localhost:4000`). Driven by **`./scripts/implement.sh "<task>"`**, which loops the
  executor until `./scripts/test.sh` is green (verifies independently; up to `MAX_ATTEMPTS`).
- **The cycle:**
  1. Planner (Claude/Opus) writes the spec as **failing tests** in `res://test/` — the contract.
  2. `./scripts/implement.sh "<task>"` — the local model edits only `src/` until green. **Claude is not in this loop.**
  3. Reviewer (Claude/Sonnet, `/review-local`) reads the **final `git diff` only** and catches what green hid.
  4. If wrong: tighten the contract (add a test that pins the intent) and re-run step 2 — don't hand-fix.
- **Token discipline (the whole point — save Claude usage):**
  - Keep Opus OUT of the iteration loop; let the executor self-check against the test command.
  - Do NOT paste full executor/test output into Claude. Hand it `green` + `git diff`, nothing more.
  - Review is the quality gate and runs on Sonnet, not Opus.
- `implement.sh` knobs: `MAX_ATTEMPTS` (default 4), `OPENCODE_MODEL` (default `litellm/brain`;
  `litellm/fast` = 7B for trivial tasks), `OPENCODE_TIMEOUT` (per-attempt seconds).

## Layout
- `src/`     — game code (`.gd`, `.tscn`). Engine path `res://src`.
- `test/`    — gdUnit4 test suites. Engine path `res://test`.
- `assets/`  — art, audio, fonts.
- `scripts/` — dev tooling (e.g. `test.sh`). Not shipped game code.
- `addons/gdUnit4/` — test framework (committed, do not edit).

## GDScript style
- Static typing everywhere: typed vars, params, and return types (`-> void`).
- Tabs for indentation (Godot default).
- One class per file; `class_name` for reusable types.
- Keep changes minimal; match surrounding patterns; no drive-by refactors.

## Don't commit
- `.godot/` (regenerable cache), `/reports/` (test output), `export_presets.cfg`,
  `.claude/settings.local.json`. Already in `.gitignore`.

## Engine binary
- `godot` is on PATH (`~/.local/bin/godot` → 4.7 stable). `GODOT_BIN` overrides.
