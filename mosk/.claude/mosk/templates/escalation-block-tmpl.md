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
a resposta: `pode ir` / `pula` / outra direção (ADR-0016 §2).

## Formato do bloco

> **Preciso de outro agente antes de seguir**
> - O que apareceu: <o que foi detectado no diff/conversa>
> - Quem resolve: `/mosk-<agente>`
> - Prompt pronto: `/mosk-<agente> <ação de uma linha, com o spec-id real>`
> - Onde o resultado fica: `docs/specs/{spec-id}/<domínio>/`
> - Quando voltar: retomo `<task atual>` de onde parei.

Para segurança, o mesmo formato com o título **"Vale uma revisão de segurança
antes do gate"** e a nota de que o verdicto `SECURITY:` alimenta o `qa-gate`.

## O cabeçalho é escrito para quem lê, não para nós

"Escalation", "side-trip", "guard", "preamble", "loopback", "fan-out" são
vocabulário **interno**. Servem para nós conversarmos sobre o toolkit; não
significam nada para quem só quer saber o que fazer agora. O bloco emitido usa
palavras comuns, no idioma de comunicação do projeto (default pt-BR).

O mesmo vale para as respostas que você oferece: `pode ir` / `pula` / outra
direção — não `go`/`skip`/`escalate`.
