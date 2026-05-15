# tasks

Generate a dependency-ordered `tasks.md` from the current design artifacts.

## User Input

```text
$ARGUMENTS
```

## Goal

Produce an immediately executable task list that is short, specific, and aligned with the happy path.

## Workflow

1. Run `.claude/mosk/scripts/check-prerequisites.sh --json` once and parse:
   - `FEATURE_DIR`
   - `AVAILABLE_DOCS`

2. Load the active artifacts:
   - required: `spec.md`, `plan.md`
   - optional: `data-model.md`, `research.md`, `contracts/`, `quickstart.md`

3. Generate `tasks.md` using `.claude/mosk/templates/tasks-template.md`.

4. Organize work in this order:
   - Setup
   - Foundations
   - Main feature increments
   - Validation and polish
   - Archive or release follow-up if needed

5. Keep the task list tight.
   - Target 8 to 25 tasks in most cases.
   - Merge low-value micro-tasks.
   - Use `[P]` only when tasks truly do not block each other.

6. Every task must follow the checklist format:

```text
- [ ] T001 Description with file path
```

Optional markers:
- `[P]` for parallel work
- `[US1]`, `[US2]`, ... when user-story grouping adds clarity

7. Report:
   - tasks path
   - total tasks
   - major phases
   - obvious parallel work
   - recommended MVP cut

8. **Update spec metadata and refresh index.** Update the current spec's
   `spec-meta.yaml`: set `current_phase: tasks` and bump
   `last_phase_change`. Then execute `../tasks/index-docs.md` to refresh
   `docs/index.md`. Automatic — no extra prompt.

## Rules

- Prefer executable tasks over exhaustive decomposition.
- Reference exact file paths whenever possible.
- Do not add a separate dependency graph or long narrative unless the user asks.
