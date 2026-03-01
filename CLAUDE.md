# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Repository Is

**MOSK** (Mad Open Spec Kit) is a **master template repository** for Spec-Driven Development (SDD). It is not a compiled application — it is a collection of Markdown, YAML, and Bash files that get installed into other projects via `npx degit rogerznts/mosk/mosk .`. The installed toolkit activates as Claude Code skills (slash commands) for structured, specification-driven development workflows.

## Installation

```bash
# Install MOSK into a target project
npx degit rogerznts/mosk/mosk .
```

There is no build step, test suite, or linter. Validation happens through Claude Code skill execution in the projects that use MOSK.

## Repository Structure

```
mosk/                              # The installable template (ships to target projects)
├── .claude/
│   ├── mosk/                      # Core flat resources (no nesting)
│   │   ├── agents/                # 10 agent definition files
│   │   │   ├── analyst.md         # Maria — discovery, brief, research
│   │   │   ├── architect.md       # Vinicius — architecture, stack, APIs
│   │   │   ├── pm.md              # João — PRD, product, spec-constitution
│   │   │   ├── po.md              # Sara — backlog, stories, AC, SpecKit pipeline
│   │   │   ├── sm.md              # Roberto — dev-readiness, agile
│   │   │   ├── dev.md             # Jaime — implementation, Chore Mode
│   │   │   ├── qa.md              # Joaquim — testing, quality gates, NFR
│   │   │   ├── ux-expert.md       # Salete — user flows, wireframes, front-end specs
│   │   │   ├── bmad-master.md     # Mestre — universal task executor
│   │   │   └── bmad-orchestrator.md # Maestro — workflow coordinator
│   │   ├── tasks/                 # Executable workflow files
│   │   │   ├── spec-constitution.md
│   │   │   ├── spec-specify.md
│   │   │   ├── spec-clarify.md
│   │   │   ├── spec-plan.md
│   │   │   ├── spec-analyze.md
│   │   │   ├── spec-checklist.md
│   │   │   ├── spec-tasks.md
│   │   │   ├── spec-implement.md
│   │   │   ├── chore-proposal.md
│   │   │   ├── chore-apply.md
│   │   │   ├── chore-archive.md
│   │   │   └── develop-story.md   # (and other BMAD tasks)
│   │   ├── templates/             # YAML-driven document scaffolds
│   │   ├── scripts/               # Support scripts
│   │   ├── constitution.md        # Project principles (created by spec-constitution)
│   │   └── core-config.yaml       # Central configuration
│   └── skills/                    # Skill delegation files (become slash commands)
│       ├── mosk-analyst/SKILL.md
│       ├── mosk-architect/SKILL.md
│       ├── mosk-dev/SKILL.md
│       ├── mosk-master/SKILL.md
│       ├── mosk-orchestrator/SKILL.md
│       ├── mosk-pm/SKILL.md
│       ├── mosk-po/SKILL.md
│       ├── mosk-qa/SKILL.md
│       ├── mosk-sm/SKILL.md
│       ├── mosk-ux-expert/SKILL.md
│       └── mosk-help/SKILL.md
└── docs/                          # Created by workflows in consuming projects
    ├── specs/                     # Feature specs: docs/specs/{###}-{name}/
    └── changes/                   # Quick changes: docs/changes/{id}/
```

## Three Core Components

### BMAD Core (agents in `.claude/mosk/agents/`)

Ten specialized AI agent personas with Brazilian names. Each agent is a fully self-contained YAML + Markdown file. Agents activate from `.claude/skills/mosk-{agent}/SKILL.md` skill delegations.

**Agent activation pattern**: skill file delegates to `../../mosk/agents/{agent}.md` → agent reads `core-config.yaml` → adopts persona, greets user by Brazilian name, halts and awaits instructions → loads tasks/templates **only on demand**.

### SpecKit (tasks in `.claude/mosk/tasks/spec-*.md`)

Transforms natural language descriptions into executable implementation plans.

**Owned by PM (João)** — strategic foundation (run ONCE per project):
```
*spec-constitution  → derive project principles from PRD + architecture
```

**Owned by PO (Sara)** — full spec pipeline per feature:
```
*spec-specify       → create spec.md from description
*spec-clarify       → resolve ambiguities (optional)
*spec-plan          → generate data-model, contracts, research
*spec-analyze       → cross-artifact consistency check (optional)
*spec-checklist     → quality checklist by domain (optional)
*spec-tasks         → generate ordered tasks.md
```

**Owned by Dev (Jaime)** — execution phase only:
```
*spec-implement     → execute all tasks in tasks.md
```

Specifications live in consuming projects at `docs/specs/{###}-{short-name}/` with: `spec.md`, `plan.md`, `tasks.md`, and optional `data-model.md`, `research.md`, `contracts/`.

### Chore Mode (tasks in `.claude/mosk/tasks/chore-*.md`)

Lightweight workflow for maintenance, bugfixes, and GMUDs. **Owned by Dev (Jaime)**:
```
*chore-proposal {id}  → create docs/changes/{id}/proposal.md + tasks.md
*chore-apply {id}     → implement the approved change
*chore-archive {id}   → close and archive
```

## Skill File Format

Every file in `.claude/skills/{name}/SKILL.md` follows this pattern:

```yaml
---
name: mosk-{agent}
description: Activate the {Agent} agent persona for...
---

CRITICAL: Read and fully execute the agent definition at `../../mosk/agents/{agent}.md`.
That file is the single source of truth — it contains the full persona, commands, dependencies,
and activation instructions. Follow ALL instructions defined there exactly.
```

The relative path `../../mosk/agents/` resolves correctly from any folder inside `skills/`.

## Key Configuration

`core-config.yaml` controls project-level settings including document locations, sharding for large PRDs/architecture docs, and which files agents auto-load for context (`devLoadAlwaysFiles`).

## Agent/Task Architecture

- **Agents** (`.claude/mosk/agents/*.md`): Self-contained persona + commands + dependencies. Each declares which tasks and templates it uses.
- **Tasks** (`.claude/mosk/tasks/*.md`): Executable workflows. When `elicit: true`, the task requires interactive user input. Task instructions override any conflicting general instructions. Path resolution: agents reference tasks as `../tasks/{name}` relative to the `agents/` folder, landing in `mosk/`.
- **Templates** (`.claude/mosk/templates/`): YAML-driven document scaffolds with section conditions and elicitation rules.

## Naming Conventions

- **Skills**: `mosk-{agent}` — no `ag` prefix (e.g., `mosk-pm`, `mosk-dev`, `mosk-ux-expert`)
- **Agent Brazilian names**: Maria, Vinicius, João, Sara, Roberto, Jaime, Joaquim, Salete, Mestre, Maestro
- **Specification folders**: `{###}-{short-name}` (e.g., `001-user-auth`)
- **Change folders**: `{id}` under `docs/changes/`
- **Agent IDs**: match filename without extension (e.g., `analyst.md` → id `analyst`)
- **Task files**: named by workflow action (e.g., `spec-specify.md`, `chore-proposal.md`)

## Agent Responsibilities

| Agent | Skill | SpecKit | Chore |
|---|---|---|---|
| João (pm) | `/mosk-pm` | `spec-constitution` only (run once) | — |
| Sara (po) | `/mosk-po` | Owns full spec pipeline (specify→tasks) + stories with AC | — |
| Roberto (sm) | `/mosk-sm` | Ensures dev-readiness of stories | — |
| Jaime (dev) | `/mosk-dev` | `spec-implement` only | Owns all chore commands |

## What Gets Installed in Target Projects

After `npx degit`, the consuming project gains:
- `.claude/mosk/` — agents, tasks, templates, scripts, core-config.yaml
- `.claude/skills/` — 11 skill delegation files (`mosk-analyst`, `mosk-pm`, `mosk-help`, etc.)

The `docs/` directory (`specs/`, `changes/`) is created by the workflows themselves as users run the commands.
