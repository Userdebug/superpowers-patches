---
name: learning
description: Self-improvement system for managing (finding/using, saving/pruning) solutions, patterns, lessons learned, and workarounds. Use whenever you discover a non-obvious fix after 2+ failed attempts, encounter unexpected behavior others might hit, or the user says "remember this", "save this pattern", "check learnings", "prior solutions".
---

# Learning System

**Purpose**: persistent knowledge base of solutions, patterns, lessons, and
workarounds - so the same non-obvious problem is never solved twice.

## Definitions

**Learnings folder**: `{repo}/docs/learnings/` (create if missing; adjust per
project AGENTS.md if it defines another location).
**File format**: `{category}-{subcategory}.md` (lowercase, hyphen-separated).

**Category examples**: `python`, `sql`, `css`, `testing`, `git`, `patterns`,
`qt`, `config`.
**Subcategory examples**: `imports`, `routing`, `errors`, `performance`,
`edge-cases`.
*(Example: `python-imports.md`, `qt-models.md`, `testing-edge-cases.md`)*

## Entry Routing

- Caller says "check learnings" / "prior solutions" / "patterns" → start at
  **Phase 1: Find**.
- Caller says "save this" / "remember this", OR you discover a non-obvious
  insight after multiple failed attempts → start at **Phase 2: Evaluate**.

---

### Phase 1: Find Learnings (when stuck or researching)

1. **Search** the learnings folder for keywords matching the current problem
   domain.
2. **Read** only matching files or relevant sections.
3. **Apply** matching Fix/Correct entries to the current task.
4. Nothing relevant found? Continue without learnings - do not block progress.

---

### Phase 2: Evaluate (Fast Fail)

Analyze the conversation for reusable, non-obvious insights. Assign a tier:

- **Tier 1 (Global/Critical)**: highly reusable, prevents major errors → save
- **Tier 2 (Domain/Useful)**: feature-specific, nice-to-know → save
- **Tier 3 (Local/Obvious)**: one-off edge case, standard documentation →
  **skip silently**

*If Tier 3, exit immediately without prompting the user.*

---

### Phase 3: Draft Content

Before drafting, check for duplicates:
- Search existing files for similar entries.
- Exact match found → exit (already captured).
- Related entry found → append/update instead of creating a new file.

Formatting rules:
- Telegraphic language (→ ✅ ❌ ⚠️)
- **Hard limit**: ≤30 lines per entry
- Include meta comment for date tracking

Unified template (bugs, errors, gotchas):
```markdown
## [Topic/Issue Name]
<!-- meta: date=YYYY-MM-DD, tier=[1|2], status=active -->
- **Trigger/Symptom**: [what happened or when to use]
- **Cause/Mistake**: [why it failed or common wrong approach]
- **Fix/Correct**: [the solution or right approach]
- **Why**: [1-line reason]
```

For **patterns and techniques** (not errors), prose format is acceptable -
still include the `<!-- meta -->` comment.

---

### Phase 4: Micro-Approval (BLOCKING)

Present a condensed summary for approval:

**💡 Proposed Learning: [Category]**
- **Issue**: [1-line description]
- **Fix**: [1-line solution]

*Save to `[file]`? (y/n)*

- Approved → save to file.
- Declined → discard silently. Do not re-propose the same learning.
- Changes requested → revise and re-present.

---

### Phase 5: Just-in-Time Maintenance

Agents do not run on a schedule. Maintenance happens during active use:

- When reading an existing learning, check its `date` metadata.
- If an entry is >6 months old AND obsolete/superseded, propose during your
  current response:
  - **Archive**: move to `{learnings folder}/archive/` (unchanged filename).
  - **Delete**: only if proven incorrect, not merely outdated.
