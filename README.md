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
| `/mosk-ui-expert` (Tiago) | premium UI, design system — plus the **Hallmark** anti-slop flow |
| `/mosk-po` (Sara) | specs, planning, task generation |
| `/mosk-sm` (Roberto) | story readiness, sequencing |
| `/mosk-dev` (Jaime) | implementation, QA fixes, archive |
| `/mosk-qa` (Joaquim) | quality gates, test strategy, reviews |
| `/mosk-security` (Heitor) | diff-aware vulnerability review, findings triage |
| `/mosk-bench` (Bento) | workbench mode for non-technical users (Payload stack) |
| `/mosk-orq` (Mauro) | orchestrator over Orca (opt-in, optional dependency) |

Each agent ships as **two layers**: `.claude/agents/mosk-<name>.md` is the
definition — and what makes it invocable by another agent in an isolated context
— while `.claude/skills/mosk-<name>/SKILL.md` is a generated wrapper that gives
you the `/mosk-<name>` slash command. Edit the agent; the wrapper is regenerated.

An agent may invoke another **to execute** work whose route a human already
approved — never to decide where the pipeline goes.

> **[docs/agents.md](./docs/agents.md)** — roster, the two layers, the invocation
> protocol, and what is particular to `bench`, `deploy`, `security` and Hallmark.
> **[TASKS.md](TASKS.md)** — every task each agent can run, with examples.

Natural language is the preferred UX: slash-activate the agent and describe what
you want; you can also name the task directly.

## Flow

A single pipeline. An optional **preamble** runs first whenever the base of the project (or the feature) is not yet grounded.

The pipeline is formalized as data in [`mosk/.claude/mosk/pipeline-graph.yaml`](mosk/.claude/mosk/pipeline-graph.yaml) — the **single source of truth** for phases, transitions, and escalations. It is **consultative**: `legal_moves.sh` computes the legal next moves from the current phase and the human decides (`go`/`escalate`/`skip`/override) — nothing auto-executes (see [ADR-0006](docs/architecture/adr/adr-0006-consultative-orchestration-graph.md)).

<!-- Este diagrama é mantido À MÃO — mantenha-o em sincronia com pipeline-graph.yaml (fonte da verdade). A versão renderizada a partir do grafo vive em docs/index.md. -->

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
    I -->|CONCERNS or FAIL · attempt < max_retries| H
    I -->|max_retries reached| K[escalate / waive / stop]
    I -->|PASS or WAIVED| J[/mosk-dev archive/]
```

Defaults:

- **Skip the preamble** when the project base (PRD, architecture, UI) already supports the request; go straight to `/mosk-po full-spec`.
- **Use the preamble** when the base is missing or stale. Only call the agents that materially help this change. Outputs may be written at the **base** (`docs/<domain>/`) when canonical, or **per-spec** (`docs/specs/{id}/<domain>/`) when specific to this change.
- **Compact path:** `full-spec → implement → qa-gate → archive`.
- **Granular path:** `specify → plan → tasks → implement → qa-gate → archive`.
- **Optional helpers:** `clarify`, `analyze`, `checklist`.

`full-spec` stops at `tasks`. Implementation stays with `/mosk-dev`.

### Delivery-loop (bounded, consultative)

The `implement ↔ qa-gate` cycle is a **bounded, consultative delivery-loop** (see [ADR-0008](docs/architecture/adr/adr-0008-consultative-delivery-loop.md)). When the gate returns `CONCERNS`/`FAIL`, `legal_moves.sh qa-gate` presents the correction loopback labeled `tentativa N/max` (default `apply-qa-fixes`) — **you** decide each turn; it never iterates on its own.

- **Termination** is the single gate verdict `PASS`/`WAIVED` (task checkboxes feed the gate, they are not a parallel exit).
- **Attempt count** is derived from each spec's `phase-history.log` (no new state); the cap `max_retries` defaults to `3` in `core-config.yaml` (`orchestration.max_retries`) and is overridable per-spec in `spec-meta.yaml`.
- On **exhaustion** the loopback is withdrawn and the loop offers `escalate` / `waive` / `stop` — never a silent give-up, never an auto-retry.

It is distinct from the bench's automated `loop-until-green`: the delivery-loop serves a **technical operator** and pauses for questions; the bench serves a layperson and never does.

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

**Opt-in exception — `/mosk-orq` (Mauro, the maestro).** For users running [Orca](https://www.onorca.dev/) — an **optional external dependency** — Mauro drives one project's pipeline across panes, handing off automatically when the phase changes agent or when an agent hits its token ceiling (transporting context via `/mosk-handoff`). The actuator sits behind a single facade (`panes.sh`), so the agent prompt never talks to the CLI directly. It automates only **transport** (spawn/handoff/close) and the graph's **happy path**; every **human decision** — judgment guards, `qa-gate` verdicts, and (in `semi-auto`) any phase/agent change — still pauses and returns to you.

Orca is **optional in the strong sense**: the pipeline runs end to end with no actuator at all, and without one Mauro degrades to the normal single-pane flow. Availability requires the session to be running **inside the Orca IDE** — having the binary on `PATH` proves installation, not context, and `spawn` creates terminals *inside the app*. `panes.sh driver` tells you which case you are in and what to do about it. See [ADR-0014](./docs/architecture/adr/adr-0014-orca-single-actuator.md) (which supersedes [ADR-0009](./docs/architecture/adr/adr-0009-herdr-orchestration.md) and revokes decision 7 of [ADR-0010](./docs/architecture/adr/adr-0010-orca-backend.md)).

**Parallel work inside a phase (fan-out).** When `tasks.md` marks two or more units `[P]`, `implement` can dispatch them as a **wave**: each unit isolated, each verified, joined at the end. You approve the **fan-out plan once** — never branch by branch — and the join always returns to you; no wave chains into another on its own. It works in three tiers by detected capability (Orca orchestration → native subagent → sequential), so it needs no Orca: `panes.sh tier` reports which one applies. See [ADR-0012](./docs/architecture/adr/adr-0012-route-decision-vs-phase-execution.md), [ADR-0013](./docs/architecture/adr/adr-0013-fanout-seam-three-tiers.md).

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
│   │   ├── data/           # reference material read by tasks
│   │   │   └── hallmark/   # vendored Hallmark (MIT) — see VENDOR.md
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
- `sync-agents-skills.sh` — regenerates skill wrappers from agent definitions and vice-versa. Use `--clean` to prune orphans, `--dry-run` to preview. Existing wrappers are edited in place — only the `description:` line is refreshed, so extra front-matter keys and hand-written bodies survive. A skill's description is declared by the agent itself, on its first line (`<!-- skill-description: … -->`), deliberately separate from `## Mission`: one is routing metadata, the other is persona prose.
- `sync-hallmark.sh` — updates the vendored Hallmark fork. Diffs the pinned upstream against the local copy to recover the MOSK adaptations, then replays them onto the new ref; a conflict leaves `.rej` files and **does not touch the vendor**. Accepts `--ref`, `--dry-run`.
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
