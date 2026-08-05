# Feature Specification: Operação em loops e grafos + Orca como atuador único

**Feature Branch**: `010-feature-graph-loop-orca`
**Created**: 2026-08-04
**Status**: Draft
**Input**: User description: "Operação melhor ajustada em loops e grafos, principalmente na parte do desenvolvimento; e o Orca, com remoção do Herdr."

## Contexto

Discovery em `docs/discovery/graph-loop-engineering-brief.md`. Decisões em
[ADR-0012](../../architecture/adr/adr-0012-route-decision-vs-phase-execution.md)
(fronteira rota × execução),
[ADR-0013](../../architecture/adr/adr-0013-fanout-seam-three-tiers.md)
(seam de fan-out em três tiers) e
[ADR-0014](../../architecture/adr/adr-0014-orca-single-actuator.md)
(Orca único e opcional).

O MOSK já tem grafo (ADR-0006/0007) e já tem loop (ADR-0008) — na granularidade
de **fases**, não de **trabalho**. Esta spec desce um nível: torna executável o
`[P]` que o `tasks.md` já produz, e torna o verificador independente de quem
implementou.

## User Scenarios & Testing

### User Story 1 - Orca único e correto (Priority: P1)

Como operador do `/mosk-orq`, quero que a orquestração use só o Orca e sem os
defeitos atuais, para que workers não fiquem pendurados nem tenham mensagens
reprocessadas.

**Why this priority**: contém dois **defeitos ativos**, não melhorias — a espera
por eventos nunca reconhece (`ack`) a Delivery processada, então o mesmo lote é
reentregue a cada janela; e não escuta `question`, então um worker que faz `ask`
fica bloqueado até o timeout. Além disso é independente das demais US e é
pré-requisito do Tier 1 da US3.

**Independent Test**: rodar `/mosk-orq` numa spec real dentro da IDE do Orca; um
worker que emite `ask` deve acordar o coordenador, e uma mesma mensagem não pode
aparecer em duas janelas consecutivas.

**Acceptance Scenarios**:

1. **Given** um worker que emitiu `ask`, **When** o coordenador está em janela de
   espera, **Then** a pergunta o acorda e é apresentada ao humano.
2. **Given** uma Delivery processada, **When** a próxima janela de espera abre,
   **Then** o mesmo lote não é reentregue.
3. **Given** uma instalação com `orchestration.driver: herdr`, **When** o atuador
   é resolvido, **Then** falha com mensagem de migração — nunca degrada em
   silêncio.
4. **Given** o binário do Orca no PATH e a sessão **fora** da IDE, **When**
   `driver` é `auto`, **Then** resolve para `none` — nunca abre terminais num app
   que o usuário não está usando.
5. **Given** `driver: orca` explícito e sessão fora da IDE, **When** o atuador é
   resolvido, **Then** o override é honrado.

---

### User Story 2 - Verificador independente e score no gate (Priority: P2)

Como responsável pela qualidade, quero que quem verifica não seja quem
implementou, e quero enxergar a trajetória entre voltas do loop, para confiar no
veredito e saber quando parar de tentar.

**Why this priority**: é pré-requisito do fan-out — sem verificação confiável,
disparar ramos em paralelo multiplica retrabalho. Independente da US1.

**Independent Test**: rodar `implement` e depois `qa-gate` numa spec com um
critério de aceite deliberadamente não atendido; o gate deve reprovar mesmo que o
`implement` tenha considerado o item entregue.

**Acceptance Scenarios**:

1. **Given** uma fase de implementação concluída, **When** os critérios de aceite
   são verificados, **Then** a verificação roda em contexto limpo, sem o histórico
   de decisões de quem implementou.
2. **Given** um gate emitido, **When** o `gate.yaml` é lido, **Then** contém um
   `score` de 0 a 100 ao lado do `status`.
3. **Given** duas voltas do delivery-loop com o mesmo `status: FAIL`, **When** o
   humano decide a próxima jogada, **Then** os scores das duas voltas estão
   visíveis, distinguindo progresso de estagnação.
4. **Given** um `score` abaixo do corte configurado, **When** o gate é decidido,
   **Then** o `status` continua sendo o único árbitro de terminação — o score
   nunca decide sozinho.

---

### User Story 3 - Fan-out no `implement` (Priority: P3)

Como desenvolvedor, quero que tarefas marcadas `[P]` rodem em paralelo, cada uma
isolada e verificada, para concluir uma fase em fração do tempo.

**Why this priority**: é o coração do pedido, e depende de US1 (Tier 1) e US2
(verificação por ramo).

**Independent Test**: numa spec com 4+ tarefas `[P]` em arquivos distintos,
aprovar o plano de fan-out e observar as unidades progredirem concorrentemente,
com um único consolidado ao final.

**Acceptance Scenarios**:

1. **Given** um `tasks.md` com tarefas `[P]`, **When** `implement` inicia,
   **Then** apresenta um **plano de fan-out** — unidades, agrupamento, critério de
   aceite, teto e o equivalente sequencial — e **aguarda** aprovação.
2. **Given** um plano aprovado, **When** as unidades são despachadas, **Then**
   nenhuma aprovação adicional é pedida por ramo.
3. **Given** uma onda em andamento, **When** um ramo encontra guard `judgment`,
   escalação ou esgota seu teto, **Then** **aquele ramo** é suspenso e devolvido
   ao humano, e os demais seguem.
4. **Given** todas as unidades assentadas, **When** o join fecha, **Then** o
   consolidado volta ao humano e nenhuma onda seguinte inicia sozinha.
5. **Given** que o humano recusa o paralelismo, **When** `implement` prossegue,
   **Then** executa o caminho sequencial equivalente sem bloquear a fase.
6. **Given** uma unidade que estoura o circuit breaker do atuador, **When** o join
   consolida, **Then** ela é reportada como unidade falha e **não** consome uma
   volta do delivery-loop.
7. **Given** um ambiente sem Orca e sem subagente nativo, **When** a onda roda,
   **Then** degrada para sequencial com o mesmo resultado observável.

---

### User Story 4 - Grafo consolidado (Priority: P4)

Como mantenedor do MOSK, quero que fan-out e join existam no vocabulário do
grafo, para que a topologia continue tendo fonte única.

**Why this priority**: consolidação. O fan-out funciona sem isso (US3), mas o
grafo passaria a mentir sobre o comportamento real — o que o ADR-0006 existe para
impedir.

**Independent Test**: `legal_moves.sh implement` apresenta a jogada paralela
quando ela existe, e o mermaid derivado do grafo mostra o fan-out.

**Acceptance Scenarios**:

1. **Given** o `pipeline-graph.yaml`, **When** um nó admite fan-out, **Then** isso
   é declarado no dado e o `parallel_with` hoje decorativo ganha semântica.
2. **Given** uma fase que admite fan-out, **When** `legal_moves.sh` é consultado,
   **Then** a jogada paralela aparece entre as legais.
3. **Given** o glossário, **When** consultado, **Then** define "onda" e desambigua
   *handoff* — no Orca, transferir posse e parar de supervisionar; no MOSK,
   transportar contexto sob supervisão.

---

### User Story 5 - Numeração de spec correta (Priority: P5)

Como usuário do toolkit, quero que a numeração de specs não seja corrompida por
nomes de branch comuns nem por zeros à esquerda.

**Why this priority**: independente e trivial — duas correções pontuais —, mas
afeta toda criação de spec futura. Encaixa em qualquer ponto da entrega. Ambos os
defeitos foram observados ao criar **esta** spec.

**Independent Test**: com um branch local chamado `fix/issue-123-foo` presente,
criar uma spec e conferir que o número não pula; criar com `--number 010` e
conferir que resulta em `010`, não `008`.

**Acceptance Scenarios**:

1. **Given** um branch local cujo nome contém `NNN-` fora do início (ex.:
   `docs/adr-0012-0014-x`), **When** o próximo número é calculado, **Then** esse
   branch é ignorado.
2. **Given** `--number 010`, **When** o número é interpretado, **Then** vale 10 em
   base 10, não 8 em octal.

---

### Edge Cases

- Orca instalado e sessão **fora** da IDE → `auto` resolve `none`; o fan-out cai
  para Tier 2 ou 3.
- Orca dentro da IDE com a orquestração **experimental desligada** → degrada para
  Tier 2 **sem erro**; o diagnóstico diz qual configuração habilitar.
- `[P]` marcado em tarefas que na verdade colidem no mesmo arquivo → em dúvida,
  sequencial; o marcador é honrado estritamente, nunca inferido.
- Ramo silencioso por muito tempo → timeout de espera é **checkpoint**, não falha;
  tarefas longas rodam de 15 a 60 minutos.
- Instalação existente com a chave `orchestration.herdr` no `core-config.yaml` →
  chave órfã não quebra a leitura; só `driver: herdr` falha.
- Onda inteira recusada pelo humano → caminho sequencial; a fase não bloqueia.
- Gate escrito fora do caminho per-spec → o loop fica cego ao veredito; o
  `gate.yaml` per-spec permanece o local canônico.

## Requirements

### Functional Requirements

**Atuador (US1)**

- **FR-001**: O sistema MUST remover `herdr.sh` e toda referência ao Herdr como
  backend suportado, preservando ADRs e specs arquivadas como registro histórico.
- **FR-002**: `panes.sh` MUST permanecer como fachada única, incluindo a
  degradação `none`.
- **FR-003**: `orchestration.driver` MUST aceitar apenas `auto | orca | none`, e
  MUST falhar com mensagem de migração ao encontrar `herdr`.
- **FR-004**: Em `auto`, o atuador MUST ser eleito apenas quando a sessão roda
  dentro da IDE do Orca **e** o `check` passa; presença de binário isolada NÃO é
  suficiente.
- **FR-005**: `panes.sh driver` MUST distinguir no diagnóstico: binário ausente ·
  fora da IDE · orquestração experimental desligada · desligado por config.
- **FR-006**: `orchestration.orca.native_tasks` MUST passar a `auto`, mantendo
  `on`/`off` explícitos.
- **FR-007**: A espera por eventos MUST reconhecer (`ack`) a Delivery processada
  antes de abrir a janela seguinte.
- **FR-008**: A espera por eventos MUST incluir `question` entre os tipos que a
  despertam.
- **FR-009**: O coordenador MUST criar ou vincular uma Run antes de criar Tasks.
- **FR-010**: O wrapper MUST expor `ask` e `reply`, e os guards `judgment` e
  blocos de escalação MUST usá-los quando o Tier 1 estiver ativo.
- **FR-011**: O wrapper MUST usar o caminho supervisionado composto para iniciar
  workers, e a leitura tipada de transcript em vez de leitura de terminal cru.
- **FR-012**: O `orq.md` MUST consultar o guia versionado servido pelo binário em
  vez de reproduzir a grammar do Orca no prompt.
- **FR-013**: `selftest-orca-driver.sh` MUST cobrir os caminhos novos.

**Loop (US2)**

- **FR-014**: `implement` MUST NOT verificar os próprios critérios de aceite; a
  verificação MUST rodar em contexto limpo.
- **FR-015**: `qa-gate` MUST ser declarado `mode: agent` no grafo.
- **FR-016**: `gate.yaml` MUST conter um `score` inteiro de 0 a 100.
- **FR-017**: O corte do score MUST ser configurável, com default 85.
- **FR-018**: O `status` MUST permanecer o único árbitro de terminação do
  delivery-loop; o `score` é observação.
- **FR-019**: A apresentação do loop MUST exibir o score das voltas anteriores
  junto do contador `tentativa N/max`.

**Fan-out (US3)**

- **FR-020**: `implement` MUST derivar o plano de fan-out dos marcadores `[P]` do
  `tasks.md`, sem inferir paralelismo por conta própria.
- **FR-021**: O plano de fan-out MUST ser apresentado e aprovado **uma vez** antes
  do disparo, contendo unidades, agrupamento, critério de aceite, teto e o
  equivalente sequencial.
- **FR-022**: Nenhuma aprovação adicional MUST ser pedida por ramo durante a onda.
- **FR-023**: Guard `judgment`, escalação ou esgotamento de teto MUST suspender
  **apenas o ramo** afetado.
- **FR-024**: O join MUST fechar somente quando toda unidade assentar, e MUST
  devolver o consolidado ao humano.
- **FR-025**: Nenhuma onda MUST iniciar automaticamente a partir do resultado de
  outra.
- **FR-026**: O seam MUST selecionar um único tier por onda, por capacidade
  detectada, degradando sem erro.
- **FR-027**: `current_phase` MUST NOT se ramificar; o `phase-history.log` MUST
  receber uma entrada por onda.
- **FR-028**: Falha de dispatch (circuit breaker do atuador) MUST ser reportada
  como unidade falha e MUST NOT consumir volta do delivery-loop.

**Grafo (US4)**

- **FR-029**: `pipeline-graph.yaml` MUST declarar fan-out e join, dando semântica
  ao `parallel_with`.
- **FR-030**: `legal_moves.sh` MUST apresentar a jogada paralela quando legal.
- **FR-031**: O glossário MUST definir "onda" e desambiguar *handoff*.

**Numeração (US5)**

- **FR-032**: O cálculo do próximo número MUST considerar apenas o prefixo
  numérico no **início** do nome do branch local.
- **FR-033**: `--number` MUST ser interpretado em base 10, aceitando zeros à
  esquerda.

### Key Entities

- **Plano de fan-out**: artefato apresentado ao humano antes de uma onda —
  unidades, agrupamento e dependências, critério de aceite, teto e alternativa
  sequencial. Aprová-lo é uma decisão de rota.
- **Onda**: conjunto de unidades despachadas juntas dentro de uma fase, encerrado
  por um join. Registra uma entrada no `phase-history.log`.
- **Unidade de trabalho**: uma tarefa do `tasks.md` executada isoladamente, que
  devolve status curto — nunca transcript.
- **Score do gate**: inteiro de 0 a 100 no `gate.yaml`, ao lado do `status`.
  Observação de trajetória, não gatilho de terminação.

## Success Criteria

### Measurable Outcomes

- **SC-001**: Numa fase com N tarefas `[P]` independentes, o tempo de parede é
  significativamente menor que a soma das execuções individuais, com uma única
  aprovação humana antes do disparo.
- **SC-002**: Zero mensagens reprocessadas entre janelas consecutivas de espera.
- **SC-003**: Um worker que emite `ask` é atendido sem depender de timeout.
- **SC-004**: Um critério de aceite não atendido é reprovado pelo gate mesmo
  quando o `implement` o considerou entregue.
- **SC-005**: Em três ambientes distintos — dentro da IDE do Orca · Claude Code
  sem Orca · runtime sem subagente — a mesma spec produz o mesmo conjunto de
  artefatos e o mesmo veredito.
- **SC-006**: Nenhum caminho de degradação produz erro fatal; cada um informa a
  causa e a ação corretiva.
- **SC-007**: O contador `tentativa N/max` não é alterado pela introdução do
  fan-out — uma onda equivale a uma entrada no log.
- **SC-008**: Criar uma spec com branches locais contendo `NNN-` fora do início
  produz o número sequencial esperado.

## Assumptions and defaults

- Corte do score default **85**, configurável — alinhado ao critério do estudo de
  origem.
- O `[P]` do `tasks.md` mantém a semântica atual (arquivos distintos, sem
  dependências); a spec não redefine o marcador, apenas passa a honrá-lo.
- Os dois tetos de retry — circuit breaker do atuador e `max_retries` do
  delivery-loop — permanecem separados (ADR-0013 §6).
- A unificação do delivery-loop com o `build-loop` do bench fica **fora de
  escopo**: é o pendente declarado do ADR-0008 §5.
- Reimplementar primitivas que o runtime já oferece fica fora de escopo — o MOSK
  aciona o runtime, não compete com ele.

## Clarifications resolved

- **`/mosk-handoff` mantém o nome** (decidido em 2026-08-04). O Orca classifica
  "handoff" como transferência de posse e instrui a **parar** de supervisionar; o
  `/mosk-handoff` faz o oposto — transporta contexto sob supervisão. A resolução
  é **desambiguar no prompt**, não renomear: custo zero de migração para
  instalações existentes. O risco residual (um agente lendo os dois contratos e
  desligando a supervisão) é mitigado por instrução explícita no `orq.md` e pelo
  verbete no glossário — ver FR-031.
