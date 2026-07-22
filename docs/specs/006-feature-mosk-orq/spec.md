# Feature Specification: `/mosk-orq` — orquestrador de agentes sobre Herdr

**Feature Branch**: `006-feature-mosk-orq`
**Created**: 2026-07-22
**Status**: Draft
**Input**: User description: "orquestrador de agentes MOSK sobre Herdr"

## Contexto

Hoje o pipeline MOSK (`specify → plan → tasks → implement → qa-gate → archive`)
roda numa única sessão: o humano troca de agente na mão e, por invariante
(Escalation Policy / ADR-0006), nenhum agente invoca outro.

O ambiente-alvo roda sobre o **Herdr** (herdr.dev), um multiplexer de agentes com
control API (CLI + socket) capaz de spawnar panes, injetar input, esperar estado
(`idle`), ler a saída e fechar panes. O `pipeline-graph.yaml` já distingue
`mode: skill` (contexto compartilhado) de `mode: agent` (isolado/paralelo), mas
não havia executor para esse `mode`.

`/mosk-orq` é o executor que faltava: um orquestrador **opt-in** que usa o Herdr
como *atuador* e o grafo do MOSK como *cérebro*, conduzindo o pipeline de UM
projeto entre panes com **handoff automático**.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Conduzir o pipeline entre panes com handoff automático (Priority: P1)

Como mantenedor do MOSK, quero invocar `/mosk-orq` e deixar que ele conduza o
pipeline de um projeto entre panes do Herdr, fazendo handoff quando a fase muda
de agente ou quando o contexto do agente atual estoura, para não precisar
trocar de agente e recompactar contexto na mão.

**Why this priority**: É o núcleo da feature — sem o loop de handoff automático
entre panes, nada mais tem valor.

**Independent Test**: Rodar `/mosk-orq semi-auto` num spec de teste com o `herdr`
disponível e observar um handoff completo (agente sai idle → `/mosk-handoff` →
novo pane com o próximo agente recebendo o documento de transição).

**Acceptance Scenarios**:

1. **Given** um projeto com `current_phase` cujo próximo nó pertence a outro
   agente, **When** o agente atual fica `idle`, **Then** o orquestrador roda
   `/mosk-handoff`, spawna um novo pane com o próximo agente e injeta o prompt
   apontando para o handoff — em `semi-auto`, pedindo ok antes.
2. **Given** um agente cujo total de tokens atinge o teto configurado, **When**
   ele fica `idle`, **Then** o orquestrador faz handoff para um novo pane do
   MESMO agente/fase (refresh de contexto), automaticamente nos dois modos.

---

### User Story 2 - Menu de ativação quando chamado sem comando (Priority: P2)

Como usuário, quando invoco `/mosk-orq` **sem** um comando direto, quero um menu
básico com os agentes iniciais que ele pode orquestrar e uma pergunta sobre o
que fazer, em vez de ele já sair atuando.

**Why this priority**: Segurança de UX e alinhamento à convenção MOSK ("menu é
fallback de ativação vazia"). Evita ação não intencional.

**Independent Test**: Invocar `/mosk-orq` sem argumentos e verificar que ele
exibe o menu derivado do grafo e aguarda a escolha, sem tocar em nenhum pane.

**Acceptance Scenarios**:

1. **Given** invocação sem argumento, **When** a skill ativa, **Then** ela
   exibe um menu derivado do grafo (agentes iniciais) e pergunta o modo/alvo.
2. **Given** invocação com comando direto (`full-auto 006`), **When** a skill
   ativa, **Then** ela pula o menu e segue direto para a resolução do alvo.

---

### User Story 3 - Degradação graciosa sem o Herdr (Priority: P3)

Como consumidor do template MOSK que **não** usa Herdr, quero que a skill não
quebre: se o `herdr` não estiver no PATH, ela me avisa e cai numa orientação
single-pane estilo `/mosk-suggestion`.

**Why this priority**: O template ships para todos; o Herdr é dependência
externa opcional. Não pode virar hard-fail.

**Independent Test**: Rodar `herdr.sh check` com o `herdr` fora do PATH e
verificar mensagem clara + exit ≠ 0; a skill cai no fallback.

**Acceptance Scenarios**:

1. **Given** `herdr` ausente do PATH, **When** `/mosk-orq` ativa, **Then** ela
   informa a ausência (com dica de instalação) e degrada para sugestão manual,
   sem erro fatal.

### Edge Cases

- O contador nativo de tokens não é parseável na leitura do pane → o sensor
  reporta `over=unknown` e não dispara o gatilho de teto (nunca bloqueia).
- Um `judgment` guard aparece na jogada legal → pausa e devolve ao humano em
  AMBOS os modos (inclusive `full-auto`).
- `qa-gate` retorna `FAIL`/`CONCERNS` → pausa e devolve ao humano.
- Pane worker não encontrado para o projeto → o orquestrador spawna um novo.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: A skill MUST ser **opt-in** e skill-only (sem persona de agente).
- **FR-002**: A skill MUST aceitar o modo de autonomia como argumento
  (`full-auto` | `semi-auto`); default configurável em `core-config.yaml`.
- **FR-003**: Sem comando direto, a skill MUST exibir um menu de ativação
  derivado do grafo e aguardar escolha, sem atuar.
- **FR-004**: O orquestrador MUST derivar a próxima jogada de `legal_moves.sh` /
  `pipeline-graph.yaml` — nunca de tabela hardcoded.
- **FR-005**: O orquestrador MUST esperar o agente ficar `idle` antes de
  qualquer handoff.
- **FR-006**: O handoff MUST usar `/mosk-handoff` no pane que sai e injetar o
  documento gerado no próximo pane.
- **FR-007**: O gatilho de handoff MUST disparar quando (a) o próximo nó pertence
  a outro agente, ou (b) `tokens_usados ≥ context_token_ceiling`.
- **FR-008**: Em `semi-auto`, o orquestrador MUST pedir confirmação antes de
  cada mudança de fase/agente; o refresh por teto é automático.
- **FR-009**: Em AMBOS os modos, o orquestrador MUST pausar e devolver ao humano
  em `judgment` guard, veredito de gate e erro.
- **FR-010**: O orquestrador MUST apenas LER `current_phase` (as tasks de fase
  é que escrevem), para não duplicar estado.
- **FR-011**: Sem `herdr` no PATH, a skill MUST degradar graciosamente (aviso +
  fallback), sem hard-fail.

### Key Entities

- **Pane worker**: um pane do Herdr rodando um agente MOSK num projeto (cwd +
  título + `agent_status`), o registro vivo vindo de `herdr agent list`.
- **Handoff doc**: arquivo em `docs/handoff/` produzido por `/mosk-handoff`,
  transporte de contexto entre panes.
- **Jogada legal**: saída de `legal_moves.sh` (nó destino + agente dono + guards).

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Um handoff por troca-de-agente completa ponta a ponta sem
  intervenção manual além do ok (em `semi-auto`).
- **SC-002**: Com o teto rebaixado para teste, o gatilho de contexto dispara o
  refresh da mesma fase de forma determinística.
- **SC-003**: Com `herdr` ausente, 0 erros fatais — a skill sempre cai no
  fallback com mensagem acionável.
- **SC-004**: `lint-graph.sh` permanece limpo e os scripts de sync deixam
  `AGENTS.md`/`.codex` coerentes após adicionar a skill.

## Fora de escopo (v2)

Multi-projeto (N workspaces em paralelo, prioridade, concorrência de panes);
sensor de tokens via hook/statusline gravando em arquivo.
