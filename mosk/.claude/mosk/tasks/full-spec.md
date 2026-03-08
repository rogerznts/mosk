# full-spec

Create or update the active spec package in one pass: `spec.md`, `plan.md`, and `tasks.md`.

## User Input

```text
$ARGUMENTS
```

Use the input as the source of truth for the requested change.

## Goal

Run the compact planning flow from `specify` through `tasks` without moving into implementation.

## Workflow

1. Start with the `specify` workflow.
   - Create or update the active `spec.md`.
   - Reuse the same branch and feature directory selected during `specify`.

2. Check whether planning is safe.
   - If the resulting spec still has critical ambiguity that changes scope, risk, UX, or public behavior, stop and ask one grouped clarification round.
   - If the spec is safe to continue, move on immediately.

3. Continue with the `plan` workflow.
   - Create or update `plan.md`.
   - Generate only the supporting artifacts that add real implementation value.

4. Continue with the `tasks` workflow.
   - Create or update `tasks.md`.
   - Keep the task list dependency-ordered and immediately executable.

5. Report the package status:
   - branch
   - spec path
   - plan path
   - tasks path
   - optional artifacts created
   - remaining blockers, if any
   - recommended next step: `implement`

## Rules

- `full-spec` ends at `tasks`. Never start implementation from this command.
- Keep the same quality bar as running `specify`, `plan`, and `tasks` separately.
- Do not force optional support artifacts by default.
- Prefer one compact clarification round over repeated interruptions.
