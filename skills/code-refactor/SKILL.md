---
name: code-refactor
description: >
  Universal refactoring skill for code and database changes. Use this skill whenever:
  - Renaming tables, columns, functions, classes, or variables
  - Refactoring, migrating, or updating references
  - Cleaning up obsolete code or old tables
  - Fixing broken references after changes
  - Column/field name mismatches
  - Duplicate tables or data structures
  - Any code or database restructuring
---

# Universal Refactoring

**Refactoring principles: never break data, find ALL references, verify
before delete.**

## Discovery (capability-first)

Resolve references with the strongest capability available this session, in
this order:

1. **Semantic symbol search** (`search_symbol` / LSP find-references) → all
   definitions and usages of the symbol. Catches dynamic aliases grep misses.
2. **Call-hierarchy analysis** (incoming calls) before changing any signature:
   know every caller, not just importers.
3. **Text search on the identifier** — fallback when semantic tools are
   unavailable or marked faulty this session. Acceptable for literal names;
   expect false negatives on aliased imports.
4. **Renames**: use the semantic rename capability (`rename_refactoring` /
   `lsp_rename`) so every reference updates atomically. **Never** blind
   replace-all/sed across files.

Database introspection: use the session's database-query capability when
available; fallback to direct inspection:

```sql
SELECT name FROM sqlite_master WHERE type='table';
PRAGMA table_info(table_name);
```

## Common Issues

### dict(row) Key Mismatch

```python
# Query returns alias, not column name
cursor.execute("SELECT si AS starting_inventory FROM ...")
row["starting_inventory"]  # ✓ works
row["si"]                  # ✗ KeyError - key is "starting_inventory"

# Verify keys before refactoring accessors
print(row.keys())
```

### Derived Data Has ONE Producer

If a wrong value appears in stored rows (labels, totals, denormalized fields),
fix the generator that wrote it AND migrate existing rows idempotently at
startup. Never compensate downstream (formatter/parser) for data corrupted at
the source.

## Refactoring Patterns

### Table rename: copy → update → verify → delete
1. `INSERT INTO new SELECT * FROM old`
2. Update all code references (discovery above)
3. VERIFY application works against the new table
4. `DROP` old table only after verification

### Column rename: align keys end-to-end
1. Check query alias ↔ code accessor expectations
2. Update `dict(row)` accesses
3. Verify calculations still resolve correct columns

### Function/method rename: find → update → verify
1. Find all call sites (semantic first, text fallback)
2. Apply semantic rename where possible; manual edits elsewhere
3. Run diagnostics + tests; no orphaned references remain

## Verification Checklist

- [ ] All references identified (semantic + text cross-check)
- [ ] Data migrated before any delete
- [ ] Diagnostics clean after edits
- [ ] Application starts without errors
- [ ] No orphaned references remaining
- [ ] Calculations produce expected values

## Output

Always provide:
1. **Summary** - what changed and why
2. **Files modified** - list
3. **Verification** - commands run and their results
4. **Rollback** - how to undo
