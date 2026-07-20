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
     endpoints, deserialization, crypto, file/path handling), emit the block
     below and **wait** before deciding the gate. Do not auto-invoke another
     agent (MOSK contract). Skip silently for clearly non-sensitive changes.

     > **Security review suggested**
     > - Signal: <one line — which sensitive surface the change touched, no report on disk>
     > - Recommended agent: `/mosk-security`
     > - Suggested prompt: `/mosk-security review the pending changes`
     > - Why now: the gate should read a `SECURITY:` verdict before deciding.
     > - On return: resume this gate with the report as evidence.

     Do not proceed until the user confirms `go`/`skip`/alternative.

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

7. **Update spec metadata and refresh index.** Update the current spec's
   `spec-meta.yaml`: set `current_phase: qa-gate` and bump
   `last_phase_change`. Then execute `../tasks/index-docs.md` to refresh
   `docs/index.md`. Automatic — no extra prompt.

## Rules

- Start with findings and the final gate.
- Keep `status_reason` to one or two sentences.
- Use `low`, `medium`, or `high` severity only.
