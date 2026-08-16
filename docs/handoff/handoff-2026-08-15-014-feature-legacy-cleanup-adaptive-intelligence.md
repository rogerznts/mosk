# Handoff — 2026-08-15

> Próxima sessão: retomar a corrida autônoma da spec 014 na US4 e seguir até abrir o PR, sem archive, merge ou E2E final do programa.

## Active documentation

- Spec / domain: `014-feature-legacy-cleanup-adaptive-intelligence` (`feature`)
- Branch: `feature/014-legacy-cleanup-adaptive-intelligence`
- Phase: `implement`
- Remote state: branch local 7 commits à frente de `origin/feature/014-legacy-cleanup-adaptive-intelligence`; nenhum push desta corrida foi feito.
- Linked artifacts:
  - `docs/specs/014-feature-legacy-cleanup-adaptive-intelligence/spec.md`
  - `docs/specs/014-feature-legacy-cleanup-adaptive-intelligence/plan.md`
  - `docs/specs/014-feature-legacy-cleanup-adaptive-intelligence/tasks.md`
  - `docs/specs/014-feature-legacy-cleanup-adaptive-intelligence/contracts/adaptive-work-contract.md`
  - `docs/specs/014-feature-legacy-cleanup-adaptive-intelligence/data-model.md`
  - `docs/specs/014-feature-legacy-cleanup-adaptive-intelligence/legacy-baseline.md`
  - `docs/specs/014-feature-legacy-cleanup-adaptive-intelligence/qa-notes.md`
  - `docs/specs/014-feature-legacy-cleanup-adaptive-intelligence/run-log.md`

## Session context

- Goal: executar autonomamente `implement → security → qa → fix`, abrir o PR da Etapa 3 e parar nele.
- What changed:
  - `b693b91` arquivou a spec 013 nesta branch, conforme autorizado pelo usuário.
  - `f38ea4a` consolidou spec, plano, contrato, modelo e 62 tarefas da spec 014.
  - `cbac96f` entregou T001–T014: inventário 50/50, allowlist, contrato/schema/classificador adaptativo, auditor e selftests.
  - `69fe23a` corrigiu a variável especial `status` para o selftest rodar em zsh.
  - `b3c5e2f` entregou US1/T015–T024: criação documental direta, uma rodada agrupada e elicitação avançada opt-in.
  - `6b9df02` entregou US2/T025–T036: contratos comuns e absorção coberta de `map-project`, `review-story` e `webdesign-output`; T037 ficou para a limpeza global.
  - `bdb4ff1` entregou US3/T038–T045: perfis adaptativos integrados em dev, security, QA e orq sem alterar a máquina de estados.
  - A US4 foi interrompida a pedido do usuário. Há trabalho parcial, não commitado e não validado, somente em:
    - `mosk/.claude/mosk/tasks/bench-mode.md`
    - `mosk/.claude/mosk/tasks/planner.md`
    - `mosk/.claude/mosk/data/bench-runtime-reference.md` (novo)
    - `mosk/.claude/mosk/data/planner-reference.md` (novo)
  - `docs/specs/014-feature-legacy-cleanup-adaptive-intelligence/run-log.md` possui uma linha ainda não commitada registrando esta parada.
- Decisions made:
  - As histórias foram executadas em série porque `tasks.md` não autoriza paralelismo entre stories; `[P]` aparece apenas em tarefas internas.
  - T037 depende do fechamento da US4: catálogo, rotas e fusões estão íntegros, mas a auditoria global ainda falha pelas ocorrências operacionais restantes.
  - O usuário definiu que o E2E global será executado somente no final do programa; nesta etapa, validar o quickstart e os gates, abrir o PR e parar.
  - O terminal autorizado é PR aberto. Não executar archive, merge, deploy ou release.
- Open threads:
  - Revisar o diff parcial da US4 antes de continuar; não descartar nem assumir que está correto.
  - T037 e T046–T053 continuam desmarcadas.
  - A auditoria atual retorna `catalog=50`, `tasks_on_disk=47`, `legacy_violations=23`, `failures=23`. As 23 ocorrências estão nos headers de tasks/checklists/templates/data listados por `audit-legacy-surface.sh`; devem ser removidas ou cobertas por allowlist estrita apenas quando forem atribuição/licença legítima.
  - A métrica atual das 18 tasks `rewrite` é 662 linhas contra baseline 2641 e alvo máximo 1848; a redução já supera 30%, mas T046 ainda precisa tornar a medição reproduzível no auditor e T055 registrar a evidência final.
  - Antes da pausa: adaptive 92/92 em Bash e zsh; pipeline-state 201/201 em Bash e zsh. `selftest-toolkit.sh` falhava somente porque a auditoria global ainda encontra as 23 ocorrências. `doctor.sh` consequentemente não está verde.
  - Execução direta de `selftest-toolkit.sh` sob zsh já apresentou problema de auto-localização via `BASH_SOURCE`; validar se é requisito real do harness ou apenas invocação não suportada antes de alterar.

## Next steps

1. Ler este handoff e os artefatos da spec; confirmar `git status` e revisar os quatro arquivos parciais da US4 com `git diff --check`.
2. Retomar `/mosk-orq 014` na US4. Concluir T046–T053 e T037: auditoria de redução/fontes únicas, referências autocontidas, compactação restante, limpeza das 23 referências operacionais, geração oficial de wrappers e contrato de saída único.
3. Não editar root `.claude/` como fonte e não rodar `link-codex-skills.sh`; toda mudança nasce em `mosk/.claude/`. Sincronizar produto → espelho apenas em T056.
4. Validar a US4 com auditoria verde, toolkit/adaptive/pipeline e instalação isolada; atualizar `legacy-baseline.md`, `qa-notes.md`, `tasks.md` e `run-log.md`; criar commit local da unidade.
5. Executar T054–T058: documentação pública, evidência final, sync de agentes/skills e espelhos, syntax Bash/zsh, ShellCheck, schemas, common/pipeline/toolkit/adaptive, doctor, docs audit, mirrors, diff-check e quickstart.
6. Rodar `/mosk-security` diff-aware com foco em parsing, command injection, paths, manipulação de perfil e bypass de pisos. Aplicar correções e revalidar até `SECURITY: PASS`.
7. Rodar `/mosk-qa qa-gate 014` em contexto independente. Repetir `apply-qa-fixes → security → QA` até `Gate PASS`, respeitando teto de 3 voltas e parada por score estagnado/dúvida real.
8. Transicionar canonicamente para `qa-gate`, atualizar `docs/index.md`, conferir staging seletivo e commits.
9. Fazer push da branch e abrir o PR da Etapa 3. Parar no PR; não arquivar nem fazer merge.

## Suggested skills

- `/mosk-orq 014` — retomar a corrida autônoma exatamente na US4 e conduzir os loops até o PR.
- `/mosk-dev apply-qa-fixes 014` — aplicar somente findings emitidos por security/QA durante as voltas.
- `/mosk-security review 014` — revisão independente obrigatória da nova superfície de scripts, paths e classificação.
- `/mosk-qa qa-gate 014` — veredito independente e escrita exclusiva de `gate.yaml`.

## References

- `docs/discovery/toolkit-autonomy-assessment-roadmap.md`
- `docs/specs/archive/012-feature-stabilize-toolkit-contracts/legacy-task-inventory.md`
- `docs/specs/archive/013-feature-deterministic-pipeline-state/`
- `mosk/.claude/mosk/data/adaptive-work-contract.md`
- `mosk/.claude/mosk/data/task-dispositions.tsv`
- `mosk/.claude/mosk/scripts/audit-legacy-surface.sh`
- `mosk/.claude/mosk/scripts/classify-change.sh`
