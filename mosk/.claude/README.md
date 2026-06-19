# MOSK Skills

This is the installed MOSK toolkit inside your project. Nine specialist agents, one spec-driven pipeline, and a small set of maintenance scripts — all living under `.claude/`.

## Where things live

```
.claude/
├── agents/            # Claude Code agent definitions (synced from mosk/agents/)
├── mosk/
│   ├── agents/        # canonical persona prompts (source of truth)
│   ├── tasks/         # executable workflows (specify, plan, tasks, implement, qa-gate, archive, boot, index-docs, …)
│   ├── templates/     # *-tmpl.yaml / *-tmpl.md (prd, architecture, story, spec-meta, docs-index, project-rule, …)
│   ├── checklists/
│   ├── scripts/       # lifecycle scripts (see below)
│   └── core-config.yaml
├── rules/             # generated per project by /mosk-boot (project.md + frontend.md + optional extras)
└── skills/            # slash-command wrappers pointing at agents/tasks
```

Each skill becomes a slash command based on its frontmatter `name`. Example: `name: mosk-po` → `/mosk-po`.

The consuming project's documentation is shaped by the same toolkit into this canonical `docs/`:

```
docs/
├── index.md                 # auto-generated entry point (task: index-docs)
├── discovery/               # mosk-analyst
├── prd/                     # mosk-pm (sharded: index.md + sections)
├── architecture/            # mosk-architect (+ adr/)
├── ui/                      # mosk-ux-expert (flows/, wireframes/) + mosk-ui-expert (design-system/, styles/)
├── qa/gates/                # mosk-qa
└── specs/
    ├── {###}-{type}-{name}/
    │   ├── spec.md
    │   ├── plan.md
    │   ├── tasks.md
    │   ├── spec-meta.yaml       # number, branch, status, current_phase
    │   ├── prd-delta.md         # optional PRD change
    │   ├── discovery/           # optional feature-scoped research
    │   ├── architecture/        # optional feature ADRs and data models
    │   ├── ui/                  # optional feature flows/wireframes/components
    │   ├── stories/
    │   ├── tests/               # dev-generated e2e checklists
    │   └── gate.yaml            # qa-gate output
    └── archive/                 # completed specs
```

See the project-level `README.md` (installed at the repo root) for the full Document Organization reference.

## Agents

Main agents:

- `mosk-analyst` — discovery, research, brainstorming
- `mosk-pm` — PRD, product scope, PRD delta
- `mosk-architect` — architecture, APIs, integrations, ADRs
- `mosk-ux-expert` — user flows, wireframes, front-end specs
- `mosk-ui-expert` — premium UI, design system, visual acabamento
- `mosk-po` — specs, planning, task generation
- `mosk-sm` — story readiness, sequencing
- `mosk-dev` — implementation, QA fixes, archive
- `mosk-qa` — quality gates, test strategy, reviews

Helpers:

- `mosk-boot` — generates `.claude/rules/` and scaffolds `docs/` on first install
- `mosk-help` — short reference guide
- `mosk-suggestion` — reads the current phase and suggests the next agent with a ready-to-paste prompt

UX Expert and UI Expert coexist in `docs/ui/` with distinct focus: UX owns structure/behavior (flows, wireframes, front-end specs), UI owns visual polish (design system, styles, premium components).

## Preferred Usage

Use agents with natural language:

```text
/mosk-po full-spec checkout com cupom
/mosk-dev implementar a spec 012
/mosk-qa revisar a spec 012
/mosk-ui-expert redesign da home atual
```

Advanced `*commands` still work as compatibility shortcuts, but natural language is the primary UX.

## Flow

A single pipeline with an optional preamble:

```text
[preamble - optional]   analyst → pm → [architect | ux-expert | ui-expert]
[pipeline]              po (specify → plan → tasks) → sm → dev → qa ↺ → dev (archive)
```

- **Skip the preamble** when the base (PRD, architecture, UI) already supports the request — go straight to `/mosk-po full-spec`.
- **Use the preamble** when the base is missing or stale; write outputs at the base (`docs/<domain>/`) when canonical, or per-spec (`docs/specs/{id}/<domain>/`) when specific to the change.
- **Compact path:** `full-spec → implement → qa-gate → archive`.
- **Granular path:** `specify → plan → tasks → implement → qa-gate → archive`.
- **Optional helpers:** `clarify`, `analyze`, `checklist`.

`full-spec` stops at `tasks` and keeps implementation with `/mosk-dev`. When `qa-gate` returns CONCERNS or FAIL, dev loops through `apply-qa-fixes` and re-runs the gate before archiving.

## Escalation Policy

Pipeline agents (`po`, `sm`, `dev`, `qa`) detect signals that require a preamble agent mid-flight — an architectural ambiguity, a missing flow, a PRD conflict — and emit an **Escalation suggested** block. Agents never invoke each other automatically; the user decides whether to go, escalate, skip, or redirect.

When a preamble agent is invoked via escalation, it writes inside the active spec (`docs/specs/{id}/<domain>/`) and ends by suggesting the user return to the originating agent.

## Promotion & spec metadata

Artifacts born inside a spec that should become canonical carry a `promote:` front-matter:

```yaml
---
promote: docs/architecture/adr/adr-0007-coupon-service.md
promote_mode: copy
---
```

Modes: `copy`, `append`, `manual`. At archive time, `/mosk-dev archive` applies them before moving the spec to `docs/specs/archive/`.

Each spec also carries `spec-meta.yaml` with number, branch, status, and `current_phase`. Pipeline tasks update the phase as they run; `index-docs` reads these files to build the Active/Archived tables in `docs/index.md`.

## Project Rules

Project context lives in `.claude/rules/*.md` as plain markdown. MOSK agents read every file there before executing any task.

`mosk-boot` generates:

- `project.md` — always (from `mosk/templates/project-rule-tmpl.md`, which carries the MOSK contract)
- `frontend.md` — only when frontend code is detected

It may also suggest, with evidence from the code, `coding-standards.md`, `testing.md`, `migrations.md`, `permissions.md`, `deploy.md`, or `api.md`.

Legacy `ctx-*` context skills from older installs can be converted:

```bash
bash .claude/mosk/scripts/migrate-ctx-skills-to-rules.sh
```

## Scripts

All under `.claude/mosk/scripts/`.

### create-new-feature.sh

Creates a new spec: branch, folder, `spec-meta.yaml`, initial commit. Pushes atomically with retry on collision (max 3 attempts), so multiple developers can create specs in parallel without duplicate numbers.

```bash
bash .claude/mosk/scripts/create-new-feature.sh --type feature --short-name 'user-auth' 'Add user authentication'
bash .claude/mosk/scripts/create-new-feature.sh --no-push 'Offline spec'
bash .claude/mosk/scripts/create-new-feature.sh --help
```

Flags: `--json`, `--type`, `--short-name`, `--number`, `--no-push`, `--help`.

### sync-agents-skills.sh

Keeps agent definitions, skill wrappers, and Claude Code agent files in sync. Run after adding, renaming, or removing an agent.

```bash
bash .claude/mosk/scripts/sync-agents-skills.sh                    # both directions
bash .claude/mosk/scripts/sync-agents-skills.sh --dry-run          # preview only
bash .claude/mosk/scripts/sync-agents-skills.sh --clean            # prune orphans too
bash .claude/mosk/scripts/sync-agents-skills.sh --clean --dry-run  # preview orphan removal
```

Default: only creates or updates — never deletes. `--clean` removes orphans whose source agent no longer exists.

### link-codex-skills.sh

Refreshes `.codex/skills/`, `.codex/rules/`, and `AGENTS.md` for Codex CLI users.

```bash
bash .claude/mosk/scripts/link-codex-skills.sh
bash .claude/mosk/scripts/link-codex-skills.sh --force
```

### migrate-docs-structure.sh

Migrates a project that was installed with an older `docs/` layout (monolithic `docs/prd.md`, `docs/architecture.md`, global `docs/stories/`) to the current structure. Idempotent.

```bash
bash .claude/mosk/scripts/migrate-docs-structure.sh --dry-run   # preview
bash .claude/mosk/scripts/migrate-docs-structure.sh              # apply
bash .claude/mosk/scripts/migrate-docs-structure.sh --keep-old   # copy instead of move
```

It scaffolds the canonical `docs/`, moves monoliths to `docs/<domain>/raw.md` (ready for `shard-doc`), maps stories into per-spec folders by epic-number heuristic (unmatched go to `_orphan-stories/`), creates retroactive `spec-meta.yaml` files, rewrites `core-config.yaml` to the current schema (with a `.legacy` backup), and seeds `docs/index.md`.

### migrate-ctx-skills-to-rules.sh

One-shot migration for older installs that still carry `.claude/skills/ctx-*/SKILL.md`. Converts them to `.claude/rules/<name>.md`.

```bash
bash .claude/mosk/scripts/migrate-ctx-skills-to-rules.sh              # convert + delete old
bash .claude/mosk/scripts/migrate-ctx-skills-to-rules.sh --keep-old   # convert, keep old
bash .claude/mosk/scripts/migrate-ctx-skills-to-rules.sh --dry-run    # preview only
```

### Helpers

- `check-prerequisites.sh`, `setup-plan.sh`, `update-agent-context.sh`, `common.sh` — internal helpers used by tasks; not invoked directly in normal use.
