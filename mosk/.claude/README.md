# MOSK Skills

This is the installed MOSK toolkit inside your project. Twelve specialist agents, one spec-driven pipeline, and a small set of maintenance scripts — all living under `.claude/`.

## Where things live

```
.claude/
├── agents/            # the agent definitions — source of truth
├── mosk/
│   ├── tasks/         # executable workflows (specify, plan, tasks, implement, qa-gate, archive, boot, index-docs, …)
│   ├── templates/     # *-tmpl.yaml / *-tmpl.md (prd, architecture, story, spec-meta, docs-index, project-rule, …)
│   ├── checklists/
│   ├── data/          # reference material a task loads only when that phase needs it
│   ├── scripts/       # lifecycle scripts (see below)
│   └── core-config.yaml
├── rules/             # generated per project by /mosk-boot (project.md + frontend.md + optional extras)
└── skills/            # generated slash-command wrappers
```

Each skill becomes a slash command based on its frontmatter `name`. Example: `name: mosk-po` → `/mosk-po`. The wrapper is generated from the agent — edit the agent under `.claude/agents/`, never the wrapper.

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

`/mosk-boot` writes the full Document Organization reference into `.claude/rules/project.md` — that file is the installed copy of the contract, generated from `.claude/mosk/templates/project-rule-tmpl.md`.

## Agents

Pipeline and preamble:

- `mosk-analyst` — discovery, research, brainstorming
- `mosk-pm` — PRD, product scope, PRD delta
- `mosk-architect` — architecture, APIs, integrations, ADRs
- `mosk-ux-expert` — user flows, wireframes, front-end specs
- `mosk-ui-expert` — premium UI, design system, visual acabamento
- `mosk-po` — specs, planning, task generation
- `mosk-sm` — story readiness, sequencing
- `mosk-dev` — implementation, QA fixes, archive
- `mosk-qa` — quality gates, test strategy, reviews

On demand:

- `mosk-security` — diff-aware vulnerability review; its report feeds the gate
- `mosk-bench` — workbench mode for non-technical users
- `mosk-orq` — autonomous delivery run, opt-in each time you start one

Helper skills:

- `mosk-boot` — generates `.claude/rules/` and scaffolds `docs/` on first install
- `mosk-help` — short reference guide
- `mosk-suggestion` — reads the current phase and suggests the next agent with a ready-to-paste prompt

UX Expert and UI Expert coexist in `docs/ui/` with distinct focus: UX owns structure/behavior (flows, wireframes, front-end specs), UI owns visual polish (design system, styles, premium components).

## Preferred Usage

Describe what you want in natural language. The agent maps the request to the right task and produces the result:

```text
/mosk-po full-spec checkout com cupom
/mosk-dev implementar a spec 012
/mosk-qa revisar a spec 012
/mosk-ui-expert redesign da home atual
```

You can also name a task directly (`/mosk-architect grill`). Advanced `*commands` still work as compatibility shortcuts, but natural language is the primary UX.

**Documents are written in one pass.** Creating a brief, a PRD, an architecture doc or a spec does not walk you through a numbered menu and does not stop for approval between sections. The agent asks questions only when a genuine ambiguity would change the scope, the architecture, the data or an external effect — and when it asks, it asks **once**, grouping everything it needs. Anything it can settle with a safe default is settled and reported as an assumption alongside the finished document.

**Deeper exploration is opt-in.** Ask for it — "critique this", "explore alternatives", "stress-test this section" — and the agent runs an advanced-elicitation pass on the part you named, then hands the document back. Nothing in a template turns that mode on by itself, and finishing it does not reopen the questions round.

**Rigor scales with the change.** `implement`, `qa-gate`, `security-review` and the autonomous runner size their work against the same shared rule: how far the change reaches, how hard it is to undo, whether it touches sensitive surface, and how much evidence exists. A rename in one file gets a short read and a focused check; anything touching data, security, a public contract or production gets more context, independent verification and a security pass before the gate. The agent states in one line how it sized the work, and it can raise that level mid-flight but never lower it. Ask for more depth and you get it; the level it computed is a floor, not a ceiling.

This changes how much work an agent does — never who decides. Phase changes, gate verdicts and detours are still yours.

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

Pipeline agents (`po`, `sm`, `dev`, `qa`) detect signals that require a preamble agent mid-flight — an architectural ambiguity, a missing flow, a PRD conflict — and pause with a plain-language block naming who resolves it, plus a ready-to-paste prompt. Agents never invoke each other automatically; the user decides whether to go, skip, or redirect.

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

Legacy `ctx-*` context skills from older installs are converted by the
`migrate-install` task, which also migrates a pre-v2 `docs/` layout.

## Scripts

Five scripts, all under `.claude/mosk/scripts/`. The list is short by design:
since [ADR-0021](../../docs/architecture/adr/), rules live in `pipeline.yaml`
and are read by the agent, so shell only covers what an agent genuinely cannot
do — a race against another process on the remote, bulk generation of derived
files, and execution outside an agent session.

### validate.sh

The single verifier. Replaces `doctor.sh`, `check-prerequisites.sh`,
`check-ship-ready.sh` and `audit-docs-paths.sh`.

```bash
bash .claude/mosk/scripts/validate.sh ship-ready      # spec is closed and mergeable
bash .claude/mosk/scripts/validate.sh prerequisites --for implement
bash .claude/mosk/scripts/validate.sh install         # toolkit integrity
bash .claude/mosk/scripts/validate.sh docs-paths      # canonical output paths
bash .claude/mosk/scripts/validate.sh single-source   # normative text not copied
bash .claude/mosk/scripts/validate.sh all
```

Exit 0 valid, 1 violations, 2 usage error. No PyYAML, npm or pip required.

**It has a named caller**, which is the whole point: `.claude/hooks/guard-spec-merge.sh`
intercepts PR/merge commands and runs `ship-ready`. A verification nobody invokes
has the force of a rule written in prose — spec 014 of this toolkit reached the
default branch in `qa-gate` precisely because the verifier existed and was never
called.

### create-new-feature.sh

Bootstraps a spec: reserves the number atomically on `origin` under
`refs/spec-numbers/`, creates branch and folder, writes `spec-meta.yaml`,
commits and pushes with renumbering on collision.

```bash
bash .claude/mosk/scripts/create-new-feature.sh \
  [--json] [--type feature|fix|hotfix|gmud|refactor|experimental|extension] \
  [--short-name <name>] [--number N] [--extends <spec-id>] [--no-push] <description>
```

Branch is `{type}/{NNN}-{name}`; the folder is `docs/specs/{NNN}-{type}-{name}`.
They are different strings (ADR-0017) — the bridge is the `branch:` field in
`spec-meta.yaml`, never string equality.

### sync.sh

Materializes derived artifacts. Replaces `sync-agents-skills.sh` and
`link-codex-skills.sh`.

```bash
bash .claude/mosk/scripts/sync.sh skills     # agents -> skill wrappers
bash .claude/mosk/scripts/sync.sh codex      # .codex/ symlinks + AGENTS.md
bash .claude/mosk/scripts/sync.sh all [--clean] [--dry-run] [--force]
```

The agent is the source, the skill is the generated wrapper — one direction
only (ADR-0015). A skill's `description:` is declared by the agent on its first
line as `<!-- skill-description: ... -->`; never edit a wrapper's description
directly.

### reset-install.sh

Reinstalls the toolkit from scratch in a consuming project, deleting orphans
that `degit --force` would leave behind forever. Always run the freshly
downloaded copy, never the installed one — it deletes the directory it lives in.

```bash
bash <tmp>/.claude/mosk/scripts/reset-install.sh --from <tmp> --to <project> [--dry-run]
```

Never touches `.claude/rules/`, `settings.json`, `docs/`, `CLAUDE.md` or
`AGENTS.md`.

> Atualizar o vendor do Hallmark deixou de ser script: é a task
> `.claude/mosk/tasks/sync-hallmark.md`, que faz o mesmo diff/replay contra o
> ref pinado em `VENDOR.md` e aborta sem tocar no vendor em caso de conflito.

### common.sh

Shared library, never executed directly. Resolves repo root, current branch and
spec directory; emits and reads `spec-meta.yaml`; contains path containment
(`validate_promotion_target`) that must resolve symlinks against the real
filesystem — which is why it stays in shell.

```bash
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
```

Self-locates in **bash and zsh** (`${BASH_SOURCE[0]}` and `${(%):-%x}`), because
tasks tell the agent to source it in its own shell and macOS defaults to zsh.

