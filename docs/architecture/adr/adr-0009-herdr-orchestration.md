---
promote: docs/architecture/adr/adr-0009-herdr-orchestration.md
promote_mode: copy
---

# ADR-0009 — Orquestração multi-pane sobre Herdr (`/mosk-orq`)

- Status: **superseded** por [adr-0018](./adr-0018-remove-orchestration-layer.md) (2026-08-14) — o subagente nativo dos runtimes tornou a camada de orquestração redundante. Preservado como registro.
- Data: 2026-07-22
- Autor: spec `006-feature-mosk-orq`
- Contexto: dar um **executor** ao `mode: skill|agent` que o grafo já declara, usando o Herdr (multiplexer de agentes) como atuador.
- Depende de: [adr-0006](../../../architecture/adr/adr-0006-consultative-orchestration-graph.md) (grafo consultivo — a invariante "nada auto-executa" é herdada e só relaxada de forma opt-in), [adr-0007](../architecture/adr-0007-graph-schema-shell-legible.md) (schema shell-legível do grafo, ainda na spec 004), [adr-0008](../../../architecture/adr/adr-0008-consultative-delivery-loop.md) (delivery-loop e `max_retries`).

## Contexto

Hoje o pipeline MOSK roda numa **única sessão**: o humano troca de agente na mão
e, por invariante (ADR-0006), nenhum agente invoca outro — o grafo apenas
apresenta jogadas legais.

O `pipeline-graph.yaml` já distingue nos nós `mode: skill` (contexto
compartilhado, interativo) de `mode: agent` (isolado, paralelo). Esse `mode`
nunca teve executor: não havia como, na prática, rodar um nó num processo/pane
próprio e passar o bastão.

O ambiente-alvo roda sobre o **Herdr** (herdr.dev), um multiplexer de agentes
com control API (CLI + socket): spawnar panes, injetar input, esperar o agente
ficar `idle`, ler a saída e fechar panes. Isso é exatamente o atuador que faltava
— e abre a possibilidade de **handoff automático** entre agentes/panes, incluindo
quando o contexto de um agente se esgota.

Dois fatos moldam a decisão e são difíceis de reverter:

1. **Dependência externa.** O Herdr não é parte do MOSK; consumidores do template
   podem não tê-lo. A feature precisa degradar sem ele.
2. **Tensão com o ADR-0006.** Qualquer coisa que "passe o bastão sozinha" colide
   com "nenhum agente invoca outro". Precisa ser uma exceção **explícita,
   opt-in e limitada** — não uma mudança do default do framework.

## Decisão

**1. `/mosk-orq` é o executor opt-in do grafo sobre o Herdr.** Encarnado na
persona **Mauro** (o maestro): prompt em `mosk/agents/orq.md` + wrapper fino em
`skills/mosk-orq/`, para o usuário tratar diretamente com o coordenador. É um
papel meta (rege os outros agentes), fora do pipeline — como Bento (`bench`) e
Heitor (`security`) já são personas não-pipeline. O **cérebro** continua sendo o
grafo (`legal_moves.sh` / `pipeline-graph.yaml`); o **atuador** é o Herdr,
encapsulado em `scripts/herdr.sh`. O orquestrador nunca inventa jogadas — só as
executa.

**2. Automatiza transporte e caminho feliz; nunca cruza decisão humana.** Ele
automatiza spawn/handoff/close e o move `default` do grafo. Mas **pausa e devolve
ao humano** em toda bifurcação de julgamento: `judgment` guards, veredito de
`qa-gate` (FAIL/CONCERNS), esgotamento do delivery-loop (ADR-0008) e — em
`semi-auto` — qualquer troca de fase/agente. Assim a invariante do ADR-0006 é
preservada no que importa (o julgamento é humano); só o mecânico é delegado.

**3. Dois modos de autonomia, escolhidos em tempo de uso.** `semi-auto` (pede ok
nas trocas de fase/agente) e `full-auto` (segue o default sozinho, parando só nos
pontos de decisão acima). Default configurável em
`orchestration.herdr.autonomy_default`.

**4. Dois gatilhos de handoff.** (a) **troca-de-agente**: o próximo nó pertence a
outro agente → novo pane com o próximo agente; (b) **teto-de-contexto**: os
tokens do agente atingem `context_token_ceiling` → novo pane com o **mesmo**
agente/fase (refresh). Em ambos, sempre após `wait-idle` — nunca cortando o
agente no meio — e com transporte de contexto via `/mosk-handoff`.

**5. Sensor por contagem de tokens, não por statusline.** O teto se mede pelo
contador **nativo** de tokens do pane (lido via `herdr.sh tokens`), não pelo
"ctx left" (statusline custom, não universal). Default `800000` (~80% de 1M),
configurável. Se o contador não parsear, o gatilho de teto é ignorado
(`over=unknown`) — nunca bloqueia; a troca-de-agente segue funcionando.

**6. Degradação graciosa.** Sem o binário `herdr` no PATH, `herdr.sh check` falha
com mensagem + dica de instalação, e a skill cai no fluxo single-pane estilo
`/mosk-suggestion`. Nunca hard-fail.

**7. Escopo v1 = um projeto.** O loop conduz um único workspace/projeto ponta a
ponta. Panes nascem fixados no space/tab do próprio orquestrador (env `HERDR_*`),
para não sequestrar o foco do usuário nem criar workspaces à toa.

## Consequências

- **Positivas:** o `mode: skill|agent` do grafo ganha semântica executável;
  handoffs (inclusive por esgotamento de contexto) deixam de ser manuais; o
  humano segue no controle de todo julgamento; consumidores sem Herdr não são
  afetados.
- **Custos/limites:** dependência externa opcional a manter; parsing do contador
  de tokens depende do layout da TUI (mitigado por `over=unknown`); v1 não trata
  multi-projeto nem concorrência de panes.
- **Fora de escopo (v2):** multi-projeto (N workspaces em paralelo, prioridade,
  concorrência); sensor de tokens via hook/statusline gravando em arquivo
  (fonte mais robusta que o parse da TUI).
