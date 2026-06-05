# MOSK Toolkit SDD — Plano de Projeto

> Mantido por `mosk-pm planner`. Edições manuais devem viver no bloco
> `<!-- custom -->…<!-- /custom -->` ao final — tudo fora dele pode
> ser reescrito em runs futuros.
>
> Espelhado no Plane em **CORPO-776 — "P2.4 - MOSK Toolkit SDD"**
> (workspace `ballroom`, projeto **Corporativo**). Ver
> [`guia-atualizacao-plane.md`](./guia-atualizacao-plane.md).

Last updated: 2026-05-31T00:00:00Z

<!-- section:objectives -->
## Resumo

O MOSK é uma toolkit própria, criada do zero pela equipe, que introduz uma
metodologia unificada de **Spec-Driven Development (SDD)** para a evolução do
ERP v3 da Ballroom: todo o ciclo — da concepção à entrega — nasce de
especificações claras, estruturadas e rastreáveis, sobre documentos vivos e
integrados ao fluxo de desenvolvimento com IA nativa. Distribuída via
`npx degit rogerznts/mosk/mosk .`, instala personas de agentes, pipelines
estilo SpecKit e scaffolding de documentação no `.claude/` e `docs/` de cada
projeto consumidor.

Este plano é uma **reconstrução retrospectiva** do histórico de
desenvolvimento (93 commits, nov/2025 → mai/2026), organizada em 6 épicos
macro que viram sub-work items do CORPO-776 no Plane.

**Objetivos:**

- Padronizar a metodologia de desenvolvimento (discovery → entrega) sobre
  especificações vivas, eliminando ambiguidade e retrabalho.
- Operar de forma nativamente integrada com IA (gera documentação, sugere
  implementações, organiza branches, registra mudanças).
- Cobrir as três frentes do ciclo: **Discovery & Ideação**, **Implementação
  & Features** e **Manutenção & Operações** (GMUDs, hotfixes, ações rápidas).
- Manter rastreabilidade completa entre documentação e código.
<!-- /section -->

<!-- section:milestones -->
## Planejamento

Marcos = épicos consolidados a partir do histórico Git. Janela = datas reais
de execução. Todos concluídos (evidência: repositório `rogerznts/mosk`).

| # | Épico | Janela real | Estado | Est. |
|---|---|---|---|---|
| 01 | [Fundação do toolkit & distribuição (degit)](./epics/01-fundacao-toolkit-distribuicao.md) | 05–07/nov/2025 | Done | 5 |
| 02 | [Agentes, skills & menus (rebrand MOSK)](./epics/02-agentes-skills-menus.md) | 18/fev–01/mar/2026 | Done | 13 |
| 03 | [Pipeline SpecKit, papéis & bootstrap de contexto](./epics/03-pipeline-speckit-papeis-boot.md) | 02–27/mar/2026 | Done | 8 |
| 04 | [Integrações: Codex, taste system & rastreabilidade E2E](./epics/04-integracoes-codex-taste-e2e.md) | 16–29/mar/2026 | Done | 8 |
| 05 | [Estrutura docs v2, sync agente-skill, rules & auditoria](./epics/05-docs-v2-sync-rules-auditoria.md) | 03/abr–03/mai/2026 | Done | 8 |
| 06 | [Framework modular, planejamento, handoff & manutenção](./epics/06-framework-modular-planejamento-handoff.md) | 15–29/mai/2026 | Done | 5 |
<!-- /section -->

<!-- section:deliverables -->
## Entregáveis

- Toolkit instalável via `npx degit` com 9 personas de agentes (analyst, pm,
  architect, ux-expert, ui-expert, po, sm, dev, qa) + webdesigner.
- Pipeline SpecKit: `specify → plan → tasks → implement → qa-gate → archive`,
  com tipos de spec, archiving e política de escalation.
- Bootstrap de contexto (`/mosk-boot`) gerando rules de projeto em
  `.claude/rules/`; integração Codex CLI (`AGENTS.md` auto-gerado).
- Estrutura `docs/` v2 (base + per-spec), promoção de artefatos, `docs/index.md`
  auto-gerado, scripts de migração idempotentes.
- Domínio `docs/project/` com planner (plano vivo + updates datados) e manual
  de acompanhamento; skills de manutenção (`mosk-handoff`, `mosk-update`,
  `mosk-write-skill`) e task `grill` de stress-test arquitetural.
- Padronização metodológica, documentação viva e integrada, maior qualidade
  técnica e velocidade segura na evolução do ERP v3.
<!-- /section -->

<!-- section:current-focus -->
## Foco Atual

A última frente (épico 06, mai/2026) consolidou o framework modular, o domínio
de planejamento de projeto (`docs/project/`), as skills de handoff/manutenção e
a remoção da `constitution`. O foco corrente é **operacionalizar o
acompanhamento do projeto no Plane** (este run): espelhar o histórico como
épicos sob o CORPO-776 e manter o `plan.md` ↔ Plane alinhados via `planner`.
<!-- /section -->

<!-- section:status-snapshot -->
## Status Snapshot

- **Estado geral:** projeto **Done** no Plane (CORPO-776). Toolkit em uso e
  evolução contínua; cada nova frente entra como spec/epic.
- **Épicos:** 6/6 concluídos (reconstrução retrospectiva do histórico).
- **Cobertura no Plane:** sub-work items sendo criados sob CORPO-776 (ciclo
  2026-1, assignee Roger.Santos, label Tecnologia).
- **Gap fechado:** CORPO-776 deixou de estar vazio (regra do manual: projeto
  não pode estar sem tarefas filhas).
<!-- /section -->

<!-- section:risks -->
## Riscos

- **Deriva plano ↔ Plane:** mudanças no planejamento que não refletem nos
  sub-itens do CORPO-776 (mitigação: rodar `planner` na cadência e seguir o
  `guia-atualizacao-plane.md`).
- **Evidência de "Done" (Protocolo Nexus):** itens concluídos precisam de link
  de evidência; cada épico referencia o repositório/commits no GitHub.
- **Numeração de sub-itens volátil:** os números `CORPO-NNNN` dos épicos só
  existem após a criação no Plane; manter a tabela do guia sincronizada.
<!-- /section -->

<!-- section:open-questions -->
## Perguntas Abertas

- Manter os 6 épicos em estado `Done` ou promover o épico 06 a `In Progress`
  enquanto houver evolução ativa do framework?
- Vincular o CORPO-776 a um módulo definitivo (hoje "2 - Governança de Dados")?
- Adotar tarefas-filhas (3º nível) por épico no futuro, caso a rastreabilidade
  por commit-grupo passe a ser exigida?
<!-- /section -->

<!-- custom -->
<!-- /custom -->
