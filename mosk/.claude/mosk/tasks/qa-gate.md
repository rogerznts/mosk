# qa-gate

Create or update a quality gate decision for the active spec or story.

## Goal

Produce a minimal gate artifact that answers one question clearly: can this move forward?

## Workflow

1. Read `.claude/mosk/core-config.yaml` and resolve the gate location.
   - **Spec-level gate (default):** write to the per-spec `specs.gateFile`
     → `docs/specs/{id}/gate.yaml`. **This is the location the per-spec
     pipeline, `index-docs`, and the delivery-loop (`legal_moves`) read** —
     writing elsewhere makes the loop blind to the verdict (QA-1, ADR-0008).
   - **Story-level gate:** for a specific story, `{qa.qaLocation}/gates/`
     remains valid (BMAD lineage). `legal_moves` falls back to the newest file
     there when no per-spec `gate.yaml` exists.

2. **Verify the acceptance criteria yourself — this is the gate's job, not the
   implementer's (spec 010 US2).**

   Read every AC from the originating artifact (story, spec, or `tasks.md`) and
   check it **against the delivered result**: the code, the tests, the running
   behaviour. Not against the implementer's report of what they did.

   Two rules make this verification worth anything:

   - **Clean context.** Judge the artifact as it stands. Do not inherit the
     reasoning, trade-offs or constraints that led to it. Whoever built it can
     explain away every gap — that is precisely why they must not be the one
     ruling on it. You are the editor reading the finished piece, not the author
     recalling how hard the shoot was.
   - **`[x]` is a claim, not proof.** A checked box in `tasks.md` records that
     the implementer touched the item. It is evidence to be checked, never a
     substitute for checking. An unmet AC under a ticked box is exactly the
     failure this gate exists to catch.

   When the runtime offers isolation, run this step through
   `invoke_phase_agent` so the verification really starts from a clean context
   rather than merely being asked to.

3. Gather the rest of the review evidence:
   - review findings
   - test results
   - open risks
   - unresolved acceptance gaps
   - security report under `{qa.qaLocation}/security/`, when one exists.
     Read its `SECURITY:` verdict: an unresolved HIGH finding (`SECURITY: FAIL`)
     justifies `FAIL`; a `SECURITY: CONCERNS` justifies at least `CONCERNS`.
   - **If no security report exists and the change touched security-sensitive
     surface** (auth/authz, user input, queries, secrets/config, external
     endpoints, deserialization, crypto, file/path handling), emit the
     **Security review suggested** block and **wait** before deciding the gate.
     Derive it from the graph — `bash .claude/mosk/scripts/legal_moves.sh
     implement` surfaces the `security-review` side-trip — using the single
     format in `../templates/escalation-block-tmpl.md` (fill `Why now:` = "o
     gate deve ler um verdicto `SECURITY:` antes de decidir"). Do not
     auto-invoke another agent (MOSK contract). Skip silently for clearly
     non-sensitive changes. Do not proceed until the user confirms
     `go`/`skip`/alternative.

4. Decide one status:
   - `PASS`
   - `CONCERNS`
   - `FAIL`
   - `WAIVED`

5. **Score the delivery from 0 to 100 (`quality_score`).**
   Judge the result as delivered: AC coverage, test evidence, severity of open
   issues, NFR standing. Read `qa.score_threshold` from
   `.claude/mosk/core-config.yaml` (default 85) as the reference cut.

   **The score never decides anything.** `gate` remains the sole terminator of
   the delivery-loop (ADR-0008 §3) — a score of 92 does not turn a `FAIL` into a
   pass, and a score of 40 does not overrule a `PASS`. What the score buys is a
   readable trajectory across loop turns: two `FAIL`s with a flat score mean the
   loop is stuck and the honest move is to escalate; two `FAIL`s with a rising
   score mean it is converging slowly and one more turn is reasonable. Without
   it, every `FAIL` looks identical and the decision at the retry cap is blind.

6. Write a short YAML file with:
   - identifier
   - gate
   - `quality_score`
   - status_reason
   - reviewer
   - updated timestamp
   - top_issues
   - waiver details when applicable

7. If the reviewed artifact has a QA results section, append the gate reference there.

8. Report:
   - gate status **and `quality_score`**
   - gate file path
   - top issues only

9. **Update spec metadata and refresh index.** Move the phase through the
   reducer so it is validated against the graph and audited:
   ```bash
   source .claude/mosk/scripts/common.sh
   update_spec_phase "$FEATURE_DIR" qa-gate
   ```
   It bumps `last_phase_change`, appends to the spec's `phase-history.log`,
   and warns-but-proceeds on an off-graph transition (never blocks; ADR-0006).
   Then execute `../tasks/index-docs.md` to refresh `docs/index.md`.
   Automatic — no extra prompt.

10. **Delivery-loop: apresentar o estado, nunca iterar sozinho (ADR-0008).**
    Se o gate ficou `CONCERNS`/`FAIL`, apresente as jogadas do loop e **pare**:
    ```bash
    bash .claude/mosk/scripts/legal_moves.sh qa-gate
    ```
    A saída traz `tentativa N/max` no loopback de correção (`apply-qa-fixes`,
    default) enquanto `N < max`; ao atingir o teto, troca para o **menu de
    esgotamento** (`escalar`/`waive`/`parar`). O contador vem do
    `phase-history.log` (não persista nada). O humano decide a próxima volta —
    **não** auto-invoque `apply-qa-fixes` nem re-rode o gate. Se o gate foi
    `PASS`/`WAIVED`, o loop convergiu: a jogada é `archive`.

    **Mostre a trajetória junto do contador.** Leia o `quality_score` dos gates
    anteriores desta spec e apresente a série ao lado de `tentativa N/max`:

    > tentativa 3/3 — score: 61 → 68 → 69 (FAIL nas três)

    É essa série que torna a decisão no teto informada em vez de arbitrária: um
    score parado diz que mais uma volta não vai resolver — o problema é de design
    ou de story, e a jogada honesta é `escalar`. Um score subindo diz o
    contrário. Apresente a leitura; **quem decide segue sendo o humano**.

## Rules

- Start with findings and the final gate.
- Keep `status_reason` to one or two sentences.
- Use `low`, `medium`, or `high` severity only.
