# Feature Specification: Grafo de orquestração consultivo

**Feature Branch**: `004-feature-orchestration-graph`
**Created**: 2026-07-22
**Status**: Draft
**Input**: Formalizar o grafo de orquestração do MOSK como artefato declarativo consultivo. Escopo e trade-offs em [`docs/architecture/adr/adr-0006-consultative-orchestration-graph.md`](../../architecture/adr/adr-0006-consultative-orchestration-graph.md) (fonte de verdade).

## Contexto

O fluxo do pipeline MOSK existe hoje em quatro cópias que podem divergir
(mermaid do README, tabela do `mosk-suggestion`, blocos "Escalation
suggested" nas tasks, enum de `current_phase`) — e já divergiram
(`clarify` no enum mas fora do README). Metade do grafo já é declarativa
(artefatos, em `core-config.yaml` → `promotion.defaults`); falta o grafo de
**orquestração**. Esta feature o torna um dado único do qual as demais
representações derivam, mantendo o invariante MOSK: **o grafo sugere
jogadas legais; o humano decide — nada auto-executa**.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Grafo declarativo como fonte de jogadas legais (Priority: P1)

Como mantenedor/usuário do MOSK, quero um `pipeline-graph.yaml` único que
descreva fases, transições e escalações, e um comando que compute as
"jogadas legais" a partir da fase atual — para que a sugestão de próximo
passo pare de ser prosa hardcoded que diverge do comportamento real.

**Why this priority**: é o coração da feature e o único slice que sozinho
já entrega valor (fonte única de verdade + cura o drift do enum). Sem ele,
nada mais existe.

**Independent Test**: com o grafo em disco, rodar `legal_moves.sh implement`
lista `qa-gate` (default) e `security-review` (guard); o `mosk-suggestion`
produz a mesma sugestão **sem** consultar nenhuma tabela hardcoded (a tabela
foi removida do SKILL).

**Acceptance Scenarios**:

1. **Given** um spec em `current_phase: implement`, **When** rodo
   `legal_moves.sh implement`, **Then** recebo as arestas legais com a
   `default` marcada e os guards `judgment` sinalizados para o agente avaliar.
2. **Given** o `pipeline-graph.yaml`, **When** leio os nós, **Then** eles se
   dividem em duas classes explícitas: fases de pipeline (`specify | plan |
   tasks | implement | qa-gate | archived`) e side-trips (preâmbulo +
   `readiness` + `security-review` + `clarify`).
3. **Given** o `spec-meta-tmpl.yaml`, **When** leio o enum de
   `current_phase`, **Then** `clarify` **não** está mais nele e o enum
   coincide com o do README (6 fases).
4. **Given** o `mosk-suggestion/SKILL.md`, **When** o inspeciono, **Then**
   não há mais tabela "estado → próximo agente"; ele deriva do grafo.

---

### User Story 2 - Demais representações derivadas + trilha de auditoria (Priority: P2)

Como mantenedor, quero que os blocos de escalação das tasks e o mermaid do
`docs/index.md` derivem do grafo, e que a troca de fase registre uma trilha
de auditoria — para completar o objetivo subtrativo e ganhar
resumabilidade, sem transformar o grafo em porteiro.

**Why this priority**: entrega o restante do valor subtrativo e a auditoria,
mas depende do grafo da US1 já existir.

**Independent Test**: alterar um guard/escala no `pipeline-graph.yaml` e
verificar que o bloco emitido pelo `qa-gate`/`implement` e o mermaid do
`index-docs` refletem a mudança sem edição manual em prosa; e que uma
transição fora do grafo gera warning + entrada no log, mas prossegue.

**Acceptance Scenarios**:

1. **Given** a seção `escalations:` do grafo, **When** o `qa-gate` detecta
   um sinal, **Then** o bloco "Escalation suggested" é montado a partir do
   dado, não de texto fixo na task.
2. **Given** o grafo, **When** o `index-docs` roda num projeto consumidor,
   **Then** o mermaid do fluxo em `docs/index.md` é renderizado a partir do
   grafo.
3. **Given** um spec em `current_phase: tasks`, **When** peço a transição
   `tasks → archived` (fora do grafo), **Then** `update_spec_phase` emite um
   warning, faz append num log de histórico e **prossegue** (nunca bloqueia).
4. **Given** uma transição legal, **When** `update_spec_phase` roda, **Then**
   a mudança também é registrada no log de histórico.

---

### User Story 3 - Fusão parcial spec + plan (Priority: P3)

Como usuário do pipeline, quero que `spec.md` e `plan.md` virem um único
documento de design (mantendo `tasks.md` separado) — para reduzir o
retrabalho de ajustar o par acoplado *o quê + o como* em dois arquivos.

**Why this priority**: dor real, mas de natureza estrutural diferente
(camada de artefato) e com ripple em scripts/templates + migração; deve ser
o **último** movimento, sequenciado depois do grafo estar de pé.

**Independent Test**: rodar o pipeline num spec novo e obter um documento de
design único (seções de contrato e de plano) + `tasks.md` separado; um spec
legado de três arquivos é migrado sem perda de conteúdo.

**Acceptance Scenarios**:

1. **Given** um spec novo, **When** rodo `specify` e depois `plan`, **Then**
   ambos escrevem em seções distintas de **um** arquivo de design, e
   `current_phase` ainda percorre `specify → plan → tasks`.
2. **Given** `tasks`, **When** roda, **Then** escreve em `tasks.md` separado
   (não no documento de design).
3. **Given** um spec legado com `spec.md` + `plan.md` separados, **When**
   aplico a migração, **Then** eles são unidos no documento de design
   preservando o conteúdo, de forma idempotente.
4. **Given** `check-prerequisites.sh`, **When** valida a fase de plano,
   **Then** checa a existência da **seção de plano** no documento de design,
   não de um `plan.md` isolado.

---

### Edge Cases

- Transição pedida para uma fase inexistente no grafo → warning claro, sem
  corromper `spec-meta.yaml`.
- `pipeline-graph.yaml` ausente ou malformado → consumidores (suggestion,
  index-docs, update_spec_phase) degradam com aviso e não travam o fluxo.
- Guard `fact` cujo artefato consultado não existe (ex.: `gate.yaml`
  ausente) → tratado como guard não satisfeito, sem erro fatal.
- Spec já em andamento durante a migração da US3 (fase intermediária) →
  migração não deve descartar seções nem duplicar conteúdo.
- README do repo-template fora de sincronia com o grafo → aceito por decisão
  (mantido à mão com nota de sync); não é falha de build.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: O sistema DEVE fornecer `mosk/.claude/mosk/pipeline-graph.yaml`
  como artefato declarativo único do grafo de **orquestração** (só
  orquestração; artefatos permanecem em `core-config.yaml`).
- **FR-002**: O grafo DEVE classificar nós em **fases de pipeline** (ocupadas
  por `current_phase`, validadas) e **side-trips** (não ocupadas pelo
  ponteiro): preâmbulo, `readiness`, `security-review`, `clarify`.
- **FR-003**: O grafo DEVE separar `edges:` (avança o ponteiro) de
  `escalations:` (pula para side-trip e volta, `return_to: origin`, com
  fan-out de múltiplas origens).
- **FR-004**: Cada guard DEVE declarar `kind: fact | judgment` e uma
  `question` legível. Guards `fact` são avaliados mecanicamente
  (`base_ready`, status do `gate.yaml`); `judgment` são avaliados pelo agente
  dono da fase.
- **FR-005**: O sistema DEVE prover `legal_moves.sh <current_phase>` que lista
  as arestas legais avaliando os guards `fact`, marca a `default` e sinaliza
  os guards `judgment` para avaliação do agente — sem tomar nenhuma aresta.
- **FR-006**: `mosk-suggestion/SKILL.md` DEVE derivar a sugestão do grafo; a
  tabela hardcoded "estado → próximo agente" DEVE ser removida.
- **FR-007**: Os blocos "Escalation suggested"/"Security review suggested" em
  `qa-gate.md` e `implement.md` DEVEM derivar da seção `escalations:` do
  grafo, com o formato do bloco definido em um único lugar.
- **FR-008**: `index-docs` DEVE renderizar o mermaid do fluxo em
  `docs/index.md` (projetos consumidores) a partir do grafo.
- **FR-009**: `update_spec_phase` (em `common.sh`) DEVE validar a transição
  contra o grafo e, se ilegal, emitir warning + append num log de histórico +
  **prosseguir**; nunca bloquear. Transições legais também são logadas.
- **FR-010**: `clarify` DEVE ser removido do enum de `current_phase` no
  `spec-meta-tmpl.yaml`, reconciliando-o com o README (6 fases).
- **FR-011**: O sistema DEVE unir `spec.md` + `plan.md` num único documento de
  design com seções distintas, mantendo `tasks.md` como arquivo separado,
  preservando o percurso `specify → plan → tasks` do `current_phase`.
- **FR-012**: `setup-plan.sh`, `check-prerequisites.sh` e os templates DEVEM
  ser ajustados para o documento de design único (checar a **seção de plano**,
  não `plan.md`).
- **FR-013**: O sistema DEVE fornecer migração idempotente de specs legados de
  três arquivos para o documento de design único, sem perda de conteúdo.
- **FR-014**: `core-config.yaml` DEVE ganhar uma chave apontando para o
  `pipeline-graph.yaml`.
- **FR-015**: O invariante DEVE ser preservado em todos os consumidores:
  nenhum agente invoca outro automaticamente; o grafo só computa e apresenta
  jogadas; o humano decide `go`/`escalate`/`skip`/override.
- **FR-016**: O mermaid do README do repo-template permanece mantido à mão,
  com nota "manter em sincronia com `pipeline-graph.yaml`" (decisão do
  ADR-0006).

### Key Entities *(include if feature involves data)*

- **Nó (node)**: uma fase do pipeline ou um side-trip; atributos: `agent`,
  `mode` (skill|agent), classe (fase|side-trip), `optional`.
- **Aresta (edge)**: transição `from → to` que avança o ponteiro; atributos:
  `guard` opcional, `default`.
- **Escalação (escalation)**: salto de uma ou mais origens para um side-trip
  com retorno; atributos: `signal`, `from[]`, `to`, `return_to`, `scope`.
- **Guard**: condição nomeada; atributos: `kind` (fact|judgment), `question`.
- **current_phase**: ponteiro único de estado no `spec-meta.yaml`; só assume
  valores de fase de pipeline.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: O número de cópias hardcoded do grafo cai de 4 para 1 fonte +
  derivados: a tabela do `mosk-suggestion`, os blocos de escalação em prosa e
  o mermaid do `index-docs` passam a derivar do `pipeline-graph.yaml`.
- **SC-002**: O enum de `current_phase` é idêntico entre `spec-meta-tmpl.yaml`
  e README (6 fases; `clarify` ausente em ambos) — drift zero verificável.
- **SC-003**: `legal_moves.sh` retorna as jogadas legais corretas para 100%
  das fases de pipeline, com a `default` marcada e nenhuma aresta tomada
  automaticamente.
- **SC-004**: Uma transição fora do grafo nunca é bloqueada: gera warning +
  entrada de histórico e prossegue em 100% dos casos.
- **SC-005**: Um spec produzido pelo pipeline tem `spec`+`plan` num único
  documento e `tasks.md` separado; um spec legado migrado preserva 100% do
  conteúdo e a migração é idempotente.
