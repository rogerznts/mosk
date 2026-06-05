# 03 — Pipeline SpecKit, papéis & bootstrap de contexto

- **Janela real:** 02–27/mar/2026
- **Estado:** Done
- **Estimativa:** 8 (Points)
- **Ciclo:** 2026-1

## Resumo

Definição do pipeline SpecKit e dos papéis dos agentes, mais o bootstrap de
contexto do projeto. Unifica a gestão de mudança sob `specify → plan → tasks →
implement → qa-gate → archive`, com tipos de spec e archiving, e introduz o
`mosk-boot` para contextualizar cada projeto consumidor.

## Planejamento

- Introduzir a knowledge base MOSK e novas definições de agentes/team skills.
- Reatribuir ownership do pipeline SpecKit (PM → PO) e do `chore-proposal`
  (dev → sm); mover `spec-constitution` (PM → PO).
- Unificar gestão de mudança sob o pipeline SpecKit com spec types e archiving.
- Adicionar mandato de teste unitário de backend ao agente dev e guardas de
  criação de branch (confirmação do usuário, branch não-main).
- Criar a skill `mosk-boot` para bootstrap de contexto e migrá-la para
  `.claude/skills/ctx-*`; adicionar carregamento dinâmico de context skills.
- Adicionar configuração de sandbox `.ai-jail` e documentar o ambiente
  recomendado.

## Entregável

Pipeline SpecKit operacional com papéis claros, tipos de spec, archiving e
escalation; `mosk-boot` gerando contexto de projeto; mandato de testes e
guardas de branch — o coração metodológico do toolkit.

## Evidência

Repositório: https://github.com/rogerznts/mosk
Commits-chave: `bb5cfac`, `f588d5a`, `fad9177`, `09447d3`, `96fa04b`,
`c326f99` (#2), `bf05a8c`, `08f1708` (#3), `5d75817`, `6bd7d0e`, `a6fe10a`,
`83be928`, `d7e72e8`, `86461b9`, `f75680d` (19 commits no total da janela).
