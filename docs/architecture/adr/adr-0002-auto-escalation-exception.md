# ADR-0002 — Escalonamento automático escopado ao Workflow da Fase B

- Status: aceito
- Data: 2026-07-19
- Autor: Vinicius (mosk-architect)
- Contexto: modo `/mosk-payload` — ver `../mosk-payload-mode.md` §5.4.
- Origem: decisão 2 do brief de discovery.

## Contexto

A **Escalation Policy** do MOSK é uma invariante do framework: agentes de
pipeline (`po`, `sm`, `dev`, `qa`) **nunca** invocam outro agente
autonomamente — eles **sugerem** o handoff e **esperam** a decisão do
usuário. Isso protege o usuário técnico de perder o controle do fluxo.

O modo `/mosk-payload` atende um **leigo**. Sua regra de ouro é: *nunca
faça um leigo tomar uma decisão técnica.* A Fase B é um build **headless**
que precisa correr de ponta a ponta sem pausas. Se, no meio do build,
`dev` esbarrar numa ambiguidade de arquitetura e **sugerir** um handoff
para o usuário decidir, colocaríamos exatamente a decisão técnica que
prometemos evitar na frente do leigo — quebrando o produto.

## Decisão

Criar uma **exceção escopada** à Escalation Policy, válida **apenas dentro
do `Workflow` da Fase B** do modo `/mosk-payload`:

- Dentro desse Workflow, o escalonamento entre subagentes
  (`po → dev → qa`, e destes para `architect`/`pm`) é **automático**: o
  Workflow invoca o subagente necessário, resolve por **default seguro** e
  **registra** a decisão no log da spec — sem pausar para o leigo.
- O **contrato global do MOSK permanece intocado.** Nenhum agente shipa
  com auto-escalação fora daqui. A exceção vive inteiramente no runtime da
  Fase B; agentes chamados fora do Workflow continuam apenas sugerindo.
- **Limite duro:** a auto-escalação resolve apenas questões **técnicas**.
  Lacuna de **regra de negócio** ausente no briefing **não** é inventada —
  o Workflow para, registra a lacuna, e devolve ao grill (Fase A) ou
  entrega com gate `CONCERNS` explicando em pt-BR o que faltou.

## Alternativas consideradas

1. **Manter a política global (sugerir e esperar) também na Fase B.**
   Quebraria a regra de ouro (leigo decidindo técnica) e travaria o build
   headless. Rejeitada.
2. **Tornar a auto-escalação global do MOSK.** Violaria a invariante que
   protege o usuário técnico em todos os outros fluxos. Rejeitada —
   o escopo tem que ser estreito.

## Consequências

**Positivas:** Fase B corre sem intervenção; o leigo nunca vê decisão
técnica; o framework global segue íntegro para os demais modos.

**Negativas:** existe agora **um** ponto no MOSK onde agentes se invocam
sozinhos — precisa estar claramente documentado e confinado ao Workflow,
sob risco de virar precedente. O log da spec registra toda decisão
automática para auditoria posterior. A fronteira técnico-vs-negócio
precisa ser respeitada com rigor pelo prompt do Workflow.
