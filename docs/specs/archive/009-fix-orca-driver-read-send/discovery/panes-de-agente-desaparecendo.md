# US3 — Panes de agente que desaparecem: causa provável identificada

- **Data:** 2026-07-29
- **Spec:** `009-fix-orca-driver-read-send`
- **Limite acordado:** uma sessão de orquestração instrumentada
- **Resultado:** não reproduzido o sintoma exato; **mecanismo plausível encontrado**,
  com evidência direta, mais um gap real do driver que o explica.

## O sintoma relatado (campo, projeto `cfo-skills`)

Panes rodando `claude --dangerously-skip-permissions` apresentaram
`terminal_handle_stale` no `wait` e `tab_not_found` no `close`. Três de três panes
de agente, **sempre depois** de o trabalho concluir. Panes `bash` nunca. Nenhuma
entrega afetada. Hipótese de timeout do `wait` corromper o handle já havia sido
testada e descartada em campo.

## O que foi instrumentado aqui

Sessão real: `spawn` de `claude --dangerously-skip-permissions` → `read` durante a
montagem da TUI → `send` de tarefa trivial → `read` confirmando execução →
`tokens` → `wait-idle` → `close` → sondagem do handle depois do `close`.

| Passo, após o worker concluir | Resultado |
|---|---|
| `wait-idle` | rc=0 |
| `read` | rc=0 |
| `managed` (handle listado) | sim |
| `close` | rc=0 |
| `close` de novo | rc=0 |
| `read` **depois** do `close` | **rc=0, conteúdo vazio** |
| `orca terminal list` (handle listado) | **não** |

O sintoma não reproduziu: nenhum `terminal_handle_stale`, nenhum `tab_not_found`.

## O achado que explica o sintoma

**Depois do `close`, o Orca não invalida o handle — ele o mantém legível como
lápide (*tombstone*):**

```json
{ "ok": true,
  "result": { "terminal": {
      "handle": "term_7754af8b…",
      "status": "exited",      ← o único sinal de que o pane morreu
      "tail": [],
      "returnedLineCount": 0 } } }
```

Note o que isso significa para quem orquestra:

- `read` devolve `ok: true`, conteúdo vazio, **exit 0**.
- Um pane **morto** é indistinguível de um pane **vivo e quieto**. Os dois dão
  string vazia e rc 0.
- **O driver ignora `status` por completo** — `cmd_read` extrai só o `tail`.
- Handle genuinamente inexistente **é** reportado: `read` num handle inventado dá
  `terminal_handle_stale` e **rc=1**, verificado.

**Mecanismo provável do sintoma de campo:** o pane não desaparecia durante o
trabalho. Ele terminava, virava lápide, e a lápide era recolhida pelo Orca em algum
momento **entre** duas chamadas do orquestrador. O `wait` seguinte encontrava um
handle já recolhido (`terminal_handle_stale`) e o `close` não achava mais a aba
(`tab_not_found`). Isso casa com os três fatos do relato que qualquer outra
hipótese deixava soltos: acontecia **só depois** de concluir, **só** em panes de
agente (o processo `claude` encerra; um `bash` interativo fica aberto), e **nunca
afetou entrega**.

Não é confirmação — é o mecanismo que explica os três fatos ao mesmo tempo, com
evidência direta do estado de lápide. Confirmar exigiria observar a janela de
recolhimento, que não é controlável pelo cliente.

## Gap real, separado do sintoma

Independente de o sintoma de campo ter essa causa ou não, o driver tem um buraco
verificado: **`status` é ignorado**. Hoje o `/mosk-orq` não tem como distinguir
"worker quieto" de "worker morto" — os dois são `read` vazio com rc 0. Enquanto a
pane responde, `status: "exited"` está ali para ser lido.

**Não foi corrigido aqui, de propósito.** O `FR-011` desta spec proíbe alteração
especulativa no driver a partir da investigação, e surfacear `status` é
comportamento novo, não correção do que foi especificado. Fica registrado como
candidato barato a spec própria:

- `read` (ou um `status` novo) propagar `status: exited` como sinal distinto de
  conteúdo vazio.
- `wait-idle` distinguir "ficou idle" de "morreu" — hoje `wait-idle` sobre um pane
  encerrado devolve rc=0, o que o orquestrador lê como "pronto pra próxima
  instrução".

## Hipóteses testadas e descartadas

| Hipótese | Veredito |
|---|---|
| Timeout do `wait` corrompe o handle | **descartada** em campo (handle sobreviveu a timeout de 5s e a um segundo `wait`) |
| `close` falha e deixa o pane órfão | **descartada**: `close` rc=0, e um segundo `close` também rc=0 |
| Handle inválido não é reportado pelo driver | **descartada**: handle inventado → `terminal_handle_stale` + rc=1 |
| `spawn`/`send`/`read`/`close` instáveis em pane de agente | **descartada**: ciclo completo com worker `claude` real, todos rc=0, worker processou a tarefa |

## Nota lateral: `wait-idle` em pane `bash`

Durante o smoke, `wait-idle` **estourou timeout (rc=1)** numa pane rodando `bash`
puro, que estava perfeitamente pronta para receber comandos (o `send` seguinte
funcionou). Reforça, por outro caminho, a leitura do achado 2:
`orca terminal wait --for tui-idle` avalia estado de **TUI**, e num shell comum ele
não conclui. Não afeta o `/mosk-orq` (que só abre panes de agente), e por isso não
entrou no escopo — mas quem for mexer no `wait` deve saber.
