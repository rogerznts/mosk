# implement

Execute the active `tasks.md` and keep progress visible with minimal process overhead.

## User Input

```text
$ARGUMENTS
```

## Goal

Implement the current spec phase by phase, validate the result, and keep `tasks.md` accurate.

## Dependencies

```yaml
data:
  - fanout-seam.md # dispatch_wave contract, tier selection, join rules
```

## Workflow

1. Run `.claude/mosk/scripts/check-prerequisites.sh --json --require-tasks --include-tasks` once.

2. Load only the artifacts needed for the active work:
   - required: `tasks.md`, `plan.md`
   - optional when referenced by the task: `spec.md`, `data-model.md`, `contracts/`, `research.md`, `quickstart.md`

3. Scan `FEATURE_DIR/checklists/` if it exists.
   - If there are incomplete checklist items, warn once and continue unless the user tells you to stop.

4. **Choose how to execute: sequential, or a fan-out wave.**

   Read the `[P]` markers in `tasks.md`. If the current phase has two or more
   `[P]` units, offer a **wave**; otherwise go sequential and skip to 4b.

   **Never infer parallelism.** `[P]` means *different files, no dependencies*.
   Honour the marker as written — do not derive it by reasoning about the code,
   and do not extend it to tasks that merely look independent. Where `[P]` is
   absent, run sequentially. The cost is asymmetric: a wrongly parallel pair
   writing the same file corrupts work that would have succeeded serially.

   **4a. Fan-out wave.** Resolve the tier with
   `bash .claude/mosk/scripts/panes.sh tier --json`, then present the **fan-out
   plan** and **wait for approval**:

   > **Fan-out plan** — onda de N unidades, tier T
   > - Unidades: `T0xx`, `T0yy`, … (arquivos distintos, sem dependência)
   > - Agrupamento: o que corre junto, o que depende de quê
   > - Critério de aceite por unidade: …
   > - Teto de tentativas: N
   > - Equivalente sequencial: se preferir, executo em série (mesmo resultado,
   >   mais tempo)

   Approval is asked **once**, here. After it, dispatch and run **without asking
   again per branch** — that is the whole point of approving a plan instead of a
   step (ADR-0012 §3). Follow `../data/fanout-seam.md` for the tier mechanics.

   In Tier 3 say plainly that the parallelism is organisational, not temporal:
   the gain is isolated verification per unit, not wall-clock time.

   **4b. Execute:**
   - complete the current phase
   - run relevant tests or validations
   - mark completed tasks as `[x]`
   - report blockers only when they are real blockers

   **4c. Join (waves only).** The wave closes when **every** unit settles —
   converged, failed, or suspended. A wait timeout is a checkpoint, not a
   failure. Then report to the human: what converged, what failed and why, what
   is suspended and on what, what remains open.

   Three signals suspend **the branch that raised them**, never the whole wave: a
   `judgment` guard, an escalation, exhaustion of that unit's cap. The other
   branches keep going — halting everything would turn any local doubt into a
   global barrier and throw away the parallelism.

   **No wave starts another on its own**, and a wave never self-corrects: if the
   approved plan stops describing what is happening, report and ask for a new
   plan. Chaining is a route decision, and those stay with the human.

   Record **one entry per wave** in the phase history, never one per unit. The
   `tentativa N/max` counter is derived from that log (ADR-0008 §4); an entry per
   unit would inflate it and declare exhaustion on the first wave.

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

    **Falha de dispatch não é volta do loop.** O atuador tem disjuntor próprio:
    três falhas seguidas numa task e o dispatch é interrompido. O `max_retries`
    do MOSK conta outra coisa — voltas do gate, por spec. A coincidência do
    número 3 é acidental:

    | Contador | Mede | Nível |
    |---|---|---|
    | disjuntor do atuador | falha de despacho: o worker não produziu resultado | infra |
    | `max_retries` (ADR-0008) | não-convergência de qualidade: há resultado e o gate reprovou | produto |

    Uma unidade que estoura o disjuntor volta ao join como **unidade falha**, e o
    humano decide. **Não** consome tentativa do delivery-loop — senão uma
    instabilidade de terminal comeria o orçamento de correção da spec
    (ADR-0013 §6).

## Rules

- Do not read the entire project when the active tasks point to a narrow slice.
- Validate behavior before marking a task complete.
- Prefer finishing a clean increment over touching many areas shallowly.
