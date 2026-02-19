---
name: /mosk-chore-archive
id: mosk-chore-archive
category: Chore Mode
description: Manually close a deployed quick change without spec merge automation.
---
<!-- CHORE:START -->
**Guardrails**
- Favor straightforward, minimal implementations first and add complexity only when it is requested or clearly required.
- Keep changes tightly scoped to the requested outcome.

**Steps**
1. Determine the change ID to close:
   - If this prompt already includes a specific change ID (for example inside a `<ChangeId>` block populated by slash-command arguments), use that value after trimming whitespace.
   - If the conversation references a change loosely (for example by title or summary), inspect `toolkit/changes/` to surface likely IDs, share candidates, and confirm which one the user intends.
   - Otherwise, ask the user which change to close and wait for a confirmed change ID before proceeding.
   - If you still cannot identify a single change ID, stop and tell the user you cannot close anything yet.
2. Validate readiness by reading `toolkit/changes/<id>/proposal.md` and `tasks.md`; stop if the change is missing, incomplete, or already moved.
3. Perform manual closure:
   - Ensure all tasks are checked (`- [x]`) and deployment/validation notes are present.
   - Optionally move the directory to `toolkit/changes/archive/<id>/` for historical tracking.
4. Record closure notes in the change artifacts (for example, completion date, environment, and validation evidence).
5. Do not perform automatic spec merges in this command.

**Reference**
- Use direct file reads in `toolkit/changes/` to confirm change IDs before manual closure.
- If additional architectural updates are required, use Plan Mode and open a dedicated follow-up change.
<!-- CHORE:END -->
