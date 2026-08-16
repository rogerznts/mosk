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
