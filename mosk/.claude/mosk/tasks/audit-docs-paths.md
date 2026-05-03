# Audit Docs Paths Task

Run the MOSK toolkit path audit and report findings.

## When to run

- Before committing changes that touch `tasks/`, `templates/`, `agents/`, or `core-config.yaml`.
- After pulling changes from a branch you didn't author, to catch regressions early.
- On demand when something feels off (a task points to a file that no longer exists, an output landed in the wrong domain, a config key seems missing).

## Process

1. Run the audit script:

   ```bash
   bash .claude/mosk/scripts/audit-docs-paths.sh
   ```

   The script enforces five rules across the toolkit:

   - **R1** — output paths declared in task prose live under `docs/<canonical-domain>/`.
   - **R2** — `filename:` in every `templates/*.yaml` lives under `docs/<canonical-domain>/`.
   - **R3** — `docOutputLocation:` in every `tasks/*.md` lives under `docs/<canonical-domain>/`.
   - **R4** — every `<domain>.<key>` config reference in tasks (e.g. `qa.qaLocation`) exists in `core-config.yaml`.
   - **R5** — every template referenced by a task exists on disk.

2. Interpret the output:
   - Exit 0 + `clean ✓` → nothing to do.
   - Exit 1 + violations list → each line is `path:line :: rule :: detail`. Address each, then re-run.

3. For violations, do not auto-fix without user confirmation. Surface the list, propose the smallest correction per line, and wait for `go`.

## Reporting

After the run, output:

- Status (`clean` or `<n> violation(s)`).
- If violations: grouped by rule, with a one-line proposed fix per item.
- If clean: a single line — no extra prose.

## Guardrails

- Never silence the audit (no `|| true`, no `--quiet` unless the user asked).
- Never edit `core-config.yaml` to "satisfy" R4 without confirming the new key is actually intended.
- If R5 reports a missing template, prefer creating the missing template over deleting the reference — but ask the user first.
