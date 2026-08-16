# correct-course

Analyze a material change and draft a concrete course-correction proposal.

## Dependency

Use `.claude/mosk/checklists/change-checklist.md` as the only impact checklist.

## Workflow

1. Read the change trigger and affected spec, PRD, architecture, UI and delivery
   artifacts. Ask one grouped question only if missing facts change the viable
   path.
2. Execute the checklist in one pass unless the user explicitly asks to work
   section by section.
3. Record impact on scope, stories, dependencies, compatibility, MVP, tests and
   rollback. Mark checklist items `addressed`, `not applicable` or `needs action`
   with evidence.
4. Compare feasible paths: adjust implementation, reduce/split scope, revert, or
   replan. Recommend one and explain trade-offs.
5. Draft a `Sprint Change Proposal` containing:
   - trigger and impact summary;
   - recommended path and rationale;
   - exact edits per affected artifact (`from`/`to` when useful);
   - migration, test and rollback work;
   - unresolved decisions and owner.
6. Present the proposal for explicit approval. Do not apply the edits during
   this task unless the user separately authorizes implementation.

If the proposal changes product scope, UX behavior or architecture, route that
decision through the corresponding human-approved agent handoff. Do not hide a
replan inside document editing.
