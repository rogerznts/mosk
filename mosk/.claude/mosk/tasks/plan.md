# plan

Create `plan.md` for the active spec and generate supporting artifacts only when they add real implementation value.

## User Input

```text
$ARGUMENTS
```

## Goal

Turn `spec.md` into an implementation plan that is clear enough for task generation without forcing unnecessary research or documentation.

## Workflow

1. Run `.claude/mosk/scripts/setup-plan.sh --json` once and parse:
   - `FEATURE_SPEC`
   - `IMPL_PLAN`
   - `SPECS_DIR`
   - `BRANCH`

2. Load:
   - `FEATURE_SPEC`
   - `.claude/mosk/constitution.md`
   - the copied `IMPL_PLAN` template

3. Fill `plan.md` with the minimum useful sections:
   - scope summary
   - technical approach
   - assumptions and constraints
   - dependencies
   - implementation milestones
   - validation strategy

4. Generate supporting artifacts only when the feature needs them:
   - `research.md` for unresolved technical choices
   - `data-model.md` for non-trivial entities or state transitions
   - `contracts/` for APIs, schemas, or external integrations
   - `quickstart.md` only if there is a meaningful end-to-end verification flow worth documenting

5. Use reasonable defaults.
   - Ask questions only when a missing decision blocks architecture, data modeling, or public behavior.
   - Otherwise, record the chosen assumption in `plan.md`.

6. If the plan introduces new technologies or conventions, run `.claude/mosk/scripts/update-agent-context.sh update_agent_file`.

7. Report:
   - plan path
   - artifacts created
   - remaining blockers, if any
   - readiness for `tasks`

8. **Update spec metadata and refresh index.** Update the current spec's
   `spec-meta.yaml`: set `current_phase: plan` and bump
   `last_phase_change`. Then execute `../tasks/index-docs.md` to refresh
   `docs/index.md`. Automatic — no extra prompt.

## Rules

- Keep the plan implementation-oriented.
- Do not create every optional document by default.
- Prefer short sections and explicit decisions over long prose.
