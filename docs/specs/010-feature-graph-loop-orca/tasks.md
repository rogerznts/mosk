# Tasks: Operação em loops e grafos + Orca como atuador único

**Branch**: `010-feature-graph-loop-orca` | **Spec**: [spec.md](./spec.md) | **Plan**: [plan.md](./plan.md)

## Convenções

- **[P]** — pode rodar em paralelo: arquivo distinto, sem dependência com outra
  `[P]` do mesmo marco. Honrado estritamente; em dúvida, sequencial.
- **[USn]** — user story de origem.
- **[dep: …]** — depende da conclusão das tarefas indicadas.

> **Regra que precede todas:** todo produto vai sob `mosk/`. A raiz `.claude/` é
> ambiente local e não faz ship. Editar no lugar errado não chega a nenhum
> consumidor.

---

## M1 — Atuador único e correto (US1 + US5)

*Entregável sozinho. Contém os dois defeitos ativos, por isso vem primeiro.*

- [x] **T001** [P] [US5] `mosk/.claude/mosk/scripts/create-new-feature.sh`: ancorar
  a extração de números de branches locais no **início** do nome (hoje
  `grep -oE '[0-9]{3}-'` casa em qualquer posição e um branch como
  `docs/adr-0012-0014-x` é lido como spec 014).
- [x] **T002** [US5] `mosk/.claude/mosk/scripts/create-new-feature.sh`: forçar
  base-10 no valor de `--number` (`$((10#$n))`), hoje `010` é lido como octal 8.
  *(Sem `[P]`: mesmo arquivo da T001 — `[P]` exige arquivos distintos.)*
- [x] **T003** [P] [US1] Remover `mosk/.claude/mosk/scripts/herdr.sh`. Não tocar
  ADRs nem specs arquivadas — são registro histórico.
- [x] **T004** [US1] `mosk/.claude/mosk/scripts/panes.sh`: remover sondagem de dois
  backends, desempate por variável de sessão dual e o mecanismo
  `unsupported`/exit 3 (com um backend, todo subcomando é suportado). [dep: T003]
- [x] **T005** [US1] `panes.sh`: em `auto`, eleger o Orca só com **sessão dentro da
  IDE `E` `check` passando**; `driver: herdr` falha com mensagem de migração;
  `driver: orca` explícito segue honrado fora da IDE. [dep: T004]
- [x] **T006** [US1] `panes.sh`: subcomando `tier [--json]` devolvendo
  `{tier, reason, actionable}` conforme a tabela do ADR-0013 §3, distinguindo
  binário ausente · fora da IDE · orquestração experimental desligada · desligado
  por config. [dep: T005]
- [x] **T007** [P] [US1] `mosk/.claude/mosk/scripts/common.sh`: remover resíduo de
  Herdr.
- [x] **T008** [P] [US1] `mosk/.claude/mosk/core-config.yaml`: `driver` para
  `auto|orca|none`, remover o bloco `herdr:`, `orca.native_tasks` para `auto`.
- [x] **T009** [US1] `mosk/.claude/mosk/scripts/orca.sh`: **defeito** — reconhecer
  (`ack`) a Delivery processada antes de abrir a próxima janela de espera. Sem
  isso o mesmo lote é reentregue indefinidamente.
- [x] **T010** [US1] `orca.sh`: **defeito** — incluir `question` entre os tipos que
  despertam a espera. Sem isso um worker que faz `ask` fica bloqueado até o
  timeout. [dep: T009]
- [x] **T011** [US1] `orca.sh`: criar ou vincular uma Run antes de `task-create`,
  conforme o contrato do guia.
- [x] **T012** [US1] `orca.sh`: expor `ask` e `reply` no wrapper.
- [x] **T013** [US1] `orca.sh`: usar o caminho supervisionado composto para iniciar
  workers, em vez do par spawn próprio + dispatch low-level.
- [x] **T014** [US1] `orca.sh`: leitura tipada de transcript por dispatch em vez de
  leitura de terminal cru (superfície que quebrou na spec 009).
- [x] **T015** [US1] `mosk/.claude/mosk/agents/orq.md`: backend único; **consultar o
  guia versionado servido pelo binário** em vez de reproduzir a grammar do Orca;
  desambiguar *handoff* (Orca = transferir posse e parar de supervisionar; MOSK =
  transportar contexto sob supervisão — a skill **mantém** o nome).
- [x] **T016** [US1] `mosk/.claude/mosk/scripts/selftest-orca-driver.sh`: cobrir
  `ack` de Delivery, `question` na espera, resolução de `tier`, regex ancorada e
  base-10 em `--number`. [dep: T002, T006, T010]

## M2 — Loop confiável (US2)

*Entregável sozinho. Pré-requisito do fan-out.*

- [ ] **T017** [US2] `mosk/.claude/mosk/tasks/implement.md`: remover o passo 5
  (auto-verificação dos próprios critérios de aceite).
- [ ] **T018** [US2] `mosk/.claude/mosk/tasks/qa-gate.md`: absorver a verificação de
  critérios de aceite, executada em contexto limpo. [dep: T017]
- [ ] **T019** [P] [US2] `mosk/.claude/mosk/pipeline-graph.yaml`: `qa-gate` passa a
  `mode: agent`; rodar `lint-graph.sh` depois.
- [ ] **T020** [P] [US2] `mosk/.claude/mosk/templates/qa-gate-tmpl.yaml`: campo
  `score` (inteiro 0–100) ao lado de `status`.
- [ ] **T021** [P] [US2] `mosk/.claude/mosk/core-config.yaml`: `qa.score_threshold`
  com default 85.
- [ ] **T022** [US2] `qa-gate.md`: emitir o `score`; a apresentação do loop passa a
  mostrar os scores das voltas anteriores junto de `tentativa N/max`. O `status`
  permanece o **único** árbitro de terminação. [dep: T020, T021]

## M3 — Fan-out no `implement` (US3)

*Depende de M1 e M2.*

- [ ] **T023** [US3] Criar `mosk/.claude/mosk/data/fanout-seam.md`: contrato
  `dispatch_wave(plan) → results`, invariantes entre tiers (disco como fronteira,
  status curto, join só fecha com tudo assentado, ponteiro não ramifica).
- [ ] **T024** [US3] `implement.md`: derivar o plano de fan-out dos marcadores `[P]`
  do `tasks.md` — sem inferir paralelismo — e apresentá-lo para **aprovação
  única** (unidades, agrupamento, critério de aceite, teto, equivalente
  sequencial). [dep: T023]
- [ ] **T025** [US3] `implement.md`: join explícito; suspensão **por ramo** em guard
  `judgment`, escalação ou esgotamento de teto; uma entrada por onda no
  `phase-history.log`; nenhuma onda encadeia sozinha. [dep: T024]
- [ ] **T026** [US3] `fanout-seam.md`: mapear o Tier 1 sobre as primitivas do Orca
  (Task DAG com dependências, `ask`/`reply`, decision gates). [dep: T023, T012]
- [ ] **T027** [US3] `fanout-seam.md`: Tiers 2 e 3 + regra de **tier único por
  onda**, com degradação silenciosa e sem erro. [dep: T026]
- [ ] **T028** [US3] Falha de dispatch (circuit breaker do atuador) é reportada como
  unidade falha e **não** consome volta do delivery-loop. [dep: T025]

## M4 — Grafo e vocabulário (US4)

- [ ] **T029** [US4] `pipeline-graph.yaml`: declarar `fan-out` e `join`, dando
  semântica ao `parallel_with` hoje decorativo; `lint-graph.sh` depois.
- [ ] **T030** [US4] `mosk/.claude/mosk/scripts/legal_moves.sh`: apresentar a jogada
  paralela quando legal. [dep: T029]
- [ ] **T031** [P] [US4] `docs/architecture/glossary.md`: verbetes "onda" e
  desambiguação de *handoff*.
- [ ] **T032** [P] [US4] Docs do repo: `README.md`, `TASKS.md`,
  `.claude/rules/scripts.md` — remover Herdr, descrever `tier` e o fan-out.

## Validação e fechamento

- [ ] **T033** Ressincronizar o espelho local e as camadas geradas:
  `sync-agents-skills.sh --clean` e `link-codex-skills.sh` (`AGENTS.md` é gerado,
  nunca editado à mão). [dep: T015]
- [ ] **T034** Matriz de ambiente (SC-005/SC-006): rodar a mesma spec pequena em
  três ambientes — dentro da IDE do Orca · Claude Code sem Orca · runtime sem
  subagente — conferindo mesmo conjunto de artefatos, mesmo veredito e nenhuma
  degradação fatal. [dep: T027, T028]
- [ ] **T035** `audit-docs-paths.sh` e `lint-graph.sh` finais; conferir que
  `docs/index.md` reflete o estado. [dep: T029, T032]

---

## Notas de execução

**Total: 35 tarefas** — acima da faixa usual de 8–25, consequência deliberada de
concentrar quatro frentes numa spec só, como decidido. Os marcos são cortáveis: M1
e M2 entregam valor isoladamente e podem virar incrementos revisáveis dentro do
mesmo branch.

**Trabalho paralelizável hoje:** T001/T002/T003/T007/T008 em M1;
T019/T020/T021 em M2; T031/T032 em M4. As demais têm dependência real de ordem ou
tocam o mesmo arquivo.

**Corte de MVP sugerido:** M1 completo. Ele sozinho corrige os dois defeitos
ativos, remove o Herdr e entrega a detecção de tier — sem depender de nenhuma
decisão das demais frentes.

**Ironia útil:** este `tasks.md` usa `[P]` no formato que a própria US3 vai tornar
executável. Quando M3 estiver pronto, ele serve de caso de teste real.
