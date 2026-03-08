# qa-gate

Create or update a quality gate decision for the active spec or story.

## Goal

Produce a minimal gate artifact that answers one question clearly: can this move forward?

## Workflow

1. Read `.claude/mosk/core-config.yaml` and resolve `qa.qaLocation`.
   - Write the gate file under `{qa.qaLocation}/gates/`.

2. Gather the review evidence:
   - review findings
   - test results
   - open risks
   - unresolved acceptance gaps

3. Decide one status:
   - `PASS`
   - `CONCERNS`
   - `FAIL`
   - `WAIVED`

4. Write a short YAML file with:
   - identifier
   - gate
   - status_reason
   - reviewer
   - updated timestamp
   - top_issues
   - waiver details when applicable

5. If the reviewed artifact has a QA results section, append the gate reference there.

6. Report:
   - gate status
   - gate file path
   - top issues only

## Rules

- Start with findings and the final gate.
- Keep `status_reason` to one or two sentences.
- Use `low`, `medium`, or `high` severity only.
