# qa-gate

Create or update an independent quality decision for a spec or a delivered
story.

<!-- Capability: post-implementation-story-review -->

## Dependencies

```yaml
data:
  - qa-evidence-contract.md
  - output-contract.md
schemas:
  - qa-gate.schema.json
templates:
  - qa-gate-tmpl.yaml
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
3. Gather evidence using `.claude/mosk/data/qa-evidence-contract.md`: review
   findings, test results, risk/NFR/trace assessments and unresolved gaps.
4. Read the current security report when one exists. `SECURITY: FAIL` justifies
   `FAIL`; `SECURITY: CONCERNS` implies at least `CONCERNS`. If sensitive surface
   changed with no report, pause with the standard security-review suggestion
   before deciding.
5. Choose `PASS|CONCERNS|FAIL|WAIVED`. Compute, do not estimate:

   ```text
   quality_score = 100 - (20 × FAILs) - (10 × CONCERNS)
   ```

   Bound to `0..100`, honoring documented custom weights. The score shows
   trajectory and never overrides the verdict.
6. Write schema 2 YAML using `qa-gate-tmpl.yaml`: stable issue ids, score and
   appended `score_history`, evidence path, reviewer/timestamp, waiver fields
   and concise reason. Preserve prior issue ids across rounds.
7. Report verdict first, then one block per finding following
   `output-contract.md`. Every cited criterion carries its meaning.
8. In spec mode only, record the phase and refresh the index:

   ```bash
   bash .claude/mosk/scripts/transition-spec-phase.sh \
     --spec "$(basename "$FEATURE_DIR")" --to qa-gate --command qa-gate
   ```

9. Stop after the decision. On PASS/WAIVED suggest archive. On
   CONCERNS/FAIL show score history and the human choices: correct, review the
   source, accept with caveat, or stop. Never start a correction loop yourself.

## Rules

- QA owns gate files; implementers never edit them.
- Use only `low|medium|high` severities.
- Missing required evidence cannot produce PASS.
- `status_reason` is one or two sentences.
