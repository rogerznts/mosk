# chore-apply

Implement an approved quick change and keep tasks in sync.

## User Input

```text
$ARGUMENTS
```

You **MUST** consider the user input before proceeding (if not empty).

## Guardrails

- Favor straightforward, minimal implementations first and add complexity only when it is requested or clearly required.
- Keep changes tightly scoped to the requested outcome.

## Steps

Track these steps as TODOs and complete them one by one.

1. Verify the active git branch:
   - Read `docs/changes/<id>/proposal.md` and extract the `**Branch:**` field.
   - If the field is present: run `git branch --show-current` and compare with the expected branch.
     - If not on the correct branch: **stop immediately** and instruct the user to run `git checkout {branch}` before continuing.
     - If on the correct branch: proceed.
   - If the `**Branch:**` field is absent (legacy chore): warn the user that this chore has no associated branch and proceed normally.
2. Read `docs/changes/<id>/proposal.md`, `design.md` (if present), and `tasks.md` to confirm scope and acceptance criteria.
3. Work through tasks sequentially, keeping edits minimal and focused on the requested change.
4. Confirm completion before updating statuses—make sure every item in `tasks.md` is finished.
5. Update the checklist after all work is done so each task is marked `- [x]` and reflects reality.
6. If scope shifts during execution, run Plan Mode again and update proposal/tasks before continuing implementation.
7. Offer to create a pull request:
   - Read the branch name and change-id from `docs/changes/<id>/proposal.md`.
   - Suggest the command: `gh pr create --title "chore({change-id}): <title>" --base <default-branch>`
   - Wait for user confirmation before executing. Skip silently if the user declines.

## Reference

- Use direct file reads under `docs/changes/<id>/` when you need additional context from the proposal while implementing.
