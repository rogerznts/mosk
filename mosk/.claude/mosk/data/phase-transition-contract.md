# Contrato de transição de fase

<!-- contract-normative:start -->

## Objetivo

Confirmar que uma spec mudou de fase, validando a mudança contra a regra
declarada e registrando-a no disco. Uma task informa o destino; **este contrato
nunca escolhe a próxima fase** — a autoridade sobre para onde o pipeline vai é
humana (ADR-0012).

## Fonte da regra

Toda a regra vive em `.claude/mosk/pipeline.yaml`. Este documento descreve o
**procedimento**; o `pipeline.yaml` descreve o **fato**. Nenhuma task repete
qualquer um dos dois em prosa: ambas referenciam pelo caminho.

Quem lê o `pipeline.yaml` é o agente, que tem um parser de verdade (ADR-0021
§3). Não há script interpretando YAML.

## Procedimento

Cinco passos, na ordem. Qualquer falha interrompe **antes** de escrever: uma
transição parcialmente aplicada é pior que uma recusada.

**1. Resolver a spec.** Por número, `spec_id` ou branch. O diretório resolvido
precisa estar sob `docs/specs/` ou `docs/specs/archive/`, sem escape por
symlink.

**2. Ler o estado atual.** `current_phase` e `status` do `spec-meta.yaml`.
Se `current_phase` já for o destino, a transição é **no-op idempotente**:
não escreva nada, relate e siga.

**3. Validar a aresta.** Contra `phases[<origem>].transitions_to` no
`pipeline.yaml`:

- a aresta origem → destino precisa existir na lista;
- o comando que invoca precisa estar em `phases[<destino>].confirmed_by`, ou
  ser um `wildcard_commands`;
- se houver `restricted_edges` para o par origem → destino, o comando precisa
  estar em `allowed_commands`;
- se `phases[<destino>].when_from[<origem>]` existir, a condição declarada ali
  precisa ser satisfeita.

`archived` é terminal: `transitions_to` vazio significa que nada sai de lá.

**4. Validar os artefatos.** Cada entrada de `phases[<destino>].requires`:

- `non_empty` — o arquivo existe e não está vazio;
- `no_blocking_marker` — não contém o token de `blocking_marker`;
- `no_open_tasks` — nenhuma linha casa `open_task_pattern`;
- `satisfies: gate.contract` / `gate.allows_completion` — o `gate.yaml` cumpre
  a seção correspondente do `pipeline.yaml`;
- `check: promotions.satisfied` — cada arquivo com `promote:` cumpre
  `promotions.satisfied` para o seu modo. A contenção do destino é verificada
  por `validate_promotion_target` em `common.sh`, que resolve symlink contra o
  disco — é a única parte deste passo que não é leitura de dado.

**5. Escrever.** Dois arquivos, nesta ordem:

- `spec-meta.yaml`: `current_phase` e `last_phase_change` (ISO 8601 UTC).
  Ao arquivar, também `status: archived` e `archived_at` — os três mudam
  juntos, nunca um sem os outros.
- `phase-history.yaml`: acrescentar um evento com `at`, `from`, `to` e
  `command`, exatamente um de cada.

**Releia `current_phase` imediatamente antes de escrever** e confirme que ainda
é a origem esperada. Se mudou, outra sessão avançou a spec: pare e relate, não
sobrescreva. Esta releitura substitui o lock que existia quando a escrita era
de um script — a transição de fase é serial por natureza, e o caso realista de
conflito é uma segunda sessão, não uma corrida de milissegundos.

Se o passo 5 falhar no meio, restaure os dois arquivos ao estado anterior.

## Limites

- Nunca escolha a fase de destino. A task informa; você valida e registra.
- Nunca dispense uma validação porque o usuário pediu para seguir. Gate
  reprovado se resolve corrigindo ou formalizando um `WAIVED` no próprio
  `gate.yaml`, com os quatro campos que `gate.allows_completion` exige.
- Nunca edite `current_phase` fora deste procedimento.
- Transição válida e reversível **não** pede confirmação: é execução de uma
  rota já decidida, não uma decisão de rota.

<!-- contract-normative:end -->

## Fonte única

Tudo entre `contract-normative:start` e `contract-normative:end` é a redação
normativa. Task, agente ou skill que precise dela **referencia este arquivo
pelo caminho**; copiar o texto cria uma segunda fonte que diverge em silêncio.
