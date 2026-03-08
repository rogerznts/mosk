# implement

Execute the active `tasks.md` and keep progress visible with minimal process overhead.

## User Input

```text
$ARGUMENTS
```

## Goal

Implement the current spec phase by phase, validate the result, and keep `tasks.md` accurate.

## Workflow

1. Run `.claude/mosk/scripts/check-prerequisites.sh --json --require-tasks --include-tasks` once.

2. Load only the artifacts needed for the active work:
   - required: `tasks.md`, `plan.md`
   - optional when referenced by the task: `spec.md`, `data-model.md`, `contracts/`, `research.md`, `quickstart.md`

3. Scan `FEATURE_DIR/checklists/` if it exists.
   - If there are incomplete checklist items, warn once and continue unless the user tells you to stop.

4. Execute the plan in order:
   - complete the current phase
   - run relevant tests or validations
   - mark completed tasks as `[x]`
   - report blockers only when they are real blockers

5. Keep progress updates short:
   - what was completed
   - what failed
   - what is next

6. At the end, report:
   - completed tasks
   - remaining tasks
   - validations run
   - blockers or follow-up work

## Rules

- Do not read the entire project when the active tasks point to a narrow slice.
- Validate behavior before marking a task complete.
- Prefer finishing a clean increment over touching many areas shallowly.
