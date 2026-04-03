# CLAUDE.md

This repository contains the MOSK template that is installed into other projects via:

```bash
npx degit rogerznts/mosk/mosk .
```

## Important Workspace Note

- The product source of truth is `mosk/`.
- The root `.claude/` directory in this repository is only the local execution environment for working on MOSK itself.
- When changing the installable toolkit, edit files under `mosk/`.

## Repository Shape

```text
mosk/
├── .claude/
│   ├── mosk/
│   │   ├── agents/
│   │   ├── tasks/
│   │   ├── templates/
│   │   ├── scripts/
│   │   └── core-config.yaml
│   └── skills/
```

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

`clarify`, `analyze`, and `checklist` are optional support tasks.

## Agent Design

Agents live in `mosk/.claude/mosk/agents/`.

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

## Tasks

Tasks live in `mosk/.claude/mosk/tasks/`.

When editing tasks:

- optimize for the happy path first
- keep outputs implementation-oriented
- avoid mandatory elicitation unless the missing answer materially changes the result
- keep optional artifacts optional

## Validation

There is no compiled app or automated test suite for the template itself.

Validation here is mainly:

- reading the installed file structure
- checking prompt and workflow consistency
- ensuring documentation matches the shipped template
