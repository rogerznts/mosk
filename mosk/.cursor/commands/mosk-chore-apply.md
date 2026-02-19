---
name: /mosk-chore-apply
id: mosk-chore-apply
category: Chore Mode
description: Implement an approved quick change and keep tasks in sync.
---
<!-- CHORE:START -->
**Guardrails**
- Favor straightforward, minimal implementations first and add complexity only when it is requested or clearly required.
- Keep changes tightly scoped to the requested outcome.

**Steps**
Track these steps as TODOs and complete them one by one.
1. Read `toolkit/changes/<id>/proposal.md`, `design.md` (if present), and `tasks.md` to confirm scope and acceptance criteria.
2. Work through tasks sequentially, keeping edits minimal and focused on the requested change.
3. Confirm completion before updating statuses—make sure every item in `tasks.md` is finished.
4. Update the checklist after all work is done so each task is marked `- [x]` and reflects reality.
5. If scope shifts during execution, run Plan Mode again and update proposal/tasks before continuing implementation.

**Reference**
- Use direct file reads under `toolkit/changes/<id>/` when you need additional context from the proposal while implementing.
<!-- CHORE:END -->
