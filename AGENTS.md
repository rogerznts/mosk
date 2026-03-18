# Repository Guidelines

## Project Structure & Module Organization

The installable product lives in `mosk/`. Treat `mosk/.claude/` as the source of truth for the shipped toolkit. The root `.claude/` directory is only this repository's local authoring environment and is ignored for distribution work.

- `mosk/.claude/mosk/agents/`: agent definitions such as `dev.md`, `po.md`, `qa.md`
- `mosk/.claude/mosk/tasks/`: executable workflow/task prompts like `specify.md`, `plan.md`, `implement.md`
- `mosk/.claude/mosk/templates/`: reusable spec, plan, QA, and architecture templates
- `mosk/.claude/mosk/scripts/`: Bash helpers for setup and branch/spec creation
- `mosk/.claude/skills/`: slash-command wrappers, one folder per skill with `SKILL.md`
- `README.md` and `CLAUDE.md`: product usage and repository maintenance notes

## Build, Test, and Development Commands

This repository has no compiled app or package-based build.

- `npx degit rogerznts/mosk/mosk .` installs the template into another project
- `npx degit rogerznts/mosk/mosk . --force` overwrites an existing install during verification
- `bash -n mosk/.claude/mosk/scripts/*.sh` checks Bash syntax for shipped scripts
- `git diff --stat` is the fastest sanity check for accidental broad template edits

When validating changes, review the installed file paths and ensure docs still match the shipped structure and slash-command flow.

## Coding Style & Naming Conventions

Keep Markdown concise, instructional, and product-facing: MOSK terminology first, BMAD/SpecKit only as lineage when needed. Use kebab-case filenames for tasks, templates, and scripts (for example, `qa-gate.md`, `create-new-feature.sh`). Keep skill folders aligned to the slash command name, with frontmatter such as `name: mosk-dev`.

Match the existing file style:

- Markdown: short sections and direct bullets
- YAML: 2-space indentation
- Bash: `#!/usr/bin/env bash`, `set -e`, clear option parsing

## Testing Guidelines

There is no automated test suite for the template itself. Validate by checking documentation consistency, reviewing prompt/task wiring, and syntax-checking any changed shell scripts. If you change a workflow, confirm the referenced paths still exist under `mosk/.claude/mosk/`.

## Commit & Pull Request Guidelines

Recent history follows Conventional Commit style: `feat:`, `fix:`, `docs:`, `refactor:`, with optional scopes such as `feat(skills): ...`. Keep commits focused on one workflow or documentation change.

Pull requests should explain the contributor-facing impact, list affected paths under `mosk/`, and call out any README or installation changes. Include example slash commands when behavior changes.
