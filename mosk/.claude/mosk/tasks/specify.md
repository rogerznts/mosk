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
   - Check the current Git branch first.
   - **If the current branch is NOT `main`/`master`/`develop`/`dev`**: you are already on a feature branch or environment branch. **Do NOT create a new branch. Do NOT run `create-new-feature.sh`.** Reuse the current branch and infer `docs/specs/{branch}/spec.md`.
   - **Only if the current branch IS a base branch (`main`, `master`, `develop`, `dev`)**: a new feature branch is needed. **Before creating it, you MUST ask the user for explicit confirmation.** Present:
     - the proposed branch name (type + short name)
     - the next available number (check `docs/specs/` directories for the highest existing prefix)
     - wait for a clear "yes" / confirmation before proceeding
   - Only after user confirmation, run `.claude/mosk/scripts/create-new-feature.sh --json` once. The script auto-detects the next available number globally to avoid collisions.
   - Parse the JSON output for the final branch and spec path.
   - **Never create a branch automatically. Branch creation always requires user approval.**

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
