---
date: {{ISO_DATE_UTC}}
author: {{GIT_USER_NAME}}
scope: {{SCOPE}}                  # project | spec
spec_id: {{SPEC_ID_OR_NONE}}      # vazio no escopo project
commits_window: {{COMMITS_WINDOW}}
commits_count: {{COMMITS_COUNT}}
specs_touched: {{SPECS_TOUCHED_LIST}}
user_comment: {{USER_COMMENT_ONE_LINE}}
plan_changed: {{PLAN_CHANGED}}
plan_sections_changed: {{PLAN_SECTIONS_CHANGED}}
delta: {{DELTA}}
---

<!--
  Documento de acompanhamento para PO, stakeholders e gestores — NÃO é
  doc técnica. Linguagem de progresso e valor; detalhe técnico é citável
  mas nunca prioritário. Gerado por `mosk-pm planner` (../tasks/planner.md).
-->

# Update {{YYYY_MM_DD}}

## Comentário

{{AI_COMMENT_FULL_OR_NONE}}

## Resumo de commits (janela {{COMMITS_WINDOW}})

{{COMMITS_GROUPED_OR_NONE}}

## Specs ativos tocados

{{SPECS_BULLET_LIST_OR_NONE}}

## Alterações no plan.md

{{PLAN_DIFF_SUMMARY_OR_NONE}}

## Próximos passos

{{NEXT_STEPS_OR_NONE}}
