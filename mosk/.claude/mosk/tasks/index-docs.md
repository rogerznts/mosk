# Index Documentation Task

## Purpose

Maintain `docs/index.md` as the canonical entry point for new
contributors. The file is auto-generated and combines:

1. **Project Overview** — links to the 6 base domains (`discovery/`,
   `prd/`, `architecture/`, `ui/`, `qa/`, `project/`).
2. **Active Specs** table — one row per folder in `docs/specs/*/`
   whose `spec-meta.yaml` has `status: active`.
3. **Archived Specs** list — one row per folder in `docs/specs/archive/*/`.
4. **Domain Contents** — alphabetical file listing per domain folder,
   with titles and brief descriptions.

This task is invoked automatically at the end of `boot`, `specify`,
`plan`, `tasks`, `implement`, `qa-gate`, `archive`, and
`migrate-docs-structure.sh`. It can also be run manually via
`/mosk-dev index-docs`.

## Task Instructions

You are now operating as a Documentation Indexer. Your goal is to
ensure `docs/index.md` accurately reflects the current state of the
project documentation, with the MOSK v2 layout as the default shape.

### Required Steps

1. **Load template**: read `.claude/mosk/templates/docs-index-tmpl.md`
   as the canonical skeleton. If the template does not exist, fall
   back to the structure described in the "Output Layout" section
   below.

2. **Scan base domains**: for each of `docs/discovery/`, `docs/prd/`,
   `docs/architecture/`, `docs/ui/`, `docs/qa/`, `docs/project/`,
   check whether the folder exists. Drop Overview links for folders
   that don't exist (warn the user that `mosk-boot` can scaffold them).

3. **Scan active specs**: iterate over `docs/specs/*/` (excluding
   `archive/`). For each folder:
   - Read `spec-meta.yaml` (use helpers `read_spec_meta` in
     `.claude/mosk/scripts/common.sh` when scripting).
   - If `status: active` (or the file is missing, treat as active with
     an `⚠️ meta missing` badge).
   - Collect: `spec_number`, `spec_id`, `current_phase`, `branch`,
     `created_at`.

4. **Scan archived specs**: iterate over `docs/specs/archive/*/`.
   Collect `spec_id` and `archived_at` from each `spec-meta.yaml`.

5. **Scan file listings per domain**: for each existing base domain
   folder, list its `.md` files (excluding `index.md`) alphabetically.
   Extract title from first `#` heading and a 1–2 line description.

6. **Parse existing `docs/index.md`**: if present, preserve any block
   delimited by `<!-- custom -->` and `<!-- /custom -->`. Everything
   outside those markers is regenerated.

7. **Detect stale entries**: for any domain file previously indexed
   that no longer exists, ask the user whether to remove the stale
   entry or update the path.

8. **Write `docs/index.md`**: use the Output Layout below. Set the
   "Last updated" timestamp to current UTC ISO 8601.

### Output Layout

```markdown
# Project Documentation Index

Last updated: YYYY-MM-DDTHH:MM:SSZ

## Overview

- **[Discovery](./discovery/)** — research, briefs, brainstorming
- **[PRD](./prd/index.md)** — product requirements (sharded)
- **[Architecture](./architecture/index.md)** — system design + ADRs
- **[UI](./ui/index.md)** — design system, flows, wireframes
- **[QA](./qa/)** — quality gates
- **[Project](./project/plan.md)** — living project plan + dated updates

## Active Specs

| # | Spec | Phase | Branch | Created |
|---|---|---|---|---|
| 005 | [feature-checkout-coupon](./specs/005-feature-checkout-coupon/) | implement | 005-feature-checkout-coupon | 2026-04-22 |
| 004 | [fix-login-timeout](./specs/004-fix-login-timeout/) | qa-gate | 004-fix-login-timeout | 2026-04-20 |

If no active specs, render: _No active specs._

## Archived Specs

- [003-feature-profile-settings](./specs/archive/003-feature-profile-settings/) — archived 2026-04-15
- [002-feature-payment-v2](./specs/archive/002-feature-payment-v2/) — archived 2026-04-10

If no archived specs, render: _No archived specs yet._

## Domain Contents

### Discovery

- **[Brief](./discovery/brief.md)** — product brief and goals
- **[Market Research](./discovery/market-research.md)** — landscape analysis

### PRD

- **[Index](./prd/index.md)** — full PRD overview
- **[Goals](./prd/goals.md)** — product goals and metrics

### Architecture

- **[Index](./architecture/index.md)** — architecture overview
- **[Tech Stack](./architecture/tech-stack.md)** — languages, frameworks, services
- **[ADRs](./architecture/adr/)** — decision records

### UI

- **[Index](./ui/index.md)** — UI overview
- **[Design System](./ui/design-system.md)** — tokens, components, styles
- **[Flows](./ui/flows/)** — user flows

### QA

- **[Gates](./qa/gates/)** — quality gate records

### Project

- **[Plan](./project/plan.md)** — living project plan
- **[Latest update](./project/update-YYYYMMDD.md)** — most recent dated update (`N` total)

_Only render this section when `docs/project/` exists. The "Latest update" entry links to the file with the most recent date in its name and prints the total update count._

<!-- custom -->
<!-- /custom -->
```

### Rules of Operation

1. NEVER modify the content of indexed files.
2. Preserve user edits between `<!-- custom -->` and `<!-- /custom -->`.
3. Use relative paths (starting with `./`).
4. Never remove entries without explicit confirmation when a file is
   stale (moved/renamed).
5. Report broken links or `spec-meta.yaml` warnings at the end.
6. Sort domain files alphabetically by title.
7. Active Specs table is sorted **by spec_number descending** (newest
   first).
8. Archived Specs are sorted **by archived_at descending**.
9. This task is idempotent: running it twice in a row produces the
   same file (modulo the "Last updated" timestamp).

### Auto-invocation points

The following tasks call this task at their final step:

- `boot.md` (Phase 2.5 — after scaffolding `docs/`)
- `specify.md` (after creating a new spec)
- `plan.md`, `tasks.md`, `implement.md`, `qa-gate.md` (after updating
  `current_phase` in `spec-meta.yaml`)
- `archive.md` (after promotions + move to archive)
- `migrate-docs-structure.sh` (after brownfield migration)

Invocation is silent (no extra prompts) unless broken links or stale
entries are detected.

### Process Output

At the end, provide:

1. Summary of changes made to `docs/index.md`.
2. Counts: active specs, archived specs, domain files indexed.
3. Warnings: broken links, missing `spec-meta.yaml`, domains without
   an `index.md`.
4. Newly indexed files (grouped by domain).
5. Optional integrity check: run
   `bash .claude/mosk/scripts/audit-docs-paths.sh --quiet` and surface
   any violations as warnings (do not block — exit 1 from the audit is
   informational here).
5. Stale entries removed (and user choice for each).
