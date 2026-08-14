# CLAUDE.md

This repository contains the MOSK template that is installed into other projects via:

```bash
npx degit rogerznts/mosk/mosk .
```

## Important Workspace Note

**This is the single most important rule in this repo. Internalize it before any change.**

`npx degit rogerznts/mosk/mosk .` ships **only the contents of `mosk/`**.
Therefore:

- **Every MOSK product change goes under `mosk/`** — agents, tasks,
  templates, skills, scripts, checklists. If it should reach a consuming
  project, it MUST live inside `mosk/`. Nothing outside `mosk/` ships.
- **Everything at the repo root is "our" local workspace, not the
  product** and does NOT ship via degit:
  - root `.claude/` — local execution environment (a mirror used to run
    MOSK on itself). Editing it never reaches consumers.
  - root `README.md`, `TASKS.md`, `AGENTS.md`, `CLAUDE.md` — repo-facing
    docs and instructions for working *on* MOSK.
  - root `docs/` — our own discovery/specs about MOSK's evolution.
- **Scripts derive `INSTALL_ROOT` from their own location.** Running
  `mosk/.claude/mosk/scripts/<x>.sh` targets the **template** (`mosk/`);
  running the root mirror `.claude/mosk/scripts/<x>.sh` targets the
  **local env** (repo root). Pick the copy that matches your intent. In
  particular, `AGENTS.md` and `.codex/` are generated per-root, so the
  template's parity for consumers comes from the skills existing under
  `mosk/.claude/skills/` (consumers regenerate their own `AGENTS.md`
  post-install) — not from any `AGENTS.md` you generate here.

When in doubt: "will a consumer of `npx degit` need this?" → `mosk/`.
"Is this about building/documenting MOSK itself?" → repo root.

## Repository Shape

```text
mosk/                        # installable template (source of truth)
├── .claude/
│   ├── agents/              # FONTE dos agentes (11) — definição completa,
│   │                        # invocável por subagent_type. Shipa (ADR-0015).
│   ├── mosk/
│   │   ├── tasks/           # executable workflows (specify, plan, tasks,
│   │   │                    # implement, qa-gate, archive, boot, full-spec,
│   │   │                    # index-docs, planner, clarify, analyze,
│   │   │                    # checklist, create-epic, create-story,
│   │   │                    # correct-course, assess-*, design-tests,
│   │   │                    # trace-spec, …)
│   │   ├── templates/       # *-tmpl.yaml / *-tmpl.md (PRD, architecture,
│   │   │                    # story, qa-gate, spec-meta, docs-index,
│   │   │                    # project-rule, project-manual,
│   │   │                    # project-plan, project-update, …)
│   │   ├── checklists/
│   │   ├── data/            # static reference material read by tasks
│   │   │   └── hallmark/    # vendored Hallmark fork (MIT) — see VENDOR.md;
│   │   │                    # update via scripts/sync-hallmark.sh, never by hand
│   │   ├── scripts/         # create-new-feature.sh, sync-agents-skills.sh,
│   │   │                    # link-codex-skills.sh, migrate-docs-structure.sh,
│   │   │                    # migrate-ctx-skills-to-rules.sh, sync-hallmark.sh,
│   │   │                    # reset-install.sh, check-ship-ready.sh,
│   │   │                    # selftest-common.sh, common.sh
│   │   └── core-config.yaml
│   └── skills/              # slash-command wrappers (e.g. /mosk-po, /mosk-dev)
└── (installed project's docs/ layout — not part of the template itself)
```

The canonical `docs/` tree that consuming projects inherit lives in
`mosk/.claude/mosk/templates/project-rule-tmpl.md` (under "Document
Organization"). Treat that file as the single source of truth — when
the layout changes, edit it there and let the README pull a slim
summary from it.

## Product Model

MOSK is now optimized for:

- direct natural-language use of slash commands
- a short SpecKit happy path
- smaller agent prompts
- optional, not mandatory, helper steps

Conceptually, the toolkit is inspired by BMAD and SpecKit, but the shipped product should be treated as MOSK first. When editing prompts, docs, or templates, prefer MOSK language and only mention BMAD as inspiration or lineage when that context is useful.

The default path is:

```text
specify -> plan -> tasks -> implement -> qa-gate -> archive
```

Preceded by an **optional preamble** (`analyst → pm → [architect | ux-expert | ui-expert]`) when the project or feature base is not yet grounded. Pipeline agents (`po`, `sm`, `dev`, `qa`) emit `Escalation suggested` blocks when they need a preamble agent mid-flight; they never invoke another agent autonomously.

`clarify`, `analyze`, and `checklist` are optional support tasks. `shard-doc` is an optional transformation for monolithic `raw.md` files written inside `docs/prd/` or `docs/architecture/`.

## Document Organization

Consuming projects follow the MOSK v2 `docs/` layout with two mirrored layers: **base** (project-wide truth in `docs/<domain>/`) and **per-spec** (feature scope in `docs/specs/{id}/<domain>/`).

Artifacts born inside a spec that should become canonical carry a `promote:` front-matter (`copy`, `append`, or `manual`). `mosk-dev archive` applies the promotions before moving the spec to `docs/specs/archive/`.

Each spec carries a `spec-meta.yaml` (number, branch, status, `current_phase`). Pipeline tasks update `current_phase` as they run. `index-docs` reads all `spec-meta.yaml` files to build `docs/index.md` as the canonical entry point.

Brownfield projects are migrated in place via `bash .claude/mosk/scripts/migrate-docs-structure.sh` (idempotent, supports `--dry-run` and `--keep-old`).

## Agent Design

Agents live in `mosk/.claude/agents/` — the definition itself, not a
wrapper. The skill under `mosk/.claude/skills/` is generated from it.

Each agent should remain:

- concise
- direct
- low-menu
- low-token
- explicit about when to ask questions

The preferred UX is:

- user invokes `/mosk-{agent}` with natural language
- agent maps the request directly to the right task or output
- menu is only fallback when activation is empty

## Skills

Skills live in `mosk/.claude/skills/`.

They should:

- point directly to the real agent or task
- avoid extra wrapper layers
- avoid quick-pick flows

Skills are for **actions/commands** only, never for project context. Project context goes in rules (see below).

## Rules

Project rules live in `.claude/rules/*.md` **inside consuming projects**, not in the template itself. They are plain markdown files (no frontmatter) generated by `/mosk-boot` (source: `mosk/.claude/mosk/tasks/boot.md`). All MOSK agents read every file in `.claude/rules/` eagerly before executing any task.

The default pack produced by `/mosk-boot`:

- `project.md` — always generated
- `frontend.md` — only when the project has frontend code

Additional rules (`coding-standards.md`, `testing.md`, `migrations.md`, `permissions.md`, `deploy.md`, `api.md`) are suggested interactively when evidence in the codebase supports them.

Legacy `ctx-*` context skills from older installs can be migrated via `mosk/.claude/mosk/scripts/migrate-ctx-skills-to-rules.sh`.

The canonical template `mosk/.claude/mosk/templates/project-rule-tmpl.md` is the source `boot.md` uses to generate `project.md`. Keep MOSK-invariant sections (Document Organization, Promotion, Agent Roles, Escalation Policy, Spec Numbering, `docs/index.md`) untouched when editing the template.

## Tasks

Tasks live in `mosk/.claude/mosk/tasks/`.

When editing tasks:

- optimize for the happy path first
- keep outputs implementation-oriented
- avoid mandatory elicitation unless the missing answer materially changes the result
- keep optional artifacts optional

Reference material a task reads at runtime lives in `mosk/.claude/mosk/data/`
and is referenced by basename (see `design-tests.md` for the `## Dependencies`
shape). `data/hallmark/` is different: it is a **vendored fork** of an upstream
MIT project, not MOSK-authored content. Do not hand-edit it — every local change
becomes part of the fork's diff. Update it with
`bash mosk/.claude/mosk/scripts/sync-hallmark.sh` and read
`data/hallmark/VENDOR.md` first.

## Agent descriptions

A skill's `description:` is **declared by the agent**, on its first line:

```md
<!-- skill-description: <Área>: <ações em pt-BR, com gatilhos de roteamento>. -->
```

It is deliberately separate from `## Mission`. The description is *routing*
metadata (pt-BR, trigger-rich, read by the host to decide when to load the
skill); the Mission is *persona prose* (English, multi-line, read by the model
once loaded). `sync-agents-skills.sh` copies the declared line into both the
skill wrapper and the CC agent, and only ever rewrites the `description:` line
of files that already exist — extra front-matter keys and hand-written bodies
survive. Never edit a wrapper's description directly; edit the agent.

## Validation

There is no compiled app or automated test suite for the template itself.

Validation here is mainly:

- reading the installed file structure
- checking prompt and workflow consistency
- ensuring documentation matches the shipped template

## Project Rules

The following project rules were generated by `/mosk-boot` and live in `.claude/rules/`:

- `project.md` — MOSK toolkit master template: two-tier repo layout (`mosk/` is source of truth, root `.claude/` is local exec only), stack (Markdown/YAML/Bash, no compiled app, no test suite), folder conventions, manual validation flow, and the MOSK-invariant framework contract (Document Organization, Promotion, Agent Roles, Escalation, Spec Numbering, `docs/index.md`).
- `scripts.md` — Reference for the Bash helpers under `mosk/.claude/mosk/scripts/` (create-new-feature, sync-agents-skills, link-codex-skills, migrate-docs-structure, migrate-ctx-skills-to-rules, setup-plan, update-agent-context, check-prerequisites, common.sh): usage, flags, when to run each one, and the idempotency/help/`--dry-run` conventions.

MOSK agents read every file in `.claude/rules/*.md` automatically before executing any task. Re-run `/mosk-boot` to regenerate them if the project structure changes significantly.
