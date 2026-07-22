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

7. **Update spec metadata and refresh index.** Move the phase through the
   reducer so it is validated against the graph and audited:
   ```bash
   source .claude/mosk/scripts/common.sh
   update_spec_phase "$FEATURE_DIR" qa-gate
   ```
   It bumps `last_phase_change`, appends to the spec's `phase-history.log`,
   and warns-but-proceeds on an off-graph transition (never blocks; ADR-0006).
   Then execute `../tasks/index-docs.md` to refresh `docs/index.md`.
   Automatic — no extra prompt.

## Rules

- Start with findings and the final gate.
- Keep `status_reason` to one or two sentences.
- Use `low`, `medium`, or `high` severity only.
