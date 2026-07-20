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

5. **After each completed phase, story, or chore:**
   - Go back to the originating artifact (`tasks.md`, story file, or spec) and verify every acceptance criterion or checklist item against what was actually implemented.
   - Mark delivered items as `[x]`. Report any item that was not met or only partially met.
   - Do not move to the next phase until all items for the current one are checked.

6. Keep progress updates short:
   - what was completed
   - what failed
   - what is next

7. **E2E test checklist suggestion:**
   - At the end of each completed phase, story, or chore, ask the user whether an E2E test checklist file should be created.
   - If the user agrees, create it at `FEATURE_DIR/tests/e2e-checklist-(phase|storie|plan|task)-X.md` following the format defined in the Dev agent.
   - The file must be:
    - A **numbered checklist** that a human tester can follow step by step.
    - Written in plain language so that an automation agent (Playwright, Cypress, or similar) can also interpret and execute each step.
    - **Never use markdown tables.** Use a flat list with `- [ ]` checkboxes, one item per step, with the expected result on a separate indented line.

8. At the end, report:
   - completed tasks
   - remaining tasks
   - validations run
   - blockers or follow-up work

9. **Update spec metadata and refresh index.** Update the current spec's
   `spec-meta.yaml`: set `current_phase: implement` and bump
   `last_phase_change`. Then execute `../tasks/index-docs.md` to refresh
   `docs/index.md`. Automatic — no extra prompt.

10. **Security review suggestion (conditional).** Inspect the diff you just
    implemented. If it touches security-sensitive surface — authentication or
    authorization, user-controlled input, database/queries, secrets or config,
    external/inbound endpoints, deserialization, crypto, or file/path handling —
    emit the suggestion block below and **wait**. Do not auto-invoke another
    agent (MOSK contract). Skip silently when the change is clearly non-sensitive
    (docs, pure refactor, tests). Recommended order: security **before** the gate,
    so `/mosk-qa qa-gate` can read the `SECURITY:` verdict.

    > **Security review suggested**
    > - Signal: <one line — which sensitive surface the diff touched>
    > - Recommended agent: `/mosk-security`
    > - Suggested prompt: `/mosk-security review the pending changes`
    > - Why now: diff is fresh; the verdict feeds `/mosk-qa qa-gate`.
    > - On return: resume toward the quality gate.

    Do not proceed until the user confirms `go`/`skip`/alternative.

## Rules

- Do not read the entire project when the active tasks point to a narrow slice.
- Validate behavior before marking a task complete.
- Prefer finishing a clean increment over touching many areas shallowly.
