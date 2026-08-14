# qa-gate

Create or update a quality gate decision for the active spec or story.

## Dependencies

```yaml
data:
  - output-contract.md # vocabulário de ids + formato de achado (obrigatório)
```

## Goal

Produce a minimal gate artifact that answers one question clearly: can this move forward?

## Workflow

1. Read `.claude/mosk/core-config.yaml` and resolve the gate location.
   - **Spec-level gate (default):** write to the per-spec `specs.gateFile`
     → `docs/specs/{id}/gate.yaml`. **This is the location the per-spec
     pipeline and `index-docs` read** — writing elsewhere leaves the verdict
     where nothing looks for it.
   - **Story-level gate:** for a specific story, `{qa.qaLocation}/gates/`
     remains valid (BMAD lineage).

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

   When the runtime offers isolation, run this step in a **`mosk-qa` subagent**
   so the verification really starts from a clean context rather than merely
   being asked to (ADR-0016). Where it does not, the discipline above still
   applies — it is just weaker, and you should say so in `status_reason`.

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
     **Security review suggested** block and **wait** before deciding the gate,
     using the single format in `../templates/escalation-block-tmpl.md`
     (recommended agent: `/mosk-security`; fill `Why now:` = "o gate deve ler um
     verdicto `SECURITY:` antes de decidir"). Do not auto-invoke another agent
     (MOSK contract). Skip silently for clearly non-sensitive changes. Do not
     proceed until the user confirms `go`/`skip`/alternative.

4. Decide one status:
   - `PASS`
   - `CONCERNS`
   - `FAIL`
   - `WAIVED`

5. **Compute `quality_score` — do not estimate it.**

   Use the toolkit's canonical formula, the same one `review-story.md` and
   `assess-nfr.md` already apply:

   ```text
   quality_score = 100 - (20 × FAILs) - (10 × CONCERNS)
   bounded to [0, 100]
   ```

   Inputs are the findings you just gathered: each `high` severity issue and each
   `FAIL` NFR counts as a FAIL; each `medium` issue and each `CONCERNS` NFR counts
   as a CONCERNS. If `technical-preferences.md` defines custom weights, use those
   instead — same override the other two tasks honour.

   **It must be computed, not judged.** The score exists to make successive turns
   comparable; a number produced by fresh appraisal each round would drift with
   the reviewer rather than with the work, and `61 → 68 → 69` would tell you
   nothing. Deriving it from counted findings is what makes the series mean
   something.

   Read `qa.score_threshold` from `.claude/mosk/core-config.yaml` (default 85) as
   the reference cut.

   **The score never decides anything.** The `gate` verdict is the sole ruling —
   a score of 92 does not turn a `FAIL` into a pass, and a score of 40 does not
   overrule a `PASS`. What the score buys is a readable trajectory across turns:
   two `FAIL`s with a flat score mean the work is stuck and the honest move is to
   escalate; two `FAIL`s with a rising score mean it is converging slowly and one
   more turn is reasonable. Without it, every `FAIL` looks identical.

6. Write a short YAML file with:
   - identifier
   - gate
   - `quality_score`
   - `score_history` — **append this round's score** to the list already in the
     file (start it on the first round). This is what makes the trajectory
     readable on the next turn; the gate file is overwritten each round, so a
     score that is not accumulated here is a score that is lost.
   - status_reason
   - reviewer
   - updated timestamp
   - `top_issues` — each with `id`, `severity`, `title` (plain language),
     `finding`, `contradicts` (the criterion **with its gloss**) and
     `suggested_action`. Ids follow the canonical vocabulary
     (`QA-#` here, `SEC-#` for security findings) and are **stable across
     rounds**: `QA-1` on the second turn is the same defect as on the first.
   - waiver details when applicable

7. If the reviewed artifact has a QA results section, append the gate reference there.

8. **Report the findings — follow `../data/output-contract.md`.**

   Open with the verdict and a count, then one **block per finding**. Never a
   table: a cell cannot hold both the claim and what the cited id means, and
   that compression is what makes a gate unreadable.

   ```markdown
   **Gate: FAIL · score 20** — 6 achados: 2 altos, 4 médios.
   Cinco dos seis são reescrita de texto; nenhum pede decisão de arquitetura.

   ### QA-1 · alta · Busca não estreita por coleção

   10 de 12 arquivos ignoram o filtro de collection.

   - Contraria: SC-004 — "toda busca deve estreitar por collection" (spec.md:112)
   - Também: FR-009, a mesma exigência do lado do requisito — corrigir um sem o
     outro deixa a contradição pela metade
   - Custo: reescrita de texto, não de código
   ```

   **Every id you cite carries its meaning the first time it appears**, and no
   id is ever the subject of a claim. The reader must be able to act without
   opening `spec.md`. Severity is written in the project's language (`alta`,
   `média`, `baixa`); the YAML keeps `high`/`medium`/`low`.

9. **Update spec metadata and refresh index.**
   ```bash
   source .claude/mosk/scripts/common.sh
   update_spec_phase "$FEATURE_DIR" qa-gate
   ```
   It records `current_phase` and bumps `last_phase_change`. Then execute
   `../tasks/index-docs.md` to refresh `docs/index.md`. Automatic — no extra
   prompt.

10. **Apresentar o estado e parar — nunca iterar sozinho.**

    Se o gate foi `PASS`/`WAIVED`, a jogada é `/mosk-dev archive {spec-id}`.

    Se ficou `CONCERNS`/`FAIL`, apresente as opções e **pare**:

    > **Gate `FAIL` · score 69** — série: 61 → 68 → 69
    > - `corrigir` → `/mosk-dev apply-qa-fixes {spec-id}`
    > - `escalar` → o problema é de design ou de story, não de execução
    > - `waive` → aceitar com ressalva registrada
    > - `parar`

    **Mostre a trajetória junto do veredito.** Leia `score_history` do
    `gate.yaml` e apresente a série. É ela que torna a decisão informada em vez
    de arbitrária: um score parado diz que mais uma volta não vai resolver — o
    problema está acima da execução, e a jogada honesta é `escalar`. Um score
    subindo diz o contrário.

    **Não** auto-invoque `apply-qa-fixes` nem re-rode o gate. Quem decide a
    próxima volta é o humano.

## Rules

- Start with findings and the final gate.
- Keep `status_reason` to one or two sentences.
- Use `low`, `medium`, or `high` severity only.
