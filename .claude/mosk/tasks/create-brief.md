## <!-- Inspired by BMAD and SpecKit -->

docOutputLocation: docs/discovery/brief.md
template: '.claude/mosk/templates/project-brief-tmpl.yaml'

---

# Create Project Brief Task

Produce the project brief that frames the problem, intended users, success criteria, and MVP shape — written by `mosk-analyst` and stored at `docs/discovery/brief.md`.

## When to run

- Project doesn't have a brief yet, or the existing one is stale.
- Before PRD work: PM needs the brief as the source of truth for goals and constraints.
- After a brainstorming session, to consolidate insights into a structured deliverable.

## Process

1. Load the YAML template at `.claude/mosk/templates/project-brief-tmpl.yaml`.
2. Apply the execution rules described in `.claude/mosk/tasks/create-doc.md`:
   - Process each section sequentially.
   - When a section has `elicit: true`, present the 1-9 options block and wait for user input.
   - Use the template's `custom_elicitation` actions whenever they fit the section better than the defaults.
3. Save the populated document to `docs/discovery/brief.md` (overwrite if it already exists; preserve any user blocks marked with `<!-- custom -->...<!-- /custom -->`).

## After saving

- Suggest the user route the brief to PM via `/mosk-pm` to start the PRD.
- If the brief surfaced unresolved market questions, suggest `/mosk-analyst market research` next.
- If the brief is bound to an active spec instead of project-wide, write inside `docs/specs/{id}/discovery/` with `promote: copy` front-matter pointing to `docs/discovery/brief.md`.

## Guardrails

- Do not invent answers when the user is the only source of truth (problem statement, target users, success metrics) — ask.
- Keep section drafts tight; deep elaboration goes through the elicitation cycle, not the initial draft.
