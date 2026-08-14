---
promote: docs/architecture/adr/adr-0008-consultative-delivery-loop.md
promote_mode: copy
---

# ADR-0008 — Delivery-loop consultivo e limitado (per-spec, sinal único de gate)

- Status: **superseded** por [adr-0018](./adr-0018-remove-orchestration-layer.md) (2026-08-14) — o subagente nativo dos runtimes tornou a camada de orquestração redundante. Preservado como registro.
- Data: 2026-07-22
- Autor: Sara (mosk-po), via `grill`
- Contexto: spec `005-feature-delivery-loop` — introduzir um loop de convergência sobre `readiness → implement → qa → security` com teto `max_retries`.
- Origem: continuação do tema "loops e grafos" — a metade **loop** do que o ADR-0006 formalizou como grafo.
- Depende de: [adr-0006](../../../architecture/adr/adr-0006-consultative-orchestration-graph.md) (grafo consultivo — o loop herda o invariante "nada auto-executa"), [adr-0004](../../../architecture/adr/adr-0004-runtime-agnostic-phase-orchestration.md) (loop-until-green do bench — o delivery-loop se distingue dele).

## Contexto

O `004` tornou o grafo de orquestração explícito e **consultivo**: computa
jogadas legais, o humano decide, nada auto-executa. O grafo já contém o
ciclo `qa-gate → implement` (guard `gate_concerns_or_fail`), mas sem
**limite** nem **contagem** — nada impede voltas infinitas e nada
operacionaliza "iterar até convergir".

O pedido: um loop sobre o ciclo de entrega que rode "até as tasks
concluírem", com um `max_retries` pré-definido. A frase inicial ("loop até
concluir") sugeria automação, o que colidiria com o invariante do `004`.

O MOSK já tem um loop de convergência: o `loop-until-green` do bench
(ADR-0004), **automático**, **por-tarefa**, para **leigos**. A pergunta não
é "automatizar ou não", e sim reconhecer que o delivery-loop é um mecanismo
**diferente por audiência**: atende um **operador técnico** e pode **pausar
para tirar dúvidas técnicas** — algo que o bench, por definição, nunca faz.

Isso molda os prompts de `implement`/`qa-gate`, o contrato do contador e a
relação com o bench — difícil de reverter, merece ADR.

## Decisão

**1. Consultivo, nunca automático.** O delivery-loop **não itera sozinho**.
A cada volta ele apresenta o estado (`tentativa N/max`, veredito do gate) e
as jogadas legais; o humano decide (`corrigir` / `escalar` / `waive` /
`parar`). O `max_retries` é um **limite que muda a jogada oferecida**, não um
gatilho de execução. Herda direto o invariante do ADR-0006. A distinção
frente ao bench é a **audiência** (técnico, que pode ser consultado), não a
automação.

**2. Fronteira do ciclo.**
- **Entrada (1×):** `readiness` — clareza da story antes de começar; **não**
  faz parte do ciclo iterado.
- **Corpo iterado (contado):** `implement` (1ª volta) / `apply-qa-fixes`
  (voltas seguintes) → `security-review` *se* `diff_security_sensitive` →
  `qa-gate`.
- Re-`readiness` só como **escalação**, quando um FAIL revela ambiguidade de
  story — não a cada volta.

**3. Terminação por sinal único = gate `PASS`/`WAIVED`.** É o único critério
de "tasks concluídas". Os checkboxes do `tasks.md` **alimentam** o gate (o
`qa-gate` avalia completude de ACs/tasks), mas **não** são um gatilho de
saída paralelo — elimina a ambiguidade "caixas marcadas × gate FAIL". Ao
esgotar `max_retries`, o loop **não desiste em silêncio nem auto-continua**:
apresenta `escalar` (FAIL persistente ≈ problema de design/story), `waive`
(qa aceita com justificativa) ou `parar` (humano assume manual).

**4. Contador por-spec, derivado do log, com teto configurável.**
- **Escopo:** por-spec, contando as **voltas do gate** (`qa-gate →
  implement`/`apply-qa-fixes`). Diverge do bench (por-tarefa) porque o sinal
  de saída (o gate) é por-spec.
- **Estado:** **derivado do `phase-history.log`** (a trilha de auditoria do
  ADR-0006) — zero estado novo persistido; cada spec tem seu log, reset
  natural.
- **Config:** default `orchestration.max_retries: 3` em `core-config.yaml`
  (reusa a convenção do bench), **sobrescrevível por-spec** no
  `spec-meta.yaml`. O teto é **política**, não topologia — não vai numa
  aresta do grafo.

**5. Coexistir com o bench, sem tocá-lo.** O `loop-until-green` do bench
permanece como está (ADR-0004). O delivery-loop é mecanismo separado.
Compartilham o *conceito* (loop limitado) e o default 3, não a
implementação. A unificação futura (um só mecanismo parametrizado por
audiência) fica **registrada e fora de escopo** desta spec.

## Alternativas consideradas

1. **Auto-loop no pipeline principal (estilo bench).** Rejeitada: viola o
   invariante do ADR-0006. Automação real só é honesta num modo
   self-contained novo — outra spec, não a `005`.
2. **Semi-automático com checkpoints.** Rejeitada: ou colapsa em "consultivo
   com passos extras", ou escorrega para auto-loop. Sem ganho sobre (1
   consultivo).
3. **Contador por-tarefa (como o bench).** Rejeitada: o sinal de saída é o
   gate, que é por-spec; contar por-tarefa desalinha teto e terminação.
4. **Dois sinais de terminação (checkboxes + gate).** Rejeitada: cria corrida
   quando discordam. O gate é o árbitro único.
5. **Persistir um contador em `spec-meta.yaml`.** Rejeitada: o
   `phase-history.log` já dá a contagem — evita estado redundante e
   dessincronizável.
6. **Unificar com o bench agora.** Rejeitada: acopla mecanismos com
   audiência/automação/granularidade diferentes; over-engineering.

## Consequências

**Positivas:**

- O loop torna a convergência **explícita e limitada** sem quebrar o "humano
  decide". `max_retries` protege contra voltas infinitas.
- **Zero estado novo:** o contador é uma leitura do `phase-history.log` que
  já existe. Auditável e retomável.
- Terminação sem ambiguidade (gate como árbitro único).
- Bench intocado; risco isolado.

**Negativas / trade-offs:**

- O usuário confirma cada volta — mais interação que um auto-loop (é o
  preço, deliberado, do invariante e da audiência técnica).
- Divergência de granularidade frente ao bench (por-spec × por-tarefa) exige
  um glossário claro para não confundir "as 3 tentativas" de cada um
  (registrado em `glossary.md`).
- Deriva a contagem do log → o log precisa ser confiável (já é escrito pelo
  reducer `update_spec_phase` do ADR-0006).

## Escopo da spec 005

Implementa as decisões 1–4 no pipeline consultivo (prompts de
`readiness`/`implement`/`qa-gate`, apresentação do contador via
`legal_moves`/reducer, config do teto). **Não** toca o bench (decisão 5). A
unificação futura fica fora de escopo.
