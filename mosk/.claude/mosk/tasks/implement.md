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

5. **After each completed phase, story, or chore — record, do not judge.**
   - Go back to the originating artifact (`tasks.md`, story file, or spec) and
     mark as `[x]` the items you actually delivered. This is a **factual record**
     of what was touched.
   - Report anything you could not deliver, or delivered only in part, and say so
     plainly. Under-reporting here is what makes the gate blind.
   - Do not move to the next phase while items of the current one are open.

   **Do not rule on acceptance criteria.** Whether the work *satisfies* an AC is
   decided by `qa-gate`, in a clean context. You carry the history of every
   decision and trade-off you made — that history is exactly what makes a
   self-assessment justify the result instead of testing it. Give the gate the
   facts; let it judge (ADR-0012, spec 010 US2).

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

9. **Update spec metadata and refresh index.** Move the phase through the
   reducer so it is validated against the graph and audited:
   ```bash
   source .claude/mosk/scripts/common.sh
   update_spec_phase "$FEATURE_DIR" implement
   ```
   `update_spec_phase` bumps `last_phase_change`, appends to the spec's
   `phase-history.log`, and — if the transition is off-graph — **warns but
   proceeds** (never blocks; ADR-0006). Then execute `../tasks/index-docs.md`
   to refresh `docs/index.md`. Automatic — no extra prompt.

10. **Side-trip / security-review suggestion (conditional, graph-derived).**
    Inspect the diff you just implemented, then ask the graph what side-trips
    leave `implement`:
    ```bash
    bash .claude/mosk/scripts/legal_moves.sh implement
    ```
    If the `diff_security_sensitive` judgment guard holds (auth/authz,
    user input, queries, secrets/config, external endpoints, deserialization,
    crypto, file/path), emit the **Security review suggested** block using the
    single format in `../templates/escalation-block-tmpl.md`, filled from the
    graph (`security-review` → `mosk-security`). Same for any escalation the
    graph lists for this phase (e.g. `missing_adr → architecture`). Skip
    silently when clearly non-sensitive (docs, pure refactor, tests).
    Recommended order: security **before** the gate, so `/mosk-qa qa-gate`
    reads the `SECURITY:` verdict. Do not auto-invoke — wait for the user's
    `go`/`skip`/alternative (MOSK contract).

11. **Delivery-loop: fronteira do ciclo (ADR-0008).** `implement` faz parte
    de um loop de convergência **consultivo e limitado**:
    - **1ª volta:** `implement` (este passo). **Voltas seguintes:** você chega
      aqui via `apply-qa-fixes` (que registra o loopback `qa-gate → implement`
      no `phase-history.log` — é o que alimenta o contador `tentativa N/max`).
    - `security-review` roda **entre** implement e gate, só se o diff tocar
      superfície sensível (passo 10).
    - `readiness` é **porta de entrada** (antes da 1ª volta), **não** se repete
      a cada volta. Só volte a `readiness` como **escalação**, quando um FAIL
      revelar que a *story* estava ambígua (não como parte do ciclo).
    - O loop **nunca itera sozinho**: quem decide cada volta (corrigir /
      escalar / waive / parar) é o humano, guiado pelo `qa-gate`.

## Rules

- Do not read the entire project when the active tasks point to a narrow slice.
- Validate behavior before marking a task complete.
- Prefer finishing a clean increment over touching many areas shallowly.
