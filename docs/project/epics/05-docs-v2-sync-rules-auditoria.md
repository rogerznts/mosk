# 05 — Estrutura docs v2, sync agente-skill, rules & auditoria

- **Janela real:** 03/abr–03/mai/2026
- **Estado:** Done
- **Estimativa:** 8 (Points)
- **Ciclo:** 2026-1

## Resumo

Maturação da arquitetura de documentação e sincronização: a estrutura `docs/`
v2 (base + per-spec), a migração de context skills para `rules`, o script de
sincronização agente↔skill e a auditoria de caminhos canônicos de docs.

## Planejamento

- Padronizar a arquitetura agente-skill e adicionar `sync-agents-skills.sh`
  (com flag `--clean` e limpeza de órfãos baseada em roster).
- Migrar context skills (`ctx-*`) para project `rules` em `.claude/rules/` e
  documentar a migração; substituir `CLAUDE.md` estático por boot template
  dinâmico.
- Rearquitetar a estrutura de specs (per-feature), automatizar criação de
  branch com retry e adicionar workflows de escalation para UI/UX.
- Adicionar o script de migração de docs v2 e reescrever o README detalhando o
  toolkit expandido.
- Alinhar caminhos de docs aos domínios canônicos e adicionar tooling de
  auditoria (`audit-docs-paths`).

## Entregável

Estrutura `docs/` v2 com camadas base e per-spec, promoção de artefatos,
`rules` de projeto, sincronização confiável das três camadas (agents/skills/CC)
e auditoria de caminhos — a espinha dorsal documental do toolkit.

## Evidência

Repositório: https://github.com/rogerznts/mosk
Commits-chave: `4fe6a43`, `633061b`, `67b5b66`, `321f3d5`, `14b86f3`,
`8f49388`, `1ab2947`, `f5e0283`, `5b269b3`, `3f103fd`, `0bd0ebc`, `2887266`,
`dc6b2a8`, `e3f1cd2`, `d0f538b`, `28a6266`, `993bbf7` (18 commits no total).
