# 06 — Framework modular, planejamento, handoff & manutenção

- **Janela real:** 15–29/mai/2026
- **Estado:** Done
- **Estimativa:** 5 (Points)
- **Ciclo:** 2026-1

## Resumo

Frente mais recente: reconstrução do framework modular de agentes, o novo
domínio de planejamento de projeto (`docs/project/` com planner + manual), e as
ferramentas de handoff e manutenção que sustentam a evolução contínua do
toolkit.

## Planejamento

- Implementar o framework modular de agentes MOSK com skills especializadas,
  templates de task e scripts de automação.
- Integrar ferramentas de planejamento de projeto: domínio `docs/project`,
  templates (`project-plan`, `project-update`, `project-manual`) e automação da
  task `planner` (plano vivo + updates datados com comentário gerado por IA).
- Adicionar a task `artefact` do PO e o spec type `extension` para adendos em
  escopo.
- Introduzir a skill `mosk-handoff` e a task `grill` (stress-test
  arquitetural); clarificar a estrutura do projeto.
- Adicionar a documentação de `mosk-update` e `mosk-write-skill`.
- Remover o arquivo `constitution` e suas referências em templates/tasks/scripts.

## Entregável

Framework modular consolidado, domínio de planejamento de projeto operante
(este `plan.md` + updates), skills de handoff/manutenção e stress-test
arquitetural — o toolkit pronto para se auto-acompanhar e evoluir com segurança.

## Evidência

Repositório: https://github.com/rogerznts/mosk
Commits-chave: `1690a68`, `86ea3d0`, `5062c45`, `51f2183`, `606d518`,
`7f7d4e5`, `acecc3e` (7 commits no total da janela).
