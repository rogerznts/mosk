# QA Notes — Spec 014

## US1 — Fluxo documental direto (T015–T024)

Data: 2026-08-15

### Pedidos simulados

- `clear-request`: `clarification_rounds: 0`, sem menu, sem elicitação avançada
  e geração direta do artefato.
- `material-ambiguity`: `clarification_rounds: 1`, com público pagador,
  países/moedas e cancelamento agrupados na mesma mensagem.
- `explicit-advanced-elicitation`: `clarification_rounds: 0`; rota avançada
  disponível somente por ativação explícita e retorno sem seleção obrigatória.
- `irreversible-action`: `clarification_rounds: 0`; a escrita/publicação não é
  executada e `human_pause: true` permanece exigido.

Fonte dos cenários:
`mosk/.claude/mosk/data/direct-flow-fixtures.md`.

### Evidência automatizada

- `bash -n mosk/.claude/mosk/scripts/selftest-toolkit.sh`: exit 0.
- `/bin/zsh -n mosk/.claude/mosk/scripts/selftest-toolkit.sh`: exit 0.
- `bash mosk/.claude/mosk/scripts/selftest-toolkit.sh`: exit 0,
  64 asserções, incluindo 15 verificações do fluxo documental direto.

As verificações cobrem contagem 0/1 de rodadas, ausência de menus obrigatórios,
consumo do contrato adaptativo, ativação avançada explícita, pausa humana e
templates alvo em modo `direct`/`grouped-once`/`opt-in`.

## US3 — Perfil adaptativo compartilhado (T038–T045)

Data: 2026-08-15

### Matriz de concordância

Todos os consumidores apontam para
`mosk/.claude/mosk/data/adaptive-work-contract.md` e para o mesmo
`classify-change.sh`; nenhum mantém score ou pisos próprios.

- `implement`: 16/16 fixtures concordantes em Bash e zsh.
- `security-review`: 16/16 fixtures concordantes em Bash e zsh; chamada
  explícita continua válida e o veredito permanece independente.
- `qa-gate`: 16/16 fixtures concordantes em Bash e zsh; evidência abaixo do
  piso não permite `PASS`.
- `orq-run`: 16/16 fixtures concordantes em Bash e zsh; especialistas são piso
  de agendamento e `human_pause` preserva a parada humana.
- Crescimento simulado de escopo e risco: `compact → elevated → critical`, sem
  rebaixamento entre reclassificações.

### Evidência automatizada

- `bash mosk/.claude/mosk/scripts/selftest-adaptive-work.sh --verbose`: exit 0,
  92 asserções.
- `/bin/zsh mosk/.claude/mosk/scripts/selftest-adaptive-work.sh --verbose`:
  exit 0, 92 asserções.
- `bash mosk/.claude/mosk/scripts/selftest-pipeline-state.sh --verbose`: exit 0,
  201 asserções.
- `/bin/zsh mosk/.claude/mosk/scripts/selftest-pipeline-state.sh --verbose`:
  exit 0, 201 asserções.

As nove novas regressões de estado provam que o perfil não autoriza salto de
fase, não bloqueia uma aresta válida, não trunca histórico, não altera a
evidência adaptativa e não permite archive com gate sem evidência.
