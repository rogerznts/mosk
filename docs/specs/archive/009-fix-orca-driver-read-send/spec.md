# Feature Specification: Driver Orca — `read` cego e `send` sem prova de entrega

**Feature Branch**: `009-fix-orca-driver-read-send`
**Created**: 2026-07-28
**Status**: Draft
**Input**: Bug report de campo (projeto `cfo-skills`, 28/07/2026), consolidado em
`docs/handoff/bug-mosk-orca-driver.md` daquele repositório, mais verificação
independente do código-fonte e dos dois ramos do extrator neste repositório.

## Contexto

O `/mosk-orq` (Mauro) rege o pipeline abrindo panes de worker e coordenando por
três primitivas: `spawn`, `send`, `read`. Numa sessão real de orquestração com o
backend Orca — quatro panes de agente, pipeline `specify → plan → tasks` — duas
dessas três primitivas falharam em silêncio.

**O defeito é um só, em duas formas: o driver devolve `exit 0` sem ter feito o
que diz.** O `read` devolve vazio como se o terminal estivesse quieto; o `send`
devolve sucesso sem que o worker tenha recebido nada. Como o `read` está cego, a
perda do `send` só aparece muito depois, quando o arquivo esperado não existe.

Custo medido na sessão: uma fase inteira perdida (1 em 4 spawns), e o maestro
regendo por inspeção de `git diff` em vez de enxergar os workers.

### Evidência verificada

`_text_from_json` (`orca.sh:220-248`) percorre o envelope procurando campos
textuais. O Orca entrega a saída do terminal na chave **`tail`**, que o helper
não conhece. Executando os dois ramos contra um envelope real:

| Ramo | Saída |
|---|---|
| Python atual (chaves `lines`, `rows`) | `''` — vazio, exit 0 |
| Python com `tail` na lista | as linhas corretas do terminal |
| **Fallback `sed`** (sem `python3`) | **`{"id":"x`** — fragmento do JSON cru |

O fallback é o achado mais grave e não constava do relato original: ele não
devolve vazio, devolve **lixo**. O `sed 's/.*"text":"//'` não casa (não existe
`text` no envelope), a linha inteira passa adiante e o segundo `sed` corta no
primeiro `",`. Uma checagem de "veio conteúdo?" vê string não-vazia e aprova; o
`cmd_tokens` passa esse fragmento para o `extract_tokens`. Falha silenciosa
disfarçada de sucesso.

O achado do `send` tem causa provável, não confirmada: `orca terminal wait --for
tui-idle` avalia o **terminal**, não a **aplicação**. Numa TUI ainda montando a
interface o terminal parece ocioso antes de existir campo de input, e o texto
injetado se perde. Panes rodando `bash` não reproduzem — o shell aceita input
assim que existe. A tentativa que funcionou na sessão diferia da que falhou por
um único ponto: um `read` confirmando o prompt montado antes do `send`.

### Este repositório é o upstream

O relato de campo recomenda "reportar upstream" e avisa que `/mosk-update`
sobrescreverá o patch local. Correto quanto ao patch, invertido quanto ao
destino: **aqui é o upstream**. `mosk/.claude/mosk/scripts/orca.sh` é a fonte que
o `degit` publica. A correção feita nesta spec é a correção de todos os
consumidores, e o patch local do `cfo-skills` deve ser descartado após o
`/mosk-update`.

## User Scenarios & Testing

### User Story 1 — O maestro enxerga o worker (Priority: P1)

O usuário roda `/mosk-orq` com backend Orca. O Mauro precisa saber o que o worker
está fazendo: se travou num prompt de confirmação, se terminou com erro, se está
consumindo contexto. Hoje ele lê string vazia (ou lixo) e rege às cegas,
verificando o estado só por diff de arquivo.

**Why this priority**: é o que torna todo o resto observável. Sem `read`
funcionando, nenhuma outra correção pode ser percebida em tempo real — inclusive
a da US2. Entrega valor sozinha, mesmo que nada mais seja feito.

**Independent Test**: `bash .claude/mosk/scripts/panes.sh read <pane> --lines 6`
sobre uma pane ativa devolve as linhas visíveis do terminal, exit 0. Verificável
offline contra envelopes-fixture, sem runtime do Orca.

**Acceptance Scenarios**:

1. **Given** um envelope do `orca terminal read` com a chave `tail` populada,
   **When** o extrator processa o envelope pelo ramo Python, **Then** devolve as
   linhas do `tail` unidas por quebra de linha.
2. **Given** o mesmo envelope e um ambiente **sem `python3`**, **When** o extrator
   cai no ramo `sed`, **Then** devolve o mesmo conteúdo textual — e **nunca**
   fragmento de JSON cru.
3. **Given** um terminal recém-criado, com `tail` vazio, **When** o `read` roda,
   **Then** devolve string vazia com exit 0 — vazio legítimo, distinguível de
   erro pelo envelope `ok: true`.
4. **Given** um envelope de erro (`ok: false`, ex. `terminal_handle_stale`),
   **When** o `read` roda, **Then** falha com exit não-zero e mensagem citando o
   erro do Orca, sem devolver conteúdo.

---

### User Story 2 — O `send` prova que entregou (Priority: P2)

O Mauro injeta a tarefa da fase num worker recém-aberto. Hoje o `send` retorna
sucesso mesmo quando a TUI descartou o texto: o agente nunca processa a mensagem,
nenhum arquivo muda, e a fase inteira se perde em silêncio.

**Why this priority**: é a falha cara — custou uma rodada completa de
`specify → plan → tasks`. Fica em P2 porque depende da US1 para ser verificável:
confirmar entrega exige conseguir ler o terminal.

**Independent Test**: injetar em pane recém-spawnada rodando TUI, antes de o
input estar montado, e observar que o `send` reporta falha em vez de exit 0.

**Acceptance Scenarios**:

1. **Given** uma pane com input pronto, **When** o `send` injeta texto, **Then**
   confirma a entrega relendo o terminal e retorna exit 0.
2. **Given** uma pane cuja TUI ainda não aceita input, **When** o `send` injeta
   texto, **Then** **não** retorna sucesso silencioso: sinaliza a entrega não
   confirmada.
3. **Given** uma pane `bash` que não produz eco visível para o comando enviado,
   **When** o `send` injeta, **Then** não gera falso negativo que quebre o fluxo
   hoje funcional do Herdr/bash.
4. **Given** o `send` com confirmação ativa, **When** medido no caminho feliz,
   **Then** o custo adicional por injeção não muda a experiência de orquestração
   de forma perceptível.

---

### User Story 3 — Instrumentar as panes de agente que desaparecem (Priority: P3)

Panes rodando `claude --dangerously-skip-permissions` apresentaram
`terminal_handle_stale` no `wait` e `tab_not_found` no `close` — o terminal
deixou de existir. Três de três panes de agente, sempre **depois** de o trabalho
concluir. Panes `bash` nunca. Nenhuma entrega foi afetada.

**Why this priority**: não reproduzido em ambiente controlado, causa desconhecida
e sem impacto de entrega. Entra como investigação **limitada**, não como
correção: o valor é fechar a dúvida ou registrá-la com evidência, para que o
próximo a ver o sintoma não reinvestigue do zero.

**Independent Test**: existe um registro em `specs/009/discovery/` que ou aponta
a causa, ou documenta as hipóteses testadas e descartadas com o traço que as
descartou.

**Acceptance Scenarios**:

1. **Given** a US1 entregue (o `read` enxerga), **When** uma pane de agente é
   levada até a conclusão do trabalho e depois inspecionada, **Then** o estado do
   terminal no momento do desaparecimento fica registrado.
2. **Given** a investigação encerrada dentro do limite acordado, **When** a causa
   não for identificada, **Then** o resultado é um documento de hipóteses
   testadas — não uma correção especulativa no driver.

### Edge Cases

- **Envelope com `tail` e outro campo textual longo.** O extrator devolve `max(out,
  key=len)` — o mais longo vence. Se outro campo do envelope for maior que o
  conteúdo do terminal, o `read` devolve o campo errado. A precedência precisa
  ser por semântica, não por comprimento.
- **`tail` com itens que não são string** (dicionários com `text`/`content`): o
  `as_line` já cobre; manter coberto.
- **Ausência de `python3`.** Hoje é um caminho de degradação que corrompe em vez
  de degradar. Ou passa a extrair corretamente, ou falha alto — nunca devolve
  fragmento.
- **`send` em pane sem retorno visível.** Confirmação por releitura pode produzir
  falso negativo em comandos silenciosos; o critério de confirmação não pode
  quebrar o fluxo `bash` que hoje funciona.
- **Assimetria com o Herdr.** ADR-0010 fixa paridade mecânica total entre
  `herdr.sh` e `orca.sh`. Se o `send` do Orca passa a garantir entrega e o do
  Herdr não, a garantia deixa de ser uniforme na fachada — mesmo sem mudar a
  superfície de subcomandos.
- **Mirror da raiz defasado.** `.claude/mosk/scripts/orca.sh` é hoje cópia
  byte-a-byte do template. Corrigir só um dos dois faz este repositório depurar
  contra código diferente do que publica.

## Requirements

### Functional Requirements

- **FR-001**: O `read` do driver Orca MUST devolver o conteúdo textual do
  terminal quando o Orca o entrega na chave `tail`.
- **FR-002**: O ramo de degradação sem `python3` MUST devolver o mesmo conteúdo
  textual do ramo principal, ou falhar explicitamente. MUST NOT devolver
  fragmento do envelope cru sob nenhuma entrada.
- **FR-003**: A seleção do conteúdo no envelope MUST ser determinada pela
  semântica da chave, não pelo comprimento do texto.
- **FR-004**: O `read` MUST distinguir três estados no valor de retorno e no exit
  code: conteúdo, vazio legítimo, e erro do Orca.
- **FR-005**: O `send` MUST confirmar que a injeção chegou ao worker antes de
  reportar sucesso, e MUST sinalizar quando a entrega não pôde ser confirmada.
- **FR-006**: A confirmação do `send` MUST NOT introduzir falso negativo em panes
  que hoje funcionam (notadamente `bash`).
- **FR-007**: Entrega não confirmada MUST escalar em três degraus, nunca seguir em
  silêncio: (a) o `send` retorna exit não-zero; (b) o chamador retenta **uma** vez
  com espera maior; (c) persistindo a não-confirmação, a orquestração **para** e
  devolve ao humano. Vale igualmente em `full-auto` e `semi-auto` — a diferença
  entre os modos é quem decide o que fazer depois da parada, não se para.
- **FR-008**: A correção MUST ser verificável **sem runtime do Orca**, por
  envelopes-fixture. O defeito existiu porque não havia como exercitar o extrator
  offline.
- **FR-009**: A correção MUST ser aplicada tanto em
  `mosk/.claude/mosk/scripts/orca.sh` (o que publica) quanto em
  `.claude/mosk/scripts/orca.sh` (mirror local), mantendo os dois idênticos.
- **FR-010**: MUST NOT adicionar subcomando ou flag nova à fachada `panes.sh`.
  A garantia de entrega é comportamento interno do `send` — decisão tomada para
  preservar o contrato do ADR-0010.
- **FR-011**: A investigação da US3 MUST produzir um registro escrito em
  `specs/009/discovery/`, mesmo quando não identificar a causa, e MUST NOT
  resultar em alteração especulativa no driver.
- **FR-012**: Se a assimetria de garantia entre `orca.sh` e `herdr.sh` for
  mantida, o desvio de paridade MUST ficar registrado como emenda ao ADR-0010.

### Key Entities

- **Envelope de resposta do Orca**: JSON com `ok`, `result.terminal.handle`,
  `status`, e o conteúdo em `tail` (lista de linhas). É o contrato de fato entre
  o CLI do Orca e o driver — e a fonte do defeito, por não estar coberto por
  fixture.
- **Pane / terminal handle**: id opaco devolvido pelo `spawn`. Comprovadamente
  estável frente a timeout de `wait` (hipótese testada e descartada em campo).

## Success Criteria

### Measurable Outcomes

- **SC-001**: `panes.sh read <pane>` devolve o conteúdo visível do terminal em
  100% dos envelopes-fixture, nos dois ramos (com e sem `python3`).
- **SC-002**: Nenhuma entrada de fixture faz o driver devolver texto que não seja
  conteúdo de terminal — zero fragmentos de JSON no retorno.
- **SC-003**: O cenário que falhou em campo (injeção em TUI ainda montando) passa
  a ser detectado pelo `send` em vez de reportar exit 0.
- **SC-004**: Uma sessão de orquestração completa (`specify → plan → tasks`) roda
  com o maestro relatando o estado dos workers por leitura direta, sem recorrer a
  inspeção de arquivo para saber se o worker recebeu a tarefa.
- **SC-005**: Zero fases perdidas em silêncio numa rodada de orquestração de
  ponta a ponta — toda perda, se ocorrer, é reportada no momento em que acontece.

## Assumptions & Defaults

- **Escopo decidido com o usuário**: US1 + US2 + investigação limitada da US3.
- **Abordagem da US2 decidida com o usuário**: `send` confirma entrega
  internamente, sem flag nova — preserva o contrato da fachada (ADR-0010).
- **A US3 é time-boxed.** Não reproduzida e sem impacto de entrega: se a causa não
  aparecer dentro do esforço previsto no `plan`, o resultado é o registro escrito
  e a spec segue. Não bloqueia o `qa-gate`.
- **O `herdr.sh` não entra nesta spec.** Tem `_read_text`/`_read_raw` próprios e
  não compartilha o helper defeituoso — não herda o bug do `read`.
- **A causa provável do achado 2 (`tui-idle` ≠ aplicação pronta) é hipótese**, não
  fato confirmado. A correção ataca o sintoma no ponto onde a perda é detectável
  (`send`), não a causa presumida no `wait`.

## Out of Scope

- Corrigir `orca terminal wait --for tui-idle` no CLI do Orca — é software de
  terceiro; o driver contorna.
- Trazer o `herdr.sh` para a mesma garantia de entrega do `send`. Se desejável,
  vira spec própria a partir da emenda do FR-012.
- A camada nativa de orquestração (`native_tasks`), que substitui `wait-idle` por
  espera por evento — desligada por padrão e fora do caminho do defeito.
- Descartar o patch local do `cfo-skills`: ação do projeto consumidor após o
  `/mosk-update`, registrada aqui apenas como consequência.

---

**Arquivado em:** 2026-07-29
**Status final:** Concluído — gate `PASS` (loop de correção convergiu em 2 de 3 tentativas)
**Promoções aplicadas:** 1 `append` — `architecture/adr-0010-amendment-send-delivery.md`
emendado em `docs/architecture/adr/adr-0010-orca-backend.md`. Nenhum `copy`,
nenhum `manual` pendente.

**Escopo adicionado durante a execução:** a Fase 6 corrigiu a resolução de caminho
do `common.sh` em zsh (achado independente, dobrado nesta spec por decisão do
usuário em vez de spec própria).

**Aberto, registrado, não corrigido:** `status: exited` ignorado pelo driver
(pane morta é indistinguível de pane viva e quieta — ver
`discovery/panes-de-agente-desaparecendo.md`); envio de até 3 caracteres cai em
confirmação fraca (`QA-009-007`); paridade de mirror pré-existente em
`payload-*.sh` e `agents/qa.md` (`QA-009-004`).
