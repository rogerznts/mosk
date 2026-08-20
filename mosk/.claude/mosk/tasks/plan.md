# plan

Create `plan.md` for the active spec and generate supporting artifacts only when they add real implementation value.

## User Input

```text
$ARGUMENTS
```

## Goal

Turn `spec.md` into an implementation plan that is clear enough for task generation without forcing unnecessary research or documentation.

## Workflow

1. Resolve the target spec yourself: current branch -> matching `branch:` field
   in a `spec-meta.yaml` under `docs/specs/`. Confirm the spec directory exists
   and read `spec.md`. Copy `../templates/plan-template.md` into
   `<spec_dir>/plan.md` if it is not there yet.

2. Load:
   - `FEATURE_SPEC`
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
   - Reuse answers already captured by `specify`/`full-spec`.
   - If invoked independently, gather every missing decision that blocks
     architecture, data modeling or public behavior and ask at most one grouped
     clarification round.
   - Otherwise, record the chosen assumption in `plan.md`.

6. If the plan introduces new technologies or conventions, update
   `.claude/rules/project.md` yourself: read the stack, framework, datastore
   and project-type decisions you just recorded in `plan.md` and reflect them
   in the rules. Interpreting a plan is judgement about content, not a
   transformation a script can do (ADR-0021 §4, question 2).

7. Report:
   - plan path
   - artifacts created
   - remaining blockers, if any
   - readiness for `tasks`

8. **Confirm the phase and refresh the index.** After `plan.md` and its required
   artifacts exist, confirm the transition to `plan` with command `plan`,
   following `../data/phase-transition-contract.md`. Then execute
   `../tasks/index-docs.md`.

## Rules

- Keep the plan implementation-oriented.
- Do not create every optional document by default.
- Prefer short sections and explicit decisions over long prose.
- Do not ask for confirmation before a valid reversible phase transition or
  index refresh.
