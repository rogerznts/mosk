# Tasks: núcleo determinístico do pipeline

**Input**: documentos em `docs/specs/013-feature-deterministic-pipeline-state/`
**Prerequisites**: `spec.md`, `plan.md`, `data-model.md`,
`contracts/pipeline-state.md`, `quickstart.md`

## Phase 1: Contratos e testes de caracterização

**Purpose**: declarar o formato antes de alterar o comportamento existente.

- [x] T001 [P] [US3] Criar o schema versionado de metadata em `mosk/.claude/mosk/schemas/spec-meta.schema.json`, cobrindo identidade, status, fases e timestamps
- [x] T002 [P] [US3] Criar o schema versionado de gate/waiver em `mosk/.claude/mosk/schemas/qa-gate.schema.json`, incluindo evidência obrigatória para novos `PASS` e `WAIVED`
- [x] T003 [US1] Criar o harness `mosk/.claude/mosk/scripts/selftest-pipeline-state.sh` com fixtures inicialmente falhas para matriz, idempotência, atomicidade, lock e histórico
- [x] T004 [US2] Adicionar ao `mosk/.claude/mosk/scripts/selftest-pipeline-state.sh` fixtures de resolução por número, `spec_id` e branch, incluindo ausência, duplicidade, archive e metadata divergente
- [x] T005 [US3] Adicionar ao `mosk/.claude/mosk/scripts/selftest-pipeline-state.sh` fixtures para schema legado, vigente, inválido e futuro, gate sem evidência e waiver incompleto

**Checkpoint**: o contrato desejado está executável e falha contra a implementação atual.

---

## Phase 2: Fonte única de estado

**Purpose**: implementar o núcleo compartilhado que bloqueia todas as adoções.

- [x] T006 [US2] Implementar `resolve_spec_dir` e validação cruzada de identidade em `mosk/.claude/mosk/scripts/common.sh`, com modos `active` e `any`
- [x] T007 [US3] Implementar validadores autocontidos de `spec-meta.yaml`, gate, waiver, evidência e versão de schema em `mosk/.claude/mosk/scripts/common.sh`
- [x] T008 [US1] Implementar matriz, pré/pós-condições e no-op idempotente em `transition_spec_phase` dentro de `mosk/.claude/mosk/scripts/common.sh`
- [x] T009 [US1] Implementar lock, temporários irmãos, rollback e append coerente de `phase-history.yaml` em `mosk/.claude/mosk/scripts/common.sh`
- [x] T010 [US1] Criar a CLI `mosk/.claude/mosk/scripts/transition-spec-phase.sh` com `--spec`, `--to`, `--command`, `--json`, `--help` e exit codes 0/1/2
- [x] T011 [US1] Tornar `update_spec_phase` um adaptador estrito ou erro orientado no `mosk/.claude/mosk/scripts/common.sh`, eliminando a escrita permissiva sem quebrar consumidores identificados

**Checkpoint**: resolver, validar e transicionar funcionam por uma única API e os testes das Phases 1–2 passam.

---

## Phase 3: Adoção pelo pipeline

**Purpose**: remover mutações diretas e fazer cada task declarar sua transição.

- [x] T012 [P] [US3] Atualizar `mosk/.claude/mosk/templates/spec-meta-tmpl.yaml` para o schema vigente e `mosk/.claude/mosk/templates/qa-gate-tmpl.yaml` para evidência verificável
- [x] T013 [US1] Migrar `mosk/.claude/mosk/tasks/plan.md` e `mosk/.claude/mosk/tasks/tasks.md` para a CLI, com pós-condições explícitas
- [x] T014 [US1] Migrar `mosk/.claude/mosk/tasks/implement.md` e `mosk/.claude/mosk/tasks/apply-qa-fixes.md` para a CLI, preservando o retorno `qa-gate -> implement`
- [x] T015 [US1] Migrar `mosk/.claude/mosk/tasks/qa-gate.md` e `mosk/.claude/mosk/tasks/archive.md` para a CLI, fazendo gate/evidência antecederem a confirmação da fase
- [x] T016 [US2] Fazer `mosk/.claude/mosk/scripts/check-prerequisites.sh` resolver e validar a spec pelo contrato canônico
- [x] T017 [US2] Fazer `mosk/.claude/mosk/scripts/check-ship-ready.sh` consumir o resolvedor, o validador de estado e o validador único de gate/evidência/promoções

**Checkpoint**: nenhuma task mantida escreve `current_phase` diretamente e todos os guardrails chegam à mesma decisão.

---

## Phase 4: Diagnóstico, distribuição e documentação

**Purpose**: tornar o contrato distribuível, observável e verificável fora do repositório mestre.

- [x] T018 [US3] Integrar schemas, CLI e `selftest-pipeline-state.sh` ao inventário de `mosk/.claude/mosk/scripts/doctor.sh` e ajustar `mosk/.claude/mosk/scripts/selftest-toolkit.sh` para o gate vigente
- [x] T019 Atualizar `README.md`, `TASKS.md`, `docs/index.md`, `.claude/rules/scripts.md` e `mosk/.claude/mosk/templates/project-rule-tmpl.md` com a máquina de estados, schemas, CLI e limites de autoridade humana
- [x] T020 Espelhar todos os arquivos de produto modificados de `mosk/.claude/` para `.claude/`, reconciliar os arquivos locais ausentes apontados pelo doctor, regenerar integrações apenas quando exigido e provar ausência de drift
- [x] T021 Executar `bash -n`, ShellCheck error, todos os `selftest-*.sh`, `doctor.sh --json`, auditoria documental, sync dry-run e `git diff --check`
- [x] T022 Materializar apenas `mosk/` num diretório temporário e executar `quickstart.md`, incluindo fluxo completo, retorno para correção, concorrência, schema legado e falhas sem mutação

**Checkpoint**: o diagnóstico e o smoke distribuível passam sem dependência externa.

---

## Dependencies & Execution Order

- T001 e T002 podem rodar em paralelo; T003–T005 consolidam o harness compartilhado.
- T006–T011 são sequenciais porque alteram `common.sh` e formam a fundação.
- T012 pode começar após T007; T013–T17 dependem da CLI pronta e devem seguir em ordem para manter o pipeline executável.
- T018–T022 dependem da adoção completa.
- **MVP recomendado**: T001–T017. Entrega a máquina aplicada ao happy path; T018–T022 são obrigatórias antes do gate para provar distribuição e compatibilidade.

## Remediação da revisão de segurança

- [x] T023 [SEC-1] Bloquear raízes e diretórios de spec symlink no resolvedor e revalidar contenção física no sink de transição
- [x] T024 [SEC-2] Restringir gate schema 1 a registros fisicamente arquivados e exigir schema vigente em specs ativas
- [x] T025 [SEC-3] Validar todos os eventos, continuidade, timestamps, arestas e comandos do histórico; exigir histórico no schema 2 após `specify`
- [x] T026 [SEC-4] Rejeitar chaves críticas YAML duplicadas em metadata, gate e histórico
- [x] T027 Adicionar regressões adversariais em Bash e zsh e executar doctor, ShellCheck, auditoria e paridade produto/espelho

## Remediação do quality gate — rodada 1

- [x] T028 [QA-1] Classificar locators por número, `spec_id` ou branch exata e cruzar pasta, número, tipo, slug e metadata em Bash e zsh
- [x] T029 [QA-2] Restaurar metadata e histórico no trap de `HUP`, `INT` e `TERM`, com regressões nos dois shells
- [x] T030 [QA-3] Compartilhar a validação de promoções entre transição para `archived` e `check-ship-ready.sh`
- [x] T031 [QA-4] [QA-5] Cruzar `last_phase_change` com o último evento e bloquear `NEEDS CLARIFICATION` nos artefatos obrigatórios
- [x] T032 [QA-6] Exigir `score_history` não vazio, limitado a 0–100 e terminando no `quality_score`, no schema e no runtime
- [x] T033 [QA-7] Cobrir os 36 pares da matriz, todos os no-ops, preservação em recusas, sinais e promoções no self-test permanente
- [x] T034 [QA-8] Reconciliar produto e espelho local para todas as superfícies modificadas
- [x] T035 Executar sintaxe Bash/zsh, ShellCheck error, 29/29 common, 142/142 pipeline, 39/39 toolkit, doctor 7/7, smoke isolado, auditoria, sync, 20 pares de espelho e diff-check

## Remediação da revisão de segurança — rodada 3

- [x] T036 [SEC-3] Registrar `origin: specify|migration` e rejeitar histórico schema 2 truncado, com regressões Bash/zsh
- [x] T037 [SEC-4] Rejeitar chaves YAML críticas citadas/alternativas ou duplicadas em metadata, gate e front-matter de promoção
- [x] T038 [SEC-5] Exigir alvo regular e equivalência material para promoções `copy`/`append`, bloqueando diretórios e conteúdo divergente
- [x] T039 Sincronizar espelhos e executar a suíte proporcional completa sem alterar `gate.yaml`

## Parallel Opportunities

- T001 e T002 escrevem schemas diferentes e não compartilham estado.
- Fora desse par, o trabalho converge em `common.sh`, no mesmo harness ou em contratos encadeados; execute sequencialmente.

## Implementation Strategy

1. Escrever fixtures e schemas antes do comportamento.
2. Fechar a fonte única em `common.sh` e expor a CLI.
3. Migrar tasks do início ao fim do pipeline, mantendo cada checkpoint rodável.
4. Integrar conclusão e diagnóstico.
5. Só então espelhar, documentar e executar o smoke completo.

## Notes

- `[P]` significa arquivos distintos e ausência real de dependência de escrita.
- Marcar `[x]` somente depois de evidência executada.
- Não iniciar a remoção das 50 tasks legadas nesta spec.
- Qualquer mudança na matriz ou na autoridade sobre fases exige decisão humana,
  não ajuste silencioso durante implementação.
