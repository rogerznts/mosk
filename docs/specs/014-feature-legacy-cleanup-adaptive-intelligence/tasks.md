# Tasks: Limpeza do legado e inteligência adaptativa

**Input**: Design documents from `docs/specs/014-feature-legacy-cleanup-adaptive-intelligence/`
**Prerequisites**: `plan.md`, `spec.md`, `data-model.md`, `contracts/adaptive-work-contract.md`, `quickstart.md`

**Tests**: Obrigatórios por FR-026 e pelos critérios SC-002, SC-003, SC-005 e SC-007. Criar primeiro as regressões que provam o comportamento atual indesejado e mantê-las vermelhas até a implementação correspondente.

**Organization**: O trabalho começa por baseline e contratos compartilhados; depois entrega cada jornada de forma verificável. Toda edição nasce em `mosk/.claude/`; `.claude/` só é atualizado na fase de integração.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: pode ser executada em paralelo porque não disputa arquivos nem depende da saída ainda não produzida por outra tarefa.
- **[USN]**: história rastreada em `spec.md`.
- Cada descrição contém paths e condição concreta de conclusão.

## Phase 1: Baseline e guardrails

**Purpose**: Congelar a superfície atual antes de remover ou compactar qualquer comportamento.

- [x] T001 Confirmar e registrar as 50 tasks atuais contra `docs/specs/archive/012-feature-stabilize-toolkit-contracts/legacy-task-inventory.md` em `docs/specs/014-feature-legacy-cleanup-adaptive-intelligence/legacy-baseline.md`, destacando qualquer divergência antes de editar o corpus.
- [x] T002 Criar `mosk/.claude/mosk/data/task-dispositions.tsv` com exatamente uma linha por task, ação `keep|rewrite|merge|remove`, destino, consumidores, estado de evidência e justificativa conforme FR-001/FR-002.
- [x] T003 Medir as linhas operacionais das 18 tasks `rewrite` com fórmula reproduzível e salvar a baseline por arquivo e total em `docs/specs/014-feature-legacy-cleanup-adaptive-intelligence/legacy-baseline.md`.
- [x] T004 [P] Criar allowlist mínima de `license|attribution|archive` em `mosk/.claude/mosk/data/legacy-reference-allowlist.tsv`, sem cobrir fonte operacional ativa por wildcard amplo.
- [x] T005 Escrever primeiro testes vermelhos em `mosk/.claude/mosk/scripts/selftest-toolkit.sh` para task ausente/duplicada, ação inválida, merge sem destino, consumidor órfão e referência ativa a path removido.
- [x] T006 Escrever primeiro testes vermelhos em `mosk/.claude/mosk/scripts/selftest-toolkit.sh` para ocorrência BMAD operacional fora da allowlist e para preservação de atribuição/licença permitida.
- [x] T007 Implementar `mosk/.claude/mosk/scripts/audit-legacy-surface.sh` para validar T002–T006, reportar contagens/referências e falhar fechado sem depender de rede.

**Checkpoint**: O inventário e a métrica são reproduzíveis; nenhuma remoção pode ocorrer silenciosamente.

---

## Phase 2: Fundação adaptativa compartilhada

**Purpose**: Entregar o contrato determinístico que todas as jornadas consumidoras utilizarão.

**⚠️ CRITICAL**: Esta fase bloqueia a integração adaptativa em implement, security, QA e orquestração.

- [x] T008 [P] Copiar e ajustar o contrato aprovado para a fonte canônica `mosk/.claude/mosk/data/adaptive-work-contract.md`, mantendo enums, score, pisos, budgets e limites da Etapa 4.
- [x] T009 [P] Criar `mosk/.claude/mosk/schemas/change-profile.schema.json` com `additionalProperties: false`, enums fechados, tipos e campos obrigatórios do output definido em `contracts/adaptive-work-contract.md`.
- [x] T010 [P] Criar fixtures de limites, pisos e falhas de input em `mosk/.claude/mosk/data/adaptive-work-fixtures.tsv`, cobrindo scores 2/3, 5/6, 9/10, todos os pisos, elevação manual e duplicidade contraditória.
- [x] T011 Escrever primeiro `mosk/.claude/mosk/scripts/selftest-adaptive-work.sh` para consumir T010 e exigir equivalência semântica em Bash/zsh, ordenação estável, schema válido quando a ferramenta existir e falha sem output para input inválido.
- [x] T012 Implementar `mosk/.claude/mosk/scripts/classify-change.sh` com parser allowlisted, score/pisos determinísticos, JSON formado apenas por constantes e status não zero para opções ausentes, desconhecidas ou contraditórias.
- [x] T013 Adicionar casos adversariais a `mosk/.claude/mosk/scripts/selftest-adaptive-work.sh` para command substitution, metacaracteres, argumentos repetidos, tentativa de rebaixamento e valores Unicode inesperados, provando que nada é avaliado como shell/path.
- [x] T014 Integrar descoberta e execução dos novos checks em `mosk/.claude/mosk/scripts/doctor.sh` e `mosk/.claude/mosk/scripts/selftest-toolkit.sh`, mantendo a instalação isolada autocontida.

**Checkpoint**: O mesmo conjunto de sinais produz o mesmo perfil em Bash e zsh e nenhum sinal crítico pode ser rebaixado.

---

## Phase 3: User Story 1 — Fluxo direto, sem cerimônia herdada (Priority: P1) 🎯 MVP

**Goal**: Criar documentos e avançar em pedidos claros sem menus ou confirmações mecânicas, com uma única rodada agrupada apenas quando realmente bloqueante.

**Independent Test**: Fixtures claras, ambíguas, opt-in e irreversíveis comprovam respectivamente 0 perguntas, 1 rodada agrupada, elicitação avançada sob demanda e pausa humana preservada.

### Tests for User Story 1

- [x] T015 [P] [US1] Adicionar fixtures de conversa para pedido claro, ambiguidade material, opt-in avançado e ação irreversível em `mosk/.claude/mosk/data/direct-flow-fixtures.md` com outputs/limites esperados.
- [x] T016 [US1] Escrever primeiro regressões em `mosk/.claude/mosk/scripts/selftest-toolkit.sh` que detectem menus obrigatórios `1-9`, hard stop por `elicit: true`, mais de uma rodada de pergunta e ausência de rota opt-in.

### Implementation for User Story 1

- [x] T017 [US1] Reescrever `mosk/.claude/mosk/tasks/create-doc.md` para geração direta, decisão por ambiguidade material e no máximo uma rodada agrupada, referenciando o contrato adaptativo sem duplicá-lo.
- [x] T018 [US1] Reescrever `mosk/.claude/mosk/tasks/advanced-elicitation.md` como modo explicitamente opt-in, sem autoativação pelo template nem menu obrigatório no retorno ao happy path.
- [x] T019 [P] [US1] Simplificar `mosk/.claude/mosk/tasks/create-brief.md` e `mosk/.claude/mosk/tasks/create-market-research.md` para chamar o contrato direto e remover instruções duplicadas de seleção `1-9`.
- [x] T020 [P] [US1] Simplificar `mosk/.claude/mosk/tasks/create-competitor-analysis.md` e `mosk/.claude/mosk/tasks/create-deep-research-prompt.md` com o mesmo contrato de clarificação agrupada.
- [x] T021 [US1] Remover hard stops de elicitação dos templates documentais em `mosk/.claude/mosk/templates/project-brief-tmpl.yaml`, `market-research-tmpl.yaml`, `competitor-analysis-tmpl.yaml`, `prd-tmpl.yaml` e templates de arquitetura, preservando seções opcionais acionáveis explicitamente.
- [x] T022 [P] [US1] Ajustar `mosk/.claude/mosk/tasks/full-spec.md`, `specify.md`, `plan.md` e `tasks.md` para explicitar o limite de uma rodada agrupada no fluxo e evitar confirmações entre transições reversíveis.
- [x] T023 [US1] Atualizar os agentes consumidores em `mosk/.claude/agents/mosk-analyst.md`, `mosk-po.md`, `mosk-pm.md` e `mosk-architect.md` para expor linguagem natural e elicitação opt-in sem replicar menus.
- [x] T024 [US1] Executar T015/T016 em pedidos simulados e registrar evidência de 0/1 rodada em `docs/specs/014-feature-legacy-cleanup-adaptive-intelligence/qa-notes.md`.

**Checkpoint**: O happy path funciona sem cerimônia herdada e mantém limites humanos reais.

---

## Phase 4: User Story 2 — Superfície menor sem perda de capacidade (Priority: P1)

**Goal**: Reescrever/consolidar o inventário e absorver candidatas de fusão sem quebrar rotas públicas.

**Independent Test**: Auditoria 50/50, zero órfã/referência quebrada e fixtures das três capacidades no novo destino.

### Tests for User Story 2

- [ ] T025 [P] [US2] Criar fixtures de capacidade para mapear projeto via boot/Architect em `mosk/.claude/mosk/data/merged-task-fixtures.md` antes de remover `map-project.md`.
- [ ] T026 [P] [US2] Criar fixtures de capability para revisão de story via qa-gate story mode em `mosk/.claude/mosk/data/merged-task-fixtures.md` antes de remover `review-story.md`.
- [ ] T027 [P] [US2] Criar fixtures de capability para saída webdesign via UI Expert/Hallmark em `mosk/.claude/mosk/data/merged-task-fixtures.md` antes de remover `webdesign-output.md`.
- [ ] T028 [US2] Estender `mosk/.claude/mosk/scripts/selftest-toolkit.sh` para executar T025–T027 e exigir destino/rota/cobertura antes de aceitar ausência dos arquivos antigos.

### Implementation for User Story 2

- [ ] T029 [P] [US2] Consolidar readiness em `mosk/.claude/mosk/checklists/story-readiness-checklist.md`, reescrevendo `mosk/.claude/mosk/tasks/enrich-story.md` e `review-story-draft.md` para uma única fonte de critérios.
- [ ] T030 [US2] Consolidar o contrato de evidência de QA entre `mosk/.claude/mosk/tasks/assess-risk.md`, `assess-nfr.md`, `design-tests.md`, `trace-spec.md` e `qa-gate.md`, mantendo tarefas especializadas somente quando agregarem saída distinta.
- [ ] T031 [P] [US2] Reescrever `mosk/.claude/mosk/tasks/apply-qa-fixes.md`, `correct-course.md` e `execute-checklist.md` para remover lineage operacional, termos de story incompatíveis e procedimentos duplicados.
- [ ] T032 [P] [US2] Reescrever `mosk/.claude/mosk/tasks/create-epic.md`, `create-story.md` e `shard-doc.md` para linguagem MOSK e referências canônicas.
- [ ] T033 [US2] Absorver `mosk/.claude/mosk/tasks/map-project.md` em `boot.md` e no agente `mosk/.claude/agents/mosk-architect.md`; atualizar rotas/fixtures e só então remover o arquivo antigo e marcar sua evidência `covered`.
- [ ] T034 [US2] Absorver `mosk/.claude/mosk/tasks/review-story.md` no modo story de `qa-gate.md` e no agente `mosk/.claude/agents/mosk-qa.md`; atualizar rotas/fixtures e só então remover o arquivo antigo.
- [ ] T035 [US2] Absorver `mosk/.claude/mosk/tasks/webdesign-output.md` em `hallmark.md` e no agente `mosk/.claude/agents/mosk-ui-expert.md`; preservar a semântica visual legítima de menu e só então remover o arquivo antigo.
- [ ] T036 [US2] Reconciliar todas as tasks restantes em `mosk/.claude/mosk/data/task-dispositions.tsv`, integrando qualquer task sem entrypoint ao agente/skill correto ou removendo-a com prova de não uso.
- [ ] T037 [US2] Executar `mosk/.claude/mosk/scripts/audit-legacy-surface.sh` após cada fusão e fechar a fase somente com 50/50 decisões, zero órfã e zero referência quebrada.

**Checkpoint**: A superfície é menor, mas todas as capacidades públicas da baseline permanecem demonstráveis.

---

## Phase 5: User Story 3 — Profundidade proporcional ao risco (Priority: P2)

**Goal**: Fazer agentes operacionais consumirem o mesmo perfil para contexto, especialistas e validação.

**Independent Test**: A matriz de fixtures produz 100% de concordância e cada consumidor respeita o piso sem criar fase/estado novo.

### Tests for User Story 3

- [ ] T038 [US3] Adicionar testes de integração em `mosk/.claude/mosk/scripts/selftest-adaptive-work.sh` para `implement`, `security-review`, `qa-gate` e `orq-run`, incluindo reclassificação quando o escopo cresce.
- [ ] T039 [US3] Adicionar regressões em `mosk/.claude/mosk/scripts/selftest-pipeline-state.sh` provando que perfis não alteram transições, não truncam histórico e não enfraquecem gate fail-closed.

### Implementation for User Story 3

- [ ] T040 [P] [US3] Integrar seleção de sinais, budget e validation floor em `mosk/.claude/mosk/tasks/implement.md`, com justificativa curta e elevação quando nova evidência ampliar o escopo.
- [ ] T041 [P] [US3] Integrar pisos e especialistas em `mosk/.claude/mosk/tasks/security-review.md` e `assess-security.md`, mantendo independência e chamada explícita sempre válida.
- [ ] T042 [US3] Integrar o perfil como piso mínimo em `mosk/.claude/mosk/tasks/qa-gate.md`, sem permitir PASS quando a evidência exigida estiver ausente.
- [ ] T043 [US3] Integrar agendamento adaptativo e parada humana em `mosk/.claude/mosk/tasks/orq-run.md` e `mosk/.claude/agents/mosk-orq.md`, sem implementar worktrees/checkpoints da Etapa 4.
- [ ] T044 [P] [US3] Atualizar `mosk/.claude/agents/mosk-dev.md`, `mosk-security.md` e `mosk-qa.md` para consumir a fonte canônica e não duplicar score/pisos.
- [ ] T045 [US3] Rodar todas as fixtures por cada consumidor e registrar a matriz de concordância em `docs/specs/014-feature-legacy-cleanup-adaptive-intelligence/qa-notes.md`.

**Checkpoint**: Mudanças simples ficam compactas; sensíveis/críticas recebem rigor mínimo idêntico em todos os agentes.

---

## Phase 6: User Story 4 — Prompts compactos e fontes únicas (Priority: P2)

**Goal**: Reduzir contexto operacional e duplicação sem minificar regras nem esconder comportamento raro necessário.

**Independent Test**: Métrica das 18 tasks cai ao menos 30%, regras comuns têm uma fonte e instalação isolada continua funcional.

### Tests for User Story 4

- [ ] T046 [US4] Estender `mosk/.claude/mosk/scripts/audit-legacy-surface.sh` para medir com a mesma fórmula da baseline, detectar cópias divergentes de contratos e falhar abaixo de 30% de redução no corpus-alvo final.
- [ ] T047 [US4] Adicionar ao `mosk/.claude/mosk/scripts/selftest-toolkit.sh` verificações de referências autocontidas e carregamento sob demanda em instalação isolada.

### Implementation for User Story 4

- [ ] T048 [P] [US4] Reescrever `mosk/.claude/mosk/tasks/bench-mode.md` para mover exemplos extensos/regras raras a referências sob demanda, preservando a persona e capacidades públicas do Bento.
- [ ] T049 [P] [US4] Reescrever `mosk/.claude/mosk/tasks/planner.md` para contrato direto e contexto adaptativo, preservando planejamento vivo e integração documental.
- [ ] T050 [P] [US4] Reescrever `mosk/.claude/mosk/tasks/advanced-elicitation.md`, `create-deep-research-prompt.md` e `facilitate-brainstorming-session.md` para consumir catálogos em `mosk/.claude/mosk/data/` sem incorporar listas extensas no prompt principal.
- [ ] T051 [US4] Revisar as demais 18 tasks `rewrite` listadas em `task-dispositions.tsv`, mover exemplos raros para `mosk/.claude/mosk/data/` somente quando reutilizáveis e eliminar duplicação sem perder fixtures.
- [ ] T052 [US4] Atualizar `mosk/.claude/skills/` por meio do gerador oficial para wrappers mínimos que apontem aos agentes como fonte, sem editar skills geradas manualmente.
- [ ] T053 [US4] Atualizar `mosk/.claude/mosk/data/output-contract.md` e consumidores para uma única forma de resposta, eliminando schemas/instruções equivalentes que a auditoria identificar.

**Checkpoint**: O toolkit carrega menos texto no caminho principal e mantém detalhes raros acessíveis apenas quando relevantes.

---

## Phase 7: Integração, documentação e gates

**Purpose**: Sincronizar produto/local, provar regressão e executar o loop autônomo até o PR.

- [ ] T054 Atualizar `mosk/README.md`, `mosk/TASKS.md`, `mosk/.claude/skills/mosk-help/SKILL.md` e documentação ativa relacionada para explicar fluxo direto, elicitação opt-in e perfis sem expor cerimônia interna.
- [ ] T055 Atualizar `docs/specs/014-feature-legacy-cleanup-adaptive-intelligence/legacy-baseline.md` com inventário final, fusões, fórmula antes/depois e evidência de redução mínima de 30%.
- [ ] T056 Executar `mosk/.claude/mosk/scripts/sync-agents-skills.sh` nos modos oficiais para sincronizar agentes/skills e depois sincronizar `mosk/.claude/` para `.claude/` sem incluir mudanças locais fora da spec.
- [ ] T057 Rodar syntax Bash/zsh, ShellCheck error, schemas, `selftest-common.sh`, `selftest-pipeline-state.sh`, `selftest-toolkit.sh`, `selftest-adaptive-work.sh`, `doctor.sh`, audit de docs, mirrors e diff-check; registrar comandos/resultados em `docs/specs/014-feature-legacy-cleanup-adaptive-intelligence/qa-notes.md`.
- [ ] T058 Validar [quickstart.md](./quickstart.md) integralmente em produto, espelho local e instalação isolada, incluindo inputs adversariais e preservação byte a byte quando a operação falhar.
- [ ] T059 Executar `/mosk-security` diff-aware com foco em parsing de argumentos, command injection, path containment, manipulação de perfil, bypass de pisos e integridade dos gates; corrigir/revalidar até `SECURITY: PASS`.
- [ ] T060 Executar `/mosk-qa qa-gate 014`, aplicar correções e repetir security/QA automaticamente até `Gate PASS`, pausando somente por dúvida real ou ação irreversível.
- [ ] T061 Atualizar `docs/index.md`, confirmar `spec-meta.yaml`/`phase-history.yaml`, staging seletivo da spec 014 e ausência das mudanças locais do archive 013 no diff preparado.
- [ ] T062 Criar commit(s) convencionais, publicar a branch e abrir o PR da Etapa 3; parar no PR sem executar archive nem o E2E final do programa.

---

## Dependencies & Execution Order

### Phase Dependencies

- **Phase 1** não depende de implementação e congela a baseline.
- **Phase 2** depende de T001–T007 e bloqueia consumidores adaptativos.
- **Phase 3 (US1)** depende do contrato de sinais/ambiguidade de Phase 2, mas pode avançar antes das fusões.
- **Phase 4 (US2)** depende da auditoria de Phase 1 e das fixtures T025–T028 antes de qualquer remoção.
- **Phase 5 (US3)** depende de Phase 2 completa e preserva os contratos 012/013.
- **Phase 6 (US4)** depende da baseline T003; T046 só fecha após as reescritas/fusões.
- **Phase 7** depende de todas as jornadas concluídas.

### Critical Path

`T001 → T002 → T005–T007 → T008–T012 → T017/T018 → T028 → T033–T035 → T038–T045 → T046/T051 → T056–T062`

### Parallel Opportunities

- T004 pode avançar enquanto T002/T003 são preparados.
- T008, T009 e T010 usam arquivos distintos; T011 espera suas saídas.
- Fixtures T025–T027 podem ser escritas em paralelo se coordenadas sem sobrescrita; consolidar antes de T028.
- T029, T031 e T032 usam conjuntos diferentes de files.
- Integrações T040/T041 e agentes T044 são separáveis, mas T042/T043 devem consumir o contrato já estável.
- T048 e T049 são independentes; T050/T051 exigem coordenação por arquivos compartilhados.

## Traceability

| Requirement group | Tasks |
|---|---|
| FR-001–FR-003 inventário/remoção segura | T001–T007, T025–T037, T055 |
| FR-004–FR-009 happy path/limites humanos | T015–T024 |
| FR-010–FR-016 perfil adaptativo | T008–T014, T038–T045 |
| FR-017–FR-022 consolidação/legado | T002, T004–T007, T029–T037, T046–T053 |
| FR-023–FR-026 compatibilidade/testes | T039, T047, T056–T060 |
| FR-027–FR-028 docs/limite Etapa 4 | T043, T054, T062 |

## Implementation Strategy

1. Tornar as regressões vermelhas antes das mudanças correspondentes.
2. Entregar baseline + classificador como fundação pequena e isoladamente testável.
3. Simplificar primeiro o happy path, depois absorver capacidades antigas em ondas.
4. Integrar o perfil aos consumidores sem alterar estado do pipeline.
5. Medir redução e só aceitar remoções com evidência.
6. Rodar security → QA → fix em loop autônomo até PASS.
7. Parar no PR; archive 014 e E2E global ficam para solicitação posterior.

## Notes

- Não usar `git add -A`: o workspace contém alterações locais do archive 013 fora do escopo desta spec.
- Não editar `.claude/` manualmente quando o arquivo correspondente existir em `mosk/.claude/`.
- Não remover a palavra “menu” de contextos visuais legítimos do Hallmark por substituição global.
- Elevação de perfil é permitida; rebaixamento abaixo do piso calculado não é.
- Nenhuma tarefa desta spec autoriza rede, worktrees, deploy ou ação irreversível sem o ponto humano existente.
