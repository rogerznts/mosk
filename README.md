# MOSK

MOSK is a Spec-Driven Development toolkit for Claude Code.

It is inspired by two ideas:

- **BMAD**: specialist agents with explicit roles
- **SpecKit**: a structured path from problem framing to executable work

MOSK is not a branded repackaging of either one. It is a lighter synthesis built for:

- direct natural-language activation
- lower token overhead
- a short default path
- fewer mandatory menus and rituals
- installability inside real projects through `.claude/`

## Core Idea

Every meaningful change should become explicit work:

1. clarify the change
2. shape the specification
3. create the implementation plan
4. generate ordered tasks
5. implement
6. review quality
7. archive the result

## Philosophy

MOSK keeps the parts that were useful in BMAD and SpecKit:

- role clarity
- structured artifacts
- explicit handoffs
- incremental delivery

MOSK intentionally removes or downplays the parts that add friction:

- heavy activation prompts
- mandatory multi-step menus
- bloated orchestration layers
- optional workflow packs in the default install
- legacy bundle branding inside the shipped toolkit

## Flow

A single pipeline. An optional **preamble** runs first whenever the base of the project (or the feature) is not yet grounded.

```mermaid
flowchart TD
    A[Request] -->|base missing/incomplete?| PRE
    A -->|base in place| F

    subgraph PRE [Preamble — optional]
        B[/mosk-analyst<br/>Discovery/] -. if vague .-> C[/mosk-pm<br/>PRD or PRD-delta/]
        C -. if architecture-heavy .-> E[/mosk-architect]
        C -. if UX-heavy .-> D[/mosk-ux-expert]
        C -. if design-heavy .-> W[/mosk-ui-expert]
    end

    PRE --> F[/mosk-po<br/>full-spec: specify → plan → tasks/]
    F --> G[/mosk-sm<br/>readiness/]
    G --> H[/mosk-dev implement/]
    H --> I[/mosk-qa qa-gate/]
    I -->|CONCERNS/FAIL| H
    I -->|PASS| J[/mosk-dev archive/]
```

Daily defaults:

- skip the preamble when the project base (PRD, architecture, UI) already supports the request; jump straight to `full-spec`.
- use the preamble when the base is missing/stale. Only call the agents that materially help this change. Preamble artifacts may be written at the **base** (`docs/<domain>/`) when canonical, or **per-spec** (`docs/specs/{id}/<domain>/`) when they are specific to this change.
- compact path: `full-spec → implement → qa-gate → archive`
- granular path: `specify → plan → tasks → implement → qa-gate → archive`
- optional helpers: `clarify`, `analyze`, `checklist`

Pipeline agents (`po`, `sm`, `dev`, `qa`) detect when a preamble agent is needed mid-flight and suggest a handoff — they never invoke another agent automatically. See **Escalation Policy** below.

`full-spec` stops at `tasks`. Implementation remains separate with `mosk-dev`.

## Document Organization

MOSK v2 uses two mirrored layers: the **base** (project-wide truth) and **per-spec** (scope of a single feature/fix).

```
docs/
├── index.md            # auto-generated entry point (task: index-docs)
├── discovery/          # mosk-analyst
├── prd/                # mosk-pm (sharded: index.md + sections)
├── architecture/       # mosk-architect (+ adr/)
├── ui/                 # mosk-ux-expert (flows/) + mosk-ui-expert (design-system)
├── qa/gates/           # mosk-qa
└── specs/
    ├── {###}-{type}-{name}/
    │   ├── spec.md, plan.md, tasks.md
    │   ├── spec-meta.yaml       # number, branch, status, phase
    │   ├── prd-delta.md         # optional PRD change
    │   ├── discovery/ architecture/ ui/   # optional feature-scoped
    │   ├── stories/ tests/ gate.yaml
    └── archive/                  # completed specs
```

**Promotion.** Artifacts born inside a spec that should become canonical carry a `promote:` front-matter. At archive time, `mosk-dev archive` applies them:

| `promote_mode` | Behavior |
|---|---|
| `copy` | Copy the file to the target path. Asks before overwrite. |
| `append` | Append body to the target file. |
| `manual` | Print the file and suggested destination; user applies by hand (default for `prd-delta.md`). |

Without `promote:`, the artifact freezes inside the archived spec.

**`shard-doc`** is an optional transformation: when `mosk-pm` writes a monolith to `docs/prd/raw.md` (or the architect to `docs/architecture/raw.md`), `shard-doc` splits it into `index.md` + section files in the same folder.

## Escalation Policy

Pipeline agents emit an **Escalation suggested** block when they detect a signal that requires a preamble agent (architecture ambiguity, missing flow, PRD gap, etc.) and wait for user confirmation. They never invoke another agent autonomously. The user decides: `go`, `escalate`, `skip`, or an alternative.

## Spec Numbering and Concurrency

Spec numbers are globally unique, three-digit, zero-padded (`001`…). When multiple developers create specs in parallel, `create-new-feature.sh` pushes atomically and retries with a new number if the push is rejected (up to 3 attempts). Each spec carries a `spec-meta.yaml` with number, branch, status, and current phase — updated by pipeline tasks as the spec progresses.

## Migrating Existing Projects

Projects installed from earlier versions (with `docs/prd.md`, `docs/architecture.md`, `docs/stories/`) can be migrated in place:

```bash
bash .claude/mosk/scripts/migrate-docs-structure.sh --dry-run   # preview
bash .claude/mosk/scripts/migrate-docs-structure.sh              # apply
```

The migration:

- scaffolds the canonical `docs/` layout,
- moves monoliths to `docs/<domain>/raw.md` (ready for `shard-doc`),
- maps stories to `docs/specs/{id}/stories/` by epic-number heuristic (unmatched go to `_orphan-stories/`),
- creates retroactive `spec-meta.yaml` for each existing spec,
- rewrites `.claude/mosk/core-config.yaml` to the v2 schema (with a `.legacy` backup),
- seeds `docs/index.md`.

The script is idempotent: running it again on an up-to-date project is a no-op.

## Fast Path

Use the agents directly with natural language:

```
/mosk-po full-spec checkout com cupom
```

```
/mosk-dev implementar a spec 012
```

```
/mosk-qa revisar a spec 012
```

Default happy path:

```
/mosk-po full-spec
```
```
/mosk-dev implement
```
```
/mosk-qa qa-gate
```
```
/mosk-dev archive
```

## Skills vs Agents

MOSK agents can be invoked in two ways inside Claude Code:

### Skill (slash command)

Runs **inside the current conversation**, sharing the full chat context. This is the default and recommended way.

```
/mosk-dev implement a spec 012
```

### Agent (subagent)

Runs as a **separate process** with its own context. Does not see the current conversation history. Useful for parallel or isolated work. Claude Code spawns agents internally when needed.

| | Skill | Agent |
|---|---|---|
| Shares conversation context | yes | no |
| Parallel execution | no | yes |
| Interactive with the user | yes | no |
| Isolates heavy output | no | yes |

**For daily use, prefer skills (slash commands).**

## Agents

| Skill | Responsibility |
|---|---|
| `/mosk-analyst` | discovery, research, brainstorming |
| `/mosk-pm` | PRD, product scope, success criteria |
| `/mosk-ux-expert` | user flows, UX specs, front-end behavior |
| `/mosk-architect` | architecture, APIs, integrations |
| `/mosk-po` | specs, planning, task generation |
| `/mosk-sm` | readiness, sequencing, story hygiene |
| `/mosk-dev` | implementation, fixes, archive |
| `/mosk-qa` | quality gates, test strategy, review |
| `/mosk-ui-expert` | premium interfaces, redesign, visual styles, design systems |

## Spec Types

The same pipeline supports:

- `feature`
- `fix`
- `hotfix`
- `gmud`
- `refactor`
- `experimental`

Folder and branch pattern:

```text
{###}-{type}-{short-name}
```

Example:

```text
012-feature-checkout-coupon
```

## Installation

Install MOSK into the current project:

```bash
npx degit rogerznts/mosk/mosk .
```

Force (overwrite existing files):

```bash
npx degit rogerznts/mosk/mosk . --force
```

One-command install for Codex users:

```bash
npx degit rogerznts/mosk/mosk . && bash .claude/mosk/scripts/link-codex-skills.sh
```

Force overwrite and recreate existing symlinks:

```bash
npx degit rogerznts/mosk/mosk . --force && bash .claude/mosk/scripts/link-codex-skills.sh --force
```

Restart Claude Code after install so the new skills are loaded.

If you also use Codex, create symlinks from the installed `.claude/skills/` into the project's `.codex/skills/` directory:

```bash
bash .claude/mosk/scripts/link-codex-skills.sh
```

Force recreation of existing symlinks:

```bash
bash .claude/mosk/scripts/link-codex-skills.sh --force
```

This step is optional. `degit` only copies files; it does not run post-install scripts automatically.

### Syncing Agents and Skills

When you add or remove agents in `.claude/mosk/agents/`, run the sync script to regenerate skill wrappers and Claude Code agent files:

```bash
bash .claude/mosk/scripts/sync-agents-skills.sh
```

Directions:

```bash
# Generate skill wrappers from agents
bash .claude/mosk/scripts/sync-agents-skills.sh agents-to-skills

# Generate Claude Code agents from skills
bash .claude/mosk/scripts/sync-agents-skills.sh skills-to-agents

# Both directions (default)
bash .claude/mosk/scripts/sync-agents-skills.sh both

# Preview without writing
bash .claude/mosk/scripts/sync-agents-skills.sh --dry-run

# Remove orphan skills/agents whose source agent was deleted
bash .claude/mosk/scripts/sync-agents-skills.sh --clean

# Preview orphan removal
bash .claude/mosk/scripts/sync-agents-skills.sh --clean --dry-run
```

By default the script only **creates or updates** — it never deletes files.
Use `--clean` to also remove orphan skills and CC agents whose source agent no longer exists.

### Migrating Legacy `ctx-*` Skills to Rules

Older MOSK installs carried project context inside `.claude/skills/ctx-*/SKILL.md`.
The current model keeps context as plain markdown in `.claude/rules/*.md` and
reserves skills for actions only. To convert an existing install, run:

```bash
bash .claude/mosk/scripts/migrate-ctx-skills-to-rules.sh
```

For each `ctx-<name>` skill found, the script writes `.claude/rules/<name>.md`
with the SKILL.md body stripped of its YAML frontmatter, rewrites a legacy
`# ctx-<name>` H1 into a clean title-cased heading (e.g. `# Project`,
`# Coding Standards`), and deletes the original `ctx-*` skill directory.
Any `.codex/skills/ctx-*` symlink pointing at a removed directory is cleaned up.

Options:

```bash
# Preview without writing or deleting
bash .claude/mosk/scripts/migrate-ctx-skills-to-rules.sh --dry-run

# Convert but keep the original ctx-* skill directories
bash .claude/mosk/scripts/migrate-ctx-skills-to-rules.sh --keep-old

# Show usage
bash .claude/mosk/scripts/migrate-ctx-skills-to-rules.sh --help
```

Behavior notes:

- Existing `.claude/rules/<name>.md` files are never overwritten — the
  corresponding `ctx-*` skill is skipped.
- Without `--keep-old`, the legacy skill directories are removed after a
  successful conversion (default).
- The script is idempotent: running it again after a full migration is a
  no-op.

After migrating, refresh the Codex symlinks so `.codex/rules/` picks up the
new files:

```bash
bash .claude/mosk/scripts/link-codex-skills.sh
```

## Installed Structure

```text
your-project/
├── .claude/
│   ├── mosk/
│   │   ├── agents/
│   │   ├── tasks/
│   │   ├── templates/
│   │   ├── scripts/
│   │   ├── core-config.yaml
│   │   └── constitution.md
│   └── skills/
│       ├── mosk-analyst/
│       ├── mosk-architect/
│       ├── mosk-boot/
│       ├── mosk-dev/
│       ├── mosk-help/
│       ├── mosk-pm/
│       ├── mosk-po/
│       ├── mosk-qa/
│       ├── mosk-sm/
│       ├── mosk-ux-expert/
│       └── mosk-ui-expert/
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

## Commands

The preferred command style is natural language via slash commands.

### SpecKit (mosk-po)

```
/mosk-po full-spec login social para clientes B2B
```

```
/mosk-po specify login social para clientes B2B
```

```
/mosk-po plan a spec atual
```

```
/mosk-po tasks para a spec atual
```

### Implementation (mosk-dev)

```
/mosk-dev implement a spec 012
```

```
/mosk-dev archive a spec 012
```

### UI (mosk-ui-expert)

```
/mosk-ui-expert landing page para produto SaaS de analytics
```

```
/mosk-ui-expert redesign da home atual
```

```
/mosk-ui-expert brutalist dashboard de monitoramento
```

### Quality (mosk-qa)

```
/mosk-qa qa-gate a spec 012
```

### Command Intent

| Command | What it does |
|---|---|
| `full-spec` | runs `specify -> plan -> tasks` in one pass |
| `specify` | creates or updates only `spec.md` |
| `plan` | creates or updates only `plan.md` |
| `tasks` | creates or updates only `tasks.md` |
| `implement` | stays with `mosk-dev` |
| `qa-gate` | stays with `mosk-qa` |
| `archive` | stays with `mosk-dev` |

Advanced star-prefixed commands can still exist as compatibility shortcuts, but they are no longer the primary UX.

## Bootstrapping Existing Projects

For an existing repository, run:

```text
/mosk-boot
```

The boot workflow generates a compact rule pack in `.claude/rules/` by default:

- `.claude/rules/project.md`
- `.claude/rules/frontend.md` only when frontend code exists

## What Changed From The Legacy Bundle

The current MOSK template already removes a large amount of optional legacy structure:

- redundant agent wrappers
- team bundles in the default install
- workflow YAML packs
- KB mode and legacy knowledge-base routing
- legacy guidance packs outside the core path

The remaining files may still show traces of the original inspiration in comments or template lineage, but the shipped product is now positioned and maintained as MOSK.

## Inspiration

MOSK owes a real conceptual debt to:

- BMAD, for role-driven collaboration
- SpecKit, for turning vague requests into explicit artifacts

The goal is to preserve those strengths while making the toolkit smaller, sharper, and cheaper to run.

## UI Expert and the Taste System

The `/mosk-ui-expert` agent (Tiago) is built on top of the **[taste](https://github.com/Leonxlnx/taste-skill)** design engineering system, a set of opinionated rules that override default LLM biases toward generic, template-like UI output. It owns the visual/acabamento layer of `docs/ui/` (design system, styles, premium components); the UX Expert (Salete, `/mosk-ux-expert`) owns the structural layer (user flows, wireframes, front-end specs).

The taste rules are embedded directly into the agent and its tasks rather than existing as standalone skills. This means the agent carries its own design intelligence without relying on skill discovery for its core capabilities.

### Available styles

| Command | Style |
|---|---|
| `/mosk-ui-expert` | shows menu with all options |
| `/mosk-ui-expert brutalist` | Swiss typography, terminal aesthetics, rigid grids |
| `/mosk-ui-expert minimalist` | editorial, warm monochrome, flat bento grids |
| `/mosk-ui-expert soft` | $150k agency feel, haptic depth, cinematic motion |
| `/mosk-ui-expert redesign` | audit and upgrade an existing interface |
| `/mosk-ui-expert stitch` | generate a DESIGN.md for Google Stitch |
| `/mosk-ui-expert output completo` | enforce full code generation, no truncation |

### What taste enforces

- strict anti-AI-pattern rules (no Inter font, no neon glows, no 3-card grids, no generic names)
- metric-based design dials (variance, motion intensity, visual density)
- hardware-accelerated CSS animation constraints
- mandatory interaction states (loading, empty, error, active)
- responsive collapse guarantees
- dependency verification before any import

The agent still loads project rules from `.claude/rules/*.md` normally through the standard MOSK context loading protocol.

## Optional Environment Tools

MOSK itself runs inside Claude Code. If you want extra operational isolation, these still pair well with it:

- `workz` for isolated worktrees
- `ai-jail` for filesystem confinement
