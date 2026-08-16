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
   - Read `.claude/mosk/data/adaptive-work-contract.md`; use its ambiguity
     signal without duplicating the scoring policy here.

2. Check whether planning is safe.
   - Gather every ambiguity that changes scope, risk, UX, data, or public
     behavior and ask at most one grouped clarification round for the entire
     `specify -> plan -> tasks` pass.
   - Reuse the answer in all later artifacts; do not reopen the interview.
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
- Do not ask for confirmation between artifact writes or valid reversible phase
  transitions. Preserve the explicit approval required to create/push a branch
  and every existing human limit for irreversible actions.
