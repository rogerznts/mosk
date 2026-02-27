# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Repository Is

**MOSK** (Mad Open Spec Kit) is a **master template repository** for Spec-Driven Development (SDD). It is not a compiled application — it is a collection of Markdown, YAML, and Bash files that get installed into other projects via `npx degit rogerznts/mosk/mosk .`. The installed toolkit enables Cursor IDE slash commands for structured, specification-driven development workflows.

## Installation

```bash
# Install MOSK into a target project
npx degit rogerznts/mosk/mosk .
```

There is no build step, test suite, or linter. Validation happens through Cursor IDE command execution in the projects that use MOSK.

## Repository Structure

```
mosk/                          # The installable template (this ships to target projects)
├── .cursor/commands/          # 21 Cursor IDE slash commands (Markdown + YAML frontmatter)
│   ├── mosk-ag-*.md          # 10 BMAD Core agent commands
│   ├── mosk-spec-*.md        # 8 SpecKit commands
│   └── mosk-chore-*.md       # 3 Chore Mode commands
└── toolkit/                   # Core resources installed alongside commands
    ├── .bmad-core/            # BMAD Core framework (agents, tasks, templates, workflows)
    └── .specify/              # SpecKit framework (templates, scripts, memory)
```

## Three Core Components

### BMAD Core (`toolkit/.bmad-core/`)
Ten specialized AI agent personas for discovery and ideation: analyst, architect, dev, pm, po, qa, sm, ux-expert, orchestrator, master. Each agent is defined as a fully self-contained YAML + Markdown file in `toolkit/.bmad-core/agents/`. Agents activate from `.cursor/commands/mosk-ag-*.md` commands.

**Agent activation pattern**: agents read `core-config.yaml`, adopt their persona, greet the user, then halt and await instructions. They load task files and templates only on demand — nothing is pre-loaded except the config.

### SpecKit (`toolkit/.specify/`)
Transforms specifications into executable implementation plans. The workflow is:
**Specify → Clarify → Plan → Analyze → Checklist → Tasks → Implement**

Specifications are stored in the consuming project at `docs/specs/{###}-{short-name}/` with: `spec.md`, `plan.md`, `tasks.md`, and optional `data-model.md`, `research.md`, `contracts/`.

### Chore Mode (`toolkit/changes/`)
Lightweight workflow for maintenance, bugfixes, and small operational changes (GMUDs). Uses three commands: proposal → apply → archive.

## Command File Format

Every file in `.cursor/commands/` follows this pattern:

```yaml
---
name: /mosk-command-name
id: command-id
category: Category Name
description: One-line description
---
[Markdown instructions for the command's execution behavior]
```

## Key Configuration

`toolkit/.bmad-core/core-config.yaml` controls project-level settings including document locations, sharding for large PRDs/architecture docs, and which files agents auto-load for context (`devLoadAlwaysFiles`). The `slashPrefix` key controls how commands appear in Cursor.

## Agent/Task Architecture

- **Agents** (`toolkit/.bmad-core/agents/*.md`): Self-contained persona + command + dependency definitions. Each declares which tasks and templates it uses.
- **Tasks** (`toolkit/.bmad-core/tasks/*.md`): Executable workflows. When `elicit: true`, the task requires interactive user input in a specific format. Task instructions override any conflicting general instructions.
- **Templates** (`toolkit/.bmad-core/templates/`, `toolkit/.specify/templates/`): YAML-driven document scaffolds with section conditions and elicitation rules.
- **Workflows** (`toolkit/.bmad-core/workflows/`): Six pre-configured agent sequences for greenfield and brownfield projects.

## Naming Conventions

- **Slash commands**: `/mosk-{category}-{action}` (e.g., `/mosk-spec-specify`, `/mosk-ag-analyst`, `/mosk-chore-proposal`)
- **Specification branches/folders**: `{###}-{short-name}` (e.g., `001-user-auth`)
- **Agent IDs**: Match the agent filename without extension (e.g., `analyst.md` → id `analyst`)
- **Task files**: Named by task type (e.g., `create-doc.md`, `execute-checklist.md`)

## What Gets Installed in Target Projects

After `npx degit`, the consuming project gains:
- `.cursor/commands/` — all 21 slash commands
- `toolkit/.bmad-core/` — agents, tasks, templates, checklists, workflows
- `toolkit/.specify/` — SpecKit templates and scripts
- `toolkit/changes/` — Chore Mode storage directory

The `docs/` directory (specs, prd, architecture) is created by the commands themselves as users run the workflow.
