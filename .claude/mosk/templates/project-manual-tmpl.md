# {{PROJECT_NAME}} — Project Manual

<!--
  Template used by `mosk-pm planner` (task: ../tasks/planner.md) to
  seed `docs/discovery/project-manual.md` in a consuming project.

  This manual is the **source of truth for how this project tracks
  progress**. The planner reads it on every run to decide cadence,
  status vocabulary, deliverable definitions, and how to summarize git
  activity into `docs/project/plan.md` + `docs/project/update-*.md`.

  Fill `{{PLACEHOLDERS}}` based on what fits the team. The planner can
  pre-fill placeholders by reading other docs (`prd/`, `architecture/`,
  `discovery/`) and will ask pointed questions only when confidence is
  low.

  Sibling pattern: [[project-rule-tmpl.md]] (the `.claude/rules/project.md`
  template). Both are consumer-facing templates seeded by MOSK tasks.
-->

> **Audiência dos artefatos do planner.** `plan.md` e `update-*.md` são
> documentos de acompanhamento para **PO, stakeholders, gestores de
> projeto e usuários não-técnicos**. Por padrão o planner escreve em
> linguagem de progresso/valor, não técnica — detalhe técnico é citável,
> mas nunca prioritário. Ajuste o tom abaixo se a sua audiência for outra.

> **Escopo por branch.** Na branch principal o planner mantém o plano do
> **projeto inteiro** (`docs/project/`). Em uma branch de spec, mantém o
> plano daquela **spec** (`docs/specs/{id}/project/`) e dá um refresh no
> plano do projeto. Este manual governa os dois escopos.

## Tracking Cadence

{{TRACKING_CADENCE}}

> Example: "Weekly snapshot every Monday morning. Ad-hoc runs before
> stakeholder sync." The planner uses this to advise the user when a
> run is overdue.

## Deliverable Definition

{{DELIVERABLE_DEFINITION}}

> Example: "A deliverable is any artifact promised to a stakeholder —
> features deployed to staging, design specs signed off, infra changes
> in production. Internal refactors are not deliverables."

## Required Sections in `plan.md`

{{REQUIRED_PLAN_SECTIONS}}

> Default order (used when the placeholder is empty):
>
> 1. **Resumo** (`section:objectives`, var `{{SUMMARY_AND_OBJECTIVES}}`) — parágrafo de resumo + objetivos declarados.
> 2. **Planejamento** (`section:milestones`) — tabela de marcos.
> 3. **Entregáveis** (`section:deliverables`).
> 4. **Foco Atual** (`section:current-focus`).
> 5. **Status Snapshot** (`section:status-snapshot`).
> 6. **Riscos** (`section:risks`).
> 7. **Perguntas Abertas** (`section:open-questions`).

The planner enforces this list: each required section appears in
`docs/project/plan.md` as a `<!-- section:<id> -->…<!-- /section -->`
block. Section IDs são âncoras estáveis — os títulos exibidos podem
mudar, os IDs ficam.

## Milestone Format

{{MILESTONE_FORMAT}}

> Example: `name | target date | status | owner`.

## Status Vocabulary

{{STATUS_VOCABULARY}}

> Example: `on-track | at-risk | blocked | done | dropped`.

## Git Summary Rules

{{GIT_SUMMARY_RULES}}

> Example: "Group commits by author and by spec prefix (`^\d{3}-`).
> Include merges only when they cross a release branch. Skip
> dependency-bump commits unless they're security-related."

## Update File Scope

{{UPDATE_FILE_SCOPE}}

> Defines what every `docs/project/update-YYYYMMDD.md` must contain
> beyond the default frontmatter + body. Example: "Always include a
> 'Blockers' section, even if empty, for the standup automation to
> parse."

## AI Commentary Rules

{{AI_COMMENTARY_RULES}}

> O campo `## Comentário` de cada `update-YYYYMMDD.md` é **escrito pela
> AI**, não copiado do usuário. Esta seção define o tom e o escopo.
>
> - **Quando o usuário passa comentário no comando**: a AI usa como
>   guia — incorpora verbatim, parafraseia, ou responde pontos
>   levantados. O texto bruto do usuário fica preservado no
>   frontmatter (`user_comment`) para auditoria.
> - **Quando o usuário não passa nada (modo YOLO)**: a AI sintetiza
>   livremente a partir do que observou (commits, specs ativos,
>   mudanças em `plan.md`) sem travar esperando direção.
>
> Exemplo de regra do projeto: "Comentário entre 3 e 8 linhas, em
> primeira pessoa do plural, pronto para colar em PR. Não mencione
> commits que só renomeiam arquivos."

## Project-Specific Tracking Rules

{{PROJECT_SPECIFIC_TRACKING_RULES}}

> Free-form rules the team wants the planner to follow. Example:
> "Pin the current week's focus to the spec with the closest
> milestone. Use Portuguese for prose in `plan.md`."

---

## How planner consumes this manual

On every `/mosk-pm planner` run, the task `planner.md`:

1. Reads this file (creates from template if missing).
2. Applies the rules above to decide what changes in
   `docs/project/plan.md` and what goes into the dated update file.
3. Reads recent git activity (window: since last `plan.md` mtime;
   bootstrap fallback: 7 days).
4. Absorbs the user comment passed with the command.
5. Writes/updates `plan.md` only when planning materially changes.
6. Always emits `update-YYYYMMDD.md` with frontmatter for PR usage.

## Relationship to `docs/index.md`

`docs/project/` is one of the six base domains in the MOSK canonical
`docs/` layout (alongside `discovery/`, `prd/`, `architecture/`,
`ui/`, `qa/`). After each planner run, `index-docs.md` regenerates
`docs/index.md` to surface `plan.md` and the most recent update.
