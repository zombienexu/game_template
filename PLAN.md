# PLAN.md — Godot Development Environment Setup (from scratch)

> Goal: a fast, low-friction Godot dev environment on Linux that an LLM can drive
> **purely by editing script files on disk** — no engine plugins, no in-editor AI.
> The engine hot-reloads files the agent writes; you review/edit in VS Code; tests
> are the contract (see the **planner/executor** workflow in the global CLAUDE.md).

## Decisions (locked)

| Choice            | Selection                          | Why                                                                 |
|-------------------|------------------------------------|---------------------------------------------------------------------|
| Engine            | **Godot 4.7 stable** (std, non-C#) | Latest stable (released 2026-06-18). Standard build = no .NET dep.  |
| Install method    | **Official binary** (downloaded)   | Self-contained single executable; no sandbox issues with VS Code.   |
| Language          | **GDScript**                       | No build step, fastest hot-reload, plain-text = ideal for LLM edits.|
| Editor            | **VS Code + godot-tools**          | Best-documented external-editor path; LSP + debug over a socket.    |
| Tests             | **gdUnit4**                        | First-class headless CLI runner + JUnit XML/HTML reports + CI action.|
| VCS               | **git** + Godot `.gitignore`       | `.godot/` cache is regenerated and must not be committed.           |

The agent toolchain (Claude Code planner / OpenCode-Qwen executor) already exists and
operates on files — **it needs nothing installed inside Godot**. This setup just makes
the files it edits live in a project the engine and your editor both understand.

---

## How the pieces fit (the mental model)

```
  ┌─────────────┐   edits .gd files on disk   ┌──────────────────────┐
  │ LLM agents  │ ──────────────────────────▶ │  project files       │
  │ (CC/OpenCode)│                            │  res:// (*.gd,*.tscn) │
  └─────────────┘                             └──────────┬───────────┘
                                                         │ watches & hot-reloads
                          LSP/DAP socket (127.0.0.1)     ▼
        ┌──────────────┐  :6005 LSP / :6006 DAP   ┌──────────────┐
        │   VS Code    │ ◀──────────────────────▶ │ Godot editor │
        │ (godot-tools)│                          │   (running)  │
        └──────────────┘                          └──────────────┘
                          headless run for tests  ▼
                          godot --headless + gdUnit4 runtest.sh
```

Key idea: **Godot's editor exposes a Language Server on `127.0.0.1:6005`.** VS Code's
godot-tools extension connects to it for completion/go-to-def/diagnostics, so you get
real IntelliSense that understands your project — but the editing itself is just text
files, which is exactly what the LLM agents manipulate.

---

## Phase 0 — Prerequisites (verify, don't assume)

- [ ] Confirm OS/arch: `uname -m` (expect `x86_64`) and a working GUI session (Godot
      editor needs a display; headless test runs do not).
- [ ] `git --version` — install if missing.
- [ ] VS Code installed (`code --version`). If not, install from the official repo or
      the `.deb`/Flatpak for your distro.
- [ ] Vulkan-capable GPU drivers for the editor (Godot 4 defaults to Vulkan; the
      Forward+/Mobile renderers need it). `vulkaninfo | head` to sanity-check.

## Phase 1 — Install Godot 4.7 (standard build)

- [ ] Download the **Linux x86_64 standard** build from the official site:
      https://godotengine.org/download/linux/ (file looks like
      `Godot_v4.7-stable_linux.x86_64.zip`). Pick **standard**, *not* the `.NET`/C# build.
- [ ] Install to a stable path and put it on `PATH` as `godot`:
      ```sh
      mkdir -p ~/.local/bin ~/.local/opt/godot
      unzip ~/Downloads/Godot_v4.7-stable_linux.x86_64.zip -d ~/.local/opt/godot
      chmod +x ~/.local/opt/godot/Godot_v4.7-stable_linux.x86_64
      ln -sf ~/.local/opt/godot/Godot_v4.7-stable_linux.x86_64 ~/.local/bin/godot
      ```
      (Ensure `~/.local/bin` is on `PATH`.)
- [ ] **Checkpoint:** `godot --version` prints `4.7.stable...` and
      `godot --headless --quit` exits cleanly.
- [ ] (Optional but recommended) create a desktop entry so it launches from your DE.

## Phase 2 — Create the project + version control

- [ ] Launch `godot`, create a **new project** in `/home/ztovs/work/mygame` (this repo),
      Forward+ renderer (switch to Mobile/Compatibility later if you target low-end/web).
- [ ] `git init` and add the official Godot `.gitignore` (key entries):
      ```gitignore
      # Godot 4+
      .godot/
      /android/
      *.translation
      export_presets.cfg   # contains absolute paths / secrets; keep local
      .DS_Store
      ```
      Commit `project.godot`, `icon.svg`, and your `res://` source. **Never commit
      `.godot/`** — it's a regenerable import/cache dir.
- [ ] **Checkpoint:** `git status` shows `project.godot` tracked and `.godot/` ignored.

## Phase 3 — Wire Godot to use VS Code as the external editor

In Godot: **Editor → Editor Settings → Text Editor → External**:
- [ ] Check **Use External Editor**.
- [ ] **Exec Path:** `/usr/bin/code` (verify with `which code`).
- [ ] **Exec Flags:** `{project} --goto {file}:{line}:{col}`
      (opens the project root and jumps to the exact line on double-click).
- [ ] In **Editor Settings → Network → Language Server**, confirm **Remote Port 6005**
      (default). Leave the editor running when you want LSP in VS Code.

## Phase 4 — VS Code side

- [ ] Install the **godot-tools** extension (publisher: `geequlim` / Godot Engine).
- [ ] In its settings set the Godot 4 executable path to `~/.local/bin/godot` so VS Code
      can launch/debug the project.
- [ ] Open `/home/ztovs/work/mygame` as the workspace folder (must contain `project.godot`).
- [ ] **Checkpoint:** with the Godot editor open, create `test.gd`, type a `Node.`
      member — completion should appear (proves LSP on :6005 is connected). Double-click
      a script in Godot → it jumps to the right file+line in VS Code.
- [ ] Add a `.vscode/launch.json` for DAP debugging (port 6006) so you can set
      breakpoints from VS Code. The extension can scaffold this.

## Phase 5 — Install & wire up gdUnit4 (the test contract)

> **What gdUnit4 is and why it matters for this workflow** — read this, it's the load-bearing
> part of the planner/executor loop.
>
> gdUnit4 is a unit-testing framework that lives *inside* your Godot project (as an
> addon). You write tests as GDScript files — classes extending `GdUnitTestSuite` with
> `test_*` methods and assertions like `assert_int(score).is_equal(10)`. Crucially it
> ships a **command-line runner** (`addons/gdUnit4/runtest.sh`) that executes those tests
> **headless** (no GUI) and exits non-zero on failure.
>
> Why this is the keystone of the hybrid LLM workflow:
> 1. **Tests are the hand-off contract.** The Claude Code *planner* writes acceptance
>    criteria as gdUnit4 tests in `PLAN.md`/`res://test/`. The OpenCode *executor*
>    (local Qwen) implements `res://src/` code until `runtest.sh` goes green. No
>    ambiguity, no hidden design decisions — "make these tests pass" is the spec.
> 2. **The LLM can verify itself without a human or a GUI.** Because the runner is a
>    plain CLI that returns an exit code, an agent can run it, read pass/fail, and
>    iterate — exactly the "run the project's test command and report pass/fail" rule
>    in the global CLAUDE.md.
> 3. **CI-ready.** It emits **JUnit XML + HTML reports** and has an official GitHub
>    Action, so the same command works locally and in CI later.

- [ ] Install gdUnit4 via Godot's **AssetLib** tab (search "gdUnit4"), or drop the
      release into `res://addons/gdUnit4/`. Enable it in
      **Project → Project Settings → Plugins**.
- [ ] Create a `res://test/` directory for test suites and `res://src/` for game code.
- [ ] Add a smoke test `res://test/smoke_test.gd`:
      ```gdscript
      extends GdUnitTestSuite

      func test_environment_is_sane() -> void:
          assert_int(2 + 2).is_equal(4)
      ```
- [ ] Make the runner executable and confirm a headless run:
      ```sh
      chmod +x addons/gdUnit4/runtest.sh
      ./addons/gdUnit4/runtest.sh -a res://test
      ```
      Use `--headless` implicitly via the runner; for full CI determinism the command
      is effectively:
      ```sh
      godot --headless --path . -s addons/gdUnit4/bin/GdUnitCmdTool.gd -a res://test
      ```
      (the `runtest.sh` wrapper handles this for you).
- [ ] **Checkpoint:** the smoke test reports **1 passed**, exit code `0`. Break the
      assertion on purpose → exit code is non-zero. This proves the contract loop works.

## Phase 6 — Define the canonical commands (so agents & you share one vocabulary)

Create a thin wrapper so "the test command" is one stable string the executor calls.
Add to repo root, e.g. `./scripts/test.sh`:
```sh
#!/usr/bin/env sh
set -e
godot --headless --import        # warm-up import so resources resolve
./addons/gdUnit4/runtest.sh -a res://test
```
- [ ] `chmod +x scripts/test.sh`. Document in repo `README`/CLAUDE.md that **`./scripts/test.sh`
      is THE test command** the executor must make pass.
- [ ] (Optional) `GODOT_DISABLE_LEAK_CHECKS=1` in the script to avoid false negatives
      from leak logs during headless runs.

## Phase 7 — Project structure & repo conventions

- [ ] Lay out:
      ```
      mygame/
      ├─ project.godot
      ├─ PLAN.md                  # planner→executor hand-off (this workflow)
      ├─ scripts/test.sh          # canonical test command
      ├─ src/                     # res://src  — game code (.gd, .tscn)
      ├─ test/                    # res://test — gdUnit4 suites
      ├─ assets/                  # art, audio
      └─ addons/gdUnit4/          # test framework (committed)
      ```
- [ ] Add a short project-level `CLAUDE.md` (or extend the global one) stating: test
      command = `./scripts/test.sh`, code lives in `src/`, tests in `test/`, GDScript
      style = tabs + typed vars, keep changes minimal.
- [ ] Commit the working skeleton as the baseline.

## Phase 8 — Verify the full loop end-to-end (acceptance)

- [ ] Planner (Claude Code) writes a trivial spec: a `Score` class with an `add(n)` that
      clamps at 100 — expressed as gdUnit4 tests in `res://test/score_test.gd`.
- [ ] Executor (OpenCode/Qwen) edits files in `res://src/` until `./scripts/test.sh`
      passes. Confirm the agent never had to touch the Godot GUI.
- [ ] Open the result in the Godot editor → no import errors, script hot-reloads.
- [ ] **Done when:** an LLM can take a test-defined task, edit only files, and you can
      verify pass/fail from one CLI command — with VS Code giving you full LSP nav.

---

## Notes / decisions deferred
- **C# (.NET):** skipped — would need the `.NET` Godot build + SDK and adds a compile
  step. Revisit only if the codebase outgrows GDScript.
- **Renderer:** start Forward+. If you target web/mobile/low-end, switch to Compatibility.
- **Flatpak Godot:** avoided — its sandbox needs `flatpak-spawn` gymnastics to launch an
  external VS Code. The plain binary sidesteps that entirely.
- **Pre-commit hook** running `./scripts/test.sh` is a reasonable later addition.

## Sources
- Godot 4.7 release / downloads — https://godotengine.org/download/linux/
- External editor docs — https://docs.godotengine.org/en/stable/tutorials/editor/external_editor.html
- godot-tools (VS Code) — https://github.com/godotengine/godot-vscode-plugin
- gdUnit4 — https://github.com/godot-gdunit-labs/gdUnit4 and https://godot-gdunit-labs.github.io/gdUnit4/latest/
- Godot on CI (test running) — https://saltares.com/run-automated-tests-for-your-godot-game-on-ci/
