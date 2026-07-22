# Feature Specification: Delivery-loop consultivo e limitado

**Feature Branch**: `005-feature-delivery-loop`
**Created**: 2026-07-22
**Status**: Draft
**Input**: Loop de convergência sobre `readiness → implement → qa → security` com `max_retries`, até o gate convergir. Decisões e trade-offs em [`architecture/adr-0008-consultative-delivery-loop.md`](./architecture/adr-0008-consultative-delivery-loop.md) (fonte de verdade); termos em [`architecture/glossary.md`](./architecture/glossary.md).

## Contexto

O `004` deixou o ciclo `qa-gate → implement` explícito no grafo, mas **sem
limite nem contagem**. Esta feature operacionaliza "iterar até convergir"
como um **delivery-loop consultivo**: a cada volta apresenta o estado
(`tentativa N/max`, veredito do gate) e as jogadas legais; **o humano
decide**. Distingue-se do `loop-until-green` do bench pela audiência —
atende um **operador técnico** e pode pausar para dúvidas técnicas — nunca
auto-itera (invariante do ADR-0006). O bench **não é tocado**.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Contador de voltas do gate + apresentação consultiva (Priority: P1)

Como operador técnico, quero que, quando o gate reprovar, o sistema me diga
em qual tentativa estou (`N/max`) e me ofereça as jogadas legais — sem rodar
nada sozinho — para eu conduzir a convergência com um teto visível.

**Why this priority**: é o coração do delivery-loop e o único slice que
entrega valor sozinho (torna a convergência explícita e limitada, mantendo o
humano no volante).

**Independent Test**: com um spec em `qa-gate` cujo `gate.yaml` é `FAIL` e um
`phase-history.log` com K voltas `qa-gate → implement`, consultar as jogadas
mostra `tentativa K+1/max` e oferece `apply-qa-fixes` (default) — nada é
executado automaticamente.

**Acceptance Scenarios**:

1. **Given** um spec em `qa-gate` com gate `FAIL` e 1 volta registrada no
   log, **When** consulto as jogadas, **Then** vejo `tentativa 2/3` e as
   jogadas legais com `apply-qa-fixes` como default — sem auto-execução.
2. **Given** a contagem, **When** ela é calculada, **Then** vem **derivada
   do `phase-history.log`** (voltas `qa-gate → implement`/`apply-qa-fixes`),
   sem nenhum contador novo persistido.
3. **Given** o gate vira `PASS` (ou `WAIVED`), **When** consulto as jogadas,
   **Then** o loop termina (oferece `archive`), independente de checkboxes.

---

### User Story 2 - Teto configurável + comportamento no esgotamento (Priority: P2)

Como mantenedor, quero um `max_retries` com default global e override
por-spec, e um comportamento claro quando ele estoura — para o loop nunca
girar infinito nem desistir em silêncio.

**Why this priority**: dá controle e fecha a borda do loop, mas depende do
contador da US1 existir.

**Independent Test**: com `max_retries: 2` e 2 voltas no log, consultar as
jogadas **não** oferece "corrigir de novo"; oferece `escalar`/`waive`/`parar`.
Alterar o teto (config ou override) muda o limite sem tocar código.

**Acceptance Scenarios**:

1. **Given** `orchestration.max_retries: 3` no `core-config.yaml`, **When**
   um spec define `max_retries: 5` no `spec-meta.yaml`, **Then** o override
   por-spec vence.
2. **Given** a contagem `>= max_retries` com gate ainda `FAIL`, **When**
   consulto as jogadas, **Then** recebo exatamente `escalar` / `waive` /
   `parar` — "corrigir de novo" **não** é oferecido e nada roda sozinho.
3. **Given** a contagem `< max_retries`, **When** o gate é `CONCERNS`/`FAIL`,
   **Then** `apply-qa-fixes` é oferecido como default, rotulado `N/max`.

---

### User Story 3 - Enquadramento do ciclo nos prompts das tasks (Priority: P3)

Como usuário do pipeline, quero que os prompts de `readiness`/`implement`/
`qa-gate` reflitam a fronteira do loop (entrada, corpo iterado, escalação de
re-readiness) — para o comportamento consultivo ser consistente sem ninguém
memorizar convenções.

**Why this priority**: consolida a UX do loop; valor incremental sobre US1/US2.

**Independent Test**: ler `implement.md`/`qa-gate.md` mostra o ciclo
`corrige → [security] → qa`, a leitura do contador, e re-`readiness` só como
escalação; o glossário está promovido.

**Acceptance Scenarios**:

1. **Given** `qa-gate.md`, **When** o gate reprova, **Then** o prompt manda
   apresentar `tentativa N/max` + jogadas do loop (via `legal_moves`), sem
   auto-invocar.
2. **Given** `readiness`, **When** o loop está em curso, **Then** ela é
   tratada como entrada única; re-readiness só aparece como escalação por
   ambiguidade de story.
3. **Given** o `glossary.md` da spec, **When** a `005` for arquivada, **Then**
   os termos promovem para o glossário canônico (`append`).

### Edge Cases

- `phase-history.log` ausente (spec antiga anterior ao `004`) → contagem = 0;
  loop começa do zero, com aviso.
- Gate `WAIVED` a qualquer momento → termina como convergência (não conta
  como falha).
- Override de `max_retries` inválido (não numérico) no `spec-meta` → cai no
  default global, com aviso.
- Transição fora do grafo (override humano) no meio do loop → registrada no
  log (avisa-e-segue do `004`); a contagem reflete o que o log mostra.
- Re-readiness disparada → é escalação (side-trip), não conta como volta do
  gate.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: O delivery-loop DEVE ser **consultivo** — nunca auto-itera; a
  cada volta apresenta estado + jogadas legais e aguarda decisão humana.
- **FR-002**: O ciclo iterado DEVE ser `implement` (1ª volta) /
  `apply-qa-fixes` (seguintes) → `security-review` *se* `diff_security_sensitive`
  → `qa-gate`; `readiness` é **entrada única**, fora do ciclo.
- **FR-003**: A terminação DEVE ser o veredito do gate `PASS`/`WAIVED` (sinal
  único); checkboxes do `tasks.md` alimentam o gate, não são gatilho de saída.
- **FR-004**: A contagem de tentativas DEVE ser **derivada do
  `phase-history.log`** (voltas `qa-gate → implement`/`apply-qa-fixes`), sem
  estado novo persistido.
- **FR-005**: `max_retries` DEVE ter default global em `core-config.yaml`
  (`orchestration.max_retries: 3`), sobrescrevível por-spec no `spec-meta.yaml`.
- **FR-006**: Com contagem `< max_retries` e gate `FAIL`/`CONCERNS`, o sistema
  DEVE oferecer `apply-qa-fixes` como default, rotulado `tentativa N/max`.
- **FR-007**: Com contagem `>= max_retries`, o sistema DEVE oferecer
  `escalar`/`waive`/`parar` e **não** oferecer "corrigir de novo"; nunca
  auto-continua nem desiste em silêncio.
- **FR-008**: Re-`readiness` DEVE aparecer só como **escalação** quando um
  FAIL revela ambiguidade de story — não a cada volta.
- **FR-009**: O loop DEVE preservar o invariante MOSK: nenhum agente
  auto-invoca outro; o loop apresenta jogadas, o humano decide.
- **FR-010**: O `loop-until-green` do bench (ADR-0004) DEVE permanecer
  intocado (coexistência).
- **FR-011**: O cômputo das jogadas do loop (contador + `N/max` + jogadas de
  esgotamento) DEVE ser derivado do grafo/log via `legal_moves` (ou companheiro),
  não de prosa hardcoded nas tasks.
- **FR-012**: Os termos de domínio (`delivery-loop`, `loop-until-green`,
  `convergência`, `max_retries`) DEVEM estar no glossário da spec, com
  `promote: append` para o canônico.

### Key Entities *(include if feature involves data)*

- **Volta do gate (attempt)**: uma iteração `qa-gate → corrige → re-qa`;
  contada a partir do `phase-history.log`.
- **max_retries**: teto de voltas por-spec; default global + override por-spec.
- **Veredito do gate**: `PASS`/`CONCERNS`/`FAIL`/`WAIVED` — árbitro único da
  terminação.
- **phase-history.log**: trilha de auditoria por-spec (do ADR-0006); fonte da
  contagem.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Para um spec que reprova o gate K vezes (K < max), a jogada
  `apply-qa-fixes` é oferecida rotulada `tentativa K+1/max` em 100% das
  voltas, com a contagem derivada do log — sem contador manual.
- **SC-002**: Na K-ésima falha com K = max, as jogadas oferecidas são
  exatamente `escalar`/`waive`/`parar`; "corrigir de novo" não aparece e nada
  roda sozinho.
- **SC-003**: `PASS`/`WAIVED` encerra o loop; nenhuma saída é disparada só
  por checkboxes.
- **SC-004**: Alterar `orchestration.max_retries` (ou o override por-spec)
  muda o teto sem alteração de código.
- **SC-005**: O comportamento do `loop-until-green` do bench permanece
  inalterado (por-tarefa, automático) — verificado intocado.

---
**Arquivado em:** 2026-07-22
**Status final:** Concluído
**Promoções aplicadas:** copy (ADR-0008 → docs/architecture/adr/), append (glossary → docs/architecture/glossary.md)
