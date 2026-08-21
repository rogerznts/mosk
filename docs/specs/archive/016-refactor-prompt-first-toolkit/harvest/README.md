# Colheita da spec 015

Material transportado da branch `feature/015-structured-autonomous-runner` (`7b050e0`) para que ele sobreviva independentemente daquela branch. Executa o que a [T029](../tasks.md) exige; a promoção para `mosk/.claude/mosk/` acontece na fase de implementação da US4.

A branch 015 **não é apagada** por esta spec. Esta pasta existe para que apagá-la depois deixe de ser uma decisão custosa.

## O que veio

| arquivo | origem na 015 | estado |
|---|---|---|
| `execution-plan-tmpl.yaml` | `mosk/.claude/mosk/templates/execution-plan-tmpl.yaml` | **íntegro**, 99 linhas — vai para o template sem alteração |
| `runner-contract-plan-schema.md` | recorte de `mosk/.claude/mosk/data/runner-contract.md` (518 linhas) | seções "Objetivo", "Artefatos", "Plano de execução — schema: 1" e "Isolamento e contenção de caminho" |

## O que ficou para trás, e por quê

Nenhum destes é perda: cada um descreve um mecanismo que o [ADR-0021](../architecture/adr-0021-declarative-rule-minimal-shell.md) elimina.

| descartado | linhas | razão |
|---|---:|---|
| `## Domínio declarado das chaves lidas por shell` | 294–404 | a decisão 3 do ADR-0021 tira o shell da posição de leitor; sem leitor não há domínio a declarar |
| `## Emissão: uma forma por tipo` | 405–467 | mesma razão — a gramática restrita existia para caber no leitor |
| `## Estado da corrida — schema: 1` | 95–128 | o estado da corrida passa a viver em `run-log.md` + frontmatter (FR-012) |
| `## Estados da unidade` | 129–183 | máquina de estados em shell; o runtime já a oferece |
| `## Trailers de commit` | 184–208 | acoplado ao `run-state.yaml` |
| `## Digest e detecção de plano vencido` | 209–221 | digest portátil em shell; sem gerador de plano em script, não se aplica |
| `## Portabilidade` | 240–293 | matriz bash × zsh × macOS × Linux dos leitores removidos |
| `contracts/runner-cli.md` | — | CLI de `build-execution-plan.sh`, `run-state.sh` e `run-worktree.sh`, os três removidos |
| `run-state-tmpl.yaml` | 70 | idem |
| `build-execution-plan.sh`, `run-state.sh`, `run-worktree.sh`, `selftest-runner.sh` | 4.093 | os scripts em si |
| `adr-0020-canonical-yaml-grammar.md` | — | permanece na 015 sem promoção; já citado como superseded pelo ADR-0021 |

## Os requisitos da 015 não foram descartados

As cinco user stories daquela spec continuam sendo exigência — plano legível, corrida retomável, ciclo de vida do worktree, paralelismo declarado, alvo explícito. Elas migraram para a **US4** desta spec, e a T033 verifica item a item que o mecanismo novo as atende. O que foi substituído é como, não o quê.
