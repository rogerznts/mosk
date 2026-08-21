# MOSK

Spec-driven development toolkit for Claude Code. Twelve specialist agents, one pipeline, two mirrored layers of documentation — installable into any repository through `.claude/`.

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
bash .claude/mosk/scripts/sync.sh codex
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
| `/mosk-orq` (Mauro) | **autonomous delivery run** — parallel agents, opt-in per run |

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

The pipeline is **consultative end to end**: every phase change, every gate
verdict and every detour is the human's call. Agents suggest and wait; they
never route on their own.

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
    I -->|PASS or WAIVED| J[/mosk-dev archive/]
```

Defaults:

- **Skip the preamble** when the project base (PRD, architecture, UI) already supports the request; go straight to `/mosk-po full-spec`.
- **Use the preamble** when the base is missing or stale. Only call the agents that materially help this change. Outputs may be written at the **base** (`docs/<domain>/`) when canonical, or **per-spec** (`docs/specs/{id}/<domain>/`) when specific to this change.
- **Compact path:** `full-spec → implement → qa-gate → archive`.
- **Granular path:** `specify → plan → tasks → implement → qa-gate → archive`.
- **Optional helpers:** `clarify`, `analyze`, `checklist`.

`full-spec` stops at `tasks`. Implementation stays with `/mosk-dev`.

### The correction cycle

When the gate returns `CONCERNS`/`FAIL`, the work goes back to `/mosk-dev apply-qa-fixes` and then to the gate again. **You decide each turn** — the cycle never iterates on its own.

- **Termination** is the single gate verdict `PASS`/`WAIVED`. Task checkboxes feed the gate; they are not a parallel exit.
- **`quality_score`** is *computed* (`100 − 20×FAIL − 10×CONCERNS`), never estimated, and accumulated in `score_history` inside `gate.yaml`. The gate presents the series — `61 → 68 → 69` — alongside the verdict.
- That series is what makes the decision informed: a **flat** score across turns says another round will not help, and the honest move is to escalate to whoever owns the design or the story. A **rising** score says the opposite.

It is distinct from the bench's automated `loop-until-green`: this cycle serves a **technical operator** and pauses for questions; the bench serves a layperson and never does.

## How the agents work

**One request, one document.** Writing a brief, a PRD, an architecture doc or a
spec is a single pass. There is no numbered menu between sections and no
approval stop on reversible writes — the agent produces the whole artifact and
tells you what it decided.

Questions are asked when — and only when — the answer changes the scope, the
architecture, the data model or an external effect. When that happens the agent
gathers everything it needs and asks **one grouped round**, then finishes.
Whatever a safe default can settle is settled and reported as an assumption
next to the delivered file. If a decision only the user can make is still
missing after that round, the agent stops and states the real question instead
of opening a second round.

**Advanced elicitation is opt-in.** Ask for critique, alternatives or a
stress-test of a specific passage and the agent runs a deep pass on exactly
that, then returns to the document. No template flag switches it on, and
finishing it does not restart the clarification round.

**Rigor is proportional to the change.** `implement`, `qa-gate`,
`security-review` and `/mosk-orq` size their work against one shared rule that
weighs how far a change reaches, how reversible it is, whether it touches
sensitive surface, and how much evidence backs it. A localized edit gets a
narrow read and a focused check; a change to data, security, a public contract
or production gets wider context, independent verification, and a security pass
feeding the gate. Each agent states in one line how it sized the work and can
raise that level mid-flight — **never lower it**, and never turn missing
evidence into a `PASS`. Asking for more depth always works; what was computed
is a floor.

This governs how much work an agent does, never who routes it. Phase changes,
gate verdicts and detours remain the human's call.

**Reference material loads per phase.** Long catalogs — elicitation methods,
test-level frameworks, runtime references — live under `.claude/mosk/data/` and
are pulled in by the task that needs them, instead of riding in every prompt.

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

The full tree — including the per-spec internals (`spec-meta.yaml`, `stories/`,
`tests/`, `gate.yaml`) — lives in
[`project-rule-tmpl.md`](mosk/.claude/mosk/templates/project-rule-tmpl.md), which
`/mosk-boot` turns into `.claude/rules/project.md` in each consuming project.
That file is the contract; this section is the summary.

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

**Write the artifact for where it will live, not where it sits.** `copy` requires
the target to stay byte-identical to the source, so a promoted file with relative
links has to use paths that resolve at the **destination** — the depth is
different there, and fixing them after the copy makes the check fail.

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
branch: "feature/005-checkout-coupon"   # branch != pasta (ADR-0017)
created_at: "2026-04-22T14:30:00Z"
created_by: "Alice <alice@example.com>"
status: active             # active | archived
schema: 2
current_phase: specify     # specify | plan | tasks | implement | qa-gate | archived
last_phase_change: "2026-04-22T14:30:00Z"
```

Pipeline tasks (`plan`, `tasks`, `implement`, `qa-gate`, `archive`) confirm their
post-condition by following `.claude/mosk/data/phase-transition-contract.md`,
which reads the rule from **`.claude/mosk/pipeline.yaml`** — the single source for
phases, valid edges, required artifacts, the gate contract and promotion modes.
The task states the destination; nothing chooses the next phase for the user.

`index-docs` reads the current metadata to build the Active Specs table in
`docs/index.md`.

## Entry Point: `docs/index.md`

`docs/index.md` is the canonical first read for new contributors. It is auto-generated by the `index-docs` task and refreshed at every pipeline step:

- **Overview** — links to the 6 base domains (discovery, prd, architecture, ui, qa, project).
- **Active Specs** — table sourced from each `docs/specs/*/spec-meta.yaml`, newest first.
- **Archived Specs** — list from `docs/specs/archive/*`, most recently archived first.
- **Domain Contents** — alphabetical file listing per base folder, with titles and short descriptions.

Manual regeneration: `/mosk-dev index-docs`.

Preserve custom text between `<!-- custom -->` and `<!-- /custom -->` markers — regenerations leave them untouched.

## Escalation Policy

Pipeline agents (`po`, `sm`, `dev`, `qa`) detect signals they have no authority to resolve mid-flight — a missing ADR, an unspecified flow, a PRD conflict — and pause with a standard block:

> **Preciso de outro agente antes de seguir**
> - O que apareceu: *o que foi detectado*
> - Quem resolve: `/mosk-architect`
> - Prompt pronto: `/mosk-architect decidir o contrato do serviço de cupom`
> - Onde o resultado fica: `docs/specs/005-feature-checkout-coupon/architecture/`
> - Quando voltar: retomo o `implement` de onde parei.

Agents never invoke each other automatically. The user answers `pode ir`, `pula`, or something else. The agent that is called writes inside the active spec and ends by pointing back to whoever was interrupted.

**The block is written for the reader.** It is emitted in the project's communication language, in ordinary words, with a prompt that can be pasted as-is. `escalation`, `side-trip`, `guard`, `preamble` are the toolkit's internal vocabulary and never appear in output — the same rule that governs identifiers (see the output contract in `.claude/rules/project.md`).

**What an agent may delegate.** Agents coordinate through the runtime's own
subagents, under one rule: **execution delegates, routing does not.** A `dev` may
hand `[P]` units to other `dev` subagents, or ask `qa` to verify a result in a
clean context; a `qa` may ask `security` for a report. None of them may change a
phase, rule on a gate, or call a preamble agent — those are routing, and routing
is yours. Every delegation is declared before and reported after, and never nests
more than one level deep. See [ADR-0012](./docs/architecture/adr/adr-0012-route-decision-vs-phase-execution.md)
and [ADR-0016](./docs/architecture/adr/adr-0016-agent-invocation-protocol.md).

**Parallel work inside a phase.** When `tasks.md` marks two or more units `[P]`,
`implement` may run them as separate `mosk-dev` subagents. `[P]` means *different
files, no dependencies* — it is **honoured as written, never inferred**. Where it
is absent, work runs sequentially: the cost is asymmetric, since a wrongly
parallel pair writing the same file corrupts work that would have succeeded
serially.

### Running a spec unattended — `/mosk-orq`

Everything above pauses and waits for you. `/mosk-orq` is the one place that does
not: it takes a spec that already has `spec.md`, `plan.md` and `tasks.md`, opens
one `mosk-dev` **per user story in its own git worktree**, merges, has `mosk-qa`
and `mosk-security` verify the result, and repeats until the gate passes.

```bash
/mosk-orq 012          # entrega a spec 012 sozinho
```

- **Opt-in per run.** No configuration value turns this on. You consent each time,
  after a preflight that states what it will do alone and what will stop it —
  including how strong the verification is (no test suite = the gate's judgment
  only, and it says so).
- **It stops on doubt and on anything irreversible**: ambiguous acceptance
  criteria, a decision the plan does not cover, a business-rule gap, a merge
  conflict, the attempt cap, a flat score — and always before a migration, a
  deploy, a push, or waiving a gate.
- **Every autonomous decision is logged** to `docs/specs/{id}/run-log.md`,
  versioned. You did not watch it happen, so it has to be readable afterwards.
- **`archive` stays yours.** It promotes artifacts and closes the spec.

See [ADR-0019](./docs/architecture/adr/adr-0019-autonomous-delivery-runner.md).
It is the second scoped exception to the consultative rule — the first being the
bench's `loop-until-green` (ADR-0002) — and it rests on a different ground:
**consent**, not audience. That difference is why this runner, unlike the bench,
may never call a preamble agent on its own.

> MOSK once shipped a *different* `/mosk-orq`: a multi-terminal orchestrator over
> an external actuator, removed once both runtimes gained native subagents
> ([ADR-0018](./docs/architecture/adr/adr-0018-remove-orchestration-layer.md)).
> This one is not that one — it does what that one could not.

## Spec Types

Specs share a single pipeline; the type appears in both the branch and the
folder — but **in different positions, on purpose** (ADR-0017):

```
branch:  {type}/{###}-{short-name}     e.g.  feature/012-checkout-coupon
folder:  docs/specs/{###}-{type}-{short-name}
                                       e.g.  docs/specs/012-feature-checkout-coupon
```

The folder stays flat so that `docs/specs/` never grows a directory level per
type. The bridge between the two strings is the `branch` field in
`spec-meta.yaml` — never string equality. The old branch shape
(`012-feature-checkout-coupon`) is still resolved, but is not what
`create-new-feature.sh` creates.

Supported types: `feature`, `fix`, `hotfix`, `gmud`, `refactor`,
`experimental`, `extension`.

`extension` continues an already-archived spec without breaking archive
immutability, and requires `--extends <spec-id>` pointing at the parent.


## Migrating Existing Projects

Projects carrying older layouts (`docs/prd.md`, `docs/architecture.md`,
`docs/stories/`) are migrated in place by the **`migrate-install`** task. It is a
task and not a script because deciding whether a loose `docs/notes.md` is
discovery or architecture requires reading it — a script can only match
filenames, which is why the old one carried a fixed list that never covered the
project in front of it.

The migration:

- scaffolds the canonical `docs/` layout,
- moves monoliths to `docs/<domain>/raw.md` (ready for `shard-doc`),
- maps stories into `docs/specs/{id}/stories/` by epic-number heuristic (unmatched go to `_orphan-stories/` for manual review),
- creates retroactive `spec-meta.yaml` for each existing spec folder,
- rewrites `.claude/mosk/core-config.yaml` to the current schema (with a `.legacy` backup),
- seeds `docs/index.md`.

Nothing moves without your confirmation, and it never overwrites: when a
destination exists and differs, it reports the conflict and asks.

After the migration, residual files often remain — briefs at `docs/` root, a legacy `docs/epics/` folder, orphan stories without an epic match. Load the companion prompt `.claude/mosk/utils/post-migration-organize.md` in a Claude Code session to walk those resíduos into the canonical layout: it scans `docs/`, classifies each file by domain heuristics, allocates orphan stories/epics into existing or newly-created specs, and regenerates `docs/index.md` at the end. Nothing is moved without your confirmation.

The same task converts legacy `ctx-*` context skills into plain
`.claude/rules/*.md`: skills are for actions, project context lives in rules.

## Installed Structure

```text
your-project/
├── .claude/
│   ├── agents/           # the 12 agent definitions (source of truth)
│   ├── hooks/            # guard-spec-merge.sh — calls validate.sh on merge/PR
│   ├── mosk/
│   │   ├── pipeline.yaml   # single source for phases, edges, gate, promotions
│   │   ├── tasks/
│   │   ├── templates/
│   │   ├── checklists/
│   │   ├── data/           # contracts + reference material read by tasks
│   │   │   └── hallmark/   # vendored Hallmark (MIT) — see VENDOR.md
│   │   ├── scripts/        # five
│   │   └── core-config.yaml
│   ├── rules/            # generated by /mosk-boot — never touched by updates
│   └── skills/           # generated wrappers: /mosk-<name>
│       ├── mosk-analyst/    mosk-architect/   mosk-bench/
│       ├── mosk-boot/       mosk-deploy/      mosk-dev/
│       ├── mosk-handoff/    mosk-help/        mosk-pm/
│       ├── mosk-po/         mosk-qa/          mosk-security/
│       ├── mosk-sm/         mosk-suggestion/  mosk-ui-expert/
│       ├── mosk-update/     mosk-ux-expert/   mosk-write-skill/
│       └── tea-*/           # git/Gitea helpers
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

## Where a rule lives

MOSK is a product made of prompts, and the shape follows from that. Rules live in
**declarative YAML read by the agent**; shell covers only what an agent cannot do.
Three questions, in order — the first "yes" decides:

1. Must the fact be read by more than one consumer, or survive the session? → **YAML**
2. Is it judgement about content — drafting, evaluating, deciding case by case? → **prompt**
3. Does applying it need a race against another process on the remote, bulk
   generation of derived files, or execution outside an agent session? → **script**

That third list is closed, and widening it takes an ADR. The pipeline's own rule
— phases, valid edges, required artifacts, gate contract, promotions — lives in
`.claude/mosk/pipeline.yaml`. No task restates it in prose; they reference it.

See [ADR-0021](./docs/architecture/adr/adr-0021-declarative-rule-minimal-shell.md)
for why, including what it cost to learn.

## Maintenance Scripts

Five, under `.claude/mosk/scripts/`. The list is short by design.

- **`validate.sh`** — the single verifier. `ship-ready` (spec closed and
  mergeable), `prerequisites --for <phase>`, `install`, `docs-paths`,
  `single-source`, `tasks-sync`, `fixtures`, `all`. Exit 0 valid, 1 violations,
  2 usage error. No PyYAML, npm or pip.

  It has a **named caller**, which is the point: `.claude/hooks/guard-spec-merge.sh`
  intercepts PR and merge commands and runs `ship-ready`. A verification nobody
  invokes has the force of a rule written in prose — this toolkit shipped a spec
  to its default branch in `qa-gate` precisely because the verifier existed and
  was never called.

- **`create-new-feature.sh`** — reserves the spec number atomically on `origin`,
  creates branch and folder, writes `spec-meta.yaml`, commits and pushes, with
  renumbering and retry on collision. `--type`, `--short-name`, `--number`,
  `--extends`, `--no-push`, `--json`.

- **`sync.sh`** — materializes derived artifacts. `skills` (agents → wrappers),
  `codex` (`.codex/` symlinks + `AGENTS.md`), `all`, with `--clean`, `--dry-run`,
  `--force`. One direction only: the agent is the source, the skill is the
  generated wrapper. A skill's `description:` is declared by the agent on its
  first line (`<!-- skill-description: … -->`) — never edit a wrapper's
  description directly.

- **`reset-install.sh`** — reinstalls from scratch, deleting orphans that
  `degit --force` would leave behind forever. Used by `/mosk-update`. Never
  touches `.claude/rules/`, settings, `docs/`, `CLAUDE.md` or `AGENTS.md`. Always
  run the freshly downloaded copy — it deletes the directory it lives in.

- **`common.sh`** — shared library, never run directly. Resolves repo root,
  branch and spec directory, and holds the path containment that has to resolve
  symlinks against the real filesystem — which is why it stays in shell.

Two capabilities that used to be scripts are now tasks, because both are
judgement about content: **`migrate-install`** (brownfield migration) and
**`sync-hallmark`** (updating the vendored fork).

## Optional Environment Tools

MOSK runs inside Claude Code. For extra operational isolation, these pair well with it:

- `workz` — isolated worktrees
- `ai-jail` — filesystem confinement

## Inspiration

MOSK owes a real conceptual debt to:

- **BMAD** — role-driven collaboration with specialist agents.
- **SpecKit** — turning vague requests into explicit, ordered artifacts.

The product is MOSK-first: a lighter, synthesized toolkit built to disappear into real projects instead of standing apart from them.
