# Contract: pipeline state

## Transition CLI

```text
transition-spec-phase.sh --spec <locator> --to <phase> --command <task> [--json]
transition-spec-phase.sh --help
```

`<locator>` aceita número, `spec_id` ou branch. Tasks normais resolvem somente
spec ativa; archive e diagnóstico podem solicitar resolução histórica por uma
opção explícita da implementação.

O resultado precisa ser um diretório real e filho físico imediato de
`docs/specs/` ou `docs/specs/archive/`. Symlinks na raiz, no archive ou na spec
são recusados; o sink revalida a contenção antes de criar lock ou temporários.

### Exit codes

- `0`: transição confirmada ou no-op idempotente.
- `1`: contrato recusado — estado, artefato, schema, lock ou transição inválida.
- `2`: uso incorreto da CLI.

### JSON de sucesso

```json
{"ok":true,"spec":"013-feature-deterministic-pipeline-state","from":"plan","to":"tasks","changed":true}
```

No-op usa `"changed":false`. Falhas de contrato retornam `ok:false`, fase
observada quando disponível e uma lista `failures`; erros de uso retornam apenas
mensagem e exit 2.

## Transition matrix

```text
specify -> plan
plan -> tasks
tasks -> implement
implement -> qa-gate
qa-gate -> implement
qa-gate -> archived
```

`X -> X` é no-op. Toda outra combinação falha. `archived` é terminal.

## Atomicity

1. Resolver uma única spec e validar metadata/schema.
2. Adquirir lock exclusivo local à spec.
3. Revalidar o estado depois do lock.
4. Validar aresta, pré-condições e pós-condições já materializadas pela task.
5. Preparar metadata e histórico completos em arquivos temporários irmãos.
6. Promover ambos sem expor um estado intermediário persistente; em falha,
   restaurar a projeção original e retornar exit 1.
7. Liberar lock em sucesso, falha ou sinal.

O histórico existente é validado evento a evento: chaves únicas e obrigatórias,
timestamp UTC, aresta, comando, continuidade, ordem temporal e concordância do
último `to` com `current_phase`. No schema 2, toda fase posterior a `specify`
exige histórico. A origem é explícita: `origin: specify` exige primeiro evento
`specify -> plan`; `origin: migration` autoriza uma primeira aresta posterior
somente quando a metadata contém `history_origin_schema: 1`, persistido pelo
caminho real de upgrade de schema 1. Uma spec criada no schema 2 não pode
autorizar migração apenas alterando o histórico.

## Schema compatibility

- `spec-meta` legado sem `schema` é lido como versão 1.
- Gate com `schema: 1` é aceito somente dentro de uma spec já arquivada em
  `docs/specs/archive/`; decisões de specs ativas exigem schema 2.
- Toda chave top-level em metadata, gate e front-matter precisa usar a gramática
  simples `^[a-z_][a-z0-9_-]*:`. Chaves citadas, escapadas, explícitas, com tag
  ou duplicadas falham antes do consumo shell.
- Templates e decisões novas usam a versão vigente declarada nos schemas.
- Versão desconhecida/futura falha e orienta atualizar o toolkit.
- O runtime valida sem carregar uma biblioteca externa; os arquivos JSON Schema
  são o contrato declarativo para ferramentas e revisão.

## Human authority

A CLI nunca calcula a próxima fase. `--to` e `--command` são obrigatórios e vêm
da task que o usuário escolheu executar. Waiver, retorno para correção e archive
continuam decisões humanas.
