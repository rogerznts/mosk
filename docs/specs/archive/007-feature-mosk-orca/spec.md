# Feature Specification: Orca como backend de orquestração do `/mosk-orq`

**Feature Branch**: `007-feature-mosk-orca`
**Created**: 2026-07-25
**Status**: Draft
**Input**: User description: "compatibilidade do /mosk-orq com o Orca como backend de orquestracao"

## Contexto

O `/mosk-orq` (Mauro, ADR-0009) nasceu com o **Herdr** como atuador único:
`scripts/herdr.sh` spawna panes, injeta input, espera `idle`, mede tokens e
fecha panes. O *cérebro* (`pipeline-graph.yaml` via `legal_moves.sh`) e o
*transporte de contexto* (`/mosk-handoff`) já são agnósticos — só o atuador
está acoplado a um multiplexer específico.

O ambiente de trabalho migrou para o **Orca** (onorca.dev), um ADE que roda
agentes em worktrees isolados, com CLI própria (`orca terminal …`,
`orca worktree …`) e uma camada de orquestração estruturada
(`orca orchestration …`). Num terminal do Orca, `herdr.sh check` falha e o
Mauro fica inerte: degrada para o fluxo single-pane e a feature inteira
some.

O Orca cobre integralmente o contrato mecânico do `herdr.sh` e oferece, acima
dele, primitivas que o Herdr não tem e que mapeiam quase 1:1 no modelo MOSK:
task DAG com dependências, dispatch com preâmbulo de lifecycle, espera por
evento (`worker_done`) em vez de polling, e decision gates.

Esta spec torna o atuador **plugável**: o Mauro passa a funcionar igual sobre
Herdr **ou** Orca, com detecção automática, sem alterar a invariante do
ADR-0006 (o humano decide toda bifurcação de julgamento) e sem quebrar
consumidores que usam Herdr ou nenhum dos dois.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Conduzir o pipeline dentro do Orca (Priority: P1)

Como mantenedor que trabalha em worktrees do Orca, quero invocar `/mosk-orq` e
tê-lo conduzindo o pipeline entre terminais do Orca exatamente como faria entre
panes do Herdr, sem precisar saber qual backend está ativo.

**Why this priority**: É o núcleo. Sem isso, o `/mosk-orq` simplesmente não
existe no ambiente onde o trabalho acontece hoje.

**Independent Test**: Rodar `/mosk-orq semi-auto` numa spec de teste dentro de
um terminal do Orca e observar um handoff completo (worker fica idle →
`/mosk-handoff` → novo terminal com o próximo agente recebendo o documento de
transição).

**Acceptance Scenarios**:

1. **Given** uma sessão dentro de um terminal gerenciado pelo Orca, **When** o
   usuário invoca `/mosk-orq`, **Then** a verificação de atuador detecta o Orca
   automaticamente e o loop de orquestração roda — sem o `herdr` instalado.
2. **Given** um worker aberto pelo Mauro no Orca, **When** o próximo nó do grafo
   pertence a outro agente e o worker fica idle, **Then** o Mauro roda
   `/mosk-handoff`, abre o terminal do próximo agente, injeta o prompt apontando
   para o documento de handoff e fecha o terminal que saiu.
3. **Given** o Mauro rodando no Orca, **When** ele precisa de um worker,
   **Then** ele permanece no terminal atual e nunca abre um terminal para si
   mesmo.

---

### User Story 2 - Trocar de backend sem tocar no agente (Priority: P1)

Como mantenedor do MOSK, quero que o `orq.md` fale com uma fachada única e que
a escolha do backend seja resolvida por script, para que adicionar ou trocar de
atuador não exija reescrever o prompt do agente.

**Why this priority**: É o que impede a feature de virar dois orquestradores
paralelos divergindo com o tempo. Sem a fachada, cada backend novo duplica o
`orq.md`.

**Independent Test**: `bash .claude/mosk/scripts/panes.sh driver --json` retorna
o backend escolhido e o motivo; forçar `orchestration.driver: herdr` no
`core-config.yaml` faz o loop antigo voltar sem nenhuma edição no `orq.md`.

**Acceptance Scenarios**:

1. **Given** ambos os backends disponíveis, **When** o dispatcher resolve o
   driver, **Then** vence o ambiente em que a sessão está rodando (variáveis
   `ORCA_*` ou `HERDR_*`), e um `driver:` explícito na config vence tudo.
2. **Given** `orchestration.driver: herdr`, **When** o Mauro roda no Orca,
   **Then** o backend usado é o Herdr — o override é respeitado.
3. **Given** um subcomando qualquer do contrato, **When** ele é chamado via
   `panes.sh` em cada backend, **Then** a saída tem o mesmo formato nos dois
   (mesmos campos JSON, mesmo identificador em stdout no `spawn`).

---

### User Story 3 - Degradar sem atuador nenhum (Priority: P2)

Como consumidor do template que não usa Herdr nem Orca, quero que o `/mosk-orq`
me diga isso com clareza e caia no fluxo single-pane, em vez de falhar.

**Why this priority**: Protege a maioria dos consumidores do template, para quem
os dois backends são dependência externa opcional.

**Independent Test**: Com o app Orca fechado e sem `herdr` no PATH,
`panes.sh check` falha com dica de instalação dos dois backends e `/mosk-orq`
se comporta como `/mosk-suggestion`.

**Acceptance Scenarios**:

1. **Given** nenhum atuador disponível, **When** o Mauro é invocado, **Then** ele
   informa a ausência, mostra as dicas de instalação e entrega um prompt pronto
   para o humano colar — nunca hard-fail.

---

### User Story 4 - Rastreabilidade nativa do Orca (Priority: P3, opt-in)

Como mantenedor, quero opcionalmente usar a camada de orquestração nativa do
Orca (task DAG, dispatch injetado, decision gates, `worker_done`) para ter
provenance verificável e espera por evento em vez de polling.

**Why this priority**: Ganho real, mas não é pré-requisito para o Mauro
funcionar no Orca. Fica atrás de tudo que é paridade.

**Independent Test**: Com `native_tasks: true`, após um dispatch,
`orca orchestration task-list --json` e `dispatch-show --task <id> --json`
mostram a task — a prova de provenance que a própria skill nativa exige.

**Acceptance Scenarios**:

1. **Given** `native_tasks: true` e runtime do Orca com a feature experimental
   habilitada, **When** o Mauro despacha uma fase, **Then** existe uma task com
   `taskId`/`dispatchId` rastreável e o worker sinaliza `worker_done` ao
   terminar.
2. **Given** um `judgment` guard ou um veredito de gate FAIL/CONCERNS, **When** o
   Mauro cria o decision gate correspondente, **Then** ele **apresenta ao
   humano** e só chama `gate-resolve` com a resposta recebida — nunca resolve
   sozinho, e o coordinator loop autônomo do Orca (`orchestration run`) não é
   usado.
3. **Given** `native_tasks: false` (padrão), **When** o loop roda, **Then** o
   comportamento é idêntico ao da paridade — nenhuma task é criada.

---

### Edge Cases

- **`orca` é o leitor de tela do GNOME.** No Linux, fora de um terminal do Orca,
  `orca` normalmente resolve para `/usr/bin/orca` e começa a **falar** na
  máquina do usuário. A resolução do binário precisa ser explícita
  (`$ORCA_CLI_COMMAND` → `orca-dev` → `orca-ide` → `orca`) e recusar-se a rodar
  quando o único candidato for o screen reader.
- **Runtime do Orca fora do ar.** O binário existe mas o app não está rodando
  (`runtime_unavailable`): `check` deve falhar como "atuador indisponível", não
  como "Orca não instalado" — a dica ao usuário é diferente.
- **Contador de tokens ausente.** O Orca não expõe tokens; o parse da TUI
  continua sendo a fonte e, quando não casa, o gatilho de teto é ignorado
  (`over=unknown`) sem bloquear a troca-de-agente.
- **Handle de terminal renovado.** O Orca pode reemitir o handle de um terminal
  após restart; o Mauro re-resolve via `terminal list` em vez de tratar handle
  antigo como worker morto.
- **Branch de worktree pessoal.** Cada worktree do Orca tem branch próprio (ex.:
  `rogerznts/master`) e a base fica ocupada por outro worktree, o que bloqueava
  a criação de specs.
- **Ambos os backends presentes.** O desempate é o ambiente da sessão, não a
  ordem alfabética.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: O sistema MUST oferecer um driver Orca que implemente o mesmo
  contrato de subcomandos do `herdr.sh` (`check | tokens | spawn | send |
  wait-idle | read | close | managed`), com os mesmos flags e o mesmo formato de
  saída.
- **FR-002**: O driver Orca MUST resolver o executável na ordem
  `$ORCA_CLI_COMMAND` → `orca-dev` (quando `$ORCA_DEV_REPO_ROOT`) → `orca-ide` →
  `orca`, e MUST recusar-se a executar quando o único candidato for
  `/usr/bin/orca`.
- **FR-003**: O sistema MUST oferecer um dispatcher único (`panes.sh`) que
  resolva o backend e delegue o argv inalterado, expondo o subcomando `driver`
  para inspeção.
- **FR-004**: A resolução do backend MUST seguir a precedência: `driver:` na
  config → ambiente da sessão (`ORCA_*` / `HERDR_*`) → primeiro `check` que
  passar → `none`.
- **FR-005**: O `orq.md` MUST falar exclusivamente com o dispatcher, sem chamar
  `herdr.sh` ou `orca` diretamente.
- **FR-006**: A configuração MUST expor `orchestration.driver` e
  `orchestration.orca.{enabled,native_tasks}` preservando a chave
  `orchestration.herdr` já existente, para não quebrar instalações atuais.
- **FR-007**: Sem atuador disponível, o sistema MUST degradar para o fluxo
  single-pane com dica de instalação dos dois backends, sem hard-fail.
- **FR-008**: Com `native_tasks: true`, o sistema MUST usar task/dispatch/gates
  do Orca e MUST manter a decisão de julgamento com o humano — o orquestrador
  cria o gate e só o resolve com a resposta recebida; `orchestration run` NÃO é
  usado.
- **FR-009**: Subcomandos nativos MUST responder `unsupported` (sem falhar o
  fluxo) quando o backend ativo for o Herdr.
- **FR-010**: `create-new-feature.sh` MUST aceitar como base um branch que
  aponte para o mesmo commit de uma base branch conhecida, mantendo intactos os
  bloqueios por padrão de ambiente/release e por branch de spec (`^[0-9]{3}-`).
- **FR-011**: A skill `mosk-orq` MUST ter gatilhos de invocação que citem tanto
  Herdr quanto Orca.
- **FR-012**: O `herdr.sh` MUST permanecer funcionalmente intacto como backend.

### Key Entities

- **Driver / backend**: implementação concreta do atuador (`herdr` | `orca` |
  `none`). Escolhido por config ou detecção.
- **Contrato de pane**: o conjunto de subcomandos que todo backend implementa.
  O identificador opaco de pane/terminal circula como string única.
- **Camada nativa (opt-in)**: task, dispatch e gate do Orca — provenance e
  espera por evento, desligados por padrão.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: `/mosk-orq` conduz um handoff completo entre fases dentro do Orca,
  sem o `herdr` instalado.
- **SC-002**: Todos os 8 subcomandos do contrato produzem saída de mesmo formato
  nos dois backends.
- **SC-003**: A troca de backend não exige nenhuma edição no `orq.md` — só
  mudar `orchestration.driver`.
- **SC-004**: Em nenhum caminho de execução o `/usr/bin/orca` é invocado.
- **SC-005**: Com os dois backends ausentes, o `/mosk-orq` responde com
  orientação single-pane e exit não-fatal.
- **SC-006**: Com `native_tasks: false`, o comportamento observável é idêntico
  ao anterior a esta spec para usuários de Herdr.

## Fora de escopo

- `create-new-feature.sh` criar/registrar um worktree do Orca por spec.
- Multi-projeto (N worktrees em paralelo) — já era limite do ADR-0009.
- Sensor de tokens via hook/statusline em arquivo, no lugar do parse da TUI.
- Backends adicionais (tmux, zellij): o dispatcher deixa o encaixe pronto, mas
  eles não serão implementados aqui.

---
**Arquivado em:** 2026-07-25
**Status final:** Concluído com ressalva (gate `CONCERNS` + waiver explícito)
**Promoções aplicadas:** 1 `copy` — `adr-0010-orca-backend.md` →
`docs/architecture/adr/`. Nenhum `append`, nenhum `manual` pendente.
**Ressalva:** T17–T20 (validação contra o runtime do Orca) não puderam ser
executadas — bug de terceiro no Orca 1.4.155 impede o CLI de alcançar o runtime.
Ver `gate.yaml` (QA-1/QA-2) e a nota de ambiente em `tasks.md`.
