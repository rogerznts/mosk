# trace-spec

Trace requirements and acceptance criteria to tests and observed evidence.

## Dependencies

```yaml
data:
  - qa-evidence-contract.md
  - output-contract.md
```

## Workflow

1. Extract every in-scope FR, NFR, SC and AC with its text; do not create new
   identifiers for criteria that are absent from the source.
2. Find tests, commands and behavioral evidence that prove each criterion.
3. Classify coverage:
   - `covered`: evidence directly proves the criterion;
   - `partial`: only part of the behavior or boundary is proved;
   - `missing`: no applicable evidence;
   - `not_applicable`: justified explicitly.
4. Link concrete test ids/paths and results. A task checkbox or implementation
   note is a claim to verify, not test evidence.
5. Turn partial/missing coverage into actionable gaps and reference designed
   scenarios when available.
6. Save `{qa.qaLocation}/assessments/{target}-trace-{YYYYMMDD}.md` and provide a
   compact trace summary for the gate.

## Output

- totals by coverage status;
- one mapping per criterion;
- critical gaps ordered by risk;
- source paths and test evidence.

Follow `.claude/mosk/data/qa-evidence-contract.md`; the gate owns the final
decision.
