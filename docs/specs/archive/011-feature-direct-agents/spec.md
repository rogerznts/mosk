# Feature Specification: Agentes diretos — o template ship a camada de agentes

**Feature Branch**: `011-feature-direct-agents`
**Created**: 2026-08-05
**Status**: Draft
**Input**: User description: "Trabalhar com os agentes direto, sem o Orca. Definir o que é agente definitivo e o que é skill, e permitir que se chamem uns aos outros. Padronizar os nomes de branch."

## Contexto

Decisões em
[ADR-0015](../../architecture/adr/adr-0015-agent-as-source-skill-as-wrapper.md)
(agente é a fonte, skill é o wrapper, e as duas camadas shipam),
[ADR-0016](../../architecture/adr/adr-0016-agent-invocation-protocol.md)
(protocolo de invocação: execução delega, rota não) e
[ADR-0017](../../architecture/adr/adr-0017-branch-naming-convention.md)
(convenção `{tipo}/{NNN}-{nome}`).

**O gap que dá urgência a esta spec:** `mosk/.claude/agents/` **não existe**. Um
projeto que instala o MOSK recebe 23 skills e **zero** agentes invocáveis. Isso
tem três consequências que só ficaram visíveis ao fim da spec 010:

- o `mode: agent` que o grafo declara desde o ADR-0006 — e que o `qa-gate`
  passou a ter na 010 — não tem lastro num consumidor;
- o **Tier 2 do fan-out não funciona fora deste repositório**, e o Tier 2 virou o
  caminho de trabalho depois do waiver do Tier 1 na 010;
- um agente **não pode invocar outro**, nem para executar trabalho já roteado,
  que o ADR-0012 permite explicitamente.

## User Scenarios & Testing

### User Story 1 - O template ship a camada de agentes (Priority: P1)

Como usuário de um projeto que instalou o MOSK, quero que os agentes existam como
entidades invocáveis, para que o `mode: agent` do grafo e o Tier 2 do fan-out
funcionem no meu projeto — e não só no repositório do toolkit.

**Why this priority**: é o desbloqueio de tudo. Sem a camada shipada, US2 não tem
o que invocar e o fan-out isolado não existe fora daqui. É também o único item
que corrige um defeito já em produção.

**Independent Test**: rodar `npx degit` num diretório limpo e confirmar que
`.claude/agents/` chega populado; invocar um agente por `subagent_type` e obter
resposta em contexto isolado.

**Acceptance Scenarios**:

1. **Given** uma instalação limpa via degit, **When** o diretório é inspecionado,
   **Then** `.claude/agents/` contém um arquivo por agente do roster.
2. **Given** um agente do roster, **When** ele é aberto, **Then** contém a
   definição completa — persona, task mapping, guardrails, escalação.
3. **Given** a skill correspondente, **When** ela é aberta, **Then** é um wrapper
   fino: front-matter mais um ponteiro para o agente, sem duplicar a persona.
4. **Given** o roster, **When** classificado, **Then** há 12 agentes e 11 skills
   puras, pelo critério do ADR-0015 §3.
5. **Given** uma `description` alterada no agente, **When** o sync roda, **Then**
   a skill recebe a mesma string — o agente segue sendo a fonte única.
6. **Given** uma instalação anterior, **When** o usuário atualiza e roda o sync,
   **Then** nada aponta para caminhos que deixaram de existir.

---

### User Story 2 - Agentes se invocam para executar (Priority: P2)

Como operador do pipeline, quero que `dev`, `qa`, `security`, `sm`, `ux` e `ui` se
coordenem sem que eu sirva de transporte — mas sem que nenhum deles decida por
onde o pipeline vai.

**Why this priority**: depende da US1 existir. Entrega o pedido original
("agentes chamados uns pelos outros") sem quebrar o invariante consultivo.

**Independent Test**: numa fase de implementação, o dev invoca o verificador e
reporta o retorno, sem pedir confirmação; e ao encontrar lacuna de ADR, **para** e
apresenta a escalação em vez de chamar o architect.

**Acceptance Scenarios**:

1. **Given** um agente executando uma fase, **When** precisa de trabalho que a
   matriz permite delegar, **Then** invoca, **declara antes** o que vai delegar e
   **reporta depois** o que voltou — sem pedir confirmação por chamada.
2. **Given** um agente que detecta lacuna de ADR, fluxo ou PRD, **When** decide o
   próximo passo, **Then** **suspende** e apresenta a escalação; **nunca** invoca
   agente de preâmbulo por conta própria.
3. **Given** um agente invocado, **When** ele precisa de um terceiro, **Then**
   **reporta a necessidade** ao chamador em vez de invocar — profundidade máxima 1.
4. **Given** uma invocação que falha, **When** o chamador consolida, **Then** ela
   é reportada como invocação falha e **não** consome volta do delivery-loop.
5. **Given** o retorno de um agente invocado, **When** ele chega, **Then** é
   status curto — nunca transcript, nunca posse do trabalho.
6. **Given** o modo bench, **When** ele roda, **Then** a exceção do ADR-0002
   permanece intacta e escopada — este protocolo não a estende nem a relaxa.

---

### User Story 3 - Nome de branch padronizado (Priority: P3)

Como usuário do toolkit, quero que todo branch de spec siga um formato único, para
que a listagem agrupe por tipo e "tem número" signifique "tem spec".

**Why this priority**: independente das outras duas. Entrega valor sozinha e não
bloqueia nada — mas mexe na superfície de numeração que a spec 010 acabou de
corrigir, então exige cuidado.

**Independent Test**: criar uma spec e conferir que o branch sai
`{tipo}/{NNN}-{nome}` e a pasta `{NNN}-{tipo}-{nome}`; conferir que uma spec no
formato legado ainda resolve.

**Acceptance Scenarios**:

1. **Given** uma nova spec, **When** criada, **Then** o branch é
   `{tipo}/{NNN}-{nome-kebab}` e a pasta permanece plana,
   `docs/specs/{NNN}-{tipo}-{nome}`.
2. **Given** um branch no formato novo, **When** a spec ativa é resolvida,
   **Then** resolve pelo número, não por igualdade de nome.
3. **Given** uma spec no formato legado, **When** resolvida, **Then** continua
   funcionando.
4. **Given** branches nos dois formatos, **When** o próximo número é calculado,
   **Then** ambos contam — e nomes com dígitos fora do prefixo seguem ignorados.
5. **Given** um tipo abreviado (`feat`, `bug`) ou nome não-kebab, **When** a spec
   é criada, **Then** falha na criação com mensagem clara.
6. **Given** trabalho fora de spec, **When** o branch é criado, **Then**
   `{tipo}/{nome}` sem número é válido.

---

### Edge Cases

- Instalação antiga cujas skills apontam para `mosk/agents/<n>.md`, que deixa de
  existir → o sync precisa reapontar sem exigir intervenção manual.
- Agente sem `skill-description` declarada → a ordem de resolução do contrato
  vale; nunca cair em descrição genérica silenciosamente.
- Agente invocado que tenta invocar outro → recusa e reporta a necessidade.
- Runtime sem primitivo de subagente → a invocação degrada para execução na
  própria sessão, com o mesmo resultado observável.
- `docs/specs/` com pastas nos dois formatos → resolução por número cobre ambos.
- Branch de spec renomeado à mão → `spec-meta.yaml` continua sendo a ponte.

## Requirements

### Functional Requirements

**Camada de agentes (US1)**

- **FR-001**: O template MUST shipar `mosk/.claude/agents/`, com um arquivo por
  agente do roster.
- **FR-002**: O CC agent MUST conter a definição completa; a skill MUST ser
  wrapper fino, sem duplicar a persona.
- **FR-003**: A camada intermediária `mosk/.claude/mosk/agents/` MUST deixar de
  existir como fonte separada — o conteúdo migra para o CC agent.
- **FR-004**: `sync-agents-skills.sh` MUST gerar a skill a partir do agente, numa
  direção só.
- **FR-005**: A `description` MUST permanecer declarada no agente e copiada para
  o wrapper — nunca editada no wrapper.
- **FR-006**: O roster MUST ser 12 agentes e 11 skills puras, pelo critério do
  ADR-0015 §3.
- **FR-007**: O `--clean` MUST continuar removendo órfãos, agora pela nova fonte.

**Protocolo de invocação (US2)**

- **FR-008**: Os prompts dos agentes MUST declarar o que podem invocar e para
  quê, conforme a matriz do ADR-0016 §2.
- **FR-009**: Agentes de preâmbulo MUST NOT ser invocáveis automaticamente;
  lacuna de ADR, fluxo ou PRD MUST suspender e apresentar escalação.
- **FR-010**: Toda invocação MUST ser declarada antes e reportada depois.
- **FR-011**: A profundidade de invocação MUST ser no máximo 1.
- **FR-012**: O retorno de uma invocação MUST ser status curto.
- **FR-013**: Falha de invocação MUST NOT consumir volta do delivery-loop.
- **FR-014**: A exceção do bench (ADR-0002) MUST permanecer intacta e escopada.

**Nome de branch (US3)**

- **FR-015**: `create-new-feature.sh` MUST gerar `{tipo}/{NNN}-{nome-kebab}`.
- **FR-016**: A pasta da spec MUST permanecer plana, `{NNN}-{tipo}-{nome}`.
- **FR-017**: A resolução branch → spec MUST ser por número, aceitando os dois
  formatos.
- **FR-018**: O cálculo do próximo número MUST aceitar `^([a-z]+/)?([0-9]{3})-`,
  mantendo a âncora que a spec 010 introduziu.
- **FR-019**: Tipos MUST ser por extenso; abreviações MUST falhar na criação.
- **FR-020**: Trabalho fora de spec MUST aceitar `{tipo}/{nome}` sem número.
- **FR-021**: Branches existentes MUST NOT ser renomeados.

### Key Entities

- **Agente**: entidade com persona e julgamento próprio. Duas camadas: definição
  (`agents/`) e wrapper de slash command (`skills/`).
- **Skill pura**: ação mecânica sem persona. Uma camada só.
- **Invocação**: chamada de um agente por outro, para **executar** trabalho de
  rota já decidida. Devolve status curto.

## Success Criteria

- **SC-001**: Instalação limpa via degit entrega `.claude/agents/` populado, e um
  agente é invocável por `subagent_type` sem edição manual.
- **SC-002**: Editar a `description` num único arquivo propaga para as duas
  camadas após o sync.
- **SC-003**: Numa fase real, o dev invoca o verificador sem pedir confirmação, e
  o retorno aparece declarado no relatório.
- **SC-004**: Ao encontrar lacuna de ADR, o agente **para** — nenhum preâmbulo é
  invocado automaticamente em nenhum cenário testado.
- **SC-005**: Uma spec nova nasce com branch no formato novo e pasta plana, e uma
  spec legada continua resolvendo.
- **SC-006**: Criar spec com branches nos dois formatos presentes produz o número
  sequencial esperado.
- **SC-007**: O selftest cobre a numeração nos dois formatos e não regride nas
  48 asserções existentes.

## Assumptions and defaults

- O roster de 12/11 é o do ADR-0015 §3; `deploy` fica como skill por ser ação
  sobre o bench, não persona própria.
- Branches existentes não são renomeados; a convenção vale do merge em diante.
- Esta spec nasceu no formato **legado** (`011-feature-direct-agents`) porque ela
  mesma implementa o formato novo — a transição fica legível no histórico.
- A validação continua manual: não há suíte além de `selftest-orca-driver.sh`,
  `lint-graph.sh` e `audit-docs-paths.sh`.
- Fora de escopo: reconciliar o espelho local `.claude/mosk/` por inteiro
  (QA-010-004) e retomar o Tier 1 do Orca (QA-010-008, dispensado).

---

**Arquivado em:** 2026-08-05
**Status final:** Concluído com waiver
**Gate:** `WAIVED` · `quality_score: 70` (série 60 → 70)
**Promoções aplicadas:** nenhuma — os ADR-0015/0016/0017 nasceram direto em
`docs/architecture/adr/`, sem front-matter `promote:`.
**Entregue:** 22 de 22 tarefas. 21/21 FRs. 6 de 8 critérios verificados, 1 parcial.
**Dispensado:** três verificações que dependem de contexto externo — formato de
branch ponta a ponta (a spec 012 resolve), degit real (o merge resolve) e a
independência do gate.
