# Tasks: estabilizar contratos do toolkit MOSK

**Input**: [spec.md](./spec.md) e [plan.md](./plan.md)  
**Organization**: tarefas agrupadas por incremento verificável. `[P]` aparece
somente quando os arquivos são distintos e não há dependência de conteúdo.

## Phase 1 — Diagnóstico autocontido

**Goal**: uma instalação limpa consegue verificar a própria integridade sem
PyYAML ou outro pacote não declarado.

- [x] T001 [US1] Substituir o uso de PyYAML por projeção awk das chaves de primeiro e segundo nível em `mosk/.claude/mosk/scripts/audit-docs-paths.sh`
- [x] T002 [US1] Criar fixtures para paths, chaves de config e templates referenciados em `mosk/.claude/mosk/scripts/selftest-toolkit.sh`
- [x] T003 [US1] Implementar o diagnóstico central com saída humana, `--json`, `--help` e exit codes 0/1/2 em `mosk/.claude/mosk/scripts/doctor.sh`
- [x] T004 [US1] Integrar `bash -n`, self-tests, auditoria documental, referências internas e sync dry-run no `mosk/.claude/mosk/scripts/doctor.sh`
- [x] T005 [US1] Validar o diagnóstico numa cópia temporária contendo somente o conteúdo distribuível de `mosk/`

**Checkpoint**: `doctor.sh` passa numa instalação limpa e falha de forma acionável nas fixtures negativas.

## Phase 2 — Gate obrigatório para conclusão

**Goal**: nenhuma spec pode ser arquivada ou considerada ship-ready sem decisão válida de QA.

- [x] T006 [US2] Adicionar resolução controlada de spec ativa/arquivada e validação de gate ao `mosk/.claude/mosk/scripts/common.sh`
- [x] T007 [P] [US2] Definir os campos shell-legíveis de waiver e exemplos válidos em `mosk/.claude/mosk/templates/qa-gate-tmpl.yaml`
- [x] T008 [US2] Fazer `mosk/.claude/mosk/tasks/archive.md` validar `PASS` ou `WAIVED` completo antes de promoção ou movimento
- [x] T009 [US2] Fazer `mosk/.claude/mosk/scripts/check-ship-ready.sh` localizar a spec arquivada e validar gate, waiver, promoções e working tree
- [x] T010 [US2] Cobrir gate ausente, desconhecido, `FAIL`, `CONCERNS`, `WAIVED` incompleto/completo e `PASS` em `mosk/.claude/mosk/scripts/selftest-toolkit.sh`

**Checkpoint**: somente `PASS` e `WAIVED` completo atravessam archive e ship-ready nas fixtures.

## Phase 3 — Limpeza conhecida e inventário do legado

**Goal**: remover defeitos confirmados e preparar a reescrita sistemática das tasks antigas.

- [x] T011 [P] [US3] Corrigir referências obsoletas ou sem extensão em `mosk/.claude/mosk/tasks/artefact.md` e `mosk/.claude/mosk/tasks/enrich-story.md`
- [x] T012 [P] [US3] Corrigir o timestamp inválido em `mosk/.claude/mosk/templates/run-log-tmpl.md`
- [x] T013 [US3] Reconciliar o roster real de 12 agentes em `README.md`, `CLAUDE.md`, `docs/agents.md`, `.claude/rules/project.md` e fontes correspondentes sob `mosk/`
- [x] T014 [US3] Classificar todas as 50 tasks e registrar sinais de menus, elicitação obrigatória, duplicação, conteúdo BMAD e ausência de rota em `docs/specs/012-feature-stabilize-toolkit-contracts/legacy-task-inventory.md`
- [x] T015 [US3] Atualizar o espelho local `.claude/` para cada arquivo de produto modificado sob `mosk/.claude/` e verificar ausência de drift não justificado

**Checkpoint**: referências e roster passam no doctor; cada task aparece exatamente uma vez no inventário.

## Phase 4 — Validação e documentação

- [x] T016 Executar `bash -n` em todos os scripts de `mosk/.claude/mosk/scripts/`
- [x] T017 Executar `selftest-common.sh`, `selftest-toolkit.sh`, `doctor.sh`, `audit-docs-paths.sh` e sync agente → skill em dry-run
- [x] T018 Materializar `mosk/` num diretório temporário e repetir o diagnóstico fora da árvore mestre
- [x] T019 Atualizar `README.md`, `TASKS.md`, `docs/index.md` e `.claude/rules/scripts.md` com o novo diagnóstico e o contrato de gate, espelhando no template quando aplicável
- [x] T020 Revisar os critérios SC-001–SC-010 contra as evidências e registrar os comandos executados nesta spec

## Dependencies & Execution Order

- T001 bloqueia T003 e T005.
- T002 começa as fixtures e recebe os casos adicionais de T010.
- T003 bloqueia T004; T004 bloqueia T005.
- T006 e T007 bloqueiam T008–T010.
- T011 e T012 podem ocorrer em paralelo.
- T013 deve usar o roster do disco como fonte, não contagens copiadas.
- T014 é a entrada obrigatória da futura spec `remove-legacy-bmad-workflows`.
- T015 acontece depois de cada grupo de mudanças no template.
- T016–T020 são o gate final desta spec.

## MVP Cut

T001–T010 formam o corte mínimo: diagnóstico autocontido e conclusão protegida
por gate. T011–T020 completam a estabilização e preparam a remoção ampla do
legado.

## Evidências de implementação

Executado em 2026-08-15:

```bash
for f in mosk/.claude/mosk/scripts/*.sh; do bash -n "$f"; done
bash mosk/.claude/mosk/scripts/selftest-common.sh --verbose
bash mosk/.claude/mosk/scripts/selftest-toolkit.sh --verbose
bash mosk/.claude/mosk/scripts/audit-docs-paths.sh --quiet
bash mosk/.claude/mosk/scripts/sync-agents-skills.sh agents-to-skills --dry-run
bash mosk/.claude/mosk/scripts/doctor.sh
bash mosk/.claude/mosk/scripts/doctor.sh --json
```

- `selftest-common.sh`: 29 asserções.
- `selftest-toolkit.sh`: 21 asserções, incluindo gate e ship-ready arquivado.
- `doctor.sh`: 7 verificações, saída humana e JSON íntegras.
- Smoke de `mosk/` materializado em diretório temporário: exit 0 íntegro; após
  remover um template obrigatório da cópia, exit 1 com causa acionável.
- `doctor.sh --invalid`: exit 2.
- Inventário: 50 arquivos no diretório, 50 linhas únicas, sem diferença de nomes;
  29 `manter`, 18 `reescrever`, 3 `fundir`, 0 `remover` imediato.
- SC-001–SC-009 possuem evidência mecânica acima. SC-010 está satisfeito: não há
  marcador de clarificação aberto; a única ocorrência literal é o próprio texto
  do critério em `spec.md`.
