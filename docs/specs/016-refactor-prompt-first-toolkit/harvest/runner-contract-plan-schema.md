> **Recorte colhido da spec 015** (`7b050e0`), não o contrato original.
> Seções preservadas: Objetivo, Artefatos, Plano de execução, Isolamento e
> contenção. O que ficou de fora e por quê está em [README.md](./README.md).
> O schema do `run-state`, os trailers, a máquina de estados da unidade e a
> gramática de leitura por shell foram descartados pelo
> [ADR-0021](../architecture/adr-0021-declarative-rule-minimal-shell.md).

# Contrato do runner autônomo — plano, estado e trailers

<!-- contract-normative:start -->

## Objetivo

Uma corrida autônoma grava no disco aquilo a que se propôs e aquilo que já fez.
Dois arquivos sustentam isso, com papéis deliberadamente separados: o **plano**,
que não muda enquanto a corrida roda, e o **estado**, que muda a cada checkpoint.
A autoridade final não é nenhum dos dois — é o histórico do git da branch da
spec, lido pelos trailers de commit. Estado é cache; commit é fato.

Nada declarado aqui liga o modo autônomo, cria fase de pipeline nem transfere ao
runner qualquer decisão que permaneça humana.

## Artefatos

| Arquivo | Local | Versionado | Papel |
|---|---|---|---|
| `execution-plan.yaml` | pasta da spec | sim | contrato da corrida; imutável enquanto ela roda |
| `run-state.yaml` | pasta da spec | não | progresso local; cache reconstruível pelo git |
| `.run-lock/` | pasta da spec | não | exclusão mútua entre invocações concorrentes |

Ponto de partida de cada um: `.claude/mosk/templates/execution-plan-tmpl.yaml` e
`.claude/mosk/templates/run-state-tmpl.yaml`.

## Plano de execução — `schema: 1`

| Chave | Tipo | Conteúdo |
|---|---|---|
| `schema` | inteiro | versão deste contrato; hoje `1` |
| `spec_id` | string | nome da pasta da spec |
| `spec_number` | string | três dígitos com zero à esquerda |
| `branch` | string | branch da spec, lida do `spec-meta.yaml` |
| `generated_at` | timestamp | ISO 8601 UTC; campo volátil |
| `generated_by` | string | nome do gerador |
| `sources` | mapa | arquivos de origem e seus digests |
| `execution` | mapa | modo pedido e tetos da corrida |
| `units` | lista | unidades de trabalho, na ordem de leitura |
| `waves` | lista | agrupamento das unidades por onda |

Campos de `sources`: `tasks_file`, `tasks_digest`, `spec_file`, `spec_digest` e
`digest_algorithm`. Campos de `execution`: `mode_requested` (`auto`, `isolated`,
`shared` ou `sequential`), `max_parallel`, `max_attempts` e `test_command`.

`max_attempts` é inteiro não negativo. `0` é valor legítimo e significa uma
coisa só: nenhuma unidade executa. É a forma declarada de ensaiar uma corrida
sem produzir efeito, e por ser indistinguível de um engano de digitação ela é
sempre anunciada ao ser lida. Valor não numérico ou negativo não é aceito: cai
no padrão, também com aviso.

Cada item de `units` declara: `id`, `kind` (`foundational` ou `story`), `title`,
`source`, `wave`, `parallel`, `depends_on`, `tasks`, `files`, `acceptance`,
`validation` e `profile`. Cada item de `waves` declara `index`, `units` e `mode`.

`acceptance` é lista de mapas, cada item com `id` e `text`; `depends_on`,
`tasks`, `files` e `validation` são listas de escalares.

`profile` carrega a saída de `classify-change.sh` para aquela unidade, com um
mapeamento de nomes que é declarado aqui e não deduzido:

| Chave em `units[].profile` | Origem no classificador |
|---|---|
| `name` | `profile` — renomeada, porque `profile.profile` seria ilegível |
| `score` | `score` |
| `floor` | `floor` |
| `context_budget` | `context_budget` |
| `validation_floor` | `validation_floor` |
| `specialists` | `specialists`, lista, mesma ordem |
| `human_pause` | `human_pause` |
| `reason` | `reasons`, unidos por `, ` na ordem emitida |

Nada da saída é descartado. `reasons` vira escalar porque o plano é lido linha a
linha e uma lista de razões controladas não ganha nada em ser lista; a ordem é
preservada e os valores continuam sendo os do classificador, nunca texto livre.

**Invariantes do plano:**

- `units` declara pelo menos uma unidade. Plano sem o bloco, com a lista vazia
  ou com o arquivo vazio é recusado na leitura, e não lido como "nada a fazer":
  o consumidor que recebe uma lista vazia com sucesso conclui a corrida sem ter
  executado nada, e relata isso como conclusão.
- `units[].id` é único, estável e casa com `^[A-Za-z][A-Za-z0-9_-]{0,31}$`. É a
  mesma string que aparece no trailer do commit, no estado e no run-log.
- A onda `0` pertence exclusivamente à unidade fundacional, quando ela existir;
  toda outra unidade depende dela.
- `parallel: true` só é emitido quando a origem marcou paralelismo de forma
  explícita. Ausência do marcador produz `false` — paralelismo nunca é inferido.
- `files` vazio é valor legítimo e informativo: significa que a origem não
  declarou caminho. Em modo compartilhado força série; na atribuição de falha
  produz item sem dono.
- `generated_at` é o único campo ignorado ao comparar duas gerações do mesmo
  plano. Qualquer outra divergência entre elas é defeito de determinismo.


## Isolamento e contenção de caminho

A raiz dos worktrees é relativa à raiz do repositório, com o valor padrão
declarado em `core-config.yaml`. O layout é `<raiz>/<spec_number>/<unit_id>` e a
branch de trabalho é `run/<spec_number>/<unit_id>`.

Um candidato a raiz é recusado quando for absoluto, contiver segmento vazio,
`.` ou `..`, terminar em barra, coincidir com a raiz do repositório, invadir a
área interna do git, ou escapar fisicamente do repositório por symlink. A
verificação é lexical primeiro e física depois, na mesma ordem já usada para
destinos de promoção.

A raiz é um caminho **literal**: metacaractere de glob nela é recusado. O motivo
não é o caminho, é o segundo uso do mesmo valor — ele também é escrito como
regra de ignore, e ali o glob deixa de ser literal e passa a casar. Uma raiz
grafada como padrão amplo retira do versionamento justamente a trilha que torna
a corrida auditável.

