# MOSK

Spec-driven development toolkit for Claude Code. Nine specialist agents, one pipeline, two mirrored layers of documentation — installable into any repository through `.claude/`.

> **Novo — MOSK Bench:** um modo que deixa pessoas **não técnicas** criarem e
> testarem suas próprias ferramentas internas só descrevendo o que precisam, em
> português e sem nenhuma decisão técnica. **[Leia o guia do Bench](./BENCH.md)**

## Why MOSK

Every meaningful change in a real codebase deserves an explicit trail: a brief that framed it, a spec that scoped it, a plan that solved it, tasks that delivered it, a gate that validated it, and an archive that preserves it. MOSK turns that trail into a lightweight, convention-driven workflow with low token overhead and no mandatory menus.

- **Role clarity** — each agent owns one thing well and knows when to defer.
- **Structured artifacts** — specs, plans, tasks, stories, gates, ADRs all live in predictable places.
- **Explicit handoffs** — pipeline agents detect when a preamble agent is needed and suggest it; they never invoke another agent autonomously.
- **Incremental delivery** — every spec carries metadata, progresses through phases, and is archived with promotable artifacts.

## Installation

```bash
npx degit rogerznts/mosk/mosk .
```

Force-overwrite an existing install:

```bash
npx degit rogerznts/mosk/mosk . --force
```

First-time setup for a codebase:

```bash
/mosk-boot
```

`mosk-boot` reads the project, generates `.claude/rules/` (a compact `project.md` plus `frontend.md` when frontend code is detected), and scaffolds the canonical `docs/` layout. Re-run it whenever the project structure changes significantly.

For Codex users, create symlinks after install:

```bash
bash .claude/mosk/scripts/link-codex-skills.sh
```

Restart Claude Code after install so the new skills load.

## Agents

| Skill | Responsibility |
|---|---|
| `/mosk-analyst` (Maria) | discovery, research, brainstorming |
| `/mosk-pm` (João) | PRD, product scope, PRD delta |
| `/mosk-architect` (Vinicius) | architecture, APIs, integrations, ADRs |
| `/mosk-ux-expert` (Salete) | user flows, wireframes, front-end specs |
| `/mosk-ui-expert` (Tiago) | premium UI, design system, visual acabamento |
| `/mosk-po` (Sara) | specs, planning, task generation |
| `/mosk-sm` (Roberto) | story readiness, sequencing |
| `/mosk-dev` (Jaime) | implementation, QA fixes, archive |
| `/mosk-qa` (Joaquim) | quality gates, test strategy, reviews |
| `/mosk-security` (Heitor) | diff-aware vulnerability review, security audit, findings triage |
| `/mosk-bench` (Bento) | workbench mode for non-technical users: build & iterate internal tools (Payload stack) |
| `/mosk-deploy` (Bento) | publishes a `/mosk-bench` tool to a hosting provider (Railway) using the user's own account — remote build, managed DB, public URL, pt-BR |

`/mosk-bench` is a **self-contained mode**, not a pipeline agent: it grills the user for a business briefing, then runs the SDD pipeline autonomously (Docker-based, pt-BR, zero technical decisions for the user). The active stack is Payload (pluggable adapter). **For a non-technical, plain-language walkthrough of everything it does, see [BENCH.md](./BENCH.md).**

`/mosk-deploy` is an **opt-in, separate** skill that publishes a bench tool to a hosting provider (Railway today) using the user's own account: the build runs **remotely** (so the local "zero build" invariant holds), managed Postgres/Redis are provisioned, and the user gets a public URL — all in pt-BR, deciding only account/token. See [ADR-0005](./docs/architecture/adr/adr-0005-deploy-skill-scoped-outside-local-invariants.md). The stack × provider model leaves room for PHP and other providers (Vercel/Fly) later.

`/mosk-security` is an **on-demand reviewer** (inspired by Anthropic's [`claude-code-security-review`](https://github.com/anthropics/claude-code-security-review)): contextual, diff-aware analysis with a hard confidence threshold and an explicit false-positive exclusion list. It is not a pipeline phase — its report **feeds the `qa-gate`** (a `SECURITY: FAIL`/`CONCERNS` verdict informs the decision). Following the MOSK escalation contract, `implement` and `qa-gate` only **suggest** running it when the diff touches security-sensitive surface, and wait for your confirmation — never auto-invoke.

UX Expert and UI Expert coexist in `docs/ui/` with distinct focus: UX owns structure and behavior (flows, wireframes, front-end specs), UI owns visual polish (design system, styles, premium components).

**Every task each agent (and standalone skill) can run — with a one-line description and usage examples — is catalogued in [TASKS.md](TASKS.md).** Natural language is the preferred UX: slash-activate the agent and describe what you want; you can also name the task directly.

## Flow

A single pipeline. An optional **preamble** runs first whenever the base of the project (or the feature) is not yet grounded.

```mermaid
flowchart TD
    A[Request] -->|base missing/incomplete?| PRE
    A -->|base in place| F

    subgraph PRE [Preamble - optional]
        B[/mosk-analyst<br/>Discovery/] -. if vague .-> C[/mosk-pm<br/>PRD or PRD-delta/]
        C -. if architecture-heavy .-> E[/mosk-architect/]
        C -. if UX-heavy .-> D[/mosk-ux-expert/]
        C -. if design-heavy .-> W[/mosk-ui-expert/]
    end

    PRE --> F[/mosk-po<br/>full-spec: specify → plan → tasks/]
    F --> G[/mosk-sm<br/>readiness/]
    G --> H[/mosk-dev implement/]
    H -. if security-sensitive .-> S[/mosk-security<br/>review/]
    H --> I[/mosk-qa qa-gate/]
    S --> I
    I -->|CONCERNS or FAIL| H
    I -->|PASS| J[/mosk-dev archive/]
```

Defaults:

- **Skip the preamble** when the project base (PRD, architecture, UI) already supports the request; go straight to `/mosk-po full-spec`.
- **Use the preamble** when the base is missing or stale. Only call the agents that materially help this change. Outputs may be written at the **base** (`docs/<domain>/`) when canonical, or **per-spec** (`docs/specs/{id}/<domain>/`) when specific to this change.
- **Compact path:** `full-spec → implement → qa-gate → archive`.
- **Granular path:** `specify → plan → tasks → implement → qa-gate → archive`.
- **Optional helpers:** `clarify`, `analyze`, `checklist`.

`full-spec` stops at `tasks`. Implementation stays with `/mosk-dev`.

## Document Organization

MOSK uses two mirrored layers: the **base** (project-wide truth) and **per-spec** (scope of a single feature/fix).

Top-level shape:

```
docs/
├── index.md          # auto-generated entry point (task: index-docs)
├── discovery/        # mosk-analyst
├── prd/              # mosk-pm (sharded)
├── architecture/     # mosk-architect (+ adr/)
├── ui/               # mosk-ux-expert + mosk-ui-expert
├── qa/gates/         # mosk-qa
├── project/          # mosk-pm planner (non-technical plan + dated updates)
└── specs/            # per-spec folders + archive/
```

The full canonical tree (including the per-spec internals like `spec-meta.yaml`, `stories/`, `tests/`, `gate.yaml`) is documented in [`mosk/.claude/mosk/templates/project-rule-tmpl.md`](mosk/.claude/mosk/templates/project-rule-tmpl.md), the file `/mosk-boot` uses to generate `.claude/rules/project.md` in every consuming project.

**Base vs spec decision rule**

- Artifact describes the project as it **is today** → `docs/<domain>/`.
- Artifact is **specific to a pending change** → `docs/specs/{id}/<domain>/`.
- Artifact born in a spec but destined to become canonical → starts in the spec and is **promoted** at archive time.

### Promotion Convention

Artifacts inside `specs/{id}/` that should become canonical carry a `promote:` front-matter declaring destination and mode:

```yaml
---
promote: docs/architecture/adr/adr-0007-coupon-service.md
promote_mode: copy
---
```

| `promote_mode` | Behavior at archive |
|---|---|
| `copy` | Copy the file to the target path. Asks before overwrite. |
| `append` | Append the body (minus front-matter) to the target. |
| `manual` | Don't apply automatically. Print the file + suggested destination and ask the user to apply by hand. Default for `prd-delta.md`. |

Without `promote:`, the artifact freezes inside the archived spec.

### Transforming raw drafts with `shard-doc`

When `mosk-pm` writes a monolithic PRD to `docs/prd/raw.md` (or the architect writes `docs/architecture/raw.md`), the optional `shard-doc` task splits it into `index.md` + section files **in the same folder**. Run it when you want a navigable sharded view.

### Project tracking with `planner`

`/mosk-pm planner` maintains a **non-technical** tracking plan plus a dated update log aimed at PO, stakeholders, and project managers — progress, scope, and value, not implementation detail. A technical file may be cited, but that is never the focus. The scope follows the current branch:

- **Base branch** (`main`/`master`/`develop`/`dev`) → the whole project, in `docs/project/plan.md` + `docs/project/update-YYYYMMDD.md`.
- **Spec branch** → that spec, in `docs/specs/{id}/project/plan.md` + `update-YYYYMMDD.md`, **plus** a light refresh of the project plan so the spec shows up as one line of the whole.

Cadence, status vocabulary, and tone live in `docs/discovery/project-manual.md` (seeded on first run). The planner reads it, the living docs (project first, then the current spec), and recent git activity — translating commits into business-readable progress. It always emits a dated update suitable for a tracking PR, even when nothing changed.

## Spec Numbering and Concurrency

Spec numbers are globally unique, three-digit, zero-padded (`001`, `002`, …). When multiple developers create specs in parallel, `create-new-feature.sh` pushes atomically and retries with a new number if the push is rejected — up to 3 attempts before surfacing a clear error.

Each spec carries `spec-meta.yaml`:

```yaml
spec_number: "005"
spec_id: "005-feature-checkout-coupon"
type: feature
branch: "005-feature-checkout-coupon"
created_at: "2026-04-22T14:30:00Z"
created_by: "Alice <alice@example.com>"
status: active             # active | archived
current_phase: specify     # specify | plan | tasks | implement | qa-gate | archived
last_phase_change: "2026-04-22T14:30:00Z"
```

Pipeline tasks (`plan`, `tasks`, `implement`, `qa-gate`, `archive`) update `current_phase` as they run. `index-docs` reads these files to build the Active Specs table in `docs/index.md`.

## Entry Point: `docs/index.md`

`docs/index.md` is the canonical first read for new contributors. It is auto-generated by the `index-docs` task and refreshed at every pipeline step:

- **Overview** — links to the 6 base domains (discovery, prd, architecture, ui, qa, project).
- **Active Specs** — table sourced from each `docs/specs/*/spec-meta.yaml`, newest first.
- **Archived Specs** — list from `docs/specs/archive/*`, most recently archived first.
- **Domain Contents** — alphabetical file listing per base folder, with titles and short descriptions.

Manual regeneration: `/mosk-dev index-docs`.

Preserve custom text between `<!-- custom -->` and `<!-- /custom -->` markers — regenerations leave them untouched.

## Escalation Policy

Pipeline agents (`po`, `sm`, `dev`, `qa`) detect signals that require a preamble agent mid-flight — a missing ADR, an unspecified flow, a PRD conflict — and emit a standardized **Escalation suggested** block:

> **Escalation suggested**
> - Signal: *what was detected*
> - Recommended agent: `/mosk-architect`
> - Suggested prompt: `/mosk-architect decide coupon service contract`
> - Scope: `feature 005-feature-checkout-coupon` (outputs written to `specs/{id}/architecture/`)
> - On return: resume `implement` from where it paused.

Agents never invoke each other automatically. The user decides: `go`, `escalate`, `skip`, or an alternative. Preamble agents invoked via escalation write inside the active spec and end by suggesting the user return to the originating agent.

## Skills vs Agents

MOSK agents can be invoked two ways inside Claude Code:

**Skill (slash command)** — runs inside the current conversation and shares its context. This is the default and preferred way.

```
/mosk-dev implement a spec 012
```

**Agent (subagent)** — runs in a separate process with its own context. Does not see conversation history. Claude Code spawns these internally when needed.

| | Skill | Agent |
|---|---|---|
| Shares conversation context | yes | no |
| Parallel execution | no | yes |
| Interactive with the user | yes | no |
| Isolates heavy output | no | yes |

For daily use, prefer skills.

## Spec Types

Specs share a single pipeline; the type lives in the folder/branch name:

```
{###}-{type}-{short-name}
```

Supported types:

- `feature`
- `fix`
- `hotfix`
- `gmud`
- `refactor`
- `experimental`

Example:

```
012-feature-checkout-coupon
```

## Migrating Existing Projects

Projects carrying older layouts (`docs/prd.md`, `docs/architecture.md`, `docs/stories/`) are migrated in place with a single idempotent script:

```bash
bash .claude/mosk/scripts/migrate-docs-structure.sh --dry-run   # preview
bash .claude/mosk/scripts/migrate-docs-structure.sh              # apply
```

The migration:

- scaffolds the canonical `docs/` layout,
- moves monoliths to `docs/<domain>/raw.md` (ready for `shard-doc`),
- maps stories into `docs/specs/{id}/stories/` by epic-number heuristic (unmatched go to `_orphan-stories/` for manual review),
- creates retroactive `spec-meta.yaml` for each existing spec folder,
- rewrites `.claude/mosk/core-config.yaml` to the current schema (with a `.legacy` backup),
- seeds `docs/index.md`.

Flags: `--dry-run` (preview), `--keep-old` (copy instead of move), `--help`.

After the script runs, residual files often remain — briefs at `docs/` root, a legacy `docs/epics/` folder, orphan stories without an epic match. Load the companion prompt `.claude/mosk/utils/post-migration-organize.md` in a Claude Code session to walk those resíduos into the canonical layout: it scans `docs/`, classifies each file by domain heuristics, allocates orphan stories/epics into existing or newly-created specs, and regenerates `docs/index.md` at the end. Nothing is moved without your confirmation.

Projects with legacy `ctx-*` context skills can convert them to plain rules:

```bash
bash .claude/mosk/scripts/migrate-ctx-skills-to-rules.sh
```

## Installed Structure

```text
your-project/
├── .claude/
│   ├── mosk/
│   │   ├── agents/
│   │   ├── tasks/
│   │   ├── templates/
│   │   ├── checklists/
│   │   ├── scripts/
│   │   └── core-config.yaml
│   ├── rules/            # generated by /mosk-boot
│   └── skills/
│       ├── mosk-analyst/
│       ├── mosk-architect/
│       ├── mosk-boot/
│       ├── mosk-dev/
│       ├── mosk-handoff/
│       ├── mosk-help/
│       ├── mosk-pm/
│       ├── mosk-po/
│       ├── mosk-qa/
│       ├── mosk-sm/
│       ├── mosk-suggestion/
│       ├── mosk-ui-expert/
│       └── mosk-ux-expert/
└── docs/
    ├── index.md
    ├── discovery/
    ├── prd/
    ├── architecture/
    │   └── adr/
    ├── ui/
    │   └── flows/
    ├── qa/
    │   └── gates/
    └── specs/
        └── archive/
```

## Maintenance Scripts

Under `.claude/mosk/scripts/`:

- `create-new-feature.sh` — spawns a new spec folder + branch + `spec-meta.yaml`, with push-atomic retry for concurrent usage. Accepts `--type`, `--short-name`, `--number`, `--no-push`, `--json`.
- `sync-agents-skills.sh` — regenerates skill wrappers from agent definitions and vice-versa. Use `--clean` to prune orphans, `--dry-run` to preview.
- `link-codex-skills.sh` — refreshes `.codex/skills/`, `.codex/rules/`, and `AGENTS.md` for Codex users.
- `migrate-docs-structure.sh` — migrates a legacy `docs/` layout to the current one (idempotent).
- `migrate-ctx-skills-to-rules.sh` — converts legacy `ctx-*` context skills to `.claude/rules/*.md`.
- `audit-docs-paths.sh` — verifies that tasks, templates, and `core-config.yaml` declare outputs only under canonical `docs/` domains and that referenced config keys and template files exist. Five rules (R1–R5), exit 0 on `clean ✓` and exit 1 with a `path:line :: rule :: detail` list on violations. Modes: default and `--quiet`. Also reachable via `/mosk-dev audit`.
- `check-prerequisites.sh`, `setup-plan.sh`, `update-agent-context.sh`, `common.sh` — helpers used by tasks.

## Optional Environment Tools

MOSK runs inside Claude Code. For extra operational isolation, these pair well with it:

- `workz` — isolated worktrees
- `ai-jail` — filesystem confinement

## Inspiration

MOSK owes a real conceptual debt to:

- **BMAD** — role-driven collaboration with specialist agents.
- **SpecKit** — turning vague requests into explicit, ordered artifacts.

The product is MOSK-first: a lighter, synthesized toolkit built to disappear into real projects instead of standing apart from them.
