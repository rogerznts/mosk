# Plano — 007-feature-mosk-orca

**Spec**: [spec.md](./spec.md) · **ADR**: [adr-0010](./architecture/adr-0010-orca-backend.md)

## Abordagem

Tornar o atuador do `/mosk-orq` plugável atrás de uma fachada, em vez de
duplicar o orquestrador por backend. Três camadas:

```
orq.md  ──fala só com──>  panes.sh  ──delega──>  herdr.sh  (backend Herdr)
                             │                   orca.sh   (backend Orca)
                             └── resolve o driver e o motivo
```

O contrato é o que já existia no `herdr.sh` — 8 subcomandos
(`check | tokens | spawn | send | wait-idle | read | close | managed`). O
`orca.sh` implementa **o mesmo contrato**, não o CLI do Orca: as divergências
(seletor de worktree, `--enter` atômico, ausência de contador de tokens,
inexistência de split/tab) são absorvidas dentro do wrapper.

## Decisões de implementação

| Ponto | Decisão | Por quê |
|---|---|---|
| Duplicação de código | `context_token_ceiling` e `extract_tokens` promovidos a `common.sh` | eram idênticos nos dois drivers; uma cópia só impede divergência silenciosa |
| Resolução do executável | `$ORCA_CLI_COMMAND` → `orca-dev` → `orca-ide` → `orca`, recusando `/usr/bin/orca` e `/bin/orca` | `orca` cru no Linux é o leitor de tela do GNOME; executá-lo fala na máquina do usuário |
| Parsing de JSON | busca por chave (recursiva com `python3`, `grep/sed` sem ele) em vez de caminhos fixos | os nomes internos do envelope podem mudar entre versões do Orca |
| Detecção do backend | config → ambiente da sessão (`ORCA_*`/`HERDR_*`) → primeiro `check` que passar → `none` | quem executa está dentro de um dos dois; esse é o sinal mais confiável de desempate |
| Camada nativa | subcomandos separados, exigindo `native_tasks: true` | mantém o padrão idêntico ao de hoje e torna o opt-in verificável |
| `unsupported` | exit **3**, próprio | distingue "este backend não faz isso" de "isto falhou" |
| Guard de base branch | aceitar branch no **mesmo commit** de uma base | todo worktree do Orca tem branch próprio; sem isso não se cria spec de dentro dele |

## Invariante preservada (ADR-0006)

A camada nativa do Orca traz um coordinator loop autônomo (`orchestration run`)
que decidiria sozinho. Ele **não é usado**. Decision gates são **criados** pelo
orquestrador e **resolvidos** com a resposta do humano.

## Arquivos

| Arquivo | Mudança |
|---|---|
| `mosk/.claude/mosk/scripts/orca.sh` | novo — backend Orca (contrato + camada nativa) |
| `mosk/.claude/mosk/scripts/panes.sh` | novo — fachada/dispatcher |
| `mosk/.claude/mosk/scripts/common.sh` | + `context_token_ceiling`, `extract_tokens` |
| `mosk/.claude/mosk/scripts/herdr.sh` | passa a consumir os helpers; `driver` no `check --json` |
| `mosk/.claude/mosk/scripts/create-new-feature.sh` | guard de base branch por commit |
| `mosk/.claude/mosk/core-config.yaml` | `driver`, chaves comuns, bloco `orca:` |
| `mosk/.claude/mosk/agents/orq.md` | fala com `panes.sh`; seção da camada nativa; guardrail do `orca` cru |
| `mosk/.claude/skills/mosk-orq/SKILL.md` | gatilhos citando Orca |
| raiz: `.claude/` (mirror), `README.md`, `TASKS.md`, `.claude/rules/scripts.md`, `AGENTS.md` | espelho e docs |

## Riscos

- **Formato de saída do Orca não verificado contra o runtime.** O parsing foi
  validado contra fixtures (com e sem `python3`), não contra o app rodando. É o
  primeiro item do qa-gate.
- **Divergência silenciosa entre drivers.** Mitigada pelo contrato fechado, pelos
  helpers compartilhados e pela checagem de paridade de subcomandos.
