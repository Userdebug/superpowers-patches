# OpenCode reference

OpenCode runs in three harnesses: the **CLI/TUI**, the **VS Code extension**, and
IDEs that expose an OpenCode/MCP bridge (e.g. JetBrains via the `pycharm_*`
tool suite). The same global skills/config are injected wherever opencode starts,
so this file only pins what is OpenCode-native. Detect the tool list at session
start (Step 0); prefer the strongest capability present, fall back to the CLI
equivalents below.

## Core tool map (any harness)

| Intent | Native tool | Fallback |
|---|---|---|
| Task planning / tracking | `todowrite` (multi-step work) | keep a manual checklist |
| Read files | `read` (parallel, with offset/limit) | `bash` only if `read` unavailable |
| Edit files | exact-search `edit` (never blind sed) | `bash` for mechanical bulk ops |
| Create files | `write` (absolute path) | — |
| Search files | `glob`, `grep` (regex, include-filter) | `bash` `rg` when counting matches |
| Run commands | `bash` (persistent shell, `workdir` param — avoid `cd &&`) | — |
| Subagents | `task` (`subagent_type`: `explore` / `general`); dispatch several in ONE message for parallel | sequential research |
| Skills | `skill` tool (load by name) | read the SKILL.md directly |
| Web | `websearch` / `webfetch` (verify external facts, never guess URLs) | — |
| User feedback | `feedback` / `/help` (about opencode: check https://opencode.ai/docs) | — |

## Subagents (task)

- Parallel dispatch = multiple `task` calls in a single message. Sequential =
  one per message.
- `explore` = fast codebase reconnaissance («quick»/«medium»/«very thorough»).
  `general` = multi-step autonomous work; give a highly detailed prompt, state
  whether it writes code or only researches, and specify the exact information
  to return.
- A subagent's final message is NOT visible to the user — relay the result
  yourself. Reuse an agent with `task_id` to resume a session if the harness
  supports it.
- Do not duplicate work you delegated: continue with non-overlapping tasks or
  wait.

## Semantic providers

- JetBrains: `pycharm_search_symbol` / `pycharm_get_symbol_info` /
  `pycharm_analyze_calls` (may be faulty — trust AGENTS.md fault notes),
  `pycharm_lint_files`, semantic `pycharm_rename_refactoring`.
- VS Code / generic LSP: `vscode_*` symbols, lint, rename.
- Neither → native CLI mode (`grep`/`glob`/`read`).

## Conventions that matter

- Tool artifacts (temp files, run output) live under the session's scratch dir;
  keep the workspace clean.
- Never commit unless explicitly asked; never update git config or force-push.
- Git: inspect `git status`, `git diff`, `git log --oneline -10` before any
  commit; stage only intended files; write concise messages matching repo style.