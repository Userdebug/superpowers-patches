---
name: using-superpowers
description: Use when starting any conversation - establishes how to find and use skills, requiring skill invocation before ANY response including clarifying questions
---

<SUBAGENT-STOP>
If you were dispatched as a subagent to execute a specific task, ignore this skill.
</SUBAGENT-STOP>

<EXTREMELY-IMPORTANT>
If you think there is even a 1% chance a skill might apply to what you are doing, you ABSOLUTELY MUST invoke the skill.

IF A SKILL APPLIES TO YOUR TASK, YOU DO NOT HAVE A CHOICE. YOU MUST USE IT.

This is not negotiable. You cannot rationalize your way out of this.
</EXTREMELY-IMPORTANT>

## The Rule

**Invoke relevant or requested skills BEFORE any response or action** — including clarifying questions, exploring the codebase, or checking files. If it turns out wrong for the situation, you don't have to use it.

**Before entering plan mode:** if you haven't already brainstormed, invoke the brainstorming skill first.

Then announce "Using [skill] to [purpose]" and follow the skill exactly. If it has a checklist, create a todo per item.

## Skill Priority

When multiple skills apply, process skills come first — they set the approach, then implementation skills (frontend-design, etc.) carry it out. Brainstorming and systematic-debugging are Superpowers' most common process skills, but the rule holds for any of them.

- "Let's build X" → superpowers:brainstorming first, then implementation skills.
- "Fix this bug" → superpowers:systematic-debugging first, then domain skills.

## STEP 0 — Capability Discovery Protocol

Run **silently** at session start and before any complex task. Never announce the probe; never let a failed probe block the task.

1. **Inventory tools**: read the tool list exposed by this session from your system prompt.
2. **Identify the semantic provider**:
   - Tools prefixed `pycharm_*` present → JetBrains semantic suite active.
   - `vscode_*` / LSP-style tools present → VS Code/LSP suite active.
   - Neither → native CLI/file-system mode (`grep`, `glob`, `read`, `bash`).
3. **Health-check advanced capabilities once per session**, cheaply:
   - Probe symbol search on the canonical probe symbol recorded in project AGENTS.md ("symbole sonde"); if absent, any well-known project function.
   - A capability that errors (e.g., call hierarchy failing to resolve valid symbols) is marked **FAULTY FOR THIS SESSION**: switch to its fallback immediately and do NOT re-probe it repeatedly.
4. **Read known state before re-diagnosing**: if project AGENTS.md records tool faults with dates, trust them; only re-probe on explicit doubt.

## Semantic Tool Mapping (capability-first)

Resolve each intention through the strongest available capability; fall back only when the capability is unavailable or marked faulty this session. Prefer AST/IDE-semantic resolution over raw text search. When authoring new skills or docs, describe CAPABILITIES - never hardcode provider names.

| Intention | Capability | Providers (examples) | Universal fallback |
|---|---|---|---|
| Find symbol / definition | symbol search | `pycharm_search_symbol`, LSP symbols | grep/glob on identifier |
| Impact analysis / who calls what | call hierarchy | `pycharm_analyze_calls`, LSP incoming calls | text search on identifier |
| Type & docstring inspection | symbol info / hover | `pycharm_get_symbol_info` | targeted `read_file` |
| Safe rename | semantic rename | `rename_refactoring`, `lsp_rename` | manual edit of ALL found references - never blind sed |
| Diagnostics after edit | lint/diagnostics | `lint_files`, `get_file_problems` | CLI linter via bash (`ruff`, `eslint`) BEFORE claiming done |
| Database inspect/query | database query | IDE DB tools (`execute_sql_query`, introspection) | throwaway sqlite3/python script |

**Non-IDE force multipliers**:
- Parallel subagents (`task`) for independent research across ≥2 files with no shared mutable state.
- `websearch`/`webfetch` for external API/library facts instead of guessing.
- Task tracking for any multi-step work.

## Red Flags

These thoughts mean STOP—you're rationalizing:

| Thought | Reality |
|---------|---------|
| "This is just a simple question" | Questions are tasks. Check for skills. |
| "I need more context first" | Skill check comes BEFORE clarifying questions. |
| "Let me explore the codebase first" | Skills tell you HOW to explore. Check first. |
| "I can check git/files quickly" | Files lack conversation context. Check for skills. |
| "Let me gather information first" | Skills tell you HOW to gather information. |
| "This doesn't need a formal skill" | If a skill exists, use it. |
| "I remember this skill" | Skills evolve. Read current version. |
| "This doesn't count as a task" | Action = task. Check for skills. |
| "The skill is overkill" | Simple things become complex. Use it. |
| "I'll just do this one thing first" | Check BEFORE doing anything. |
| "This feels productive" | Undisciplined action wastes time. Skills prevent this. |
| "Grep is faster than the IDE tool" | Only true until aliases, renames, or dynamic code fool text search. Semantic first, grep as fallback. |

## Platform Adaptation

If your harness appears here, read its reference file for special instructions:

- Codex: `references/codex-tools.md`
- Pi: `references/pi-tools.md`
- Antigravity: `references/antigravity-tools.md`
- Hermes Agent: `references/hermes-tools.md`

## User Instructions

User instructions (CLAUDE.md, AGENTS.md, GEMINI.md, etc, direct requests) take precedence over skills, which in turn override default behavior. Only skip skill workflows or instructions when your human partner has explicitly told you to.
