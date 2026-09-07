---
name: pre-deploy
description: Use when preparing a deliverable build, packaging for distribution, configuring remote CI/CD builds, or diagnosing cross-platform and packaging failures
---

# Pre-Deploy Readiness

## Overview

Deliverable builds fail on omitted assets, hidden imports, and host/target mismatches — not on code logic. Validate the package the way the user will run it.

## The Iron Law

```
NO SHIP WITHOUT A GREEN AUDIT
```

If any BLOQUANT pillar is red, do not build, tag, or publish. Fix it first.

## When to Use

**Use when:**
- Packaging a desktop/CLI app for distribution (PyInstaller, Nuitka, Briefcase, cx_Freeze, or equivalent)
- Selecting which files to bundle (DB, user data, configs, assets, native libs)
- Build fails or the packaged app crashes / shows missing files on launch
- Preparing or fixing remote CI/CD that builds the distributable
- Asked to ship on a different OS/arch than the dev machine

**Skip when:** single-file logic fix, typo, or doc edit with no packaging, asset, dependency, or CI impact. This skill is for deliverables, not trivial corrections.

## The 7 Pillars — Quick Reference

| # | Pillar | Fail-fast probe (seconds) | Severity if red |
|---|--------|---------------------------|-----------------|
| 1 | **Repo hygiene** | `git status --porcelain` clean? untracked bundle assets? | BLOQUANT if required asset untracked & unbundled |
| 2 | **Dependencies & hidden imports** | `py_compile` all files + `pip freeze` vs manifest + grep `importlib`/`entry_points`/dynamic plugins | BLOQUANT |
| 3 | **Architecture / layering** | Project arch gate (e.g. `check_arch.py`) + forbidden imports | BLOQUANT |
| 4 | **Data & migrations** | Migrations idempotent? FK/WAL/indexes? seed does not overwrite prod? | BLOQUANT |
| 5 | **Build blockers** | Linter + absolute paths vs `BASE_DIR`/`sys._MEIPASS` + Qt/native plugins | BLOQUANT |
| 6 | **Deliverable cleanup** | `__pycache__`/`*.pyc`/`-wal`/`-shm`/`*.log` outside bundle; dev DB not shipped as prod | WARNING |
| 7 | **Environments & remote CI** | Host OS ≠ target OS? remote runner matrix? cache + `sha256` artefact? | BLOQUANT if cross-build assumed portable |

In-chat checklist at the end of this skill is the exit gate — render it in chat, not in a report file.

## Workflow

### Step 0 — Capability discovery (silent)

Follow `using-superpowers` STEP 0: inventory semantic provider (`pycharm_*` vs LSP vs native), health-check once, respect `AGENTS.md` fault notes. Faulty `analyze_calls` → text search fallback immediately.

### Step 1 — Fail-fast probes (parallel)

Run in this order; stop on first BLOQUANT. Pillars 1-4 are independent — dispatch parallel subagents when no shared mutable state.

1. **Syntax:** `python -m py_compile` (or `python -m compileall`) — 10 s.
2. **Arch gate:** project linter/arch check (e.g. `scripts/check_arch.py`). Fallback: capability-first diagnostics (`lint_files` / `get_file_problems` → CLI `ruff`/`flake8`).
3. **Types/diagnostics** on changed files.
4. **Tests:** `python -m pytest` (not bare `pytest`) — respects repo `PYTHONPATH`.
5. **Import/asset audit:** grep `importlib`, `QStandardPaths`, `BASE_DIR`, dynamic `glob`/`import *`.
6. **Dry build:** `onedir` / unpacked bundle first. `onefile` only after `onedir` launches.

### Step 2 — Bundled assets

- **Source of truth is runtime, not git.** `git ls-files` misses `.gitignore`'d runtime data (DB, photos, user configs). Enumerate what the app *reads at launch* via symbol search (`search_symbol` for `BASE_DIR`/`DB_PATH`/`PHOTOS_DIR`/`settings`/`contrat`) → text grep fallback → confirm with a throwaway `sqlite3`/`python -c` probe, not IDE DB assumptions.
- **Datas vs binaries vs hooks:** code → `datas` (templates, styles, `ui/`, `data/*.json.example`); native libs/Qt plugins → `binaries`/`hooks` (e.g. `PyQt6.sip`, `platforms/`, `reportlab`/`openpyxl`/`Pillow` hooks).
- **Portable storage:** bundle-relative paths via `BASE_DIR`/`sys._MEIPASS` fallback; user exports via `QStandardPaths::DocumentsLocation` (never inside the bundle). Verify duplicated path constants are aligned (e.g. `config.py` vs `db_manager.py:DB_PATH` pattern).
- **Never bundle** `.venv/`, `__pycache__/`, `*.pyc`, `*-wal`/`*-shm`, or a dev DB as production seed unless the app explicitly recreates it.

### Step 3 — CI/CD & cross-platform

- **Cross-build is not portable.** A Linux-built `PyQt6` exe does not run on Windows. Windows target → `windows-latest` runner; macOS → `macos-latest`. Document this, do not attempt Wine cross-compile as a shortcut.
- **Remote build pattern (GitHub Actions example):** matrix `os: [windows-latest, ubuntu-latest]` (add `macos-latest` when needed), `python` setup + `pip` cache, `python -m pytest`, `pyinstaller --onedir` (then `onefile` if policy), `sha256sum` artefact, upload artefact, draft release on tag `v*`. See `references/build-matrix.md`.
- **Local ≠ remote proof.** A green local build does not prove the remote runner has the same Qt/native deps.

### Step 4 — In-chat exit checklist

Render this in chat and check every box before `git tag` / `publish`. Do not create a report file.

```markdown
- [ ] Pillar 1 — `git status` clean or intentional untracked explained; required assets listed in bundler `datas`
- [ ] Pillar 2 — `py_compile` green; hidden imports declared (`hiddenimports`/`hooks`); dynamic plugins enumerated
- [ ] Pillar 3 — arch gate green (no UI→DB/sqlite3, no wildcards, no alias shims)
- [ ] Pillar 4 — migrations idempotent; app launches on empty `data/` and recreates DB
- [ ] Pillar 5 — no absolute dev paths; `BASE_DIR`/`_MEIPASS` fallback present; native/Qt plugins included
- [ ] Pillar 6 — bundle excludes `.venv/__pycache__/*-wal/*-shm`; dev DB not shipped as prod
- [ ] Pillar 7 — target OS built on matching runner (or matrix); artefact `sha256` published
- [ ] Smoke — `onedir` bundle launched from clean dir (no `.venv` on PATH) and exercised once
```

If any BLOQUANT box is unchecked, state it verbatim and stop.

## Red Flags — STOP and Audit

| Thought | Reality |
|---------|---------|
| "It builds on Linux, the Windows exe will work too" | PyQt/native wheels are OS-specific. Build Windows on Windows. |
| "PyInstaller is cross-platform" | The *tool* runs everywhere; its *output* does not. |
| "gitignored means not shipped" | Runtime data is often gitignored *and* required in the bundle. Audit runtime reads. |
| "If it's not imported, it's not needed" | Dynamic `importlib`/`entry_points`/plugin dirs are invisible to static grep. |
| "Just include the dev DB, users can overwrite it" | Ships test data and breaks first-launch init. Recreate, don't bundle. |
| "Small typo fix — skip the audit" | Out of scope for this skill (correctly skipped). Don't conflate with deliverable builds. |

## Common Rationalizations

| Excuse | Reality |
|--------|---------|
| "I'll add the hook/hiddenimport later if it crashes" | Missing hook = BLOQUANT. Declare before build. |
| "`git ls-files` is the bundle" | Misses `.gitignore`'d runtime assets. Trace `BASE_DIR` reads instead. |
| "Build succeeded so it's fine" | Build ≠ launch. Smoke-launch the bundle from a clean dir. |
| "Signing/installer is v2" | Unsigned bundles are blocked by Defender/Gatekeeper. Treat as BLOQUANT for distribution. |
| "CI is green locally" | Local ≠ runner. Reproduce on the target runner matrix. |

## Supporting Reference

- `references/build-matrix.md` — OS × packager (PyInstaller primary) × Qt/native pitfalls and minimal CI workflow.
