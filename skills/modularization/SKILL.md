---
name: modularization
description: >
  Use when restructuring a disorganized or monolith Python project (PyQt, Flask,
  FastAPI, argparse-CLI, etc.) into a clean, sealed, layered modular layout
  (src/ pure app code, ops/ tooling, data/ runtime, extensions/ isolated modules,
  tests/ split into unit/integration/fixtures). Trigger on flat roots, mixed concerns
  at the top level, hidden data in the repo, or imports that cross layer boundaries.
---

# Modularization

**Any restructuring that touches file locations, imports, or data paths is a
refactor: never break data, never break VCS history, and stop at every gateway
for explicit user validation before mutating the tree.**

## Why This Matters

A project that works but is arranged as one flat pile eventually breaks:
data files get bundled and committed, tooling mixes with production code, tests
write onto live databases, and no one knows where any concern lives. Modularization
gives every file one unambiguous home, then freezes the boundaries with a layer
gate. The value is not the folder names — it's that the layering becomes
enforceable and future code follows it by construction.

## Target Layout

| Path | Holds | Git |
|---|---|---|
| `src/` | 100% pure production app code (UI, Services, Repositories, Models). No personal/dynamic data. | tracked |
| `ops/` | Out-of-development tooling (import scripts, migrations, client setup, arch-check gate). | tracked |
| `data/` | Dynamic runtime files (SQLite DBs, photos, generated documents, temp CSVs). | **always excluded** |
| `extensions/` | Isolated optional modules (socle + modules). | tracked |
| `tests/` | Split rigorously into `unit/` (RAM, fast), `integration/` (complex flows), `fixtures/` (data generation). | tracked |

## Workflow — Phases with Mandatory Gateways

Every phase ends with a **Gateway**: present the result and **wait for the
user's explicit validation** before starting the next phase. Do not batch or
skip a Gateway "because the next step is obvious."

### Phase 1 — Audit and classify

1. Map the current tree.
2. Classify every file/group into one of the four targets: pure app code →
   `src/`, admin tooling → `ops/`, dynamic/client data → `data/`, tests/seeds →
   `tests/`.
3. Note any non-code residue at the root (configs, specs, CI) that stays in place.

> **GATEWAY #1 (user validation required):** present the reclassification as a
> comparison table `Current location → Target location`. Do not touch a single
> file until the developer explicitly validates the mapping.

### Phase 2 — Create structure and move safely

1. Create the target directories (`src/`, `ops/`, `data/`, `tests/unit`,
   `tests/integration`, `tests/fixtures`).
2. Move files **only with the VCS move command** (e.g. `git mv`) to preserve
   history. Plain `mv`/`cp` breaks history and leaves no audit trail.
3. Add `.gitkeep` to empty `data/` subfolders so the structure is preserved.

> **GATEWAY #2 (user validation required):** show the resulting tree and confirm
> with the user that nothing at the root was omitted.

### Phase 3 — Repair imports and configure the core

1. Update **all** import paths (`import` and `from`) — resolve via the session's
   strongest capability first (semantic symbol search → call hierarchy → text
   search fallback); never blind replace-all/sed.
2. Isolate configuration in `src/config.py`:
   - Derive `BASE_DIR` dynamically relative to the source tree.
   - Route data to the root `data/` folder (never `~/`, never inside the repo).
   - Enable test isolation (e.g. in-memory DB when the test runner is detected in
     `sys.modules`).
3. Update build scripts (PyInstaller spec, packaging, entry-point launchers) to
   target the new entry point.

> **GATEWAY #3 (user validation required):** run the layer/arch-check gate and the
> test suite, present any errors, and validate the fixes with the user.

### Phase 4 — Split and secure tests

1. Separate pure unit tests (`tests/unit/`) from integration flows
   (`tests/integration/`).
2. Move destructive or mass-data-generation scripts into `tests/fixtures/`.
3. Ensure no test writes to the live `data/` DB during execution.

> **GATEWAY #4 (final sign-off, user required):** run the full unit suite and launch
> the main entry point. Get explicit developer confirmation before declaring the
> modularization delivered.

## Non-Negotiables

- **No boundary-crossing imports.** UI must not import DB/models internals or raw
  SQL; services must not import `sqlite3`. The layer gate (`ops/check_arch.py` or
  equivalent) is the enforcement, run it after every phase.
- **Data never lives in the repo.** Dynamic files live in `data/` and are
  gitignored. Do not relocate runtime data to a user's home folder or commit it.
- **Preserve VCS history.** Every move via the VCS move command; no plain
  `mv`/`cp`/manual re-creation.
- **Gateways are mandatory.** Each phase blocks on explicit user validation. No
  "I'll get sign-off at the end" — sign-off happens at every boundary.

## Common Mistakes

| Mistake | Fix |
|---|---|
| Moving files with `mv`/`cp` "it's faster" | Use the VCS move command; history is a hard requirement |
| Bundling SQLite/photos into the bundle and committing them | Move to `data/`, gitignore, keep beside the code/executable |
| Only fixing the display/importer downstream of bad data | Fix the data producer (writer/service/seed) + migrate existing rows idempotently |
| UI importing DB/models directly | Route through services; enforce with the arch gate |
| Tests writing onto the live DB | Use fixtures + in-memory/isolated DB; split seeds into `tests/fixtures/` |
| Batching all gateways into one final review | Validate at every boundary — rework is cheapest earliest |

## Verification Checklist

- [ ] All files classified; no concern left at the root
- [ ] Every move used the VCS move command; history intact
- [ ] Imports updated with capability-first discovery (no blind sed)
- [ ] `src/config.py` derives paths dynamically; data routed to `data/`
- [ ] Test isolation active under the test runner
- [ ] Layer gate passes; no boundary-crossing imports, no SQL in UI
- [ ] Unit suite and integration suite green; entry point launches
- [ ] Every Gateway received explicit user validation

## Output

Always provide:
1. **Summary** — what moved and why
2. **Mapping** — current → target for every group
3. **Files modified** — imports, config, build scripts
4. **Verification** — gate/tests/launch results
5. **Rollback** — how to undo (VCS checkout / reverse moves)
