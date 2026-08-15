# Contract — Adaptive Work Profile

## Purpose

Um único contrato decide quanta investigação, contexto e validação uma mudança exige. Agentes declaram sinais enumerados com evidência; o classificador aplica regras determinísticas. O contrato define um piso, não uma autorização para ampliar escopo.

## Input

```yaml
schema: 1
scope: localized | multi_file | cross_domain | public_contract
reversibility: easy | coordinated | irreversible
sensitive_surface: none | paths_state | data_security | production_critical
evidence: strong | partial | absent
ambiguity: clear | bounded | material
requested_floor: "" | standard | elevated | critical
```

### Signal selection

- `scope`: usar `public_contract` para interfaces, schemas, comandos ou comportamento consumido externamente; `cross_domain` para dois ou mais domínios com ownership distinto.
- `reversibility`: `irreversible` quando rollback não restaura dados/efeitos ou exige intervenção humana externa.
- `sensitive_surface`: usar o sinal mais severo presente; paths, estado e escrita em arquivos são `paths_state`; autenticação, segredos, privacidade e dados sensíveis são `data_security`; produção destrutiva, credenciais de produção ou controle de acesso central são `production_critical`.
- `evidence`: `strong` exige testes relevantes reproduzíveis e contexto confirmado; ausência de um deles não pode ser forte.
- `ambiguity`: `material` quando respostas diferentes mudariam arquitetura, escopo, dados ou efeito externo.
- `requested_floor`: apenas elevação deliberada; nunca aceita `compact` porque não pode rebaixar o cálculo.

## Decision

### Score

| Signal | 0 | 1 | 2 | 3 | 5 |
|---|---|---|---|---|---|
| scope | localized | multi_file | cross_domain | public_contract | — |
| reversibility | easy | coordinated | — | irreversible | — |
| sensitive_surface | none | — | paths_state | data_security | production_critical |
| evidence | strong | partial | absent | — | — |
| ambiguity | clear | bounded | material | — | — |

- 0–2 → `compact`
- 3–5 → `standard`
- 6–9 → `elevated`
- 10+ → `critical`

### Floors

Applied after scoring, strongest wins:

1. `data_security` → at least `elevated`.
2. `production_critical` or `irreversible` → `critical`.
3. `cross_domain` + `absent` evidence → at least `elevated`.
4. `requested_floor` → at least the requested value.

Unknown options, missing required signals or contradictory duplicates fail closed with non-zero status and no profile output.

## Output

Canonical JSON shape:

```json
{
  "schema": 1,
  "profile": "elevated",
  "score": 7,
  "floor": "elevated",
  "reasons": ["score:6-9", "floor:data_security"],
  "context_budget": "elevated",
  "validation_floor": "independent",
  "specialists": ["security", "qa"],
  "human_pause": false
}
```

Ordering of keys and arrays must be stable for fixtures. Reasons use controlled values; free text evidence remains in the consuming artifact, not in CLI arguments.

## Profile matrix

| Profile | Context | Validation | Specialists | User interaction |
|---|---|---|---|---|
| compact | alvo + regras + refs/teste diretos | `focused` | nenhum obrigatório | nenhuma pergunta se claro |
| standard | compact + interfaces/chamadores/docs do domínio | `domain` | conforme domínio | uma rodada apenas se bloqueante |
| elevated | standard + contratos cruzados + histórico QA/security | `independent` | security ou QA conforme superfície; ambos se compartilhada | expor risco e pausar em dúvida material |
| critical | elevated + operação, recovery, ownership e evidência independente | `release` | security e QA obrigatórios | aprovação humana para ação irreversível |

## Context expansion

1. Começar no conjunto inicial do perfil.
2. Expandir apenas por referência direta, falha de teste, mudança de escopo ou sinal sensível descoberto.
3. Reclassificar quando uma expansão revelar sinal mais severo.
4. Nunca omitir fonte necessária apenas para permanecer no budget.
5. Não carregar referências extensas “por precaução” quando nenhum gatilho as conecta ao pedido.

## Integration contract

- `implement`: usa perfil para inspeção e validação mínimas; não muda a fase por causa do perfil.
- `security-review`: obrigatório por piso/superfície ou chamada explícita; mantém independência do implementador.
- `qa-gate`: usa o piso como mínimo e pode ampliar cobertura; nunca converte ausência de evidência em PASS.
- `orq-run`: agenda especialistas conforme perfil, preservando os pontos humanos irreversíveis.
- Tasks documentais: usam `ambiguity` para decidir se existe uma única rodada agrupada de perguntas.

O contrato não implementa worktrees, checkpoints ou execução paralela; isso pertence à Etapa 4.

## Security properties

- Todos os argumentos são enums allowlisted.
- Nenhum valor é avaliado como shell, path ou comando.
- JSON é construído apenas com constantes internas.
- Opções repetidas com valores diferentes falham.
- Flags que tentem rebaixar pisos não existem.
- O script não lê rede, segredos, YAML arbitrário ou estado de usuário.

## Compatibility

- Bash 3.2+ e zsh em modo de execução do script.
- Sem arrays/recursos exclusivos de Bash em helpers compartilhados sem cobertura zsh.
- Sem `jq` obrigatório em runtime; validação com `jq` pode existir em desenvolvimento quando disponível.
