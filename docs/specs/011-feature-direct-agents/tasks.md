# Tasks: Agentes diretos — o template ship a camada de agentes

**Branch**: `011-feature-direct-agents` | **Spec**: [spec.md](./spec.md) | **Plan**: [plan.md](./plan.md)

## Convenções

- **[P]** — arquivo distinto, sem dependência com outra `[P]` do mesmo marco.
  Honrado estritamente; em dúvida, sequencial.
- **[USn]** — user story de origem. **[dep: …]** — depende das indicadas.

> **Regra que precede todas:** todo produto vai sob `mosk/`. A raiz `.claude/` é
> ambiente local e não faz ship.

> **Nota:** o M1 é o primeiro caso real do fan-out da spec 010 — 12 agentes em
> arquivos distintos, sem dependência entre si. As T004–T007 formam uma onda.

---

## M1 — Camada de agentes (US1 + US2)

*Desbloqueia o resto. A matriz de invocação (US2) entra na mesma passada dos
arquivos — abrir os 12 agentes duas vezes seria desperdício.*

- [x] **T001** [US1] Criar `mosk/.claude/agents/` e fixar o contrato do arquivo
  migrado: front-matter (`name`, `description` vinda da `skill-description`) +
  corpo preservado + caminhos relativos à raiz do install
  (`.claude/mosk/tasks/x.md`, nunca `../tasks/x.md`).
- [x] **T002** [US1] Migrar um agente-piloto (`dev`) ponta a ponta e validar o
  contrato: front-matter correto, zero `../tasks/`, skill regenerada apontando
  para o novo local. **Só depois de passar, seguir para a onda.** [dep: T001]
- [x] **T003** [US2] Redigir a matriz de invocação do ADR-0016 §2 em formato
  reutilizável, para entrar em cada agente que pode invocar. [dep: T001]

### Onda de migração — 4 unidades independentes

- [x] **T004** [P] [US1+US2] Pipeline: `po`, `sm`, `dev` (dev já feito na T002 —
  revisar). Migrar + matriz de invocação. [dep: T002, T003]
- [x] **T005** [P] [US1+US2] Qualidade: `qa`, `security`. Migrar + matriz.
  [dep: T002, T003]
- [x] **T006** [P] [US1] Preâmbulo: `analyst`, `pm`, `architect`. Migrar. **Não
  recebem matriz de invocação** — são os que ninguém pode invocar
  automaticamente; recebem a nota inversa. [dep: T002, T003]
- [x] **T007** [P] [US1] Design e meta: `ux-expert`, `ui-expert`, `bench`, `orq`.
  Migrar. `bench` mantém a exceção do ADR-0002 intacta. [dep: T002, T003]

### Fechamento do M1

- [x] **T008** [US1] Remover `mosk/.claude/mosk/agents/` como fonte, após
  confirmar que os 12 migraram. [dep: T004, T005, T006, T007]
- [x] **T009** [US1] `sync-agents-skills.sh`: inverter a direção (agente → skill),
  remover o modo `skills-to-agents`, ajustar o `--clean` para a nova fonte, e
  garantir que instalação antiga reaponte sem falhar em silêncio. [dep: T008]
- [x] **T010** [US1] Validar o roster: 12 agentes, 11 skills puras, toda skill
  apontando para agente existente, zero `../tasks/` nos agentes. [dep: T009]

## M2 — Nome de branch (US3)

*Independente de M1. Pode entregar a qualquer momento.*

- [x] **T011** [US3] `create-new-feature.sh`: separar `BRANCH_NAME`
  (`{tipo}/{NNN}-{nome}`) de `SPEC_DIR_NAME` (`{NNN}-{tipo}-{nome}`) — hoje são a
  mesma string, e é essa fusão que precisa acabar.
- [x] **T012** [US3] Detecção de número aceita `^([a-z]+/)?([0-9]{3})-`,
  **mantendo a âncora** da spec 010. Sem a âncora, `docs/adr-0012-0014-x` volta a
  contar como spec 014. [dep: T011]
- [x] **T013** [US3] Resolução branch → spec por número (não por igualdade de
  nome), aceitando legado e novo. Toca `common.sh` e `check-prerequisites.sh`.
  [dep: T012]
- [x] **T014** [US3] Validar tipo na criação: por extenso; `feat`/`bug`/`hf` e
  nome não-kebab falham com mensagem clara. [dep: T011]
- [x] **T015** [US3] `selftest-orca-driver.sh`: cobrir numeração nos dois
  formatos, sem regredir as 48 asserções. [dep: T012]

## M3 — Docs

- [x] **T016** [P] `.claude/rules/scripts.md`: sync invertido, formato de branch,
  detecção dos dois formatos.
- [x] **T017** [P] `README.md` e `TASKS.md`: a camada de agentes passa a shipar;
  o que é agente e o que é skill.
- [x] **T018** [P] `CLAUDE.md` e `project-rule-tmpl.md`: a estrutura do template
  ganhou `agents/` — o mapa do repo precisa refletir.

## M4 — Validação e fechamento

- [x] **T019** **Smoke de instalação:** `npx degit` num diretório limpo e
  verificar `.claude/agents/` populado. É a **única** prova do SC-001 — o único
  teste que enxerga o que o consumidor recebe. [dep: T010]
- [ ] **T020** Invocar um agente migrado por `subagent_type` e confirmar retorno
  em contexto isolado. Fecha o SC-003. [dep: T019]
  **NÃO EXECUTADA.** O runtime carrega a lista de agentes no início da sessão, e
  a migração aconteceu durante ela — invocar agora exercitaria a versão em
  memória, não a do disco. Os 12 arquivos estão no lugar, com front-matter
  válido e caminhos que resolvem (T019). Fica para a primeira sessão nova:
  invocar qualquer `mosk-<n>` por `subagent_type` e confirmar retorno isolado.
- [x] **T021** Ressincronizar espelho local e camadas geradas
  (`sync-agents-skills.sh`, `link-codex-skills.sh`). [dep: T010]
- [x] **T022** `audit-docs-paths.sh`, `lint-graph.sh` e selftest finais; conferir
  `docs/index.md`. [dep: T015, T018]

---

## Notas de execução

**Total: 22 tarefas.** Dentro da faixa usual, diferente da 010.

**Piloto antes da onda (T002).** Migrar um agente e validar o contrato antes de
disparar os outros onze é o que evita repetir um erro doze vezes. É também o que
torna a onda segura: quando ela dispara, o contrato já está provado.

**Trabalho paralelizável:** T004–T007 (a onda) e T016–T018. As demais têm
dependência real de ordem ou tocam o mesmo arquivo.

**Corte de MVP:** M1 completo. Sozinho fecha o gap que motivou a spec — o
consumidor passa a receber agentes invocáveis.

**A US3 não bloqueia nada** e pode ser entregue em qualquer ponto, inclusive
primeiro, se você preferir ver o formato novo em uso antes.
