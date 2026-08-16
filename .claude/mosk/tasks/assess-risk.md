# assess-risk

Identify delivery risks and produce mitigation evidence for QA. This assessment
informs the gate; it does not decide the gate.

## Dependencies

```yaml
data:
  - qa-evidence-contract.md
  - output-contract.md
```

## Inputs

Read the target story/spec, affected implementation, tests, architecture and
known operational constraints. Ask once only when a missing fact changes the
risk materially; otherwise mark the uncertainty as evidence absent.

## Workflow

1. Identify risks in security, performance, data, business, operations and
   maintainability. Do not invent a category outside the canonical id form.
2. For each risk, record probability `low|medium|high`, impact
   `low|medium|high` and score `1..9` using `1|2|3 × 1|2|3`.
3. Classify `critical` for 9, `high` for 6, `medium` for 4, otherwise `low`.
4. Assign a stable id `RISK-<CAT>-#`, cite the observed source, name the owner,
   mitigation, residual risk and trigger for reassessment.
5. Map critical/high risks to concrete test or operational evidence. Missing
   evidence is a gap, never a pass.
6. Save a compact report under
   `{qa.qaLocation}/assessments/{target}-risk-{YYYYMMDD}.md` and provide a
   `risk_summary` block compatible with the gate template.

## Output

- totals by severity;
- one actionable block per critical/high risk;
- `must_fix` and `monitor` lists;
- evidence sources and review triggers.

Follow `.claude/mosk/data/qa-evidence-contract.md`; do not duplicate its finding
format or quality-score rules here.
