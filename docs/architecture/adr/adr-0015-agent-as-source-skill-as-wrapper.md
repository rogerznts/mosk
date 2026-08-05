# ADR-0015 — O agente é a fonte; a skill é o wrapper. E o template ship as duas camadas

- Status: aceito
- Data: 2026-08-05
- Autor: Vinicius (mosk-architect)
- Contexto: definir o que é **agente definitivo** e o que é **skill**, e por que hoje um consumidor do MOSK não consegue invocar agente nenhum programaticamente.
- Depende de: [adr-0006](./adr-0006-consultative-orchestration-graph.md) (o grafo já distingue `mode: skill` de `mode: agent`), [adr-0013](./adr-0013-fanout-seam-three-tiers.md) (o Tier 2 do fan-out precisa de subagente), [adr-0004](./adr-0004-runtime-agnostic-phase-orchestration.md) (isolamento como capacidade de runtime).

## Contexto

O MOSK tem hoje **três** camadas por agente, e a mais importante não ship:

| Camada | Onde | Ship? |
|---|---|---|
| Persona (definição completa) | `mosk/.claude/mosk/agents/<n>.md` | sim |
| Skill (wrapper de slash command) | `mosk/.claude/skills/mosk-<n>/SKILL.md` | sim |
| CC agent (invocável por outro agente) | `mosk/.claude/agents/mosk-<n>.md` | **não existe** |

Um projeto que roda `npx degit rogerznts/mosk/mosk .` recebe 23 skills e **zero**
agents. Os 12 CC agents existem apenas na raiz deste repositório — ambiente de
execução local, que por definição não alcança consumidor nenhum.

Isso tem três consequências que só ficaram visíveis agora:

1. **`mode: agent` do grafo é uma declaração sem lastro.** O ADR-0006 distingue
   `mode: skill` (contexto compartilhado) de `mode: agent` (isolado) desde o
   início, e o `qa-gate` acabou de virar `mode: agent`. Num consumidor não há
   agent para honrar isso.
2. **O Tier 2 do fan-out não funciona fora deste repo.** O ADR-0013 prevê
   despachar unidades como subagentes nativos; sem agents shipados, todo
   consumidor cai direto no Tier 3.
3. **Um agente não pode invocar outro** — nem para executar trabalho já roteado,
   que o ADR-0012 permite explicitamente.

As duas camadas **não são redundantes**, e é isso que torna a escolha real:

| | Skill | CC agent |
|---|---|---|
| Slash command (`/mosk-dev`) | **sim** | não |
| Invocável por outro agente (`subagent_type`) | não | **sim** |
| Contexto | compartilhado | **isolado** |

Elas mapeiam quase exatamente no `mode: skill | agent` que o grafo já declara. A
camada de arquivos é que nunca acompanhou o vocabulário.

## Decisão

**1. O CC agent passa a ser a fonte; a skill vira wrapper fino.** A definição
completa — persona, task mapping, guardrails, escalação — vive em
`.claude/agents/mosk-<n>.md`. A skill guarda apenas front-matter (`name`,
`description`) e um ponteiro para o agente.

Inverte a direção atual (hoje a skill aponta para a persona) e **elimina uma
camada**: `mosk/.claude/mosk/agents/<n>.md` deixa de existir como arquivo
separado — seu conteúdo migra para o CC agent. Passa-se de três camadas para
duas, uma das quais é gerada.

**2. As duas camadas shipam.** `mosk/.claude/agents/` passa a existir e a fazer
parte do pacote. É o que dá lastro ao `mode: agent`, habilita o Tier 2 do fan-out
num consumidor, e torna possível o protocolo do
[adr-0016](./adr-0016-agent-invocation-protocol.md).

**3. Critério para separar agente de skill.**

- **Agente** — tem **persona** e emite **julgamento**: interpreta ambiguidade,
  decide trade-offs, produz artefato opinado. Ganha as duas camadas.
- **Skill pura** — executa uma **ação mecânica ou utilitária**, sem persona e sem
  julgamento próprio. Ganha só a camada de skill.

Aplicando o critério ao roster atual:

| Agentes (12) | Skills puras (11) |
|---|---|
| `analyst` · `pm` · `architect` · `ux-expert` · `ui-expert` · `po` · `sm` · `dev` · `qa` · `security` · `bench` · `orq` | `boot` · `deploy` · `handoff` · `help` · `suggestion` · `update` · `write-skill` · `tea-commit` · `tea-open-pr` · `tea-open-fast-pr` · `tea-prune-branches` |

`deploy` fica como skill apesar de falar na voz do Bento: é uma **ação** sobre o
modo bench (publicar), não uma persona própria — a persona é a do `bench`.

**4. O script deixa de ser conversão e vira materialização.** O
`sync-agents-skills.sh` para de traduzir entre duas fontes concorrentes: lê o CC
agent e **gera** o wrapper de skill. Uma direção só, um arquivo editável por
agente. O contrato de `description` declarada continua valendo — a linha
`skill-description` migra para o CC agent.

**5. Migração é mecânica e verificável.** Cada persona vira um CC agent com
front-matter; cada skill vira ponteiro. O roster de 12 agentes e 11 skills puras
é a asserção a checar depois da migração.

## Alternativas consideradas

1. **Eliminar as skills, ficar só com agents.** Uma camada só, tentador. Rejeitada:
   agents não criam slash command — `/mosk-po`, `/mosk-dev` e os outros
   deixariam de existir, e o acionamento viraria só programático ou por
   linguagem natural. Perde-se a superfície que os usuários de fato usam.
2. **Manter a persona como fonte e gerar as duas camadas a partir dela.**
   Preserva o arranjo atual e resolve o ship. Rejeitada: mantém três camadas
   quando duas bastam, e obriga a inventar um formato de persona que não é nem
   agent nem skill — a fonte deixa de ser um arquivo que o runtime executa
   diretamente.
3. **Shipar agents e deixar as skills como estão (persona como fonte da skill).**
   Rejeitada: cria duas fontes de verdade para o mesmo conteúdo, exatamente o
   drift que o ADR-0006 §1 recusa.
4. **Tratar todo item do roster como agente.** Simples de explicar. Rejeitada:
   `boot`, `handoff`, `update` e as `tea-*` não têm persona nem julgamento; dar a
   elas contexto isolado e invocabilidade custa sem entregar nada.

## Consequências

**Positivas:**

- `mode: agent` do grafo passa a ter lastro em consumidor, não só aqui.
- O Tier 2 do fan-out funciona fora deste repositório.
- Uma camada a menos para manter, e um arquivo editável por agente.
- O que é agente e o que é skill deixa de ser tradição oral e vira critério.

**Negativas / trade-offs:**

- Migração toca os 12 agentes e as 12 skills correspondentes de uma vez; até
  concluída, o roster fica em estado misto.
- O template cresce (uma camada nova de arquivos por agente).
- Instalações existentes precisam de um `sync` após atualizar; sem ele, ficam com
  skills apontando para personas que não existem mais.

**Risco residual:**

- Se a `description` divergir entre agent e skill, o roteamento do host fica
  inconsistente. Mitigação: continua sendo **declarada no agente** e copiada pelo
  script — nunca editada no wrapper.
