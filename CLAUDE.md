# mygame — project conventions

Godot 4.7 (standard build, GDScript). Planner/executor workflow per the global
CLAUDE.md. See `PLAN.md` for the environment setup and `PLAN.md` hand-offs for tasks.

## The test command (the contract)
- **`./scripts/test.sh`** is THE test command. It must exit `0`.
- Tests are gdUnit4 suites in `res://test/` (`extends GdUnitTestSuite`, `test_*` methods).
- Acceptance criteria for any task are written as tests the executor must make pass.

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
