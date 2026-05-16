---
description: "Tasks for artefact [NNN]-[slug] (parent spec: [###-type-name])"
---

# Tasks: Artefact [NNN]-[slug]

**Parent spec:** `docs/specs/[###-type-name]/`
**Artefact:** `docs/specs/[###-type-name]/artefacts/[NNN]-[slug].md`

## Format: `[ID] [P?] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- Include exact file paths in descriptions
- Each task should reference back to the artefact's acceptance criteria
- Task IDs use the `A` prefix (`A001`, `A002`, …) to distinguish from
  the parent spec's `T###` IDs

## Phase 1: Setup (only if needed)

- [ ] A001 [Setup task — e.g., scaffold new folder, add dependency, prepare fixtures]

## Phase 2: Implementation

- [ ] A002 [Implementation task tied to AC #1] (exact path: `src/...`)
- [ ] A003 [P] [Implementation task tied to AC #2] (exact path: `src/...`)
- [ ] A004 [Wiring / integration with parent spec components]

## Phase 3: Validation

- [ ] A005 [Manual or automated check of AC #1]
- [ ] A006 [Manual or automated check of AC #2]
- [ ] A007 Handoff to QA — update artefact's front-matter to `status: ready`, then request `/mosk-qa qa-gate` scoped to this artefact

## Notes

- Update the artefact's front-matter `status` as work progresses:
  `draft → ready → in-progress → done`.
- Keep this file focused on the artefact's scope only. The parent
  spec's `tasks.md` and `gate.yaml` remain untouched.
- If implementation reveals scope beyond the artefact, stop and either
  add a new artefact via `/mosk-po artefact` or open a new spec.
