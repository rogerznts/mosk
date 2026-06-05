# 02 — Agentes, skills & menus (rebrand MOSK)

- **Janela real:** 18/fev–01/mar/2026
- **Estado:** Done
- **Estimativa:** 13 (Points)
- **Ciclo:** 2026-1

## Resumo

Consolidação da identidade MOSK e da arquitetura de agentes/skills: rebrand de
OpenSpec para "Chore Mode", introdução das skills Claude/Codex, centralização
dos agentes em `.claude/mosk`, padronização de nomes `mosk-*` e a UX de menus
quick-pick com `mosk-help`.

## Planejamento

- Renomear OpenSpec → Chore Mode e atualizar comandos/documentação.
- Adicionar skills Claude/Codex e migrar caminhos de docs do chore.
- Centralizar definições de agentes e consolidar assets em `.claude/mosk`.
- Padronizar nomenclatura `mosk-ag-*` → `mosk-*`.
- Implementar menus quick-pick agrupados e execução direta de comando na
  ativação do agente; adicionar `/mosk-help`.
- Reorganizar grupos de menu (renomear "Story & Spec" → "SpecKit") e refinar a
  saída de help com listas agrupadas e descrições localizadas.

## Entregável

Roster de agentes MOSK com nomes padronizados, skills Claude/Codex funcionais,
e navegação por menus quick-pick de dois níveis — base de UX consistente para
todo o toolkit.

## Evidência

Repositório: https://github.com/rogerznts/mosk
Commits-chave: `8151c10`, `d60c8c5` (#1), `e2f36ef`, `ac843ec`, `87a9e5e`,
`2dcbec8`, `d357d40`, `9e7dc09`, `c77c28c`, `eb9c231`, `a4c0e5d`, `16877e8`,
`5a6e148` (20 commits no total da janela).
