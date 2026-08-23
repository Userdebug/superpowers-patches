---
name: ui-governance
description: Use when writing or modifying ANY UI code (widgets, views, components, stylesheets) - enforces reuse of existing components, design tokens, and framework patterns before creating anything new. Prevents hardcoded styles, duplicated component logic, and architecture violations. Trigger even for small UI tweaks.
---

# UI Governance

## Why This Matters

UI code rots faster than any other layer because every new widget is an
invitation to reinvent a button. Once a hardcoded hex color or a hand-rolled
table sneaks into a view, it multiplies. The codebase almost always already
contains the right abstraction - the job is to find and compose it, not to
create a parallel one.

## When to Use

- Writing or editing any widget, view, component, dialog, or stylesheet
- Adding a button, table, form field, layout, or visual element
- tempted to paste styling values (colors, paddings, fonts) into view code
- Reviewing UI code for architecture compliance

## Workflow

### Step 1 - Investigate before writing (mandatory)

Before generating ANY UI element, resolve these three facts using the session's
semantic capabilities first (symbol search, then text search as fallback):

1. **Core UI framework** and its native mechanisms (e.g., PyQt/Qt widgets,
   stylesheets, layouts; Flutter theme; React component model).
2. **Existing design system / atomic components**: base classes, factories,
   centralized style modules, shared widget libraries. Search the project's
   `ui/components`, `ui/widgets`, `styles` (or equivalents) by symbol, not by
   filename guesswork.
3. **Established patterns**: how existing views wire callbacks, manage state,
   and apply styling. Read one exemplar view end-to-end before writing yours.

If semantic tools are unavailable this session, fall back to text/glob search
on class names and style tokens - but never skip the investigation.

### Step 2 - Compose, don't invent

- **Wrapped over raw**: if a factory/base class exists for a behavioral role
  (destructive action, toggle, secondary action), use it. Never instantiate a
  raw unstyled framework widget where a wrapped alternative exists.
- **Zero hardcoded design values**: no hex colors, explicit paddings, font
  sizes, or inline style strings inside views. Route everything through the
  project's central tokens/style module.
- **No speculative abstraction**: do not create subclasses or wrappers for
  trivial parameter variations (text or color change). Let the framework's
  native properties do their job.

### Step 3 - Events and dynamic data

- Inside container views (tables, lists, grids), use the parent's helper APIs
  or the framework's native event propagation instead of fighting focus and
  selection at the cell level.
- When binding callbacks to row-specific entities, capture context cleanly
  (lambda/partial with explicit binding) - never leak global mutable state.

### Step 4 - Pre-flight checklist

- [ ] Searched for an existing wrapper/factory handling this element?
- [ ] Zero hardcoded colors/sizes/style strings in my diff?
- [ ] Native framework behavior respected (no brittle workarounds)?
- [ ] Callbacks capture exactly the entity context they need?
- [ ] Project layer rules respected (e.g., UI must not import DB/services
      internals - check AGENTS.md)?

## Red Flags

| Thought | Reality |
|---------|---------|
| "It's just one label, I'll inline the color" | The second instance is already born. Use the token. |
| "The existing component is close but not exact" | Extend its API if needed; don't fork it silently. |
| "I'll copy that view and tweak it" | Extract the shared part; duplication is debt. |
