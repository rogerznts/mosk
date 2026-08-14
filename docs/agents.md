# MOSK — Guia dos agentes

Roster completo, o que cada um faz de particular, e como eles se relacionam.
O [README](../README.md) traz a tabela resumida; as **tasks** que cada um executa
estão catalogadas em [TASKS.md](../TASKS.md).

## Roster

| Skill | Persona | Responsabilidade |
|---|---|---|
| `/mosk-analyst` | Maria | discovery, pesquisa, brainstorming |
| `/mosk-pm` | João | PRD, escopo de produto, PRD delta |
| `/mosk-architect` | Vinicius | arquitetura, APIs, integrações, ADRs |
| `/mosk-ux-expert` | Salete | user flows, wireframes, front-end specs |
| `/mosk-ui-expert` | Tiago | UI premium, design system, acabamento visual + Hallmark |
| `/mosk-po` | Sara | specs, planejamento, geração de tasks |
| `/mosk-sm` | Roberto | prontidão de story, sequenciamento |
| `/mosk-dev` | Jaime | implementação, QA fixes, archive |
| `/mosk-qa` | Joaquim | quality gates, estratégia de testes, revisões |
| `/mosk-security` | Heitor | revisão de vulnerabilidade diff-aware, triagem |
| `/mosk-bench` | Bento | modo workbench para não-técnicos (stack Payload) |

`/mosk-deploy` fala na voz do Bento mas **não é agente**: é uma ação sobre o modo
bench (publicar), não uma persona própria — ver "Agente ou skill?" abaixo.

## As duas camadas

Cada agente existe em dois arquivos, e eles **não são redundantes**:

| | `.claude/agents/mosk-<n>.md` | `.claude/skills/mosk-<n>/SKILL.md` |
|---|---|---|
| O que é | a **definição** — persona, task mapping, guardrails | wrapper fino, **gerado** |
| Dá | invocabilidade por `subagent_type`, em contexto isolado | o slash command `/mosk-<n>` |

Só skills criam slash command; só agents são invocáveis. **Edite o agente** — o
wrapper é regenerado por `sync-agents-skills.sh`, numa direção só
([ADR-0015](./architecture/adr/adr-0015-agent-as-source-skill-as-wrapper.md)).

### Quando cada camada é usada

| | Skill (slash command) | Agent (subagente) |
|---|---|---|
| Compartilha o contexto da conversa | sim | não |
| Execução em paralelo | não | sim |
| Interativo com o usuário | sim | não |
| Isola saída volumosa | não | sim |

**No uso diário, prefira a skill**: `/mosk-dev implement a spec 012`. O agente
entra quando o trabalho precisa de isolamento — unidades `[P]` rodando em
paralelo, ou uma verificação que não deve herdar o histórico de quem
implementou. Desde a spec 011 isso é explícito: um agente invoca outro pelo
protocolo acima, não por mágica do runtime.

### Agente ou skill?

- **Agente** — tem persona e emite **julgamento**: interpreta ambiguidade, decide
  trade-offs, produz artefato opinado. Ganha as duas camadas.
- **Skill pura** — executa ação **mecânica**, sem persona nem julgamento próprio.
  Ganha só a camada de skill: `boot`, `deploy`, `handoff`, `help`, `suggestion`,
  `update`, `write-skill` e as `tea-*`.

## Invocação entre agentes

Um agente pode invocar outro **para executar** trabalho cuja rota um humano já
aprovou — nunca para decidir por onde o pipeline vai. O teste: *se a resposta
muda por onde o pipeline vai, é rota*, e rota é do humano.

Os agentes de preâmbulo — `analyst`, `pm`, `architect`, `ux-expert`, `ui-expert` —
são deliberadamente **não invocáveis** automaticamente: lacuna de ADR, fluxo ou
PRD é sinal de rota, e o agente **suspende e apresenta uma escalação**. Chamar o
architect sozinho não economiza um passo — decide que a arquitetura muda, que é
a decisão mais cara do pipeline.

Profundidade máxima 1: quem foi invocado não invoca; reporta a necessidade a quem
o chamou. Toda invocação é declarada antes e reportada depois
([ADR-0016](./architecture/adr/adr-0016-agent-invocation-protocol.md)).

## Particularidades

### `/mosk-bench` (Bento) — modo autocontido

Não é agente de pipeline: entrevista o usuário para extrair um briefing de
negócio e então roda o pipeline SDD sozinho — em Docker, em pt-BR, com zero
decisão técnica exposta. A stack ativa é Payload (adapter plugável).

Para um passo a passo em linguagem simples, ver [BENCH.md](../BENCH.md).

### `/mosk-deploy` — publicação opt-in

Publica uma ferramenta do bench num provedor (Railway hoje) usando a conta do
próprio usuário. O build roda **remotamente**, preservando a invariante local de
"zero build"; Postgres e Redis gerenciados são provisionados, e o usuário recebe
uma URL pública — decidindo apenas conta e token
([ADR-0005](./architecture/adr/adr-0005-deploy-skill-scoped-outside-local-invariants.md)).
O modelo stack × provedor deixa espaço para PHP e outros provedores depois.

### `/mosk-security` (Heitor) — revisor sob demanda

Análise contextual e diff-aware, com limiar de confiança rígido e lista explícita
de exclusão de falso-positivo. **Não é fase do pipeline**: o relatório dele
**alimenta o `qa-gate`** — um verdicto `SECURITY: FAIL`/`CONCERNS` informa a
decisão. Seguindo o contrato de escalação do MOSK, `implement` e `qa-gate` apenas
**sugerem** rodá-lo quando o diff toca superfície sensível, e esperam
confirmação. Nunca auto-invocam.

Inspirado no [`claude-code-security-review`](https://github.com/anthropics/claude-code-security-review) da Anthropic.

### UX Expert × UI Expert

Convivem em `docs/ui/` com focos distintos: **UX** é dono de estrutura e
comportamento (flows, wireframes, front-end specs); **UI** é dono do acabamento
visual (design system, styles, componentes premium).

### Hallmark — o segundo rule-set do `/mosk-ui-expert`

O rule-set embutido governa **acabamento**: tipografia, paleta, estados, os "AI
tells" nomeados. O **Hallmark** governa **estrutura**: escolhe uma de 21
macroestruturas nomeadas e um de 20 temas OKLCH por briefing, e rotaciona
arquétipos de nav e footer entre execuções (memória em `.hallmark/log.json`), de
modo que duas builds nunca compartilhem a mesma impressão digital.

A razão é específica: o sinal mais forte de UI gerada por LLM não é a fonte
errada — é a **forma repetida**.

```
hallmark landing page do produto        # build (fluxo padrão)
hallmark audit src/App.tsx              # punch list ranqueada, zero edições
hallmark redesign src/App.tsx           # mesmo conteúdo, nova impressão digital
hallmark study https://example.com      # extrai o DNA, nunca os pixels
```

Digite direto ou atrás de `/mosk-ui-expert`. Enquanto o Hallmark roda, **as
regras dele prevalecem sobre a baseline embutida** onde houver conflito (serifas
de display e saída em HTML + CSS puro são legais ali).

É um [fork vendorizado](https://github.com/Nutlope/hallmark) (MIT, por Nutlope /
Together AI) em `.claude/mosk/data/hallmark/` — atualize com `sync-hallmark.sh`,
nunca à mão ([ADR-0011](./architecture/adr/adr-0011-vendor-hallmark.md)).
