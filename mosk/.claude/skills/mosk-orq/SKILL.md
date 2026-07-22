---
name: mosk-orq
description: "Orquestrador (Herdr): conduz o pipeline MOSK de UM projeto entre panes do Herdr, fazendo handoff automático quando a fase muda de agente ou quando o contexto do agente atinge o teto de tokens. Deriva as jogadas do pipeline-graph.yaml via legal_moves.sh e transporta contexto via /mosk-handoff. Modo opt-in: full-auto ou semi-auto. Use quando o usuário pedir 'orquestrar no herdr', 'rodar o pipeline em panes', 'conduzir os agentes automaticamente', 'orquestra pra mim', ou quiser um maestro que troca de agente sozinho respeitando os pontos de decisão. Degrada graciosamente quando o herdr não está instalado."
argument-hint: "full-auto | semi-auto  [+ spec/projeto alvo]  (vazio abre o menu)"
---

# Orquestrador MOSK sobre Herdr (`/mosk-orq`)

Conduz o pipeline (`specify → plan → tasks → implement → qa-gate → archive`) de
**um** projeto entre panes do Herdr, usando o Herdr como **atuador** e o grafo do
MOSK (`pipeline-graph.yaml` via `legal_moves.sh`) como **cérebro**. Passa o
bastão entre agentes sozinho, mas **nunca cruza uma decisão humana**.

> **IMPORTANT — exceção opt-in à Escalation Policy (ADR-0006/0009).**
> O MOSK proíbe que um agente invoque outro automaticamente. Esta skill é a
> única exceção, e só age quando o usuário a chama de propósito. Ela automatiza
> apenas o **transporte** (spawn / handoff / close) e o **caminho feliz**
> (`default` do grafo). Toda **bifurcação de julgamento** — `judgment` guards,
> veredito de `qa-gate`, e (em `semi-auto`) qualquer troca de fase/agente —
> **pausa e volta pro humano**. Nunca decide um guard de julgamento sozinha.

> **Idioma:** responda no idioma de comunicação do projeto (campo *Idioma de
> comunicação* em `.claude/rules/project.md`); padrão **pt-BR**. Mantenha
> literais apenas nomes de skill, comandos, caminhos e ids de spec.

---

## Ativação

1. **Pré-requisito (sempre primeiro):** rode
   `bash .claude/mosk/scripts/herdr.sh check`.
   - Falhou (herdr ausente ou server parado) → vá para **Degradação**. Não atue.
2. **Com comando direto** no argumento (ex.: `full-auto`, `semi-auto 006`,
   `semi-auto docs/specs/006-feature-x`): registre o modo e o alvo e siga direto
   para o **Workflow**.
3. **Sem comando direto** (ativação vazia): **NÃO atue**. Exiba um menu básico e
   aguarde a escolha. Monte o menu a partir do grafo, não de tabela fixa:
   - Rode `bash .claude/mosk/scripts/legal_moves.sh __start__` e leia os nós de
     preâmbulo/entrada em `.claude/mosk/pipeline-graph.yaml` (`nodes:` →
     `agent`).
   - Apresente algo como:

     ```
     > **Orquestrador MOSK (Herdr) — o que vamos conduzir?**
     > Agentes iniciais disponíveis:
     >   • /mosk-analyst  — discovery/brief
     >   • /mosk-pm       — PRD
     >   • /mosk-architect / /mosk-ux-expert / /mosk-ui-expert — preâmbulo
     >   • /mosk-po       — specify (entrada do pipeline)
     > Modos: `full-auto` (segue o default sozinho) | `semi-auto` (pede ok nas trocas)
     > Diga: o que orquestrar (spec/projeto) e em qual modo.
     ```
   - Só avance quando o usuário escolher alvo + modo.

---

## Workflow (loop de um projeto)

Todas as chamadas mecânicas passam por `herdr.sh`; a decisão vem do grafo.

### Step 1 — Resolver o alvo
- `bash .claude/mosk/scripts/check-prerequisites.sh --json --paths-only`
  → `REPO_ROOT`, `BRANCH`, `FEATURE_DIR`.
- Leia a fase: `current_phase` de `FEATURE_DIR/spec-meta.yaml` (helper
  `read_spec_meta` em `common.sh`). Sem spec ativa → fase `__start__`.
- **Só leia** `current_phase`. Quem escreve são as tasks de fase — não duplique.

### Step 2 — Achar/abrir o pane worker do projeto
- `bash .claude/mosk/scripts/herdr.sh managed --cwd "<REPO_ROOT>"` para ver se já
  há um pane worker do projeto (registro vivo do `agent list`: cwd, título,
  status).
- Se não houver, spawne um no **space atual do orquestrador**, com **bypass de
  permissões** (senão o worker trava esperando aprovação de cada tool):
  `bash .claude/mosk/scripts/herdr.sh spawn --cwd "<REPO_ROOT>" --label claude -- claude --dangerously-skip-permissions`
  (por padrão fixa em `HERDR_TAB_ID`; use `--workspace`/`--tab` para um space
  dedicado).
- **Prompts iniciais:** com `--dangerously-skip-permissions` o worker não pede
  trust nem aprovação de tools. Ainda assim, se aparecer um prompt de MCP/trust,
  navegue com `herdr pane send-keys <pane> <keys>` (ex.: `Down Down Enter` para
  "Continue without").

### Step 3 — Laço (enquanto `current_phase` != `archived` e o humano não parar)
1. **Jogada legal:** `bash .claude/mosk/scripts/legal_moves.sh <phase> --json`.
   - Pegue o move `default` e mapeie o nó destino → agente dono em
     `pipeline-graph.yaml` (`nodes:` → `agent`).
   - Qualquer `judgment` guard, `gate` FAIL/CONCERNS, ou menu de esgotamento →
     **pause e devolva ao humano** (nos dois modos).
2. **Monitorar o worker:**
   - `herdr.sh wait-idle <pane>` — espere terminar a rodada.
   - `herdr.sh tokens <pane> --json` — leia `used/ceiling/over`.
3. **Definir o gatilho de handoff:**
   - **troca-de-agente:** agente do próximo nó ≠ agente do pane atual.
   - **teto-de-contexto:** `over == true`.
   - Nenhum dos dois → deixe o worker seguir; volte ao passo 1 quando ele agir.
4. **Executar o handoff (após idle):**
   - **semi-auto** + troca-de-agente → peça **ok** ao humano antes.
     **full-auto** → siga. Refresh por teto (mesma fase) é automático nos dois.
   - No pane que sai: `herdr.sh send <pane> "/mosk-handoff <foco da próxima fase>"`
     → `herdr.sh wait-idle <pane>` → leia o path gerado em `docs/handoff/`.
   - Spawne o próximo pane (`herdr.sh spawn ...`): **troca-de-agente** = próximo
     agente; **teto** = mesmo agente/fase. Injete o prompt apontando para o
     handoff + a ação (`herdr.sh send <novo> "<prompt>"`).
   - `herdr.sh close <pane que saiu>`. Atualize seu registro mental de panes.
5. Repita.

### Step 4 — Encerrar
Ao chegar em `archived`, ou quando o humano pedir parada, relate: fases
percorridas, handoffs feitos, panes abertos/fechados e o estado final da spec.

---

## Autonomia

- **`semi-auto`** — automatiza o mecânico (refresh por teto, spawn/close,
  transporte do handoff), mas **pede ok antes de cada mudança de fase/agente**.
- **`full-auto`** — segue o `default` do grafo sozinho; **só para** em `judgment`
  guard, `gate` FAIL/CONCERNS, esgotamento do delivery-loop, ou erro.
- Default quando o modo não é informado: `orchestration.herdr.autonomy_default`
  em `core-config.yaml` (fallback `semi-auto`).

## Degradação (sem Herdr)

Se `herdr.sh check` falhar: **não** tente orquestrar. Informe que o Herdr
(atuador) não está disponível, mostre a dica de instalação que o `check` emitiu,
e ofereça o fluxo single-pane normal — chame o comportamento do
`/mosk-suggestion` (derive a próxima jogada de `legal_moves.sh` e entregue um
prompt pronto para o humano colar). Nunca falhe de forma fatal.

## Rules

- **Só age quando invocada** e nunca sem escolha na ativação vazia (menu = fallback).
- **Deriva do grafo.** A próxima jogada vem de `legal_moves.sh` /
  `pipeline-graph.yaml` — jamais de uma tabela mantida à mão aqui.
- **Nunca cruza decisão humana:** `judgment` guards, veredito de gate e (em
  semi-auto) trocas de fase/agente sempre pausam e voltam pro humano.
- **Codex é manual-only.** O orquestrador é um processo automatizado e **nunca**
  ativa/registra a integração Codex (`link-codex-skills.sh`, `.codex/`,
  `AGENTS.md`) nem spawna agentes Codex por conta própria. Qualquer ativação
  Codex é invocação **manual** do humano — jamais parte deste fluxo.
- **Espera idle** antes de qualquer handoff — nunca corta um agente no meio.
- **Ignora ghost text.** Texto após `❯` que não foi enviado pode ser sugestão do
  harness do Claude Code, não input real — não o trate como pendente. O
  `herdr.sh send` digita input real por cima de qualquer forma.
- **Workers rodam com bypass** (`claude --dangerously-skip-permissions`) para não
  travar em aprovações; são panes efêmeros que o orquestrador conduz e o humano
  observa.
- **Só lê `current_phase`.** Escrita de fase é das tasks; não duplique estado.
- **Fixa panes no space do orquestrador** por padrão; não sequestra o foco do
  usuário nem cria workspaces à toa.
- **Um projeto por vez** (v1). Multi-projeto é escopo futuro.
- **Saída no idioma de comunicação do projeto** (default pt-BR), exceto nomes de
  skill, comandos, caminhos e ids.

## Notes

- Teto de tokens: `orchestration.herdr.context_token_ceiling` (default `800000`,
  ~80% de 1M). Override por `--ceiling` ou env `MOSK_CONTEXT_TOKEN_CEILING`.
- O `check` valida binário **e** server; ambos precisam estar de pé.
- O sensor de tokens lê o contador nativo do pane; se não parsear, reporta
  `over=unknown` e o gatilho de teto é ignorado (nunca bloqueia) — a
  troca-de-agente continua funcionando normalmente.
