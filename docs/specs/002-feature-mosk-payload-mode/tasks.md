---
description: "Task list for building the /mosk-bench mode (persona Bento) inside the mosk/ template"
---

# Tasks: Modo `/mosk-bench` (persona Bento)

**Input**: `docs/specs/002-feature-mosk-payload-mode/` (spec.md, plan.md)
**Prerequisites**: plan.md (required), spec.md (required)
**Escopo**: construir as peças em `mosk/` (shipam via degit), exceto o template da rule que gera `payload.md` por projeto.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: pode rodar em paralelo (arquivos diferentes, sem dependência).
- **[Story]**: US1 (criar do zero), US2 (iteração aditiva), US3 (ambiente sem Docker).
- Caminhos exatos incluídos.

> **Nota de teste**: o toolkit MOSK não tem suite automatizada; a validação é manual (leitura estrutural, cross-refs, smoke-install via degit, `--dry-run` dos scripts). Os "testes" do produto gerado (Vitest/Local API) vivem no starter, não neste repo.

---

## Phase 1: Setup

**Purpose**: preparar o esqueleto dos diretórios das novas peças em `mosk/`.

- [x] T001 Criar diretórios: `mosk/.claude/skills/mosk-bench/`, `mosk/.claude/mosk/templates/payload-starter/src/collections/`, `mosk/.claude/mosk/templates/payload-starter/src/tests/`, `mosk/.claude/mosk/templates/payload-starter/.mosk-infra/`.

---

## Phase 2: Foundational — Starter versionado (M1) 🎯 base "sobe e loga"

**Purpose**: golden starter que sobe e loga antes de qualquer customização (ADR-0003). Bloqueia US1/US2 (o build da Fase B depende do starter e dos smoke tests).

**⚠️ CRITICAL**: nenhuma story funciona end-to-end sem o starter verde.

- [x] T002 [P] Criar `mosk/.claude/mosk/templates/payload-starter/docker-compose.yml` — só serviço `app` (`node:22-bookworm-slim`, sem build), código como volume + volume nomeado `node_modules`, rede externa `mosk-net`, `${ADMIN_PORT}:3000`, `command: corepack enable && pnpm install && pnpm dev` (FR-010).
- [x] T003 [P] Criar `mosk/.claude/mosk/templates/payload-starter/.mosk-infra/docker-compose.yml` — Postgres `16-alpine` + Redis `7-alpine` + rede `mosk-net` (`name: mosk-net`, quem cria a rede), volumes nomeados persistentes (FR-005, ADR-0001).
- [x] T004 [P] Criar `mosk/.claude/mosk/templates/payload-starter/{.env.example,.gitignore}` — `.env.example` documenta `DATABASE_URI/REDIS_URL/PAYLOAD_SECRET/ADMIN_PORT`; `.gitignore` ignora `.env`, `node_modules`, `dist`.
- [x] T005 [P] Criar `mosk/.claude/mosk/templates/payload-starter/{package.json,pnpm-lock.yaml,tsconfig.json}` — deps Payload+Vitest pinadas; scripts `dev`/`test`/`migrate`; lockfile versionado para subida reprodutível.
- [x] T006 Criar `mosk/.claude/mosk/templates/payload-starter/payload.config.ts` — i18n `fallbackLanguage: 'pt'`, admin **sem** `hidden`/agrupamentos (menu completo — INV-1), registro de collections (FR-011).
- [x] T007 [P] Criar `mosk/.claude/mosk/templates/payload-starter/src/collections/Users.ts` — collection base `auth: true`, labels pt-BR; login funciona no primeiro `pnpm dev`.
- [x] T008 [P] Criar `mosk/.claude/mosk/templates/payload-starter/src/tests/smoke.test.ts` — smoke via Local API: admin instancia, login funciona, Postgres e Redis conectam (FR-019).

**Checkpoint M1**: teste manual local — `docker compose up` no starter sobe admin em pt-BR, login OK, smoke verde.

---

## Phase 3: Foundational — Scripts determinísticos (M2)

**Purpose**: ambiente + infra + provisionamento sem expor nada técnico ao leigo. Bloqueia US1/US2/US3.

- [x] T009 [US3] Criar `mosk/.claude/mosk/scripts/payload-env.sh` — validação Docker na ordem `docker --version → docker info → docker compose version`; faltando Docker, instalação guiada com **uma confirmação** (detecta SO, comando oficial, Linux `sudo`), nunca silenciosa, recusa → para amigável; `--help`, `--dry-run`, `source common.sh` (FR-003/004).
- [x] T010 [US1] Criar `mosk/.claude/mosk/scripts/payload-infra.sh` — detecção/criação/reuso idempotente da infra (`docker network inspect mosk-net`, copia `.mosk-infra/` p/ `~/projects/.mosk-infra/`, `up -d`) + health gate `pg_isready`/`redis-cli ping`; `--help`, `--dry-run` (FR-005/006).
- [x] T011 [US1] Adicionar a `payload-infra.sh` o modo `--provision <projeto>` — DB próprio (checa `pg_database` antes de `CREATE DATABASE`, slug `[a-z0-9_]`), índice Redis livre (0–15, fallback prefixo `<projeto>:`), porta livre por bind-test desde 3000, tudo gravado em `~/projects/.mosk-infra/registry.yaml` (FR-007/008).

**Checkpoint M2**: `--dry-run` limpo nos dois scripts; rodar 2x não corrompe; `registry.yaml` aloca db/porta/redis sem colisão.

---

## Phase 4: Peças de prompt (M3)

**Purpose**: persona, orquestração, gatilho e template da rule. Serve todas as stories.

- [x] T012 Criar `mosk/.claude/mosk/agents/bench.md` — persona Bento (pt-BR simples, conduz grill com paciência, nunca expõe termo técnico), lê `.claude/rules/*.md` na ativação, `## Task mapping → bench-mode.md` (FR-001/002/033).
- [x] T013 [P] Criar `mosk/.claude/skills/mosk-bench/SKILL.md` — wrapper `/mosk-bench` → agente Bento, padrão dos demais skills, descrição com gatilhos (FR-031).
- [x] T014 [P] Criar `mosk/.claude/mosk/templates/payload-rule-tmpl.md` — base pt-BR p/ gerar `.claude/rules/payload.md` por projeto (menu completo, collections=módulos, convenções, portas/DB alocados), no molde de `boot.md` (FR-036).
- [x] T015 Criar `mosk/.claude/mosk/tasks/bench-mode.md` (esqueleto do fluxo §6): validar ambiente (T009) → provisionar infra (T010/T011) → scaffold **ou** detectar bootstrap → chamar Fase A → congelar briefing → derivar testes → disparar Fase B → entregar pt-BR (FR-032). *(A seção de orquestração da Fase B é detalhada em T019.)*

---

## Phase 5: US1 — Criar ferramenta do zero + Fase A/B (M4/M5) 🎯 MVP

**Goal**: fluxo end-to-end do leigo (spec US1). **Independent Test**: `/mosk-bench` em máquina só com Docker gera ferramenta que sobe/loga/responde às regras, sem decisão técnica exposta.

- [x] T016 [US1] Em `bench-mode.md`: bloco de **scaffold de projeto novo** — copia `payload-starter/` as-is p/ `~/projects/<nome>`, `git init`, gera `.env` (DB/porta/Redis do `registry.yaml`), gera `.claude/rules/payload.md` a partir do T014 (FR-009).
- [x] T017 [US1] Em `bench-mode.md`: **Fase A (grill)** — invoca `tasks/grill.md` com checklist obrigatório (collections+campos, papéis, integrações, labels pt-BR, regras, critério de "pronto"); pergunta só regra de negócio; bifurcação técnica → default+aviso; converge só com checklist 100%; escape "chega" congela com lacunas (FR-013/014/015/016).
- [x] T018 [US1] Em `bench-mode.md`: **congelar briefing + derivar testes** — grava `briefing.md`+`checklist.yaml`; deriva camadas de teste (smoke herdado; por collection: existe/campos/CRUD/papéis; asserts de regra) via Local API, simetria checklist=testes (FR-017/018/019).
- [x] T019 [US1] Em `bench-mode.md`: **Fase B (build headless)** — orquestração SDD `specify→plan→tasks→build-loop→qa-gate→deliver` como **contrato de fases agnóstico de runtime (RAPC)**, estado por filesystem (`spec-meta.yaml.current_phase`, artefatos, `decisions-log.md`), loop determinístico com `MAX_FIX_ATTEMPTS=3`, auto-escalação escopada (ADR-0002). Isolamento via **um único seam** `invoke_phase_agent(role, phase, spec_dir)`: **Tier 1** = subagente nativo (Claude Code, isolamento estrutural); **Tier 2** = mesma sessão com supressão de output + `build-log.md` (Codex, isolamento lógico). **Contrato de apresentação único** (mesma linha de progresso pt-BR por fase + entrega final nos dois runtimes). `gate.yaml`, entrega pt-BR (FR-020..029, ADR-0004). ✅ **Desbloqueado** por T020.
- [x] T020 [US1] **[RESOLVIDO]** ADR-0004 fechado — síntese: contrato de fases agnóstico de runtime + isolamento como capacidade (Tier 1 estrutural / Tier 2 lógico), **não** (a) puro nem (b) nivelado por baixo. Ver `architecture/adr-0004-runtime-agnostic-phase-orchestration.md` (promove p/ `docs/architecture/adr/`). Ajustes aplicados: FR-030 e Edge Case Codex suavizados para "equivalente + isolamento por capacidade"; T019 reescrito.

**Checkpoint US1/MVP**: fluxo do zero à ferramenta rodando; smoke+regra verdes; entrega pt-BR com URL/credenciais.

---

## Phase 6: US2 — Iteração aditiva (M5)

**Goal**: reativar num projeto existente (spec US2). **Independent Test**: reativar → scaffold pulado → spec aditiva N rastreável no git → mudança sobe sem quebrar.

- [x] T021 [US2] Em `bench-mode.md`: **detecção de bootstrap** — projeto existente pula scaffold, reusa infra/provisionamento do `registry.yaml` (sem reprovisionar) e entra direto no grill do incremento (FR-012). Feito: Fase 3 (roteamento) + Fase 6a/6b.
- [x] T022 [US2] Em `bench-mode.md`: **ciclo SDD aditivo** — build gera **spec aditiva N** (não 001) via `create-new-feature.sh`, reusando o contrato SDD; rastreável no git (FR-021). Feito: Fase 6c (build aditivo com preservação + regressão acumulada).

**Checkpoint US2**: reativação produz spec incremental; scaffold não recopiado; infra reusada.

---

## Phase 7: Sincronização, paridade e validação (M6)

**Purpose**: manter as três camadas alinhadas, paridade Codex e docs.

- [x] T023 Rodar `bash mosk/.claude/mosk/scripts/sync-agents-skills.sh --clean` (gera `.claude/agents/mosk-bench.md`, alinha as 3 camadas) e validar cross-refs skill↔agente↔task (FR-037).
- [x] T024 **Resolvido por decisão (não rodar no template):** `link-codex-skills.sh` gera `AGENTS.md`/`.codex` per-root, que **não** shipam via degit. Por regra do workspace (CLAUDE.md), a paridade Codex do template vem das **skills sob `mosk/.claude/skills/`** — o consumidor regenera o próprio `AGENTS.md` pós-install. A skill `mosk-bench` já está presente, então a paridade estrutural (FR-030) está satisfeita. Rodar aqui violaria a regra de não gerar artefatos per-root não-shippáveis.
- [x] T025 [P] Smoke-install validado por **simulação local** (cópia de `mosk/.` → dir consumidor, equivalente ao que o degit extrai): skill/task/agente/starter(22 arquivos)/scripts materializam; referências skill→`agents/bench.md` íntegras; pins corrigidos (`next 15.3.9` + `@payloadcms/translations`) presentes; README M1 sem o comando de rede bugado; Fase 6 (US2) completa. Runtime do starter validado à parte (smoke 5/5, admin pt-BR). **Ressalva:** o `npx degit` real contra o GitHub só refletirá isto após os commits da feature serem enviados (push).
- [x] T026 Atualizar docs do repo (CLAUDE.md/README/rules) mencionando o modo `/mosk-bench` e refrescar `docs/index.md`. Feito: README (roster + nota do modo), CLAUDE.md (10 agents), `.claude/rules/project.md` (10 persona prompts + nota bench), TASKS.md (linha `/mosk-bench` em Standalone skills), `docs/index.md` (refs `/mosk-payload`→`/mosk-bench`, fase `implement`, ADR-0004). Index atualizado à mão (não via `index-docs`) para preservar o conteúdo PMO curado.

---

## Dependencies & Execution Order

- **Setup (T001)** → primeiro.
- **Foundational Starter (T002–T008)** e **Scripts (T009–T011)** → bloqueiam as stories; podem correr em paralelo entre si (arquivos distintos), respeitando T006 depois de T005 (config depende de deps).
- **Prompt (T012–T015)** → depois do starter/scripts existirem (a task os referencia).
- **US1 (T016–T020)** → depende de Foundational + Prompt. **T020 (ADR-0004) resolvido → T019 desbloqueado.**
- **US2 (T021–T022)** → depende de US1 (reusa scaffold/Fase B).
- **Sync/validação (T023–T026)** → por último; T023 antes de T024.

### Parallel Opportunities
- T002, T003, T004, T005, T007, T008 (arquivos distintos do starter).
- T013 e T014 em paralelo a T012 (skill/template vs agente).
- T025 em paralelo a T026.

---

## Implementation Strategy

### MVP (US1)
1. T001 → Foundational (T002–T011) → Prompt (T012–T015).
2. ✅ **T020 (ADR-0004) fechado** — T019 desbloqueado.
3. US1 (T016–T019) → **validar end-to-end** (leigo do zero à ferramenta rodando).

### Incremental
- + US2 (T021–T022): iteração aditiva.
- + Sync/paridade/validação (T023–T026): degit smoke, Codex, docs.

---

## Notes

- **Bloqueio resolvido**: T020 (ADR-0004) fechado — a redação da Fase B (T019) segue o RAPC + seam `invoke_phase_agent` (Tier 1/Tier 2). Nada trava o `implement`.
- Todas as peças (exceto `payload.md`, gerada por projeto) shipam via degit — devem viver sob `mosk/`.
- Scripts idempotentes, `--help`, `--dry-run`, `source common.sh`.
- Invariantes INV-1..6 travadas por construção no starter, nunca deixadas para o LLM.
- Commit após cada task ou grupo lógico; validação é manual (sem suite no toolkit).
