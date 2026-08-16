# implement

Execute the active `tasks.md` and keep progress visible with minimal process overhead.

## Dependencies

```yaml
data:
  - adaptive-work-contract.md
scripts:
  - classify-change.sh
```

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

   Before expanding beyond those sources, select the observable change signals
   and run `.claude/mosk/scripts/classify-change.sh` as defined by
   `.claude/mosk/data/adaptive-work-contract.md`. Record one short line with the
   selected signals, profile and reason. Use `context_budget` as the initial
   loading boundary and `validation_floor` as the minimum validation; neither
   grants permission to broaden the agreed scope.

   Reclassify when a direct reference, failing test, changed scope or newly
   discovered sensitive surface requires more context. Record the trigger and
   keep the most rigorous result. A profile never changes pipeline phase or
   removes a human pause.

3. Scan `FEATURE_DIR/checklists/` if it exists.
   - If there are incomplete checklist items, warn once and continue unless the user tells you to stop.

4. **Choose how to execute: sequential, or delegated units.**

   **Never infer parallelism.** `[P]` means *different files, no dependencies*.
   Honour the marker as written — do not derive it by reasoning about the code,
   and do not extend it to tasks that merely look independent. Where `[P]` is
   absent, run sequentially. The cost is asymmetric: a wrongly parallel pair
   writing the same file corrupts work that would have succeeded serially.

   **4a. Delegating `[P]` units (optional).** When `tasks.md` marks two or more
   units `[P]`, you may hand each one to a `mosk-dev` subagent instead of doing
   them yourself — the runtime's own isolation, nothing else involved. Say which
   units you are delegating before you call, and report the consolidated result
   after (ADR-0016 §4). Depth is 1: a delegated unit does not delegate further.

   Each unit returns a **short status**, never a transcript — the disk is the
   state boundary. A unit that dies or comes back empty is a **failed
   invocation**, not a quality failure: you decide whether to retry it, do it
   yourself, or hand it back to the user.

   **4b. Execute:**
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

9. **Update spec metadata and refresh index.**
   ```bash
   bash .claude/mosk/scripts/transition-spec-phase.sh \
     --spec "$(basename "$FEATURE_DIR")" --to implement --command implement
   ```
   The command validates the completed task list and records the transition.
   Then execute `../tasks/index-docs.md`. Never edit `current_phase` directly.

10. **Security-review suggestion (conditional).**
    Inspect the diff you just implemented. If it touched security-sensitive
    surface — auth/authz, user input, queries, secrets/config, external
    endpoints, deserialization, crypto, file/path handling — emit the
    escalation block (`../templates/escalation-block-tmpl.md`) with the header
    **"Vale uma revisão de segurança antes do gate"**, recommending
    `/mosk-security`. Skip silently when clearly non-sensitive (docs, pure
    refactor, tests).
    Recommended order: security **before** the gate, so `/mosk-qa qa-gate`
    reads the `SECURITY:` verdict. Do not auto-invoke — wait for the user's
    resposta: `pode ir` / `pula` / outra direção (MOSK contract).

11. **O que vem depois.** `implement` entrega; quem julga é o gate.
    - Próximo passo: `/mosk-qa qa-gate {spec-id}`.
    - Se o gate reprovar, a correção volta por `/mosk-dev apply-qa-fixes`.
    - Quem decide cada volta — corrigir, escalar, dispensar ou parar — é o
      **humano**, lendo o gate. Não re-rode o gate nem se auto-corrija.
    - `readiness` (`/mosk-sm`) é **porta de entrada**, antes da primeira volta.
      Só volte a ela como escalação, quando um FAIL revelar que a *story*
      estava ambígua.

## Rules

- Do not read the entire project when the active tasks point to a narrow slice.
- Validate behavior before marking a task complete.
- Prefer finishing a clean increment over touching many areas shallowly.
