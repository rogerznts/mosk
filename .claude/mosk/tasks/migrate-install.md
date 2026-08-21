---
description: "Migra uma instalação MOSK legada para o layout atual — docs/ v2 e rules"
---

# Task: Migrate legacy install

## Goal

Bring a brownfield project up to the current MOSK layout: the canonical `docs/`
tree and `.claude/rules/`. Replaces the former `migrate-docs-structure.sh` and
`migrate-ctx-skills-to-rules.sh`.

This is a task and not a script because migration is judgement about content
(ADR-0021 §4, question 2). Deciding whether a loose `docs/notes.md` is
discovery, PRD or architecture requires reading it; a script can only match
filenames, which is why the old one carried a hardcoded list that never covered
the project in front of it.

## Guardrails

- **Never overwrite.** Create only what is missing. When a destination exists
  and differs, report the conflict and ask.
- **Never delete the original** without saying so. Default is to move; if the
  user wants both, copy and say where each one lives.
- Show the full plan before touching anything, and get a go-ahead. This is the
  one migration where a wrong guess is expensive to undo.

## Workflow

### 1. Survey

Read what exists before proposing anything:

- `docs/` — every file and folder, including loose files at the root
- `.claude/skills/ctx-*` — legacy context skills, if any
- `.claude/rules/` — what is already there
- `.claude/mosk/core-config.yaml` — schema version

Report the survey as a table: path, what it looks like, where it would go.

### 2. Scaffold the canonical tree

Create only what is missing, each with a `README.md` explaining which agent
writes there:

```
docs/{discovery,prd,architecture/adr,ui/flows,qa/gates,specs}/
```

### 3. Place the existing content

For each artifact found, decide by **reading it**, not by filename:

| What it is | Where it goes |
|---|---|
| research, interviews, brainstorming, market analysis | `docs/discovery/` |
| product scope, requirements, epics | `docs/prd/` |
| system design, stack, integrations, decisions | `docs/architecture/` (ADRs under `adr/`) |
| flows, wireframes, front-end spec, design system | `docs/ui/` |
| test strategy, gates, NFR assessments | `docs/qa/` |
| anything scoped to one pending change | `docs/specs/{id}/<domain>/` |

A monolithic `prd.md` or `architecture.md` may be sharded — but only if it is
genuinely several documents stapled together. Do not shard for the sake of it.

A global `docs/stories/` moves into the per-spec `docs/specs/{id}/stories/`
that owns each story. Stories without an owning spec are reported, not guessed.

### 4. Retrofit `spec-meta.yaml`

Every folder under `docs/specs/` needs metadata. Derive number, type and slug
from the folder name; derive `branch` from git when a matching branch exists,
otherwise ask. Set `current_phase` to what the artifacts on disk actually show
(a spec with `tasks.md` and no `gate.yaml` is not in `qa-gate`), and record the
history with `origin: migration` — see `../data/phase-transition-contract.md`
and `../pipeline.yaml` for what the metadata must satisfy.

Archived specs get `status: archived`, `current_phase: archived` and
`archived_at` together — never one without the others.

### 5. Convert legacy `ctx-*` skills into rules

For each `.claude/skills/ctx-<name>/SKILL.md`, write the durable project
context into `.claude/rules/<name>.md` as plain markdown (no front-matter), then
remove the old skill directory. Skills are for actions; project context lives in
rules.

Merge rather than multiply: three `ctx-*` skills describing the same stack
become one `project.md`, not three files.

### 6. Update `core-config.yaml`

Bring it to the current schema, preserving every project-specific value.

### 7. Regenerate the index and verify

Run `../tasks/index-docs.md`, then:

```bash
bash .claude/mosk/scripts/validate.sh install
bash .claude/mosk/scripts/validate.sh docs-paths
```

Report what moved, what was left alone and why, and anything that needs a human
decision.

## Rules

- Ask once, in one grouped round, about everything ambiguous. Do not interrogate
  file by file.
- When unsure where something belongs, leave it and report it. A misfiled
  document is worse than an unfiled one.
- Never invent a `spec-meta.yaml` phase that the artifacts do not support.
