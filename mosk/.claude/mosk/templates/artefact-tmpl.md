---
artefact_number: "[NNN]"
slug: "[short-slug]"
parent_spec: "[###-type-name]"
created_at: "[ISO 8601 UTC]"
status: draft   # draft | ready | in-progress | done
# Optional: promote this artefact to a base location on archive.
# promote: docs/architecture/adr/adr-XXXX-<name>.md
# promote_mode: copy   # copy | append | manual
---

# Artefact [NNN]: [Title]

**Parent spec:** `[###-type-name]`
**Branch:** `[branch from parent]`
**Status:** Draft
**Created:** [DATE]

## Context

[Why this addendum exists. What changed in the conversation with the
customer/user, or what was discovered during the spec's execution.
Explain why it complements the parent spec instead of justifying a
new spec or a new branch.]

## Scope

[What this artefact adds or changes inside the parent spec's scope. Be
concrete and minimal. Target 1-3 acceptance criteria. If scope grows
past that, stop and open a new spec instead.]

## Acceptance Criteria

1. **Given** [initial state], **When** [action], **Then** [expected outcome]
2. **Given** [initial state], **When** [action], **Then** [expected outcome]

## Out of Scope

- [Item that could be added but is intentionally excluded from this artefact]
- [Item parked for a future spec or future artefact]

## Dependencies

- Parent spec: `docs/specs/[###-type-name]/spec.md`
- Related stories/tasks in parent: [story IDs, task IDs]
- External: [other artefacts, APIs, services]

## Notes

[Free-form notes, design hints, links to discussions.]
