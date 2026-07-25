# Tasks — 007-feature-mosk-orca

Legenda: `[x]` feito e verificado · `[~]` feito, verificação pendente de runtime
· `[ ]` pendente.

## Fase 1 — Paridade de atuador

- [x] **T01** `common.sh`: promover `context_token_ceiling` e `extract_tokens`
  (antes duplicados no `herdr.sh`). *Verificado: `800000` e `123000` a partir de
  fixture com linha de dica ignorada.*
- [x] **T02** `herdr.sh`: consumir os helpers; `"driver":"herdr"` no
  `check --json`. *Verificado: `check`, `tokens` (caminho `over=unknown`) e
  `managed` contra o servidor Herdr real.*
- [x] **T03** `orca.sh`: contrato de 8 subcomandos sobre `orca terminal …`.
- [x] **T04** `orca.sh`: `resolve_orca_cmd` com recusa de `/usr/bin/orca`.
  *Verificado: resolve `orca-ide` em todos os cenários; predicado de recusa
  testado; sem candidato seguro → `orca-not-found` com dica.*
- [x] **T05** `orca.sh`: parsing defensivo do envelope JSON.
  *Verificado contra fixtures nos dois caminhos — `python3` (`lines`, `rows`,
  `text`, `output`) e fallback `grep/sed`.*
- [x] **T06** `panes.sh`: fachada + `driver [--json]` + precedência de escolha.
  *Verificado: config explícita, driver inválido com aviso, ausência da chave,
  env de sessão e sondagem.*
- [x] **T07** `core-config.yaml`: `driver`, chaves comuns, bloco `orca:`,
  preservando `herdr:`.
- [x] **T08** `orq.md` + `SKILL.md`: fachada, degradação generalizada, guardrail
  do `orca` cru, gatilhos citando Orca.
- [x] **T09** `create-new-feature.sh`: base branch por commit.
  *Verificado: esta própria spec foi criada de `rogerznts/master`.*

## Fase 2 — Camada nativa (opt-in)

- [x] **T10** `orca.sh`: `native | task-create | task-list | dispatch | await |
  gate-create | gate-resolve`, exigindo `native_tasks: true`.
  *Verificado: off por padrão, mensagem clara, on por env.*
- [x] **T11** `panes.sh`: `unsupported` + exit 3 nos backends sem a camada.
  *Verificado com `driver: herdr`.*
- [x] **T12** `orq.md`: seção da camada nativa com a invariante explícita
  (gate criado pelo orquestrador, resolvido pelo humano; `orchestration run`
  nunca usado).

## Documentação e espelho

- [x] **T13** Espelhar em `.claude/` da raiz. *Verificado: `diff` limpo nos 7
  arquivos.*
- [x] **T14** `.claude/rules/scripts.md`: entradas de `panes.sh` e `orca.sh`,
  nota no `herdr.sh`, guard de base branch, tabela *When to run what*.
- [x] **T15** `README.md` / `TASKS.md`: "Herdr **ou** Orca".
- [x] **T16** `AGENTS.md` regenerado via `link-codex-skills.sh`.

## Pendente de runtime do Orca (qa-gate)

O app Orca está com o runtime inacessível (`orca status` → `stale_bootstrap`),
então estes itens **não puderam ser executados**:

> **Nota de ambiente (2026-07-25).** Não é limitação do AppImage nem do CLI: o
> app está vivo, mas `~/.config/orca/orca-runtime.json` aponta para um PID/socket
> que já morreu. `orca open` **não** corrige com o app já aberto — ele sobe uma
> instância efêmera que se registra, é encerrada pelo single-instance lock, e
> deixa o bootstrap apontando para si mesma (morta). A saída é reiniciar o app
> pela UI. O daemon de terminais é `setsid` e independente, então as sessões
> tendem a sobreviver ao restart.
>
> Efeito colateral útil: este cenário validou a degradação do `orca.sh` em
> condição real — `check` reporta `runtime-unavailable` (distinto de
> `orca-not-found`) e `panes.sh` cai para o backend Herdr sozinho.

- [~] **T17** Paridade contra um pane real: `spawn → send → wait-idle → read →
  tokens → managed → close`, conferindo que o formato de saída bate com o do
  `herdr.sh`.
- [~] **T18** Loop ponta a ponta: `/mosk-orq semi-auto` com um handoff completo,
  confirmando que o Mauro não abre pane para si.
- [~] **T19** Camada nativa: após um `dispatch`, `task-list --json` e
  `dispatch-show --task <id> --json` devem mostrar a task (prova de provenance).
- [~] **T20** Confirmar as chaves reais do envelope de `terminal create` e
  `terminal read` — o parsing é defensivo, mas nunca viu a saída verdadeira.
