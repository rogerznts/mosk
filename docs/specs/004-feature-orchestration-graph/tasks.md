# Tasks: Grafo de orquestração consultivo

**Spec**: `004-feature-orchestration-graph` · **Plan**: [plan.md](./plan.md) · **ADR**: [0006](../../architecture/adr/adr-0006-consultative-orchestration-graph.md)

Formato: `[ID] [P?] [Story] Descrição` — `[P]` = paralelizável (arquivos
independentes). Todo caminho sob `mosk/` (embarca); a nota do README é o
único item fora. Sem app/testes: cada tarefa fecha com validação manual.

## Phase 1 — Grafo + legal_moves (US1, P1 · MVP)

- [x] **T001** [US1] Criar `mosk/.claude/mosk/pipeline-graph.yaml` com `nodes:`
  (atributo `kind: phase | side-trip`, `agent`, `mode`, `optional`), fases =
  `specify,plan,tasks,implement,qa-gate,archived`, side-trips =
  `discovery,prd,architecture,ux,ui,readiness,security-review,clarify`.
  (FR-001, FR-002)
- [x] **T002** [US1] No mesmo arquivo, adicionar `edges:` (from/to/guard?/
  default?) refletindo o caminho feliz + fan-out de `security-review`, e
  `escalations:` (signal/from[]/to/return_to: origin/scope). (FR-003)
- [x] **T003** [US1] No mesmo arquivo, adicionar catálogo `guards:` com
  `kind: fact|judgment` + `question`. `fact`: `base_ready`, `gate_pass`,
  `gate_concerns_or_fail`. `judgment`: `request_vague`, `architecture_heavy`,
  `ux_heavy`, `design_heavy`, `diff_security_sensitive`. (FR-004)
- [x] **T004** [P] [US1] `core-config.yaml` (template + mirror da raiz):
  adicionar chave `orchestration.graph: .claude/mosk/pipeline-graph.yaml`.
  (FR-014)
- [x] **T005** [P] [US1] `spec-meta-tmpl.yaml`: remover `clarify` do
  comentário-enum de `current_phase` (6 fases). (FR-010)
- [x] **T006** [US1] Criar `mosk/.claude/mosk/scripts/legal_moves.sh
  <current_phase>` [dep: T001-T003]: ler o grafo, filtrar `edges` por `from`,
  avaliar guards `fact` (checar `docs/prd/`; ler `status` do `gate.yaml`),
  imprimir jogadas com `default` marcada + guards `judgment` sinalizados;
  nunca tomar aresta. `--help`, `--json`, `set -e`, `source common.sh`,
  degradar com aviso se grafo faltar/malformar. (FR-005, Edge Cases)
- [x] **T007** [US1] Reescrever `mosk-suggestion/SKILL.md` [dep: T006]:
  remover a tabela "estado → próximo agente"; Workflow passa a chamar
  `legal_moves.sh` e apresentar, agente avaliando os `judgment`. Preservar
  "só sugere, nunca invoca". (FR-006, FR-015)
- [x] **T008** [US1] Validação Fase 1: rodar `legal_moves.sh` para as 6 fases
  e conferir defaults; `grep` confirmando ausência da tabela no SKILL; `diff`
  do enum `spec-meta-tmpl.yaml` ↔ README. (SC-002, SC-003)

## Phase 2 — Representações derivadas + auditoria (US2, P2)

- [ ] **T009** [US2] Definir o **formato único** do bloco "Escalation
  suggested"/"Security review suggested" num só lugar (snippet dedicado ou
  seção do `project-rule-tmpl.md`). (FR-007)
- [ ] **T010** [P] [US2] `qa-gate.md` [dep: T009]: trocar o texto fixo do
  bloco por instrução de consultar `escalations:` do grafo + o formato único.
  (FR-007)
- [ ] **T011** [P] [US2] `implement.md` [dep: T009]: idem T010. (FR-007)
- [ ] **T012** [US2] `index-docs.md` [dep: T001-T003]: acrescentar passo que
  renderiza o mermaid do fluxo em `docs/index.md` a partir do grafo,
  determinístico/idempotente. (FR-008)
- [ ] **T013** [US2] `common.sh` / `update_spec_phase` [dep: T001-T002]:
  validar transição contra `edges`; se ilegal → warning + append em
  `phase-history.log` da spec + prosseguir; legal também loga. Nunca bloquear.
  (FR-009, SC-004)
- [ ] **T014** [US2] Validação Fase 2: alterar um guard/escala e ver bloco +
  mermaid refletirem sem edição de prosa; forçar `tasks → archived` e conferir
  warning + entrada de log + prosseguimento. (SC-001, SC-004)

## Phase 3 — Fusão parcial spec + plan (US3, P3 · por último)

- [ ] **T015** [US3] Decidir e registrar o nome do documento de design
  (reusar `spec.md` com seções vs `design.md`) — resolve open item do plan.
- [ ] **T016** [US3] Unir `spec-template.md` + `plan-template.md` num template
  de design com seções distintas; `tasks-template.md` intacto. [dep: T015]
  (FR-011, FR-012)
- [ ] **T017** [P] [US3] `specify.md` e `plan.md` [dep: T016]: escrever em
  seções distintas do documento de design; `current_phase` segue
  `specify → plan → tasks`. (FR-011)
- [ ] **T018** [P] [US3] `setup-plan.sh` + `check-prerequisites.sh` [dep:
  T016]: deixar de tratar `plan.md` isolado; checar a **seção de plano**.
  (FR-012)
- [ ] **T019** [US3] Migração idempotente de specs legados (script novo ou
  extensão do `migrate-docs-structure.sh`) [dep: T016]: fundir
  `spec.md`+`plan.md` no documento de design sem perda; `--dry-run`. (FR-013)
- [ ] **T020** [US3] Validação Fase 3: smoke run do pipeline em spec de
  scratch; migrar um spec legado com `--dry-run` e rodar 2x (idempotência).
  (SC-005)

## Cross-cutting / fechamento

- [ ] **T021** [P] Atualizar docs do produto que descrevem o fluxo/scripts:
  `README.md` (raiz — nota de sync do mermaid, FR-016), `.claude/rules/
  scripts.md` (adicionar `legal_moves.sh`), `CLAUDE.md` se o inventário mudar.
- [ ] **T022** Rodar `bash mosk/.claude/mosk/scripts/audit-docs-paths.sh
  --quiet` e `sync-agents-skills.sh --dry-run` / `link-codex-skills.sh` se
  rosters mudarem; smoke-install em diretório de scratch para checar a árvore
  materializada.

## Dependências (resumo)

- Fase 1 (T001-T008) é o MVP e precede tudo.
- T006 depende de T001-T003; T007 depende de T006.
- Fase 2 depende do grafo (T001-T003) existir; T010/T011 dependem de T009.
- Fase 3 é a última; T016 é a raiz da fase, T017-T019 dependem dela.
- T021/T022 fecham após a fatia entregue.

## Sequenciamento de entrega

MVP = **Fase 1** (grafo consultivo + suggestion derivado + drift do enum
curado). Entregável e demonstrável sozinho. Fase 2 completa o subtrativo +
auditoria. Fase 3 (fusão de documentos) é opt-in e sequenciada por último,
podendo ir num PR separado.
