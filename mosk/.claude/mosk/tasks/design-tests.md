# design-tests

Design the smallest test portfolio that proves the target criteria and covers
its important risks.

## Dependencies

```yaml
data:
  - qa-evidence-contract.md
  - test-levels-framework.md
  - test-priorities-matrix.md
```

## Workflow

1. Read the target ACs/requirements, affected boundaries, existing tests and
   current risk/NFR evidence.
2. Map each criterion to observable scenarios. Include happy path, material
   failures and boundaries; do not restate implementation tasks as tests.
3. Pick the lowest test level that proves the behavior. Add integration or E2E
   only when a boundary cannot be proved lower.
4. Prioritize with the canonical matrix and explain every P0/P1 using impact and
   likelihood.
5. Record for each scenario: id, criterion with gloss, risk, level, priority,
   preconditions, action and expected result.
6. Identify uncovered criteria and blocked evidence explicitly.
7. Save `{qa.qaLocation}/assessments/{target}-design-tests-{YYYYMMDD}.md` and
   expose scenario ids for traceability.

## Output

- scope and test-level rationale;
- scenarios grouped by criterion, not by framework;
- execution order;
- coverage gaps and evidence dependencies.

Follow `.claude/mosk/data/qa-evidence-contract.md`; this task designs evidence
and does not issue a gate verdict.
