# Escalation / side-trip block — formato único

Fonte única do **formato** dos blocos de sugestão de side-trip do MOSK. As
tasks (`implement`, `qa-gate`, …) **não** repetem esse texto: montam o bloco a
partir daqui, para que o formato viva em um só lugar.

## Quando emitir

Um side-trip é sugerido quando a execução esbarra numa lacuna que a fase atual
não tem autoridade para fechar. Os sinais recorrentes:

| Sinal detectado | Agente recomendado |
|---|---|
| o diff tocou superfície sensível (auth/authz, input, queries, secrets, endpoints, desserialização, cripto, path) | `/mosk-security` |
| falta um ADR para uma decisão que o código está tomando implicitamente | `/mosk-architect` |
| o requisito conflita com o PRD, ou o PRD não cobre o caso | `/mosk-pm` |
| um fluxo de usuário está sem especificação | `/mosk-ux-expert` |
| falta acabamento visual / decisão de design system | `/mosk-ui-expert` |
| a story está ambígua o bastante para travar a implementação | `/mosk-sm` |

Avalie o sinal contra o diff e a conversa. Se valer, emita **um** bloco no
formato abaixo. Se for claramente irrelevante, **pule em silêncio** — um bloco
emitido por precaução a cada fase treina o usuário a ignorá-lo.

**Nunca invoque outro agente automaticamente.** Lacuna de ADR, de PRD ou de
fluxo é sinal de **rota**, e rota é decisão do humano: sugira e aguarde
`go`/`skip`/`escalate`/alternativa (ADR-0016 §2).

## Formato do bloco

> **Escalation suggested**
> - Signal: <o que foi detectado no diff/conversa>
> - Recommended agent: `/mosk-<agent>`
> - Suggested prompt: `/mosk-<agent> <ação de uma linha com o spec-id real>`
> - Scope: `feature {spec-id}` (saída em `specs/{id}/<domain>/`)
> - On return: retomar `<task atual>` de onde pausou.

Para o caso específico de segurança, o mesmo formato vale com o título
**Security review suggested** e a nota "o verdicto `SECURITY:` alimenta o
`qa-gate`".
