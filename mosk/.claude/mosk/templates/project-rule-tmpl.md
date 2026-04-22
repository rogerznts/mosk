# {{PROJECT_NAME}} — Project Rules

<!--
  Template used by `mosk-boot` (task: ../tasks/boot.md) to generate
  `.claude/rules/project.md` in a consuming project.

  Fill `{{PLACEHOLDERS}}` with information discovered from the codebase.
  Drop sections that do not apply. Keep the MOSK-invariant sections
  (Document Organization, Promotion, Agent Roles, Escalation Policy,
  Spec Numbering, docs/index.md) as they are — they are the framework
  contract.
-->

## System Purpose

{{ONE_PARAGRAPH_DESCRIBING_WHAT_THIS_PROJECT_IS_AND_ITS_PRIMARY_GOAL}}

## Stack

- Language / runtime: {{LANGUAGE_RUNTIME}}
- Framework(s): {{FRAMEWORKS}}
- Datastore(s): {{DATASTORES}}
- Package manager: {{PACKAGE_MANAGER}}
- Build / dev commands: {{BUILD_DEV_COMMANDS}}
- Test framework: {{TEST_FRAMEWORK}}

## Architecture

{{ARCHITECTURE_PATTERN_AND_KEY_LAYERS}}

Reference documents in `docs/architecture/`:

- `docs/architecture/index.md` — overview
- `docs/architecture/tech-stack.md` — stack details
- `docs/architecture/coding-standards.md` — conventions
- `docs/architecture/source-tree.md` — folder map
- `docs/architecture/adr/` — decision records

## Folder Conventions

{{FOLDER_CONVENTIONS_DISCOVERED_IN_THE_CODEBASE}}

## Testing

{{HOW_TO_RUN_TESTS_UNIT_INTEGRATION_E2E}}

---

## Document Organization (MOSK contract)

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
standardized "Escalation suggested" block and **waits for confirmation**.
Agents NEVER invoke another agent autonomously. The user is the sole
authority that decides whether to escalate, skip, or redirect.

Block format:

> **Escalation suggested**
> - Signal: <what was detected>
> - Recommended agent: `<skill>`
> - Suggested prompt: `<agent> <one-line ask>`
> - Scope: `feature {spec-id}` (outputs written to `specs/{id}/<domain>/`)
> - On return: resume `<current task>`.

Preamble agents invoked via escalation write inside the current
`specs/{id}/<domain>/` and end by suggesting the user return to the
originating agent.

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
branch: "005-feature-checkout-coupon"
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
- Respect the `docs/` layout above. Never create ad-hoc folders under
  `docs/` outside the canonical set without updating this rule file.
- When in doubt whether an artifact belongs to the base or to a spec,
  ask the user. Default to the spec — it is reversible.
- Never bypass the escalation policy: suggest a handoff, do not invoke
  another agent yourself.
- Update `spec-meta.yaml` `current_phase` when advancing a spec
  through the pipeline.
- {{PROJECT_SPECIFIC_AI_RULES}}
