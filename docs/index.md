# MOSK — Índice da Documentação

> Entry point gerado/atualizado pelo fluxo `planner` (mosk-pm). Ponto de
> partida para navegar a documentação viva do projeto.

Last updated: 2026-08-16T03:25:00Z

Toolkit health can be checked with
`bash .claude/mosk/scripts/doctor.sh`. A spec is only considered closed when
`check-ship-ready.sh` finds it archived with a `PASS` gate or a fully documented
`WAIVED`, all promotions applied, and a clean working tree.

## Visão geral

MOSK é a toolkit própria de **Spec-Driven Development (SDD)** que padroniza a
evolução do ERP v3 da Ballroom. Acompanhamento de projeto espelhado no Plane em
**CORPO-776 — "P2.4 - MOSK Toolkit SDD"** (workspace `ballroom`, projeto
Corporativo).

## Domínios base

- **discovery/** — `project-manual.md` (manual de acompanhamento PMO: Tripé,
  Protocolo Nexus, Pulsação, auditoria de metadados);
  [`mosk-payload-mode-brief.md`](./discovery/mosk-payload-mode-brief.md)
  (brief do modo `/mosk-bench`, persona Bento — 13 decisões);
  [`toolkit-autonomy-assessment-roadmap.md`](./discovery/toolkit-autonomy-assessment-roadmap.md)
  (avaliação funcional e roadmap para remover legado BMAD, tornar o pipeline
  determinístico e ampliar a autonomia com segurança).
- **architecture/** — [`mosk-payload-mode.md`](./architecture/mosk-payload-mode.md)
  (design do modo `/mosk-bench`) + [`adr/`](./architecture/adr/)
  (ADR-0001 infra compartilhada, ADR-0002 auto-escalação escopada,
  ADR-0003 golden starter versionado, ADR-0004 orquestração agnóstica de
  runtime — promovido no archive da spec 002; ADR-0005 deploy escopado;
  ADR-0006 grafo de orquestração consultivo (spec 004), ADR-0008 delivery-loop
  consultivo (spec 005), ADR-0009 orquestração multi-pane sobre Herdr (spec 006)
  e ADR-0010 Orca como backend (spec 007) — **todos superseded pelo ADR-0018**;
  ADR-0011 Hallmark vendorizado como corpo de referência do `mosk-ui-expert` —
  promovido no archive da spec 008;
  ADR-0012 fronteira decisão-de-rota × execução-de-fase (mantido — sustenta o
  ADR-0016);
  ADR-0013 seam de fan-out em três tiers e ADR-0014 Orca como atuador único
  (spec 010) — **superseded pelo ADR-0018**;
  ADR-0015 agente como fonte, skill como wrapper (e o template passa a shipar
  as duas camadas),
  ADR-0016 protocolo de invocação entre agentes (execução delega, rota não),
  ADR-0017 convenção de nome de branch `{tipo}/{NNN}-{nome}`,
  **ADR-0018 remoção da camada de orquestração** — o subagente nativo dos
  runtimes tornou o atuador externo redundante) +
  [`glossary.md`](./architecture/glossary.md) (termos de domínio; promovido da spec 005).
- **project/** — planejamento vivo do projeto:
  - [`plan.md`](./project/plan.md) — plano de projeto (6 épicos).
  - [`guia-atualizacao-plane.md`](./project/guia-atualizacao-plane.md) — como
    espelhar o planejamento no Plane (CORPO-776).
  - [`update-20260531.md`](./project/update-20260531.md) — último update datado.
  - [`epics/`](./project/epics/) — um arquivo por épico (Tripé + evidência).
- **qa/** — [`security-review-012-feature-stabilize-toolkit-contracts.md`](./qa/security/security-review-012-feature-stabilize-toolkit-contracts.md)
  (`SECURITY: PASS`; contenção de destinos de promoção revalidada) e
  [`security-review-013-feature-deterministic-pipeline-state.md`](./qa/security/security-review-013-feature-deterministic-pipeline-state.md)
  (`SECURITY: PASS`; seis variantes de mapping raiz indentada foram bloqueadas
  em Bash e zsh e o gate QA final passou) e
  [`security-review-014-feature-legacy-cleanup-adaptive-intelligence.md`](./qa/security/security-review-014-feature-legacy-cleanup-adaptive-intelligence.md)
  (`SECURITY: PASS`; quatro achados `LOW` na validação de `path_pattern` da
  allowlist — três fechados e revalidados, SEC-4 aceito sem correção).

## Planejamento (épicos ↔ Plane)

| # | Épico | Plane | Estado |
|---|---|---|---|
| 01 | Fundação do toolkit & distribuição (degit) | CORPO-1254 | Done |
| 02 | Agentes, skills & menus (rebrand MOSK) | CORPO-1255 | Done |
| 03 | Pipeline SpecKit, papéis & bootstrap de contexto | CORPO-1256 | Done |
| 04 | Integrações: Codex, taste system & rastreabilidade E2E | CORPO-1257 | Done |
| 05 | Estrutura docs v2, sync agente-skill, rules & auditoria | CORPO-1258 | Done |
| 06 | Framework modular, planejamento, handoff & manutenção | CORPO-1259 | Done |

## Specs

### Ativas

| # | Spec | Fase | Branch | Criada |
|---|---|---|---|---|
| 014 | [feature-legacy-cleanup-adaptive-intelligence](./specs/014-feature-legacy-cleanup-adaptive-intelligence/) (limpeza do legado, happy path direto e classificação adaptativa de risco/contexto — gate `PASS`, score 100; corpus 2641 → 618 linhas) | implement | feature/014-legacy-cleanup-adaptive-intelligence | 2026-08-15 |

### Arquivadas

| # | Spec | Fase | Branch | Arquivada |
|---|---|---|---|---|
| 013 | [feature-deterministic-pipeline-state](./specs/archive/013-feature-deterministic-pipeline-state/) (máquina de estados determinística, schemas versionados, histórico atômico e validação fail-closed — gate `PASS`, score 100) | archived | feature/013-deterministic-pipeline-state | 2026-08-15 |
| 012 | [feature-stabilize-toolkit-contracts](./specs/archive/012-feature-stabilize-toolkit-contracts/) (doctor autocontido, conclusão fail-closed e inventário para remover legado BMAD — gate `PASS`, score 100) | archived | feature/012-stabilize-toolkit-contracts | 2026-08-15 |
| 004 | [feature-orchestration-graph](./specs/archive/004-feature-orchestration-graph/) (grafo de orquestração consultivo — **revertida** pelo ADR-0018) | archived | 004-feature-orchestration-graph | 2026-08-14 |
| 011 | [feature-direct-agents](./specs/archive/011-feature-direct-agents/) (template ship a camada de agentes; protocolo de invocação; nome de branch — gate `WAIVED`) | archived | 011-feature-direct-agents | 2026-08-05 |
| 010 | [feature-graph-loop-orca](./specs/archive/010-feature-graph-loop-orca/) (loops e grafos no desenvolvimento; Orca como atuador único — gate `WAIVED`) | archived | 010-feature-graph-loop-orca | 2026-08-05 |
| 009 | [fix-orca-driver-read-send](./specs/archive/009-fix-orca-driver-read-send/) (driver Orca: `read` cego, `send` sem prova de entrega; + `common.sh` em zsh) | archived | 009-fix-orca-driver-read-send | 2026-07-29 |
| 008 | [feature-ui-expert-hallmark](./specs/archive/008-feature-ui-expert-hallmark/) (Hallmark como ferramenta anti-slop do `/mosk-ui-expert`) | archived | 008-feature-ui-expert-hallmark | 2026-07-26 |
| 007 | [feature-mosk-orca](./specs/archive/007-feature-mosk-orca/) (Orca como segundo backend do `/mosk-orq`; atuador plugável) | archived | 007-feature-mosk-orca | 2026-07-25 |
| 006 | [feature-mosk-orq](./specs/archive/006-feature-mosk-orq/) (orquestrador `/mosk-orq` — Mauro — sobre Herdr) | archived | 006-feature-mosk-orq | 2026-07-23 |
| 005 | [feature-delivery-loop](./specs/archive/005-feature-delivery-loop/) (delivery-loop consultivo e limitado) | archived | 005-feature-delivery-loop | 2026-07-22 |
| 002 | [feature-mosk-payload-mode](./specs/archive/002-feature-mosk-payload-mode/) (modo `/mosk-bench`) | archived | 002-feature-mosk-payload-mode | 2026-07-20 |

### Outras

- `specs/001-refactor-structure-v2/` — `plan.md` (sem `spec-meta.yaml`; não
  ativo no rastreamento de fase).

## Updates recentes

- [2026-05-31](./project/update-20260531.md) — reconstrução do planejamento a
  partir do histórico Git e espelhamento no Plane (CORPO-776).
