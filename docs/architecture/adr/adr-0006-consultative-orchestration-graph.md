# ADR-0006 — Grafo de orquestração explícito como fonte-de-verdade consultiva

- Status: **superseded** por [adr-0018](./adr-0018-remove-orchestration-layer.md) (2026-08-14) — o subagente nativo dos runtimes tornou a camada de orquestração redundante. Preservado como registro.
- Data: 2026-07-22
- Autor: Vinicius (mosk-architect)
- Contexto: sessão de `grill` sobre "loops e grafos" no pipeline MOSK — tornar explícito o grafo que hoje está implícito em prosa espalhada.
- Origem: proposta externa de um `pipeline-graph.yaml` declarativo (nós/arestas/guards derivados do flowchart atual), submetida a grill decisão-a-decisão.
- Depende de: [adr-0004](./adr-0004-runtime-agnostic-phase-orchestration.md) (contrato de fases dirigido por disco — este ADR o generaliza), [adr-0002](./adr-0002-auto-escalation-exception.md) (auto-escalação escopada — este ADR distingue dela a escalação **consultiva**).

## Contexto

O fluxo do pipeline MOSK existe hoje em **quatro cópias** que podem
divergir (e já divergiram):

1. o `flowchart` mermaid do README (desenhado à mão);
2. a tabela "estado detectado → próximo agente" em
   `mosk-suggestion/SKILL.md`;
3. o texto dos blocos "Escalation suggested" espalhado em
   `qa-gate.md`, `implement.md` e outras tasks;
4. o enum de `current_phase` no `spec-meta-tmpl.yaml`.

Prova empírica do drift: `clarify` aparece no enum do
`spec-meta-tmpl.yaml` mas some do README; e representações do fluxo
listam `readiness`/`security-review` sem que existam no enum.

Ao mesmo tempo, **metade** do grafo já é declarativa: o grafo de
**artefatos** (arestas `promote:`) vive como dado em
`core-config.yaml` → `promotion.defaults` e é consumido pelo
`archive`. O que falta formalizar é o grafo de **orquestração** (a
ordem temporal das fases e as transições permitidas).

A tentação é construir um executor de grafo autônomo (tipo LangGraph).
Isso quebraria o contrato central do MOSK — *agentes nunca invocam
outro agente automaticamente; o humano é a autoridade que roteia* — e
o ethos de "toolkit que desaparece". O risco real aqui é **fazer
demais**, não de menos.

## Decisão

Formalizar o grafo de orquestração como um artefato declarativo,
**`mosk/.claude/mosk/pipeline-graph.yaml`**, tratado como **camada de
validação e sugestão** — nunca como executor. O grafo computa as
jogadas legais a partir do estado atual; o humano decide
`go`/`escalate`/`skip`/override.

**1. Subtrativo, não aditivo (condição de existência).** O grafo só
entra se **apagar** as cópias hardcoded, virando a fonte de que as
outras representações derivam. Um YAML mantido ao lado da prosa seria
a 5ª cópia — valor líquido negativo. Se em algum ponto não der para
deletar a cópia, não se adiciona o dado.

**2. Só orquestração.** O `pipeline-graph.yaml` modela apenas a ordem
das fases e as transições. O grafo de **artefatos** permanece onde já
vive (`core-config.yaml` → `promotion.defaults`). Fronteira limpa:
*guards podem **consultar** a existência de um artefato (ex.:
`base_ready` = existe `docs/prd/`?), mas nunca **possuem** regra de
promoção.*

**3. Duas classes de nó — o ponteiro só ocupa uma delas.**

- **Fases de pipeline** (o `current_phase` ocupa; `update_spec_phase`
  valida contra elas): `specify | plan | tasks | implement | qa-gate |
  archived`.
- **Side-trips** (alcançáveis a partir de uma fase, mas o ponteiro
  **não entra**): preâmbulo (`discovery/prd/architecture/ux/ui`) +
  `readiness` + `security-review` + `clarify`.

Consequência subtrativa: **`clarify` sai do enum** de `current_phase`
(vira side-trip) — e o enum do `spec-meta-tmpl.yaml` converge com o do
README nas **mesmas 6 fases**, curando o drift.

**4. `specify/plan/tasks` são 3 nós, não 1.** Manter três nós sustenta
os dois caminhos: *granular* = parar em cada nó; *compacto*
(`full-spec`) = atravessar os três sem pausar. A diferença
compacto-vs-granular deixa de ser **estrutura** do grafo e vira
**política de execução**.

**5. Guards híbridos, com o default sendo julgamento do agente.** Cada
guard declara `kind: fact | judgment` e uma `question` legível.

- `fact` (avaliado mecanicamente, verificável em disco): `base_ready`
  (existe `docs/prd/`?) e o status do `gate.yaml` (`gate_pass` /
  `gate_concerns_or_fail`).
- `judgment` (avaliado pelo agente dono da fase, no prompt):
  `request_vague`, `architecture_heavy`, `ux_heavy`, `design_heavy`,
  `diff_security_sensitive`, …

`diff_security_sensitive` fica **`judgment` deliberadamente** — um
`grep` de shell produziria falsa confiança nos dois sentidos e briga
com o contrato de segurança diff-aware. **Em nenhum caso o grafo toma
a aresta**: ele apresenta a jogada + a resposta do guard; o humano
decide.

**6. `escalations:` é uma seção separada de `edges:`.** Uma aresta
normal avança o ponteiro (ida só). Uma escalação pula para um nó
**side-trip** e volta (`return_to: origin`), com fan-out de múltiplas
origens para um alvo (ex.: `missing_adr` vem de `plan`, `tasks` ou
`implement`). São os blocos "Escalation suggested" formalizados. Duas
listas com semânticas limpas > um campo `return_to` em toda aresta que
o consumidor teria de inspecionar.

**7. Transição fora do grafo: avisa-e-segue, nunca bloqueia.**
`update_spec_phase` valida a transição contra o grafo; se for
ilegal, **emite warning + faz append num log de histórico + prossegue**.
Isso entrega a trilha de auditoria e a resumabilidade sem transformar
o grafo em porteiro — o humano continua sendo quem aperta o gatilho,
inclusive para sair do trilho. Bloqueio duro trairia "o humano é a
autoridade".

## Alternativas consideradas

1. **Executor de grafo autônomo (LangGraph-like) que dispara
   transições.** Rejeitada: quebra o contrato "nenhum agente invoca
   outro automaticamente" e o ethos de desaparecer no projeto. É o
   over-engineering que o grill existia para evitar.
2. **YAML aditivo, mantido ao lado da prosa.** Rejeitada: vira 5ª
   cópia e piora o drift. Ver Decisão #1.
3. **Colapsar `specify/plan/tasks` em 1 nó** (como alguns SDD fazem).
   Rejeitada: jogaria fora o caminho granular sem ganho de
   orquestração — a fusão que faz sentido é a de **documentos**
   (`spec`+`plan`), não a de **nós** (ver "Fora de escopo").
4. **Guards como predicados de shell** (`yq` + `case`, inclusive
   `diff_security_sensitive` por `grep`). Rejeitada como default:
   frágil e produz falsa confiança nos guards semânticos. Mantida só
   para os dois guards factuais.
5. **Unificar `edges` e `escalations` numa lista só com `return_to`.**
   Rejeitada: empurra lógica de "avança vs retorna" para todo
   consumidor de `legal_moves()`.
6. **Bloquear transições ilegais.** Rejeitada: converte o grafo de
   conselheiro em executor/porteiro, contra o ethos.

## Consequências

**Positivas:**

- **Fonte única de verdade.** O `pipeline-graph.yaml` passa a alimentar:
  o `legal_moves` do `mosk-suggestion` (apaga a tabela hardcoded), os
  blocos de escalação nas tasks (derivam da seção `escalations:`), e o
  mermaid do `docs/index.md` nos projetos consumidores (renderizado a
  partir do dado). O diagrama para de poder mentir sobre o
  comportamento real.
- **Drift curado.** `clarify` fora do enum reconcilia
  `spec-meta-tmpl.yaml` e README.
- **Auditoria + resumabilidade** via `update_spec_phase` com log de
  histórico, sem sacrificar a autoridade do humano.
- O humano continua roteando; o grafo só torna explícitas as jogadas
  que já estavam implícitas na prosa.

**Negativas / trade-offs:**

- O mermaid do **README deste repo** (doc *sobre* o MOSK, não embarca
  via degit) **fica mantido à mão**, com um comentário "manter em
  sincronia com `pipeline-graph.yaml`". Automatizar geração para um
  único doc que não faz ship não se paga — mas reintroduz um pequeno
  risco de drift **nesse** arquivo específico.
- Introduz um artefato novo por install (`pipeline-graph.yaml`) e um
  helper (`legal_moves.sh`), além de ripple nos scripts de fase.
- Guards `judgment` dependem do julgamento do agente — consistência de
  roteamento melhora, mas não vira determinística (é intencional).

## Fora de escopo (registrado, decidido em spec separada)

A sessão também decidiu **fundir `spec.md` + `plan.md` num único
documento de design** (o par co-ajustado, de baixa volatilidade),
mantendo `tasks.md` separado (volátil, regenerável, 251 linhas de
template). Isso é **camada de artefato**, não de orquestração (Decisão
#2), não perturba o enum de `current_phase`, e será escopado/executado
na spec de implementação — junto com o `pipeline-graph.yaml`,
`legal_moves.sh`, as edições de task e a migração dos specs existentes.
