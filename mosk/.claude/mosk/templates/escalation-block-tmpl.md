# Escalation / side-trip block — formato único (ADR-0006)

Fonte única do **formato** dos blocos de sugestão de side-trip do MOSK. As
tasks (`implement`, `qa-gate`, …) **não** repetem esse texto: elas consultam
o grafo e montam o bloco a partir daqui. Assim o formato vive em um só lugar
e os sinais vêm de `pipeline-graph.yaml` (nunca de prosa duplicada).

## Como derivar do grafo

Rode as jogadas legais da fase atual:

```bash
bash .claude/mosk/scripts/legal_moves.sh <current_phase>
```

O retorno traz, para a fase corrente:

- **moves** com guard `judgment` (ex.: `security-review` sob
  `diff_security_sensitive`) → side-trip opt-in que avança para um nó.
- **escalations** (ex.: `missing_adr → architecture`,
  `prd_conflict → prd`, `unspecified_flow → ux`, `design_gap → ui`) →
  side-trip de preâmbulo que **volta** para a fase de origem
  (`return_to: origin`).

Avalie o guard/sinal contra o diff e a conversa. Se valer, emita **um** bloco
no formato abaixo, preenchido com os dados do grafo (nó de destino → `agent`
em `nodes:`). **Nunca** invoque outro agente automaticamente — sugira e
aguarde `go`/`skip`/`escalate`/alternativa.

## Formato do bloco

> **Escalation suggested**
> - Signal: <sinal do grafo ou o que foi detectado no diff/conversa>
> - Recommended agent: `/mosk-<agent do nó de destino>`
> - Suggested prompt: `/mosk-<agent> <ação de uma linha com o spec-id real>`
> - Scope: `feature {spec-id}` (saída em `specs/{id}/<domain>/`)
> - On return: retomar `<task atual>` de onde pausou.

Para o caso específico de segurança (side-trip `security-review`), o mesmo
formato vale com o título **Security review suggested** e a nota "o verdicto
`SECURITY:` alimenta o `qa-gate`".
