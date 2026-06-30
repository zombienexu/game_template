# Game Template

A batteries-included **Godot 4.7 + GDScript** starter wired for a **two-tier LLM workflow**:
a planner/reviewer (Claude Code) writes tests and reviews diffs, while a **local model**
(OpenCode → Qwen) does the implementation — with **gdUnit4 tests as the contract**.

The goal: spin up a new game with the dev loop, tests, and editor integration already
solved, and keep expensive cloud-LLM usage low by offloading implementation to a local model.

## What's inside
- **Godot 4.7** project skeleton — `src/` (code), `test/` (tests), `assets/`, `scripts/` (tooling).
- **gdUnit4** test framework (committed) + **`./scripts/test.sh`** — the one canonical test command.
- **`./scripts/implement.sh`** — hands a task to the local executor and loops until tests pass.
- **`./scripts/rename-project.sh`** — renames the project in one command.
- **VS Code** config (`.vscode/`) for the `godot-tools` extension (LSP + debug).
- A worked example — `src/score.gd` + `test/score_test.gd` — demonstrating the loop (safe to delete).
- Conventions in **`CLAUDE.md`**; full environment-setup history in **`PLAN.md`**.

## Start a new game from this template
```sh
# 1. Clone (or click "Use this template" on GitHub)
git clone git@github.com:zombienexu/game_template.git my-new-game
cd my-new-game

# 2. Rename the project
./scripts/rename-project.sh "My New Game"

# 3. (optional) remove the worked example
git rm src/score.gd src/score.gd.uid test/score_test.gd test/score_test.gd.uid

# 4. Point the remote at your own repo, then build
git remote set-url origin git@github.com:<you>/my-new-game.git
```
> Tip: enable **Settings → Template repository** on GitHub to get the green
> "Use this template" button for one-click copies.

## The workflow (TL;DR)
1. **Plan** — the planner writes the spec as *failing* gdUnit4 tests in `test/` (the contract).
2. **Implement** — `./scripts/implement.sh "<task>"` runs the local model until `./scripts/test.sh` is green. The cloud LLM is **not** in this loop.
3. **Review** — the planner reviews the final `git diff` only; if wrong, tighten the contract with a new test and re-run.

See `CLAUDE.md` for the full workflow, token discipline, and the executor model config.

## Requirements
- **Godot 4.7** on `PATH` as `godot` (`GODOT_BIN` overrides). See `PLAN.md` for install.
- **Tests:** gdUnit4 is bundled — just run `./scripts/test.sh` (exit `0` = pass).
- **Executor loop (optional):** OpenCode + a local model endpoint (defaults to `litellm/brain`). Without it, you can still write code by hand and use `./scripts/test.sh`.

## Daily commands
```sh
godot --editor --path .                 # open the editor
./scripts/test.sh                       # run all tests (the contract)
./scripts/implement.sh "<task>"         # hand a task to the local executor
```
