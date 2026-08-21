# Data Model — Limpeza do legado e inteligência adaptativa

## TaskDisposition

Representa a decisão canônica sobre uma das 50 tasks da baseline.

| Campo | Tipo | Regras |
|---|---|---|
| `task` | nome de arquivo | único, existente na baseline |
| `action` | enum | `keep`, `rewrite`, `merge`, `remove` |
| `destination` | path/lista | obrigatório para `merge`; vazio para `keep` |
| `consumers` | lista | agentes, skills ou tasks que expõem a capacidade |
| `evidence` | enum | `pending`, `covered`, `not_applicable` |
| `reason` | texto curto | obrigatório e objetivo |

Invariantes:

- Existem exatamente 50 linhas de dados após a reconciliação inicial.
- Cada task aparece uma vez.
- `merge` só chega a `covered` com destino existente, zero referência quebrada e fixture equivalente verde.
- `remove` só chega a `covered` com zero consumidor e prova de não uso ou absorção explícita.
- O catálogo é alterado na fonte do produto e sincronizado; o espelho nunca diverge.

## CapabilityRoute

Relaciona intenção pública a uma implementação canônica.

| Campo | Tipo | Regras |
|---|---|---|
| `capability` | identificador | estável e único |
| `entrypoint` | lista | agente/skill acionável pelo usuário |
| `implementation` | path | task ou contrato canônico existente |
| `fixtures` | lista | ao menos uma quando houver merge/remove |

Uma capacidade pode ter múltiplos entrypoints, mas apenas uma regra operacional canônica.

## ChangeSignals

Entrada controlada para a decisão adaptativa.

| Campo | Valores |
|---|---|
| `scope` | `localized`, `multi_file`, `cross_domain`, `public_contract` |
| `reversibility` | `easy`, `coordinated`, `irreversible` |
| `sensitive_surface` | `none`, `paths_state`, `data_security`, `production_critical` |
| `evidence` | `strong`, `partial`, `absent` |
| `ambiguity` | `clear`, `bounded`, `material` |
| `requested_floor` | vazio, `standard`, `elevated`, `critical` |

Os valores são enums para impedir que diferenças textuais mudem a decisão. O agente deve conseguir apontar evidência observável para cada sinal.

## ChangeProfile

Saída derivada, não editável manualmente.

| Campo | Tipo | Descrição |
|---|---|---|
| `schema` | inteiro | versão do contrato |
| `profile` | enum | `compact`, `standard`, `elevated`, `critical` |
| `score` | inteiro | soma das dimensões |
| `floor` | enum | piso mais severo aplicado |
| `reasons` | lista de enum | sinais/pisos que explicam o resultado |
| `context_budget` | enum | budget associado ao perfil |
| `validation_floor` | enum | validação mínima associada |
| `specialists` | lista | especialistas mínimos requeridos |
| `human_pause` | boolean | pausa por dúvida material/irreversibilidade |

Invariantes:

- `profile >= floor` na ordem compact < standard < elevated < critical.
- Um `requested_floor` só eleva o resultado.
- `irreversible` e `production_critical` implicam `critical` e `human_pause: true` quando a próxima ação for irreversível.
- `data_security` implica no mínimo `elevated` e revisão de segurança.
- A mesma entrada na mesma versão do schema produz bytes JSON semanticamente equivalentes em Bash e zsh.

## ContextBudget

Política imutável associada a cada perfil.

| Budget | Fontes iniciais | Expansão permitida |
|---|---|---|
| `compact` | regras do projeto, alvo, referências diretas e teste focal | apenas se uma referência direta ou falha exigir |
| `standard` | compact + interfaces, chamadores e documentação do domínio | até fechar dependências do domínio |
| `elevated` | standard + domínios cruzados, contratos, histórico QA/security relevante | até cobrir toda superfície sensível |
| `critical` | elevated + operação, recuperação, ownership e evidência independente | sem atalho; toda fonte crítica aplicável |

Budget limita relevância, não impede carregar evidência necessária. Expansões devem registrar o gatilho.

## ValidationFloor

| Piso | Validações mínimas |
|---|---|
| `focused` | sintaxe/lint aplicável e teste focal |
| `domain` | focused + suíte do domínio e contrato afetado |
| `independent` | domain + regressão ampla + especialista security/QA conforme sinal |
| `release` | independent + security e QA independentes, rollback/recuperação e aprovação humana quando irreversível |

## LegacyAllowance

Exceção estreita para ocorrências de legado que podem permanecer.

| Campo | Regra |
|---|---|
| `path_pattern` | escopo explícito, sem wildcard amplo sobre produto ativo |
| `kind` | `license`, `attribution`, `archive` |
| `reason` | obrigatório |
| `operational` | sempre `false` |

Qualquer ocorrência fora da allowlist em fonte ativa falha a auditoria.

## Lifecycle

```text
pedido + contexto
      │
      ▼
ChangeSignals ── valida enums ──► score + pisos
                                      │
                                      ▼
                               ChangeProfile
                               ├─ ContextBudget
                               ├─ ValidationFloor
                               ├─ specialists
                               └─ human_pause
```

`ChangeProfile` é recalculado quando o escopo muda materialmente. Ele não cria uma nova fase no pipeline nem substitui `spec-meta.yaml`/`phase-history.yaml`.
