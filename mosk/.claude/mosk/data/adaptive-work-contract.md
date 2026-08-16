# Contrato de perfil adaptativo de trabalho

<!-- contract-normative:start -->

## Objetivo

Um único contrato decide quanta investigação, contexto e validação uma mudança
exige. O agente declara sinais enumerados com evidência observável; o
classificador aplica regras determinísticas. O perfil estabelece um piso de
rigor, não autoriza ampliar escopo nem executar ações irreversíveis.

## Entrada

| Sinal | Valores aceitos |
|---|---|
| `scope` | `localized`, `multi_file`, `cross_domain`, `public_contract` |
| `reversibility` | `easy`, `coordinated`, `irreversible` |
| `sensitive_surface` | `none`, `paths_state`, `data_security`, `production_critical` |
| `evidence` | `strong`, `partial`, `absent` |
| `ambiguity` | `clear`, `bounded`, `material` |
| `requested_floor` | vazio, `standard`, `elevated`, `critical` |

Use `public_contract` para interfaces, schemas, comandos ou comportamento
externo. Use `cross_domain` quando houver ownership de dois ou mais domínios.
`irreversible` significa que rollback não restaura o efeito sem intervenção
externa. O sinal de superfície é sempre o mais severo presente. Evidência
`strong` exige contexto confirmado e teste reproduzível. Ambiguidade `material`
é aquela cuja resposta muda arquitetura, escopo, dados ou efeito externo.

## Pontuação

| Dimensão | 0 | 1 | 2 | 3 | 5 |
|---|---|---|---|---|---|
| Escopo | localized | multi_file | cross_domain | public_contract | — |
| Reversibilidade | easy | coordinated | — | irreversible | — |
| Superfície sensível | none | — | paths_state | data_security | production_critical |
| Evidência | strong | partial | absent | — | — |
| Ambiguidade | clear | bounded | material | — | — |

- `0–2`: `compact`
- `3–5`: `standard`
- `6–9`: `elevated`
- `10+`: `critical`

Depois do score, aplica-se o piso mais severo:

1. `data_security` exige no mínimo `elevated`.
2. `production_critical` ou `irreversible` exige `critical`.
3. `cross_domain` com evidência `absent` exige no mínimo `elevated`.
4. `requested_floor` apenas eleva o resultado.

Opções ausentes, desconhecidas ou repetidas com valores contraditórios falham
sem emitir perfil.

## Saída

O script emite um objeto JSON com chaves e arrays em ordem estável:

```json
{"schema":1,"profile":"elevated","score":7,"floor":"elevated","reasons":["score:6-9","floor:data_security"],"context_budget":"elevated","validation_floor":"independent","specialists":["security","qa"],"human_pause":false}
```

`reasons` contém somente valores controlados. Evidência em texto livre permanece
no artefato consumidor e nunca vira argumento do classificador.

## Budgets e validação

| Perfil | Contexto inicial | Validação mínima | Especialistas mínimos |
|---|---|---|---|
| `compact` | regras, alvo, referências e teste diretos | `focused` | nenhum |
| `standard` | compact + interfaces, chamadores e docs do domínio | `domain` | conforme o domínio |
| `elevated` | standard + contratos cruzados e histórico relevante | `independent` | QA; security quando houver dados/segurança |
| `critical` | elevated + operação, recovery, ownership e evidência independente | `release` | security e QA |

Comece no conjunto inicial e expanda apenas por referência direta, falha de
teste, mudança de escopo ou descoberta de superfície mais sensível. Reclassifique
ao descobrir sinal mais severo. Budget limita irrelevância; nunca impede carregar
evidência necessária.

## Integração e limites

- `implement` usa o perfil como inspeção e validação mínimas.
- `security-review` é obrigatório por superfície/piso ou chamada explícita.
- `qa-gate` pode ampliar cobertura e nunca transforma ausência de evidência em PASS.
- `orq-run` agenda especialistas preservando limites humanos.
- Tasks documentais usam `ambiguity` para decidir se há uma única rodada
  agrupada de perguntas.

O contrato não cria fase ou estado novo e não implementa worktrees, checkpoints
ou execução paralela; essas capacidades pertencem à Etapa 4.

## Segurança e portabilidade

- Argumentos são enums allowlisted; nenhum valor é avaliado como shell, path ou comando.
- JSON é formado somente por constantes internas.
- Elevação manual nunca rebaixa o piso calculado.
- Não há rede, segredos, YAML arbitrário ou dependência obrigatória de `jq`.
- Compatibilidade: Bash 3.2+ e zsh executando o script diretamente.

<!-- contract-normative:end -->

## Fonte única

Tudo acima, entre os comentários `contract-normative:start` e
`contract-normative:end`, é a redação normativa deste contrato. Task, agente ou
skill que precise dela **referencia este arquivo pelo caminho**; copiar o texto
cria uma segunda fonte que passa a divergir em silêncio.

`audit-legacy-surface.sh` falha quando três ou mais linhas normativas — as de 30
caracteres ou mais, comparadas com espaçamento normalizado — reaparecem
literalmente em outro arquivo do produto. Mencionar, linkar ou citar uma linha
isolada continua correto e não dispara nada.
