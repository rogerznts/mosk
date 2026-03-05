<!-- Powered by BMAD™ Core -->

# MOSK Knowledge Base

## Overview

MOSK (Mad Open Spec Kit) é um framework de Spec-Driven Development (SDD) que combina agentes de IA especializados com fluxos de trabalho estruturados. O sistema é modular, baseado em personas brasileiras e instalável em qualquer projeto via `npx degit`.

### Key Features

- **Sistema de Agentes Modular**: Agentes de IA especializados para cada papel no desenvolvimento
- **SpecKit**: Pipeline completo de especificação (spec-specify → spec-tasks → spec-implement)
- **Chore Mode**: Workflow leve para manutenção, bugfixes e GMUDs
- **Skill Integration**: Comandos slash nativos do Claude Code para ativação rápida
- **Spec-Driven**: Documentação guia tudo — consistência e rastreabilidade garantidas

### Quando usar MOSK

- **Novos Projetos (Greenfield)**: Desenvolvimento end-to-end com planejamento completo
- **Projetos Existentes (Brownfield)**: Adições de features e melhorias estruturadas
- **Manutenção e Bugfixes**: Chore Mode para mudanças rápidas e rastreáveis
- **Qualidade e Testes**: Fluxo QA integrado com gates de qualidade
- **Documentação**: PRDs, arquitetura, specs de features e stories com AC

## Como o MOSK Funciona

### O Método Core

MOSK transforma você no "Diretor de Produto" — dirigindo um time de agentes de IA especializados com nomes brasileiros através de workflows estruturados:

1. **Você Dirige, IA Executa**: Você fornece visão e decisões; agentes cuidam dos detalhes
2. **Agentes Especializados**: Cada agente domina um papel (PM, Dev, Arquiteto, etc.)
3. **SpecKit**: Pipeline de spec transforma linguagem natural em planos executáveis
4. **Chore Mode**: Para mudanças menores sem necessidade de spec completa

### Os Dois Workflows Principais

#### SpecKit (Features e Novos Projetos)

```text
spec-constitution  → princípios do projeto (run once, PM)
spec-specify       → criar spec.md da descrição (PO)
spec-clarify       → resolver ambiguidades (PO, opcional)
spec-plan          → data-model, contratos, research (PO)
spec-analyze       → consistência entre artefatos (PO, opcional)
spec-checklist     → checklist de qualidade por domínio (PO, opcional)
spec-tasks         → gerar tasks.md ordenado (PO)
spec-implement     → executar todas as tasks (Dev)
spec-archive {id}  → arquivar spec concluída em docs/specs/archive/ (Dev)
```

> **Tipos de spec** (prefixo no nome da branch e pasta):
> `feature` | `fix` | `hotfix` | `gmud` | `refactor` | `experimental`
> Pasta: `docs/specs/{###}-{tipo}-{nome}/` — Arquivadas: `docs/specs/archive/{###}-{tipo}-{nome}/`

### O Loop de Desenvolvimento (SpecKit)

```text
1. PO (Sara) → spec-specify + spec-tasks → cria spec e tasks
2. Você → Revisa e aprova spec/tasks
3. Dev (Jaime) → spec-implement → implementa todas as tasks
4. QA (Joaquim) → revisa e valida qualidade
5. Você → Verifica conclusão
6. Repita para próxima feature
```

### Por que Funciona

- **Specs como Fonte da Verdade**: Todos os agentes partem do mesmo documento
- **Especialização de Papéis**: Agentes não mudam de contexto = maior qualidade
- **Progresso Incremental**: Tasks pequenas = complexidade gerenciável
- **Supervisão Humana**: Você valida cada etapa = controle de qualidade
- **Rastreabilidade**: Specs guiam tudo = consistência e histórico

## Começando

### Instalação

```bash
# Instalar MOSK em um projeto alvo
npx degit rogerznts/mosk/mosk .
```

**Após a instalação**:

- `.claude/mosk/` criado com todos os agentes, tasks, templates e configurações
- `.claude/skills/` criado com 11 skill delegation files
- Comandos slash disponíveis imediatamente no Claude Code

### Ativação de Agentes

**Claude Code** (comandos slash):
- `/mosk-orchestrator` — Maestro, coordenador de workflows
- `/mosk-master` — Mestre, executor universal
- `/mosk-pm` — João, PRD e estratégia
- `/mosk-po` — Sara, backlog e SpecKit
- `/mosk-analyst` — Maria, discovery e pesquisa
- `/mosk-architect` — Vinicius, arquitetura
- `/mosk-dev` — Jaime, implementação e spec-archive
- `/mosk-qa` — Joaquim, qualidade e testes
- `/mosk-ux-expert` — Salete, UX e front-end specs
- `/mosk-sm` — Roberto, dev-readiness e agile guidance

### Guia de Seleção de Ambiente

**Use IDE (Claude Code) para**:

- Desenvolvimento ativo e codificação
- Operações de arquivo e integração com projeto
- Execução do SpecKit e Chore Mode
- Revisão de código e debugging

## Core Configuration (core-config.yaml)

O arquivo `.claude/mosk/core-config.yaml` é a configuração central do MOSK. Ele informa aos agentes onde encontrar documentos do projeto e como estão estruturados.

### Para que Serve o core-config.yaml?

- **Localização de Documentos**: Onde ficam PRD, arquitetura e specs
- **Sharding**: Configuração de fragmentação de documentos grandes
- **Contexto do Dev**: Quais arquivos o agente Dev sempre carrega (`devLoadAlwaysFiles`)
- **Debug**: Suporte a logs para troubleshooting

### Áreas de Configuração

#### Configuração de PRD

- **prdSharded**: Se epics estão embedados (false) ou em arquivos separados (true)
- **prdShardedLocation**: Onde encontrar os arquivos de epic shardados

#### Arquivos do Developer

- **devLoadAlwaysFiles**: Lista de arquivos que o agente Dev carrega em toda task
- **devDebugLog**: Onde o agente Dev loga falhas repetidas

### Por que Importa

1. **Sem Migrações Forçadas**: Mantenha sua estrutura de documentos existente
2. **Adoção Gradual**: Configure conforme necessário
3. **Agentes Inteligentes**: Agentes se adaptam automaticamente à sua configuração

## Sistema de Agentes

### Time de Desenvolvimento Core

| Agente | Nome | Papel | Função Principal | Quando Usar |
|---|---|---|---|---|
| `analyst` | Maria 🔍 | Business Analyst | Pesquisa, brainstorming, briefs | Descoberta, análise competitiva |
| `pm` | João 📋 | Product Manager | PRD, estratégia, spec-constitution | Planejamento estratégico |
| `ux-expert` | Salete 🎨 | UX Designer | UI/UX, wireframes, front-end specs | Experiência do usuário |
| `architect` | Vinicius 🏗️ | Solution Architect | Arquitetura de sistema | Sistemas complexos |
| `po` | Sara 📊 | Product Owner | Backlog, SpecKit pipeline, stories com AC | Especificação e refinamento |
| `sm` | Roberto 🏃 | Scrum Master | Dev-readiness, clareza técnica das stories | Validação de stories e agile guidance |
| `dev` | Jaime 💻 | Developer | spec-implement, spec-archive, debugging | Implementação |
| `qa` | Joaquim 🔬 | QA Specialist | Qualidade, testes, NFR | Validação e qualidade |

### Agentes Meta

| Agente | Nome | Papel | Função Principal | Quando Usar |
|---|---|---|---|---|
| `orchestrator` | Maestro 🎭 | Team Coordinator | Coordenação multi-agente, workflows | Tarefas multi-papel complexas |
| `master` | Mestre 🧙 | Universal Expert | Todas as capacidades sem troca de agente | Trabalho abrangente em sessão única |

### Responsabilidades por Agente

| Agente | Skill | SpecKit |
|---|---|---|
| João (pm) | `/mosk-pm` | `spec-constitution` apenas (run once) |
| Sara (po) | `/mosk-po` | Pipeline completo (specify→tasks) + stories com AC |
| Roberto (sm) | `/mosk-sm` | Garante dev-readiness das stories |
| Jaime (dev) | `/mosk-dev` | `spec-implement` + `spec-archive` |

## Configurações de Times

### Times Pré-construídos

#### Team All (`/mosk-team-all`)

- **Inclui**: Todos os 10 agentes + orchestrator
- **Uso**: Projetos completos que requerem todos os papéis

#### Team Fullstack (`/mosk-team-fullstack`)

- **Inclui**: orchestrator, analyst, pm, ux-expert, architect, po
- **Uso**: Desenvolvimento web/mobile end-to-end

#### Team No-UI (`/mosk-team-no-ui`)

- **Inclui**: orchestrator, analyst, pm, architect, po
- **Uso**: Serviços backend, APIs, desenvolvimento de sistema

#### Team IDE Minimal (`/mosk-team-ide`)

- **Inclui**: po, sm, dev, qa
- **Uso**: Ciclo mínimo para implementação no IDE

## Arquitetura Core

### Visão Geral do Sistema

O MOSK é organizado em torno do diretório `.claude/mosk/`, que serve como cérebro de todo o sistema. Esta estrutura permite ao framework operar efetivamente no IDE Claude Code.

### Componentes Arquiteturais

#### 1. Agentes (`.claude/mosk/agents/`)

- **Propósito**: Cada arquivo markdown define um agente de IA especializado
- **Estrutura**: Contém YAML com persona, capacidades e dependências do agente
- **Ativação**: Agents leem `core-config.yaml`, adotam persona, aguardam instruções

#### 2. Agent Teams (`.claude/mosk/agent-teams/`)

- **Propósito**: Definem coleções de agentes agrupados para propósitos específicos
- **Exemplos**: `team-all.yaml`, `team-fullstack.yaml`, `team-ide-minimal.yaml`

#### 3. Workflows (`.claude/mosk/workflows/`)

- **Propósito**: YAMLs definindo sequências de passos para tipos específicos de projeto
- **Tipos**: Greenfield e Brownfield para UI, serviço e fullstack

#### 4. Recursos Reutilizáveis

- **Templates** (`.claude/mosk/templates/`): Scaffolds de documentos em YAML
- **Tasks** (`.claude/mosk/tasks/`): Instruções para ações repetíveis (SpecKit, Chore Mode)
- **Checklists** (`.claude/mosk/checklists/`): Checklists de qualidade e validação
- **Data** (`.claude/mosk/data/`): Knowledge base e preferências técnicas

### Sistema de Templates

O MOSK utiliza um sistema de templates sofisticado:

1. **Formato de Template** (`utils/doc-template.md`): Define linguagem de markup para substituição de variáveis e diretivas de processamento de IA
2. **Criação de Documentos** (`tasks/create-doc.md`): Orquestra seleção de template e interação do usuário
3. **Elicitação Avançada** (`tasks/advanced-elicitation.md`): Refinamento interativo através de brainstorming estruturado

## Workflow de Desenvolvimento Completo

### Fase de Planejamento (IDE — Claude Code)

**Para Projetos Greenfield**:

1. **Análise Opcional**: `/mosk-analyst` → Maria — pesquisa de mercado, análise competitiva
2. **Project Brief**: Maria cria documento de briefing
3. **PRD**: `/mosk-pm` → João — `*spec-constitution` (uma vez por projeto) + `*create-doc prd`
4. **Arquitetura**: `/mosk-architect` → Vinicius — design técnico
5. **Validação**: `/mosk-po` → Sara — checklist mestre de consistência

**Para Projetos Brownfield**:

1. **Documentar sistema existente**: `/mosk-analyst` → Maria — `*document-project`
2. **PRD Brownfield**: `/mosk-pm` → João — `*create-doc brownfield-prd`
3. **Arquitetura de integração**: `/mosk-architect` → Vinicius

### IDE Development Workflow

**Pré-requisitos**: Documentos de planejamento existem na pasta `docs/`

#### Via SpecKit (único fluxo — features, fixes, GMUDs e refatorações)

```text
1. PO (Sara) → spec-specify: Criar spec.md com tipo adequado (feature/fix/hotfix/gmud/refactor/experimental)
2. PO (Sara) → spec-tasks: Gerar tasks.md ordenado
3. Você → Revisa e aprova spec + tasks
4. Dev (Jaime) → spec-implement: Executar todas as tasks
5. QA (Joaquim) → Revisão e validação
6. Dev (Jaime) → spec-archive: Arquivar spec concluída
7. Repetir para próxima feature
```

### Localização dos Documentos

Especificações ficam em `docs/specs/{###}-{tipo}-{nome}/`:
- `spec.md` — especificação da feature
- `plan.md` — plano técnico
- `tasks.md` — tasks ordenadas
- `data-model.md`, `research.md`, `contracts/` — opcionais

Specs arquivadas ficam em `docs/specs/archive/{###}-{tipo}-{nome}/`.

## Boas Práticas

### Nomenclatura de Documentos

- `docs/prd.md` — Product Requirements Document
- `docs/architecture.md` — System Architecture Document
- `docs/specs/{###}-{tipo}-{nome}/spec.md` — Feature/fix/gmud specifications (ativas)
- `docs/specs/archive/{###}-{tipo}-{nome}/` — Specs arquivadas (concluídas)

**Por que Esses Nomes Importam**:

- Agentes referenciam automaticamente esses arquivos durante o desenvolvimento
- Tasks de spec esperam esses nomes específicos
- Automação de workflow depende de nomenclatura padrão

### Gerenciamento de Qualidade

- Use agentes apropriados para tasks especializadas
- Siga o pipeline SpecKit para features novas
- Use Chore Mode para mudanças pequenas e rastreáveis
- Validação regular com checklists e QA

### Otimização de Performance

- Use agentes especializados vs. `master` para tasks focadas
- Aproveite preferências técnicas para consistência
- Mantenha conversas focadas — um agente, uma task

## Dicas de Sucesso

- **Siga o SpecKit para features**: O pipeline garante specs consistentes antes da implementação
- **Use Chore Mode para manutenção**: Rastreabilidade sem overhead de spec completa
- **Aproveite a especialização**: Cada agente tem persona e foco otimizados para sua função
- **Revise sempre**: Aprove specs e tasks antes de iniciar implementação
- **Mantenha conversas focadas**: Um agente, uma task por conversa

## Obtendo Ajuda

- **Comandos**: Use `*help` em qualquer agente para ver comandos disponíveis
- **Troca de Agente**: Use `/mosk-orchestrator` (Maestro) para orientação sobre qual agente usar
- **Documentação**: Verifique a pasta `docs/` para contexto específico do projeto
- **Instalação**: `npx degit rogerznts/mosk/mosk .` — instalar MOSK em novo projeto
