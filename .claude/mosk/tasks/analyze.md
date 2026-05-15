# analyze

Run a focused consistency review across the active spec artifacts.

## User Input

```text
$ARGUMENTS
```

## Goal

Find contradictions, missing links, or readiness gaps before implementation.

## Workflow

1. Resolve the active feature directory with `.claude/mosk/scripts/check-prerequisites.sh --json`.

2. Read:
   - `spec.md`
   - `plan.md` if present
   - `tasks.md` if present
   - optional supporting docs only when they are relevant

3. Check for:
   - contradictory scope or terminology
   - missing assumptions that block planning or execution
   - tasks that do not map back to the spec
   - required validations that are not represented
   - obvious sequencing issues

4. Report findings first:
   - blockers
   - warnings
   - ready-to-proceed signal if no important issues exist

## Rules

- Keep the report short.
- Do not create new artifacts unless the user asks.
- If there are no material issues, say so explicitly.
