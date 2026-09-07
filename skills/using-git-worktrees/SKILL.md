---
name: using-git-worktrees
description: Use before any heavy feature work, refactoring, or modularization that touches many files - ensures work happens in an isolated git worktree so the current branch stays clean. Priorité haute pour tâches lourdes.
---

# Using Git Worktrees

## Overview

Ensure heavy work (refactoring, modularization, large features) happens in an isolated workspace. OpenCode has **no native worktree tool**, so this skill uses the **git worktree fallback** directly.

**Core principle:** Detect existing isolation first. Then create a worktree via git. Never work in place for a heavy task when a worktree is possible.

**Announce at start:** "I'm using the using-git-worktrees skill to set up an isolated workspace for <task>."

## When to Activate

- Before refactoring, modularization, or restructuring that touches 5+ files
- Before implementing a large feature or executing a written implementation plan
- When the task risks leaving the current branch dirty / hard to revert
- When `code-refactor`, `modularization`, or `executing-plans` is about to run

## Step 0: Detect Existing Isolation

**Before creating anything, check if you are already in an isolated workspace.**

```bash
GIT_DIR=$(cd "$(git rev-parse --git-dir)" 2>/dev/null && pwd -P)
GIT_COMMON=$(cd "$(git rev-parse --git-common-dir)" 2>/dev/null && pwd -P)
BRANCH=$(git branch --show-current)
```

**Submodule guard:** `GIT_DIR != GIT_COMMON` is also true inside git submodules. Verify you are not in a submodule:

```bash
git rev-parse --show-superproject-working-tree 2>/dev/null
```

**If `GIT_DIR != GIT_COMMON` (and not a submodule):** You are already in a linked worktree. Skip to Step 2 (Project Setup). Do NOT create another worktree.

Report with branch state:
- On a branch: "Already in isolated workspace at `<path>` on branch `<name>`."
- Detached HEAD: "Already in isolated workspace at `<path>` (detached HEAD)."

**If `GIT_DIR == GIT_COMMON` (or in a submodule):** You are in a normal repo checkout.

Has the user already indicated their worktree preference in your instructions? If not, ask for consent before creating a worktree:

> "Would you like me to set up an isolated worktree for this task? It protects your current branch."

Honor any already declared preference without asking. If the user declines consent, work in place and skip to Step 2.

## Step 1: Create Isolated Workspace (git worktree)

OpenCode has no native worktree tool (no `EnterWorktree`, no `/worktree` command). Use the git worktree fallback directly.

#### Directory Selection

Follow this priority order. Explicit user preference always beats observed filesystem state.

1. **Check your instructions for a declared worktree directory preference.** If the user has already specified one, use it without asking.

2. **Check for an existing project-local worktree directory:**
   ```bash
   ls -d .worktrees 2>/dev/null     # Preferred (hidden)
   ls -d worktrees 2>/dev/null      # Alternative
   ```
   If found, use it. If both exist, `.worktrees` wins.

3. **If there is no other guidance available**, default to `.worktrees/` at the project root.

#### Safety Verification (project-local directories only)

**MUST verify directory is ignored before creating worktree:**

```bash
git check-ignore -q .worktrees 2>/dev/null || git check-ignore -q worktrees 2>/dev/null
```

**If NOT ignored:** Add to .gitignore, commit the change, then proceed.

**Why critical:** Prevents accidentally committing worktree contents to repository.

#### Create the Worktree

```bash
# Determine path based on chosen location
path="$LOCATION/$BRANCH_NAME"

git worktree add "$path" -b "$BRANCH_NAME"
cd "$path"
```

**Permission fallback:** If `git worktree add` fails with a permission error (sandbox denial), tell the user the sandbox blocked worktree creation and you're working in the current directory instead. Then run setup and baseline tests in place.

**Branch name convention:** Use a short descriptive name matching the task, e.g. `refactor/paiements-echerances`, `modularisation/ops`, `feat/import-excel`. Never reuse `main` or `master`.

## Step 2: Project Setup

Auto-detect and run appropriate setup for this repository (Python/PyQt6):

```bash
# Python venv (this project uses .venv)
if [ -d .venv ]; then
    # venv already exists — nothing to install for a git worktree checkout? 
    # Python venvs are NOT shared with worktrees (absolute paths).
    # Create a project-local copy if tests are needed:
    echo "Note: venv = .venv is machine-local; reuse via absolute path or recreate."
fi
if [ -f requirements.txt ]; then
    .venv/bin/python -m pip install -r requirements.txt 2>/dev/null || pip install -r requirements.txt
fi
```

**Critical for this project:** The `.venv/` directory is **not** tracked by git and not shared with a worktree. If the worktree needs to run tests, either:
- Re-create a venv inside the worktree, OR
- Point commands back at the main repo's `.venv/bin/python` (absolute path works since the venv was created with `--upgrade-deps`/`--system-site-packages` compatibility — reuse it read-only).

**Data dir:** `data/` is runtime (gitignored). The worktree starts without local data — DB/photos/contrat are in the main checkout. Decide with the user whether to symlink them or run against a test DB.

## Step 3: Verify Clean Baseline

Run the baseline to ensure the workspace starts clean. For this project (AGENTS.md):

```bash
.venv/bin/python -m pytest tests/ -q
```

Adjust per project's actual test command.

**If tests fail:** Report failures, ask whether to proceed or investigate.

**If tests pass:** Report ready.

### Report

```
Worktree ready at <full-path>
Tests passing (<N> tests, 0 failures)
Ready to implement <feature-name>
```

## Getting Back to the Main Branch

After merging/finishing the worktree work, clean up:

```bash
git worktree remove <path> --force   # after the branch is merged
git branch -d <branch-name>          # delete merged branch
```

Or use the `finishing-a-development-branch` skill to decide how to integrate the work.

## Quick Reference

| Situation | Action |
|-----------|--------|
| Already in linked worktree | Skip creation (Step 0) |
| In a submodule | Treat as normal repo (Step 0 guard) |
| OpenCode native worktree tool | None exists → use git fallback (Step 1) |
| `.worktrees/` exists | Use it (verify ignored) |
| `worktrees/` exists | Use it (verify ignored) |
| Both exist | Use `.worktrees/` |
| Neither exists | Check instruction file, then default `.worktrees/` |
| Directory not ignored | Add to .gitignore + commit |
| Permission error on create | Sandbox fallback, work in place |
| Tests fail during baseline | Report failures + ask |
| No package.json/Cargo.toml | Skip dependency install |
| venv not shared with worktree | Re-create or reuse main checkout's venv by absolute path |
| data/ absent in worktree | Symlink or use test DB (decide with user) |

## Common Rationalizations

| Excuse | Reality |
|--------|---------|
| "I'm obviously not in a worktree — no need to check" | Run Step 0. Submodules and harness-created isolation both fool eyeballing; the detection commands settle it. |
| "The worktree directory is surely ignored already" | Run `git check-ignore`. An unignored worktree directory commits the whole tree into the repo. |
| "Any directory name works" | Explicit instructions beat an existing project-local directory, which beats the `.worktrees/` default. |
| "Refactor fast, isolation can wait" | An isolated worktree makes the heavy task revertible and reviewable. Without it, a botched refactor dirties the main branch. |
| "The workspace is fresh — baseline tests can wait" | A dirty baseline makes every later failure ambiguous. Run the tests now; proceeding past failures is your human partner's call. |