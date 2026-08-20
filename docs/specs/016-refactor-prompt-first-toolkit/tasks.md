---
description: "Tasks — toolkit prompt-first (ADR-0021)"
---

# Tasks: Toolkit prompt-first

**Input**: `docs/specs/016-refactor-prompt-first-toolkit/`
**Prerequisites**: [spec.md](./spec.md), [plan.md](./plan.md), [ADR-0021](./architecture/adr-0021-declarative-rule-minimal-shell.md)

**Tests**: sem suíte de self-test de shell (ADR-0021 §6). O que se prova aqui é que o dado declarado e o prompt que o lê concordam — fixtures de contrato dentro do `validate.sh`, e um caso de regressão real (a spec 014).

**Organization**: agrupadas por user story, na ordem das fases A→E do plano. A ordem importa: cada fase remove o que tornaria a seguinte cara.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: pode rodar em paralelo — arquivos distintos, sem dependência
- **[Story]**: `US1`–`US5`; tasks sem marcador são compartilhadas

---

## Phase 1: Setup

- [x] T001 Medir e registrar a linha de base em `docs/specs/016-refactor-prompt-first-toolkit/baseline.md`: linhas por script, chamador de cada um, contagem de funções de `common.sh`. É contra este arquivo que SC-001 e SC-003 são verificados no fim.

---

## Phase 2: Foundational — declarar a regra (Fase A)

**⚠️ Bloqueante**: nada é removido antes desta fase terminar. `pipeline.yaml` e shell coexistem aqui, e devem concordar — é a única duplicação aceitável da spec, e ela é temporária por construção (FR-009).

- [x] T002 [US1] Criar `mosk/.claude/mosk/pipeline.yaml` com as 6 fases (`specify`, `plan`, `tasks`, `implement`, `qa-gate`, `archived`) e, por fase, as arestas válidas em `transitions_to` — traduzido de `phase_transition_allowed` em `common.sh`, sem inventar aresta nova
- [x] T003 [US1] Declarar em `pipeline.yaml` a exceção `qa-gate -> implement` como atributo `allowed_commands: [apply-qa-fixes]` da aresta — traduzido de `phase_command_matches_destination`
- [x] T004 [US1] Declarar `phases[].requires` — artefatos obrigatórios por fase, traduzido de `validate_phase_preconditions`
- [x] T005 [US1] Declarar o bloco `gate`: vereditos válidos (`PASS`, `CONCERNS`, `FAIL`, `WAIVED`), forma do waiver (justificativa, aprovador, timestamp UTC) e quais vereditos permitem avançar — traduzido de `validate_gate_contract` e `validate_gate_for_completion`
- [x] T006 [US1] Declarar em `phases.archived.requires` a exigência de promoções satisfeitas — traduzido de `validate_spec_promotions_satisfied`
- [x] T007 [P] [US1] Mover a classificação de risco/escopo de `classify-change.sh` para `mosk/.claude/mosk/data/adaptive-work-contract.md` como tabela declarativa
- [x] T008 [US1] Conferir cada uma das regras da tabela do plano contra sua origem em shell, uma a uma, e registrar a conferência — feito em [rule-migration-audit.md](./rule-migration-audit.md); a tabela fechou com **9** regras, não 7 (FR-009)

---

## Phase 3: US1 — inverter o leitor (Fase B)

**Objetivo**: o agente vira o único leitor de dado estruturado; script recebe valor por argumento (ADR-0021 §3). É esta fase que faz 33 funções de `common.sh` perderem chamador.

- [x] T009 [US1] Reescrever `plan.md`, `tasks.md`, `implement.md`, `qa-gate.md`, `archive.md` e `apply-qa-fixes.md` para aplicar a transição sem `transition-spec-phase.sh` — as seis referenciam `data/phase-transition-contract.md`, criado para não repetir o procedimento seis vezes
- [x] T010 [US1] Remover das mesmas tasks a regra repetida em prosa (FR-002). Também invertidos os leitores de estado: `setup-plan.sh` e `check-prerequisites.sh` saíram de `plan.md`, `tasks.md` e `implement.md` — o agente resolve a spec pelo branch e lê os artefatos
- [x] T011 [US1] ~~Mover a emissão do `spec-meta.yaml` para `specify.md`~~ — **rota corrigida**. O emissor está dentro do laço de retry da corrida de numeração (caso 1 da lista fechada do ADR-0021): tirá-lo quebraria a atomicidade branch+pasta+commit+push. O que foi feito: eliminada a **duplicação real** — o script tinha `write_initial_spec_meta` e o `common.sh` tinha `write_spec_meta`, dois emissores do mesmo arquivo, divergindo em `type:`. Agora há um só, com escrita atômica e suporte a `extends`
- [x] T012 [US1] **Não se aplica** — consequência da correção de rota da T011. O `specify.md` segue recebendo o meta pronto do script, que é onde a corrida acontece
- [x] T013 [US1] Substituir `update-agent-context.sh` por instrução dentro de `plan.md` — o agente reflete stack/framework/datastore em `.claude/rules/project.md`
- [x] T014 [US1] Verificar AS-4 — provado: as 6 arestas do YAML batem uma a uma com o `case` de `phase_transition_allowed`; removendo `archived` de `qa-gate.transitions_to` só no YAML, o archive deixa de ser aceito. Revertido limpo

---

## Phase 4: US3 — uma validação, com chamador (Fase C)

**Objetivo**: fundir os quatro auditores e resolver a falha que deixou a 014 passar. O chamador é task **desta** fase, não posterior — é a mitigação explícita do risco de repetir o erro.

- [x] T015 [US3] Criar `validate.sh` com os quatro casos como subcomandos (`install`, `prerequisites`, `ship-ready`, `docs-paths`), mais `self-check` e `fixtures`. 437 linhas contra 717 dos quatro somados
- [x] T016 [US3] Sem dependência externa: o `self-check` usa PyYAML quando existe e **pula com aviso** quando não (FR-007)
- [x] T017 [US3] 12 fixtures de contrato embutidas. Escritas **antes** do leitor estar correto, e reprovaram: `gate: |` devolvia `|`. A causa era o padrão ser blocklist — trocado por allowlist
- [x] T018 [US3] Fixture de regressão da 014 (spec em `qa-gate` reprova). Equivalência com `check-ship-ready.sh` conferida no repo real: mesmas 4 falhas, mesma ordem
- [x] T019 [US3] `hooks/guard-spec-merge.sh` criado, **ativo neste repo** e shipado no template; `boot.md` ganhou a Phase 2.55 que o registra em projetos consumidores (FR-008)
- [x] T020 [US3] Chamadores nomeados no `--help` do `validate.sh` e no `boot.md`

---

## Phase 5: US2 — o corte (Fase D)

**Pré-condição**: nenhum dos scripts abaixo pode ter chamador restante. Se algum tiver, a Fase 3 ou 4 não terminou.

- [x] T021 [P] [US2] Removidos os quatro `selftest-*.sh` — 1.726 linhas
- [x] T022 [P] [US2] Removidos `transition-spec-phase`, `setup-plan`, `classify-change`, `update-agent-context`, `audit-legacy-surface` — 1.611 linhas. `validate.sh single-source` absorveu a checagem de fonte única do último
- [x] T023 [P] [US2] Removidos `doctor`, `check-prerequisites`, `check-ship-ready`, `audit-docs-paths`. R4 e R5 do auditor implementados no `validate.sh` antes da remoção
- [x] T024 [US2] Os dois migradores viraram a task `migrate-install.md` — 684 linhas de shell trocadas por um prompt que decide lendo o conteúdo, não casando nome de arquivo
- [x] T025 [US2] `sync.sh` funde os dois (807 → 619) e remove o `skills_to_agents`, que era dead code. Equivalência conferida: `AGENTS.md` idêntico, mesmas 23 skills
- [x] T026 [US2] `common.sh` de 39 para **18** funções e 1.334 → 586 linhas. O número bate com a correção da T008 (~14), não com a estimativa original (~6)
- [x] T027 [US2] Verificado em [cut-report.md](./cut-report.md). **SC-002 e SC-003 atingidos**; **SC-001 não**: 2.730 contra a meta de 1.500. A meta foi estimada antes de os scripts serem lidos — mesmo padrão que já errara em T011 e T026
- [x] T028 [US2] `payload-infra.sh` sinalizado no `cut-report.md`: sem chamador, mas fora do escopo — pendência para spec própria

---

## Phase 6: US4 — o runner sobre a primitiva do runtime

- [x] T029 [US4] Colher da branch da 015 — feito em `harvest/`, com procedência e o descarte justificado item a item em [harvest/README.md](./harvest/README.md). Resta promover para `mosk/.claude/mosk/` na implementação
- [x] T030 [US4] `orq-run.md` Step 1 materializa o `execution-plan.yaml`; template promovido do `harvest/` e adaptado (schema 2, sem digest, sem gramática restrita)
- [x] T031 [US4] Preflight ganhou a linha `Isolamento:` e o plano ganhou `execution.mode_effective`. A primitiva do runtime já era usada; o que faltava era **declarar** o modo
- [x] T032 [US4] Estado no front-matter do `run-log.md` (`units_merged`, `attempts`, `current_wave`). Um arquivo a menos, e o estado ao lado do histórico que o explica
- [x] T033 [US4] Conferência em [spec-015-requirements-check.md](./spec-015-requirements-check.md). **A US5 (falha tem dono) estava descoberta** e só apareceu ao ler os cenários um a um — Step 5 ganhou a atribuição por interseção de `files`

---

## Phase 7: US5 — alinhar os documentos (Fase E)

**Sem esta fase o roadmap vigente continua instruindo o contrário e a próxima spec repete o padrão.**

- [x] T034 [US5] Roadmap: Etapa 1 marcada como entregue, **Etapa 2 substituída**, Etapa 3 entregue (spec 014), **Etapa 4 refeita** pela 016, Etapa 5 preservada e agora é a próxima. Métricas e ordem de decisão emendadas
- [x] T035 [P] [US5] `.claude/rules/scripts.md` reescrito: 6 scripts com chamador, a regra de decisão em primeiro lugar, e a tabela do que saiu e para onde
- [x] T036 [P] [US5] `CLAUDE.md` e `project-rule-tmpl.md` atualizados. As seções MOSK-invariantes foram preservadas; a de Spec Numbering trocou a menção ao script pelo contrato + `pipeline.yaml`
- [x] T037 [US5] Regra de decisão publicada em três lugares: `CLAUDE.md` (este repo), `.claude/rules/scripts.md` (antes do inventário) e `project-rule-tmpl.md` (**chega aos consumidores** via `/mosk-boot`)
- [x] T038 [US5] `sync.sh skills` limpo (12 wrappers preservados). **SC-007 atingido**: nenhum documento vigente instrui a mover regra para Bash

---

## Fora do escopo desta spec

- **Fechamento da 014** (mesclada em `qa-gate`): pendência real, decisão do usuário, não bloqueia esta spec.
- **Apagar a branch da 015**: a colheita é T029; a branch fica.
- `payload-*.sh`, modo bench e deploy.
