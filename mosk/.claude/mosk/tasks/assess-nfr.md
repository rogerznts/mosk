# assess-nfr

Assess applicable non-functional requirements with observable evidence. This
assessment feeds the gate and never replaces it.

## Dependencies

```yaml
data:
  - qa-evidence-contract.md
  - output-contract.md
```

## Workflow

1. Read explicit NFRs and project thresholds. Evaluate security, performance,
   reliability and maintainability only where applicable; add another named NFR
   only when the source defines it.
2. For each NFR, record criterion with gloss, threshold, observed evidence and
   status `PASS|CONCERNS|FAIL`.
3. Use `FAIL` when evidence contradicts a mandatory threshold. Use `CONCERNS`
   when the requirement applies but evidence is missing or incomplete. Never
   infer `PASS` from the absence of failures.
4. Give every gap the smallest verifiable action and cite commands/files.
5. Save `{qa.qaLocation}/assessments/{target}-nfr-{YYYYMMDD}.md` and expose an
   `nfr_validation` block for the gate.

## Output

- status per applicable NFR;
- critical issues and quick wins;
- evidence sources;
- calculated score contribution using the shared contract.

Follow `.claude/mosk/data/qa-evidence-contract.md`; do not copy its score or
finding format into this task.
