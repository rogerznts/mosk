# {{PROJECT_NAME}} — Project Manual

<!--
  Template used by `mosk-pm planner` (task: ../tasks/planner.md) to
  seed `docs/discovery/project-manual.md` in a consuming project.

  This manual is the **source of truth for how this project tracks
  progress**. The planner reads it on every run to decide cadence,
  status vocabulary, deliverable definitions, and how to summarize git
  activity into `docs/project/plan.md` + `docs/project/update-*.md`.

  Fill `{{PLACEHOLDERS}}` based on what fits the team. The planner can
  pre-fill placeholders by reading other docs (`prd/`, `architecture/`,
  `discovery/`) and will ask pointed questions only when confidence is
  low.

  Sibling pattern: [[project-rule-tmpl.md]] (the `.claude/rules/project.md`
  template). Both are consumer-facing templates seeded by MOSK tasks.
-->

## Tracking Cadence

{{TRACKING_CADENCE}}

> Example: "Weekly snapshot every Monday morning. Ad-hoc runs before
> stakeholder sync." The planner uses this to advise the user when a
> run is overdue.

## Deliverable Definition

{{DELIVERABLE_DEFINITION}}

> Example: "A deliverable is any artifact promised to a stakeholder —
> features deployed to staging, design specs signed off, infra changes
> in production. Internal refactors are not deliverables."

## Required Sections in `plan.md`

{{REQUIRED_PLAN_SECTIONS}}

> Default (used when the placeholder is empty):
>
> - Objectives
> - Current Focus
> - Milestones
> - Deliverables
> - Status Snapshot
> - Risks
> - Open Questions

The planner enforces this list: each required section appears in
`docs/project/plan.md` as a `<!-- section:<id> -->…<!-- /section -->`
block.

## Milestone Format

{{MILESTONE_FORMAT}}

> Example: `name | target date | status | owner`.

## Status Vocabulary

{{STATUS_VOCABULARY}}

> Example: `on-track | at-risk | blocked | done | dropped`.

## Git Summary Rules

{{GIT_SUMMARY_RULES}}

> Example: "Group commits by author and by spec prefix (`^\d{3}-`).
> Include merges only when they cross a release branch. Skip
> dependency-bump commits unless they're security-related."

## Update File Scope

{{UPDATE_FILE_SCOPE}}

> Defines what every `docs/project/update-YYYYMMDD.md` must contain
> beyond the default frontmatter + body. Example: "Always include a
> 'Blockers' section, even if empty, for the standup automation to
> parse."

## User Comment Handling

{{USER_COMMENT_HANDLING}}

> Defines when the free-form comment passed to `/mosk-pm planner`
> modifies `plan.md` vs. lives only in the update file. Example:
> "Always include verbatim in the update. Mirror into `plan.md` only
> when the comment names a milestone, status change, or risk."

## Project-Specific Tracking Rules

{{PROJECT_SPECIFIC_TRACKING_RULES}}

> Free-form rules the team wants the planner to follow. Example:
> "Pin the current week's focus to the spec with the closest
> milestone. Use Portuguese for prose in `plan.md`."

---

## How planner consumes this manual

On every `/mosk-pm planner` run, the task `planner.md`:

1. Reads this file (creates from template if missing).
2. Applies the rules above to decide what changes in
   `docs/project/plan.md` and what goes into the dated update file.
3. Reads recent git activity (window: since last `plan.md` mtime;
   bootstrap fallback: 7 days).
4. Absorbs the user comment passed with the command.
5. Writes/updates `plan.md` only when planning materially changes.
6. Always emits `update-YYYYMMDD.md` with frontmatter for PR usage.

## Relationship to `docs/index.md`

`docs/project/` is one of the six base domains in the MOSK canonical
`docs/` layout (alongside `discovery/`, `prd/`, `architecture/`,
`ui/`, `qa/`). After each planner run, `index-docs.md` regenerates
`docs/index.md` to surface `plan.md` and the most recent update.
