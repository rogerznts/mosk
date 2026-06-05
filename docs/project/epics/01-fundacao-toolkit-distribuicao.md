# 01 — Fundação do toolkit & distribuição (degit)

- **Janela real:** 05–07/nov/2025
- **Estado:** Done
- **Estimativa:** 5 (Points)
- **Ciclo:** 2026-1

## Resumo

Nascimento do toolkit: a estrutura inicial do MOSK, sua documentação base e o
mecanismo de distribuição via `npx degit`, estabelecendo `docs/specs` como casa
das especificações e os modelos de uso greenfield/brownfield.

## Planejamento

- Implementar a estrutura inicial do toolkit (pastas, agentes, tasks base).
- Escrever a documentação inicial e o README com recomendações de uso.
- Definir a instalação por `npx degit rogerznts/mosk/mosk .` (e passo manual).
- Mover o diretório de specs para `/docs/specs` e corrigir o cálculo de
  repo-root nos scripts base.
- Migrar/limpar comandos legados (base OpenSpec) e ajustar caminhos.

## Entregável

Toolkit instalável e documentado, com estrutura de specs em `docs/specs`,
instruções de instalação via degit e modelos greenfield/brownfield — a fonte
única da verdade a partir da qual o projeto evolui.

## Evidência

Repositório: https://github.com/rogerznts/mosk
Commits-chave: `3209f50`, `4aaf3d3`, `f68a4af`, `111e949`, `b6a658f`,
`d809cab`, `9f52d7c`, `65230a1`, `46825f9`, `3fd4f3f`.
