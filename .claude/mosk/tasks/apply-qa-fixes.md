# apply-qa-fixes

Apply an approved set of QA findings to a spec or story without taking ownership
of the gate.

## Dependencies

```yaml
data:
  - qa-evidence-contract.md
  - output-contract.md
```

## Workflow

1. Read `.claude/mosk/core-config.yaml` and resolve the target from the request.
   Prefer `{FEATURE_DIR}/gate.yaml`; for a story, use the matching file under
   `{qa.qaLocation}/gates/`. Include referenced assessments when present.
2. If this is a spec correction, record the return to implementation:

   ```bash
   bash .claude/mosk/scripts/transition-spec-phase.sh \
     --spec "$(basename "$FEATURE_DIR")" --to implement --command apply-qa-fixes
   ```

3. Build a fix list from stable finding ids. Order: high findings, failed NFRs,
   missing P0/P1 coverage, uncovered criteria, required risk mitigations, then
   medium/low findings.
4. For each selected finding, verify its cited evidence, implement the smallest
   complete correction and add/update tests that prove the changed behavior.
5. Run the project lint/tests and any focused reproducer. Do not declare a
   finding resolved when its validation could not run; report the limitation.
6. Update implementation records allowed by the target artifact (task boxes,
   dev log, completion notes, file list and change log). Do not edit ACs,
   requirements, QA results or gate YAML.
7. Report fixed, partially fixed and untouched ids with validation results, then
   hand back to `/mosk-qa qa-gate <target>`.

## Blocking conditions

- target or finding ids are ambiguous;
- no gate/assessment or explicit human-approved fix list exists;
- a finding requires a new product, UX or architecture decision.

Gate ownership remains with QA. A code change is evidence for a new review, not
permission to rewrite the previous verdict.
