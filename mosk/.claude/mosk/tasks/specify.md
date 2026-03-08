# specify

Create or update the active `spec.md` from a natural-language request.

## User Input

```text
$ARGUMENTS
```

Use the input as the source of truth for the requested change.

## Goal

Produce a short, implementation-safe specification that is ready for planning without turning every unknown into a blocker.

## Workflow

1. Check whether `.claude/mosk/constitution.md` exists.
   - If it is missing, run `../tasks/constitution.md` first, then continue.

2. Determine the spec type:
   - `feature`
   - `fix`
   - `hotfix`
   - `gmud`
   - `refactor`
   - `experimental`
   Use a reasonable default from the request. Ask only if the choice materially changes urgency or rollout.

3. Determine the active branch and spec path.
   - If the current branch is not `main` or `master`, reuse it and infer `docs/specs/{branch}/spec.md` when needed.
   - Otherwise, find the next available number for the short name and run `.claude/mosk/scripts/create-new-feature.sh --json` once.
   - Parse the JSON output for the final branch and spec path.

4. Load `.claude/mosk/templates/spec-template.md`.

5. Write or update `spec.md` with these minimum outcomes:
   - problem or opportunity
   - users or actors
   - core scenarios
   - functional requirements
   - edge cases
   - assumptions and defaults chosen
   - success criteria

6. Use defaults aggressively.
   - Only insert `[NEEDS CLARIFICATION: ...]` when the answer changes scope, risk, UX, or public behavior.
   - Hard limit: 3 markers total.

7. Do not generate checklists automatically.
   - `clarify`, `analyze`, and `checklist` are optional follow-up steps.

8. Report:
   - branch name
   - spec path
   - chosen spec type
   - clarification marker count
   - recommended next step:
     - `plan` when the spec is ready
     - `clarify` only when critical markers remain

## Rules

- Keep the spec readable by both product and engineering.
- Do not leak implementation detail unless the request explicitly requires it.
- Do not ask the user to repeat the original request unless the input is empty.
