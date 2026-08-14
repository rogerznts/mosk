# MOSK Toolkit — Project Rules

> This is the **master template repository** for the MOSK toolkit. It is
> not a consuming project: it ships the framework that other projects
> install via `npx degit rogerznts/mosk/mosk .`.

## System Purpose

MOSK is a Markdown/YAML/Bash toolkit that adds opinionated agent personas,
SpecKit-style pipelines, and document scaffolding to a project's
`.claude/` and `docs/` layout. This repository is where the toolkit
itself is authored, evolved, and released. Consuming projects pull a
snapshot of `mosk/` via degit; they never depend on this repo at
runtime.

## Stack

- Language / runtime: Markdown (.md), YAML (.yaml), Bash (.sh) — no
  compiled application.
- Framework(s): none. The "framework" is the prompt/task/template
  contract that MOSK itself defines.
- Datastore(s): none.
- Package manager: none (no Node/Python/etc. manifest). Distribution is
  `npx degit` against the GitHub repo.
- Build / dev commands: none. Edits are file edits; helper scripts in
  `mosk/.claude/mosk/scripts/` are run manually.
- Test framework: none. Validation is manual — read the installed
  structure, check prompt/workflow consistency, verify docs match the
  shipped template.

## Architecture

**Two-tier repo** with a strict source-of-truth boundary:

| Path                  | Role                                                                                     |
|-----------------------|------------------------------------------------------------------------------------------|
| `mosk/`               | **Installable template** (source of truth). Everything here ships to consumer projects.  |
| `mosk/.claude/agents/`| **Fonte dos 11 agentes** — definição completa, invocável por `subagent_type` (ADR-0015). |
| `mosk/.claude/mosk/`  | Canonical content: `tasks/`, `templates/`, `scripts/`, `checklists/`, `data/`, etc.       |
| `mosk/.claude/skills/`| Wrappers de slash command, **gerados** a partir dos agentes. Não editar à mão.          |
| `.claude/` (root)     | **Local execution environment** for working on MOSK itself. Not shipped, not authoritative. |
| `docs/`               | Discovery + specs about MOSK's own evolution. Not part of the installable template.       |
| `CLAUDE.md`           | Project instructions (this repo). Distinct from `.claude/mosk/claude_boot.md` (shipped). |
| `AGENTS.md`           | Auto-generated for Codex CLI by `link-codex-skills.sh`. Do not hand-edit.                |
| `README.md`           | User-facing intro to the toolkit + degit install instructions.                            |

Key layers inside `mosk/.claude/mosk/`:

- `agents/` (em `mosk/.claude/agents/`, fora de `mosk/mosk/`) — 11 definições
  (analyst, pm, architect, ux-expert, ui-expert, po, sm, dev, qa, security,
  bench). Concisas, low-menu, low-token. `bench` (Bento) é o modo workbench
  standalone — o único que não é fase do pipeline.
- `tasks/` — executable workflows referenced by agents (e.g.
  `specify.md`, `plan.md`, `tasks.md`, `implement.md`, `qa-gate.md`,
  `archive.md`, `boot.md`, `full-spec.md`, `index-docs.md`, plus
  optional accelerators: `clarify.md`, `analyze.md`, `checklist.md`).
- `templates/` — `*-tmpl.yaml` / `*-tmpl.md` for PRD, architecture,
  story, qa-gate, spec-meta, docs-index, **project-rule**, etc.
- `scripts/` — Bash helpers (`create-new-feature.sh`,
  `sync-agents-skills.sh`, `link-codex-skills.sh`,
  `migrate-docs-structure.sh`, `migrate-ctx-skills-to-rules.sh`,
  `sync-hallmark.sh`, `reset-install.sh`, `check-ship-ready.sh`,
  `selftest-common.sh`, `common.sh`).
- `checklists/` — quality checklists invoked by optional tasks.
- `data/` — static reference material read by tasks (elicitation methods,
  test frameworks, …), plus `data/hallmark/`: a **vendored fork** of the
  MIT-licensed [Hallmark](https://github.com/Nutlope/hallmark) design skill
  (106 upstream files + `tokens.css` + `LICENSE` + `VENDOR.md`), consumed by
  `tasks/hallmark.md`. Never hand-edit it as if it were MOSK-authored — every
  local change becomes part of the fork's diff. Update with
  `sync-hallmark.sh`.

Reference documents in `docs/architecture/` (numeric prefix optional — always resolve via `index.md` links or glob `*<stem>.md`):

- `index.md` — overview and entry point (auto-generated)
- *(this repo has no permanent architecture/ folder yet; specs live in
  `docs/specs/`)*

## Folder Conventions

- **Never edit under root `.claude/`** expecting it to ship. That tree
  is the local exec environment only. All product changes go under
  `mosk/`.
- New agent → escreva a definição em `mosk/.claude/agents/mosk-<name>.md`
  (front-matter `name`/`description` + persona) e gere o wrapper com
  `sync-agents-skills.sh`. Nunca escreva o wrapper à mão.
- New task → add `mosk/.claude/mosk/tasks/<name>.md` and reference it
  from the relevant agent under `## Task mapping`.
- New template → add `mosk/.claude/mosk/templates/<name>-tmpl.{md,yaml}`
  and reference from the consuming task.
- Bash scripts live in `mosk/.claude/mosk/scripts/` and `source`
  `common.sh` for shared helpers. Keep them POSIX-friendly and
  idempotent.
- Per-section MD/YAML files prefer kebab-case filenames (e.g.
  `project-rule-tmpl.md`, `spec-meta-tmpl.yaml`).

## Testing

There is no compiled app or automated test suite. Validation is:

1. **Structural read** — open the changed files and adjacent files
   together; confirm naming, references, and cross-links match.
2. **Prompt/workflow consistency** — when a task changes, check that
   referencing agents still describe it correctly and that mentioned
   templates still exist.
3. **Smoke-install** (optional) — run `npx degit rogerznts/mosk/mosk
   .` in a scratch directory and inspect the materialized tree.
4. **Script idempotency** — Bash helpers must be safe to rerun. Spot
   check with `--dry-run` flags when available.

---

## Document Organization (MOSK contract)

> The block below is **part of the shipped framework contract**. It
> describes the canonical `docs/` layout that MOSK installs into
> **consuming projects**, not the shape of this repo. Keep it intact
> when editing — it is reproduced from
> `mosk/.claude/mosk/templates/project-rule-tmpl.md`.

This project follows the MOSK canonical `docs/` layout — two mirrored
layers: **base** (project-wide truth) and **per-spec** (scope of a
single feature/fix/refactor).

```
docs/
├── index.md                 # auto-generated entry point
├── discovery/               # mosk-analyst writes here
├── prd/                     # mosk-pm writes here (sharded)
├── architecture/            # mosk-architect writes here (+ adr/)
├── ui/                      # mosk-ux-expert + mosk-ui-expert
├── qa/gates/                # mosk-qa writes gates here
└── specs/
    ├── {###}-{type}-{name}/
    │   ├── spec.md
    │   ├── plan.md
    │   ├── tasks.md
    │   ├── spec-meta.yaml      # metadata (number, branch, status, phase)
    │   ├── prd-delta.md        # optional, when this spec changes PRD
    │   ├── discovery/          # optional, feature-specific research
    │   ├── architecture/       # optional, feature ADRs + data models
    │   ├── ui/                 # optional, feature flows/wireframes/components
    │   ├── project/            # optional, planner tracking for this spec (non-technical: plan.md + update-YYYYMMDD.md)
    │   ├── stories/            # stories live HERE, not in a global docs/stories/
    │   ├── tests/              # dev-generated e2e checklists
    │   └── gate.yaml           # qa-gate output
    └── archive/                # completed specs
```

**Base vs spec decision rule:**

- Artifact describes the project as it **is today** → `docs/<domain>/`.
- Artifact is **specific to a pending change** → `docs/specs/{id}/<domain>/`.
- Artifact born in a spec but becomes canonical → stays in the spec,
  gets **promoted** at archive time (see Promotion Convention below).

## Promotion Convention (`promote:` front-matter)

Artifacts inside `specs/{id}/` that should become canonical carry a
YAML front-matter declaring destination and mode:

```yaml
---
promote: docs/architecture/adr/adr-0007-coupon-service.md
promote_mode: copy
---
```

Supported modes:

| `promote_mode` | Behavior at archive time |
|---|---|
| `copy`   | Copy the file to `promote:` target. Fail if target exists (user confirms). |
| `append` | Append body (without front-matter) to end of `promote:` target. |
| `manual` | Do not apply. Archive prints the file + suggested destination and asks the user to apply manually. Default for `prd-delta.md`. |

Without `promote:`, the artifact freezes inside the archived spec and
does not touch the base `docs/`.

## Agent Roles

- `/mosk-analyst` (Maria) — discovery, research, brainstorming.
- `/mosk-pm` (João) — PRD, product scope, PRD delta.
- `/mosk-architect` (Vinicius) — architecture, APIs, integrations, ADRs.
- `/mosk-ux-expert` (Salete) — user flows, wireframes, front-end specs, UX behavior.
- `/mosk-ui-expert` (Tiago) — visual acabamento, design system, premium pages, taste system.
- `/mosk-po` (Sara) — specs, planning, task generation (SpecKit pipeline).
- `/mosk-sm` (Roberto) — story readiness, sequencing.
- `/mosk-dev` (Jaime) — implementation, QA fixes, archive.
- `/mosk-qa` (Joaquim) — gates, test strategy, reviews.

UX Expert and UI Expert coexist in `docs/ui/` with distinct focus:
UX owns structure/behavior (`flows/`, `wireframes/`), UI owns visual
polish (`design-system.md`, `styles/`).

## Escalation Policy

Pipeline agents (`po`, `sm`, `dev`, `qa`) may detect, during execution,
that a preamble agent (`analyst`, `pm`, `architect`, `ux-expert`,
`ui-expert`) is needed to resolve an ambiguity.

**Rule:** the agent **suggests** the handoff to the user in a
standardized block (formato em `.claude/mosk/templates/escalation-block-tmpl.md`) and **waits for confirmation**.
Agents NEVER invoke another agent autonomously. The user is the sole
authority that decides whether to escalate, skip, or redirect.

Block format:

> **Preciso de outro agente antes de seguir**
> - O que apareceu: <o que foi detectado>
> - Quem resolve: `/mosk-<agente>`
> - Prompt pronto: `/mosk-<agente> <ação de uma linha, com o spec-id real>`
> - Onde o resultado fica: `docs/specs/{spec-id}/<domínio>/`
> - Quando voltar: retomo `<task atual>` de onde parei.

O cabeçalho e os rótulos vão no idioma de comunicação do projeto, em palavras
comuns. "Escalation", "side-trip", "guard", "preamble" são vocabulário interno
do MOSK — nunca aparecem na saída ao usuário.

Preamble agents invoked via escalation write inside the current
`specs/{id}/<domain>/` and end by suggesting the user return to the
originating agent.

## Spec Naming — branch e pasta são strings diferentes

Isto confunde com frequência, então vale explícito (ADR-0017):

```
branch:  {tipo}/{NNN}-{nome}                  →  feature/012-checkout-coupon
pasta:   docs/specs/{NNN}-{tipo}-{nome}       →  docs/specs/012-feature-checkout-coupon
```

O tipo aparece nos dois, **em posições diferentes**: no branch ele é um
segmento de caminho (agrupa no `git branch`), na pasta ele é parte do nome
(mantém `docs/specs/` plano, sem um nível de diretório por tipo).

**A ponte entre os dois é o campo `branch` do `spec-meta.yaml`** — nunca
igualdade de string. Código que assume `branch == nome da pasta` quebra.

O formato antigo de branch (`012-feature-checkout-coupon`) continua sendo
**resolvido** para trás, mas não é o que `create-new-feature.sh` cria.

## Spec Numbering and Concurrency

Spec numbers are globally unique, three-digit, zero-padded (`001`,
`002`, …). Generation + concurrency are handled by
`.claude/mosk/scripts/create-new-feature.sh`:

1. `git fetch --all --prune` to get fresh remote state.
2. Compute `max(remote branches, local branches, spec dirs) + 1`.
3. Create branch + folder + initial `spec-meta.yaml` + commit.
4. `git push -u origin <branch>` immediately.
5. On push rejection (race): re-fetch, renumber, rename branch + folder,
   retry push. Max 3 attempts, then abort with clear message.

`spec-meta.yaml` is the authoritative metadata per spec:

```yaml
spec_number: "005"
spec_id: "005-feature-checkout-coupon"
type: feature
branch: "feature/005-checkout-coupon"   # branch != pasta (ADR-0017)
created_at: "2026-04-22T14:30:00Z"
created_by: "<name>"
status: active             # active | archived
current_phase: specify     # specify | plan | tasks | implement | qa-gate | archived
```

Pipeline tasks (`plan.md`, `tasks.md`, `implement.md`, `qa-gate.md`,
`archive.md`) update `current_phase` when they run.

## docs/index.md as Entry Point

`docs/index.md` is the canonical entry point for new contributors. It
is auto-generated by the `index-docs` task and refreshed automatically
at key points: `boot` (initial), `specify` (new spec added),
`plan`/`tasks`/`implement`/`qa-gate` (phase updates), `archive` (spec
archived), and after `migrate-docs-structure.sh`.

The index always contains:

- **Overview** with links to the 5 base domains (discovery, prd,
  architecture, ui, qa).
- **Active Specs** table (reading `spec-meta.yaml` from each
  `docs/specs/*/`).
- **Archived Specs** list.
- **Domain contents** (files per folder, alphabetical).

Manual regeneration: `/mosk-dev index-docs`.

---

## AI Rules for Working on This Project

- Read this file and every other `.claude/rules/*.md` before starting
  any task. These are the durable project context.
- **All product changes go under `mosk/`.** Editing files under the
  root `.claude/` only affects the local exec environment for this
  repo; it does not ship.
- When changing an agent prompt, also check the matching skill wrapper
  under `mosk/.claude/skills/mosk-<name>/SKILL.md` and any task it
  references in `mosk/.claude/mosk/tasks/`. Cross-references must stay
  valid.
- When changing a task, audit which agents reference it (`grep -r` in
  `mosk/.claude/agents/`) and verify the descriptions still match.
- Keep prompts **concise, direct, low-menu, low-token**. Menus are
  fallback for empty activation; the preferred UX is natural language
  → direct task mapping.
- Optional tasks (`clarify`, `analyze`, `checklist`, `shard-doc`) must
  stay optional. Do not force them into the happy path.
- Do not paraphrase or drop the MOSK-invariant sections above
  (Document Organization, Promotion Convention, Agent Roles, Escalation
  Policy, Spec Numbering, docs/index.md) when editing
  `project-rule-tmpl.md` — they are the framework contract.
- Mention BMAD and SpecKit only as lineage/inspiration when useful.
  Default voice is MOSK first.
- Bash scripts under `mosk/.claude/mosk/scripts/` must remain idempotent
  and prefer `--dry-run` switches for destructive operations.
- `AGENTS.md` is auto-generated. Do not hand-edit; regenerate via
  `bash mosk/.claude/mosk/scripts/link-codex-skills.sh`.
- Validation is manual (no test suite). After edits, read adjacent
  files and cross-references; do a smoke install in a scratch directory
  for non-trivial structural changes.
