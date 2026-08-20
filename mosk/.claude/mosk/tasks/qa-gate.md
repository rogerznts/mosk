# qa-gate

Create or update an independent quality decision for a spec or a delivered
story.

<!-- Capability: post-implementation-story-review -->

## Dependencies

```yaml
data:
  - qa-evidence-contract.md
  - output-contract.md
  - adaptive-work-contract.md
schemas:
  - qa-gate.schema.json
templates:
  - qa-gate-tmpl.yaml
scripts:
  - classify-change.sh
```

## Modes

- **Spec mode (default):** review the active spec and write
  `docs/specs/{id}/gate.yaml`.
- **Story mode:** when a story id/path is supplied, review that delivered story
  and write `{qa.qaLocation}/gates/{story-id}-{slug}.yml`.

Both modes verify the delivered result against its source criteria. Story mode
replaces the former separate post-implementation review workflow; draft
readiness remains `review-story-draft`.

## Workflow

1. Read `.claude/mosk/core-config.yaml`, resolve the mode, source artifact and
   destination. Fail on an ambiguous or missing target.
2. Start from clean review context when the runtime supports isolation. Read all
   in-scope ACs/requirements and verify them against code, tests and running
   behavior. `[x]` records work claimed; it is not proof.
3. Select observable signals from the delivered change and run
   `.claude/mosk/scripts/classify-change.sh` according to
   `.claude/mosk/data/adaptive-work-contract.md`. Record the profile and short
   justification. Its `context_budget`, `validation_floor` and `specialists`
   are minimums: QA may expand them, never reduce them. Reclassify upward if
   verification reveals broader scope, weaker evidence or a sensitive surface.
   The profile does not alter pipeline transitions or the independent verdict.
4. Gather evidence using `.claude/mosk/data/qa-evidence-contract.md`: review
   findings, test results, risk/NFR/trace assessments and unresolved gaps.
   Missing evidence required by the adaptive validation or specialist floor
   cannot produce `PASS`.
5. Read the current security report when one exists. `SECURITY: FAIL` justifies
   `FAIL`; `SECURITY: CONCERNS` implies at least `CONCERNS`. If sensitive surface
   changed with no report, pause with the standard security-review suggestion
   before deciding.
6. Choose `PASS|CONCERNS|FAIL|WAIVED`, then compute `quality_score` with the
   canonical formula in `.claude/mosk/data/qa-evidence-contract.md` — count, do
   not estimate. The score shows trajectory and never overrides the verdict.
7. Write schema 2 YAML using `qa-gate-tmpl.yaml`: stable issue ids, score and
   appended `score_history`, evidence path, reviewer/timestamp, waiver fields
   and concise reason. Preserve prior issue ids across rounds.
8. Report verdict first, then one block per finding following
   `output-contract.md`. Every cited criterion carries its meaning.
9. In spec mode only, confirm the transition to `qa-gate` with command
   `qa-gate`, following `../data/phase-transition-contract.md`, and refresh the
   index.

10. Stop after the decision. On PASS/WAIVED suggest archive. On
   CONCERNS/FAIL show score history and the human choices: correct, review the
   source, accept with caveat, or stop. Never start a correction loop yourself.

## Rules

- QA owns gate files; implementers never edit them.
- Use only `low|medium|high` severities.
- Missing required evidence cannot produce PASS.
- `status_reason` is one or two sentences.
