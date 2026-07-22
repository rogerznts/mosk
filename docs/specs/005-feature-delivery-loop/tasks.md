# Tasks: Delivery-loop consultivo e limitado

**Spec**: `005-feature-delivery-loop` · **Plan**: [plan.md](./plan.md) · **ADR**: [0008](./architecture/adr-0008-consultative-delivery-loop.md)

Formato: `[ID] [P?] [Story] Descrição` — `[P]` = paralelizável. Tudo sob
`mosk/` (embarca). Sem app/testes: cada tarefa fecha com validação manual.
Base reutilizada do `004` (já no `master`): `phase-history.log`,
`update_spec_phase`, `legal_moves.sh`.

## Phase 1 — Contador + apresentação consultiva (US1, P1 · MVP)

- [x] **T001** [US1] Decidir o **dono do loopback** (open item): confirmar que
  `apply-qa-fixes.md` grava a volta com `update_spec_phase "$FEATURE_DIR"
  implement` antes de corrigir — é o que torna a volta `qa-gate → implement`
  contável no log. Registrar a decisão. (FR-004)
- [x] **T002** [US1] `common.sh`: `attempt_count <spec_dir>` — conta as
  transições `qa-gate -> implement` no `phase-history.log` da spec; sem log →
  `0` (aviso em stderr). (FR-004)
- [x] **T003** [US1] `legal_moves.sh` loop-aware na fase `qa-gate` [dep: T002]:
  ler `_gate_status` + `attempt_count`; `PASS`/`WAIVED` → oferecer `archived`;
  `FAIL`/`CONCERNS` e `count < max` → oferecer o loopback rotulado
  `tentativa {count+1}/{max}` como default; nunca executar. (FR-001, FR-006)
- [x] **T004** [P] [US1] `apply-qa-fixes.md` [dep: T001]: acrescentar o passo
  que chama `update_spec_phase ... implement` ao iniciar a correção, para a
  volta ser registrada. (FR-004)
- [x] **T005** [US1] Validação Fase 1: com `phase-history.log` sintético (K
  voltas) + `gate.yaml` FAIL, `legal_moves.sh qa-gate` mostra `tentativa
  K+1/max` e loopback default; `gate.yaml` PASS → oferece `archived`; nada
  auto-executa. (SC-001, SC-003)

## Phase 2 — Teto configurável + esgotamento (US2, P2)

- [x] **T006** [P] [US2] `core-config.yaml` (template + mirror da raiz): +
  `orchestration.max_retries: 3` (ao lado de `orchestration.graph`). (FR-005)
- [x] **T007** [P] [US2] `spec-meta-tmpl.yaml`: documentar o campo opcional
  `max_retries:` como override por-spec. (FR-005)
- [x] **T008** [US2] `common.sh`: `resolve_max_retries <spec_dir>` — override
  do `spec-meta.yaml` → fallback `core-config.yaml` → default `3`; valor não
  numérico → default + aviso. (FR-005, Edge Cases)
- [x] **T009** [US2] `legal_moves.sh` esgotamento [dep: T003, T008]: quando
  `count >= max` e gate `FAIL`/`CONCERNS`, **não** oferecer loopback;
  apresentar `escalar` (escalações já derivadas) · `waive` (dica: `qa-gate` →
  `WAIVED` → `archived`) · `parar` (no-op) — como **anotações**, sem nós/arestas
  novos. Nunca auto-continua. (FR-007)
- [x] **T010** [US2] Validação Fase 2: `count >= max` → jogadas viram
  `escalar/waive/parar` sem loopback; alterar `max_retries` (config e override
  no `spec-meta`) muda o teto sem código; override inválido → default + aviso.
  (SC-002, SC-004)

## Phase 3 — Enquadramento nos prompts (US3, P3)

- [ ] **T011** [P] [US3] `qa-gate.md` [dep: T003, T009]: ao reprovar,
  apresentar `tentativa N/max` + jogadas do loop via `legal_moves.sh qa-gate`,
  sem auto-invocar. (FR-011)
- [ ] **T012** [P] [US3] `implement.md`: descrever a fronteira do ciclo (1ª
  volta `implement`, seguintes `apply-qa-fixes`; `security-review` condicional;
  `readiness` só na entrada). (FR-002)
- [ ] **T013** [P] [US3] `implement.md`/`qa-gate.md`: registrar que
  re-`readiness` só aparece como **escalação** por ambiguidade de story, não a
  cada volta. (FR-008)
- [ ] **T014** [US3] Confirmar `promote: append` no `glossary.md` da spec
  (já escrito no specify). (FR-012)

## Cross-cutting / fechamento

- [ ] **T015** [P] Regressão do bench: `bench-mode.md` inalterado (grep/diff)
  — decisão 5 do ADR-0008. (SC-005, FR-010)
- [ ] **T016** Auditorias: `lint-graph.sh` clean, `bash -n` nos scripts,
  `audit-docs-paths.sh --quiet`; smoke-check da saída do `legal_moves.sh` nas
  fases do loop.
- [ ] **T017** [P] Docs do produto: `.claude/rules/scripts.md` (novos helpers
  `attempt_count`/`resolve_max_retries` e o comportamento loop-aware do
  `legal_moves.sh`); `README` se o fluxo mencionar o teto.

## Dependências (resumo)

- Fase 1 é o MVP. T002 → T003; T001 → T004.
- Fase 2: T008 depende de T006; T009 depende de T003 + T008.
- Fase 3 (prompts) depende de T003/T009 existirem.
- T015–T017 fecham após as fatias.

## Sequenciamento de entrega

MVP = **Fase 1** (contador derivado do log + apresentação `N/max`
consultiva). Demonstrável sozinho. Fase 2 fecha a borda (teto + esgotamento).
Fase 3 consolida a UX nos prompts. Bench intocado em todas.
