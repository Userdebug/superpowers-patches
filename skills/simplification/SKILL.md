---
name: simplification
description: |
  Clean, improve, and simplify code; find elimination cascades. Use when:
  - "Clean up this file", "Fix issues in [file]", "Analyze [file]"
  - "Refactor", "Remove dead code", "Improve code structure"
  - Same concept implemented multiple ways (cascades)
  - Growing special-case lists, "just add one more case"
  - "Don't touch that, it's complicated" situations
---

# Code Simplification

**Two modes: Tactical Cleanup + Strategic Cascades.**

---

## Mode 1: Tactical Cleanup (File Cleaner)

### When to Use
- "Clean up this file" / "Fix issues in [file]"
- Analyze code quality, remove dead code
- Minor improvements and refactoring

### Analysis Checklist
- Syntax errors / runtime errors
- Unused imports / variables
- Dead code (unreachable branches)
- Code duplication
- Missing type hints
- Inconsistent naming
- Style violations

Run the diagnostics capability first (IDE problems/linter integration when
available, e.g. `lint_files`/`get_file_problems`), fall back to CLI linters
(`ruff`, `eslint`) otherwise.

### Workflow
1. **Read** - analyze the entire file
2. **Categorize** - Critical / Warning / Info
3. **Verify safety net** - working tree must be clean in VCS (commit first if
   needed) instead of creating .bak files
4. **Fix** - apply fixes
5. **Verify** - re-run diagnostics + tests, confirm no behavior change

### Output Format
```
## Analysis: [filename]

### Issues
#### Critical: [issue at line X]
#### Warning: [issue at line Y]

### Actions Taken
- [fix]: [description]
```

### Constraints
- **Never modify** code you don't understand
- **Ask before** major changes
- **Preserve** all functionality

---

## Mode 2: Strategic Cascades

### Core Principle
**One insight eliminates multiple components.**

### When to Use
- Same concept 5+ implementations
- Growing special-case list
- "Just add one more case..."
- Refactoring feels like whack-a-mole
- "Don't touch that, it's complicated"

### Disqualifiers (Stop if Apply)
- Only superficially similar
- Abstraction needs more config than it replaces
- Loses type safety or clear errors
- Harder to understand than original

### Process

1. **Gather** - list all variations via semantic search (all definitions of
   the pattern, not just grep hits)
2. **Find essence** - ask: "What is the same underneath?"
   > "All of X are just [unified concept] with different [params]"
3. **Measure depth** - count eliminated:
   - 1-2 → refactor, not cascade
   - 3-5 → solid cascade
   - 6+ → major cascade (verify carefully)
4. **Stress-test** - do all cases fit cleanly? Carve-outs = wrong abstraction.
5. **Present** - get approval BEFORE changes.

### Proposal Template
```
## Simplification Cascade Found

**Current**: [X implementations / Y special cases]

**Insight**: "Everything is [unified concept]"

**Abstraction**: [One sentence]

**Eliminated**:
- [Component A]
- [Component B]

**Cascade depth**: [N files/functions]

**Risk**: [Edge cases to verify]
```

### Constraints
- **VCS clean state** before any cascade
- **Get approval** before major changes
- **Test** after implementation

---

## Combined Workflow

1. **Assess** - tactical (1 file) or strategic (multiple)?
2. **Choose mode** - cleanup OR cascade
3. **Analyze** - apply appropriate checklist
4. **Fix/Propose** - apply fixes or draft proposal
5. **Verify** - diagnostics + tests, approval if needed
