# Implementation Plan: Delivery-loop consultivo e limitado

**Spec**: `005-feature-delivery-loop` · **Fonte de verdade**: [ADR-0008](./architecture/adr-0008-consultative-delivery-loop.md) · **Glossário**: [glossary.md](./architecture/glossary.md)

## Summary

Operacionalizar o ciclo `qa-gate → implement` (já no grafo do `004`) como um
**delivery-loop consultivo e limitado**: uma contagem de voltas **derivada do
`phase-history.log`**, um teto `max_retries` configurável, e uma
apresentação que muda a jogada oferecida conforme `N/max` — sempre deixando
o humano decidir. Reusa toda a base do `004` (`legal_moves.sh`,
`update_spec_phase`, `phase-history.log`). Não toca o bench.

## Technical Context

- **Stack**: Markdown/YAML/Bash, sem app/testes; validação manual +
  idempotência de scripts. Tudo que embarca vive sob `mosk/`.
- **Base reutilizada (do `004`, já no `master`)**:
  - `phase-history.log` (escrito pelo reducer `update_spec_phase`) → **fonte
    da contagem**.
  - `legal_moves.sh` → ponto de extensão para apresentar `N/max` e trocar as
    jogadas no esgotamento.
  - `graph_edge_exists` / `graph_edges_from` / guards `fact`.
- **Sem estado novo persistido**: a contagem é uma leitura do log; o teto vem
  de config. Coerente com o ADR-0008 #4.

## Abordagem por fatia

### Fase 1 — Contador + apresentação consultiva (US1, P1) — MVP

1. **`attempt_count` em `common.sh`** — helper que conta as voltas do gate
   lendo o `phase-history.log` da spec: número de transições `qa-gate ->
   implement` (a volta de correção). Sem log → 0 (com aviso). (FR-004)
2. **Registrar a volta** — garantir que o retorno para corrigir **grave** a
   transição `qa-gate → implement` no log. `apply-qa-fixes.md` (e/ou o passo
   de loopback) DEVE chamar `update_spec_phase "$FEATURE_DIR" implement`
   antes de corrigir, para a volta ser contável. (FR-004) *(open item: confirmar
   que apply-qa-fixes é o dono desse update)*
3. **`legal_moves.sh` loop-aware na fase `qa-gate`** — ao computar as jogadas
   de `qa-gate`:
   - ler status do gate (já existe `_gate_status`) e `attempt_count`;
   - se `PASS`/`WAIVED` → oferecer `archived` (convergiu);
   - se `FAIL`/`CONCERNS` e `count < max` → oferecer o loopback (a jogada de
     correção) rotulado **`tentativa {count+1}/{max}`**, default;
   - nunca executar — só apresentar. (FR-001, FR-006)

### Fase 2 — Teto configurável + esgotamento (US2, P2)

4. **`resolve_max_retries` em `common.sh`** — lê `spec-meta.yaml`
   (`max_retries:`) com fallback para `core-config.yaml`
   (`orchestration.max_retries`), default final `3`. Valor inválido → default
   + aviso. (FR-005, Edge Cases)
5. **`core-config.yaml`**: adicionar `orchestration.max_retries: 3` (ao lado
   da chave `orchestration.graph` do `004`). Espelhar no mirror da raiz.
   (FR-005)
6. **`spec-meta-tmpl.yaml`**: documentar o campo opcional `max_retries:` como
   override por-spec. (FR-005)
7. **Esgotamento em `legal_moves.sh`** — quando `count >= max` e gate ainda
   `FAIL`/`CONCERNS`: **não** oferecer o loopback; apresentar exatamente
   `escalar` (as escalações já derivadas do grafo) · `waive` (dica: `qa-gate`
   define `WAIVED` → `archived`) · `parar` (no-op, humano assume). Nunca
   auto-continua. (FR-007)

### Fase 3 — Enquadramento nos prompts (US3, P3)

8. **`qa-gate.md`**: ao reprovar, mandar apresentar `tentativa N/max` + as
   jogadas do loop via `legal_moves.sh qa-gate`, sem auto-invocar. (FR-011)
9. **`implement.md`**: descrever a fronteira do ciclo (1ª volta `implement`,
   seguintes `apply-qa-fixes`; `security-review` condicional; `readiness` só
   na entrada). (FR-002)
10. **Re-readiness como escalação** — registrar em `implement.md`/`qa-gate.md`
    que re-`readiness` só aparece como escalação por ambiguidade de story, não
    a cada volta. (FR-008)
11. **Glossário** já escrito no `specify`; garantir `promote: append`
    (feito). (FR-012)

## Decisões herdadas do ADR-0008

- Consultivo, nunca automático (FR-001/009). O `max_retries` muda a **jogada
  oferecida**, não dispara execução.
- Terminação por **gate como sinal único** (FR-003).
- Contagem **por-spec**, derivada do **log** (FR-004) — diverge do bench
  (por-task), que fica **intocado** (FR-010).

## Open items (resolver no início da implementação)

- **Dono do loopback**: `apply-qa-fixes.md` chama `update_spec_phase ...
  implement` para gravar a volta, ou há um passo de loop explícito? Decidir no
  T-inicial da Fase 1 (afeta como `attempt_count` enxerga as voltas).
- **Apresentação de `waive`/`parar`**: são "jogadas" que não são arestas puras
  do grafo. Representá-las como **anotações** na saída do `legal_moves` quando
  `count >= max` (não como nós/arestas novos), para não sujar a topologia.
- **`legal_moves` para `implement`**: o rótulo `N/max` aparece só em `qa-gate`
  ou também ao voltar para `implement`? Recomendação: a contagem é uma
  propriedade da volta do gate; exibir em `qa-gate` (onde a decisão acontece).

## Validação (manual)

1. **Fase 1**: montar um `phase-history.log` sintético com K voltas + um
   `gate.yaml` FAIL; `legal_moves.sh qa-gate` mostra `tentativa K+1/max` e o
   loopback como default; `PASS` → oferece `archived`.
2. **Fase 2**: `count >= max` → jogadas viram `escalar/waive/parar`, sem
   loopback; alterar `max_retries` (config e override) muda o limite sem
   código; override inválido cai no default com aviso.
3. **Fase 3**: ler `qa-gate.md`/`implement.md` e conferir o enquadramento.
4. **Regressão**: `bench-mode.md` inalterado (grep/diff); `lint-graph.sh`
   clean; `bash -n` nos scripts; `audit-docs-paths.sh --quiet`.

## Project Structure — arquivos tocados

```
mosk/.claude/mosk/
├── scripts/
│   ├── common.sh              # + attempt_count, resolve_max_retries
│   └── legal_moves.sh         # qa-gate loop-aware (N/max, esgotamento)
├── core-config.yaml           # + orchestration.max_retries: 3
├── templates/
│   └── spec-meta-tmpl.yaml    # documentar override max_retries
└── tasks/
    ├── qa-gate.md             # apresenta N/max + jogadas do loop
    ├── implement.md           # fronteira do ciclo + re-readiness
    └── apply-qa-fixes.md      # grava loopback (update_spec_phase implement)

(bench-mode.md NÃO é tocado — decisão 5 do ADR-0008)
```
