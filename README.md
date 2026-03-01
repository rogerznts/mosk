# MOSK Toolkit

**Mad Open Spec Kit** — Toolkit de Spec-Driven Development (SDD) instalável em qualquer projeto via `npx degit`.

---

## O que é o MOSK

O MOSK combina dois frameworks em um único toolkit coeso:

- **BMAD Core** — 10 agentes especializados para discovery, arquitetura, produto e qualidade
- **SpecKit** — Pipeline de especificação-para-implementação gerenciado pelo PM, executado pelo Dev
- **Chore Mode** — Fluxo leve para mudanças rápidas, bugfixes e GMUDs (Dev-owned)

Tudo funciona através de skills do Claude Code (slash commands) sem dependência de CLI externa.

---

## Instalação

```bash
# Instalar na raiz do projeto atual
npx degit rogerznts/mosk/mosk .

# Forçar (sobrescrever arquivos existentes)
npx degit rogerznts/mosk/mosk . --force
```

Após instalar, reinicie o Claude Code. As skills aparecem automaticamente como slash commands.

---

## Estrutura Instalada

```
seu-projeto/
├── .claude/
│   ├── mosk/                  # Core MOSK (agentes, tasks, templates)
│   │   ├── agents/            # Definições dos 10 agentes
│   │   ├── tasks/             # Workflows executáveis
│   │   ├── templates/         # Templates de documentos
│   │   ├── scripts/           # Scripts de suporte
│   │   ├── constitution.md    # Princípios do projeto (criado pelo PM)
│   │   └── core-config.yaml   # Configuração central
│   └── skills/                # Delegações de skill (slash commands)
│       ├── mosk-analyst/
│       ├── mosk-architect/
│       ├── mosk-dev/
│       ├── mosk-master/
│       ├── mosk-orchestrator/
│       ├── mosk-pm/
│       ├── mosk-po/
│       ├── mosk-qa/
│       ├── mosk-sm/
│       └── mosk-ux-expert/
└── docs/                      # Criado pelos workflows
    ├── specs/                 # Especificações de features (SpecKit)
    │   └── 001-nome-feature/
    │       ├── spec.md
    │       ├── plan.md
    │       ├── tasks.md
    │       ├── data-model.md  # (opcional)
    │       ├── research.md    # (opcional)
    │       └── contracts/     # (opcional)
    └── changes/               # Mudanças rápidas (Chore Mode)
        └── [change-id]/
            ├── proposal.md
            └── tasks.md
```

---

## Os 10 Agentes

| Skill | Agente | Role |
|---|---|---|
| `/mosk-analyst` | Maria | Pesquisa de mercado, brainstorming, project brief, análise competitiva |
| `/mosk-architect` | Vinicius | Arquitetura de sistemas, stack, APIs, infraestrutura |
| `/mosk-pm` | João | PRDs, estratégia de produto, feature specs (SpecKit) |
| `/mosk-po` | Sara | Backlog, stories com AC, critérios de aceitação |
| `/mosk-sm` | Roberto | Dev-readiness de stories, notas técnicas, agilidade |
| `/mosk-dev` | Jaime | Implementação, debugging, refatoração, Chore Mode |
| `/mosk-qa` | Joaquim | Arquitetura de testes, quality gates, NFR, revisões |
| `/mosk-ux-expert` | Salete | UI/UX, wireframes, front-end specs, prompts para geração de UI |
| `/mosk-master` | Mestre | Executor universal — expertise em todos os domínios |
| `/mosk-orchestrator` | Maestro | Coordenação de agentes, orientação de workflow |

---

## Fluxo Completo (Greenfield)

### Fase 1 — Discovery e Arquitetura

```
/mosk-analyst    → Project Brief, pesquisa de mercado
/mosk-architect  → Documento de arquitetura, stack, decisões técnicas
/mosk-pm         → PRD, epics
```

### Fase 2 — Constituição (uma vez por projeto)

```
/mosk-pm  → *spec-constitution
             └─ Lê PRD + arquitetura
             └─ Deriva princípios do projeto
             └─ Gera .claude/mosk/constitution.md
             └─ Executa UMA VEZ antes de começar specs de features
```

### Fase 3 — Feature Spec (SpecKit — dono: PM)

```
/mosk-pm  → *spec-specify [descrição]   → docs/specs/{id}/spec.md
/mosk-pm  → *spec-clarify               → (opcional) resolve ambiguidades
/mosk-pm  → *spec-plan                  → data-model, contracts, research
/mosk-pm  → *spec-analyze               → (opcional) validação cross-artifact
/mosk-pm  → *spec-checklist [tipo]      → (opcional) checklist de qualidade
/mosk-pm  → *spec-tasks                 → tasks.md ordenado por dependências
```

### Fase 4 — Story Preparation (PO → SM)

```
/mosk-po  → Cria stories com AC e valor de negócio
/mosk-sm  → Refina stories para dev-readiness (notas técnicas, checklists)
```

### Fase 5 — Implementação

```
OPÇÃO A — Story por story (fluxo BMAD):
/mosk-dev  → *develop-story

OPÇÃO B — Feature completa via tasks.md (fluxo SpecKit):
/mosk-dev  → *spec-implement
```

### Fase 6 — Quality Gate

```
/mosk-qa  → Review de arquitetura, testes, quality gates, NFR
```

---

## Mudanças Rápidas (Chore Mode — dono: Dev)

Para GMUDs, bugfixes e ajustes que não justificam o pipeline completo do SpecKit:

```
/mosk-dev  → *chore-proposal {id}   → docs/changes/{id}/proposal.md + tasks.md
/mosk-dev  → *chore-apply {id}      → implementa a mudança aprovada
/mosk-dev  → *chore-archive {id}    → encerra e arquiva
```

---

## Referência Rápida de Skills

### Agentes

| Comando | Quando usar |
|---|---|
| `/mosk-orchestrator` | Não sabe qual agente usar; precisa coordenar workflow |
| `/mosk-master` | Tarefa pontual sem persona específica; expertise geral |
| `/mosk-analyst` | Discovery inicial, brief, pesquisa |
| `/mosk-architect` | Arquitetura técnica, stack, decisões estruturais |
| `/mosk-pm` | PRD, estratégia, feature specs (SpecKit completo) |
| `/mosk-po` | Backlog, épicos, stories com AC |
| `/mosk-sm` | Refinar stories para dev; garantir clareza para implementação |
| `/mosk-dev` | Implementar stories, spec-implement, Chore Mode |
| `/mosk-qa` | Revisão de qualidade, testes, NFR, quality gates |
| `/mosk-ux-expert` | UI/UX, wireframes, specs de front-end |

### SpecKit

| Comando | Dono | O que faz |
|---|---|---|
| `*spec-constitution` | PM (uma vez) | Deriva princípios do projeto a partir de PRD + arquitetura |
| `*spec-specify` | PM | Cria spec.md a partir de descrição em linguagem natural |
| `*spec-clarify` | PM | Resolve ambiguidades com até 5 perguntas direcionadas |
| `*spec-plan` | PM | Gera artefatos de design (data-model, contracts, research) |
| `*spec-analyze` | PM | Valida consistência cross-artifact (não-destrutivo) |
| `*spec-checklist` | PM | Gera checklist de qualidade por domínio (ux, api, security...) |
| `*spec-tasks` | PM | Gera tasks.md ordenado e acionável |
| `*spec-implement` | Dev | Executa todas as tarefas do tasks.md |

### Chore Mode

| Comando | O que faz |
|---|---|
| `*chore-proposal {id}` | Cria proposal.md + tasks.md em `docs/changes/{id}/` |
| `*chore-apply {id}` | Implementa a mudança aprovada |
| `*chore-archive {id}` | Encerra e arquiva a mudança |

---

## Sobre Este Repositório

Este repositório é o **master template** do MOSK. Não é uma aplicação compilada — é uma coleção de Markdown, YAML e Bash que é instalada em projetos via `npx degit`.

Não há build, testes ou linter. A validação acontece via execução das skills nos projetos que usam o MOSK.

Para contribuir ou manter o toolkit, edite os arquivos em `mosk/` e teste instalando em um projeto de exemplo.
