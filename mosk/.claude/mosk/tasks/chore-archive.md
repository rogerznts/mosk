# chore-archive

Manually close a deployed quick change without spec merge automation.

## User Input

```text
$ARGUMENTS
```

You **MUST** consider the user input before proceeding (if not empty).

## Guardrails

- Favor straightforward, minimal implementations first and add complexity only when it is requested or clearly required.
- Keep changes tightly scoped to the requested outcome.

## Steps

1. Determine the change ID to close:
   - If this task already includes a specific change ID (for example inside a `<ChangeId>` block populated by arguments), use that value after trimming whitespace.
   - If the conversation references a change loosely (for example by title or summary), inspect `docs/changes/` to surface likely IDs, share candidates, and confirm which one the user intends.
   - Otherwise, ask the user which change to close and wait for a confirmed change ID before proceeding.
   - If you still cannot identify a single change ID, stop and tell the user you cannot close anything yet.
2. Validate readiness by reading `docs/changes/<id>/proposal.md` and `tasks.md`; stop if the change is missing, incomplete, or already moved.
3. Perform manual closure:
   - Ensure all tasks are checked (`- [x]`) and deployment/validation notes are present.
   - Optionally move the directory to `docs/changes/archive/<id>/` for historical tracking.
4. Record closure notes in the change artifacts (for example, completion date, environment, and validation evidence).
4b. Offer to create a pull request before archiving:
   - Read the `**Branch:**` field from `docs/changes/<id>/proposal.md`.
   - If the field is present:
     - Ask the user whether they want to create a PR before archiving.
     - If yes: run `gh pr create --title "chore({change-id}): <title>" --base <default-branch>` with a body summarising the change, and wait for the PR to be created before continuing.
     - If no: proceed to archiving.
   - If the field is absent (legacy chore): skip this step and inform the user that no branch was associated with this chore.
5. Do not perform automatic spec merges in this task.

## Reference

- Use direct file reads in `docs/changes/` to confirm change IDs before manual closure.
- If additional architectural updates are required, use Plan Mode and open a dedicated follow-up change.
