# Data model: núcleo determinístico do pipeline

## SpecState

Projeção atual persistida em `spec-meta.yaml`.

Campos obrigatórios no schema vigente:

- `schema`: versão inteira do contrato.
- `spec_number`: identificador decimal de três dígitos.
- `spec_id`: nome canônico da pasta.
- `type`: tipo permitido de spec.
- `branch`: branch canônica registrada.
- `status`: `active` ou `archived`.
- `current_phase`: uma das seis fases canônicas.
- `created_at`, `last_phase_change`: timestamps UTC.

Invariantes:

- `status: archived` implica `current_phase: archived` e `archived_at` válido.
- `current_phase: archived` nunca volta a outra fase.
- Número, `spec_id`, branch e diretório resolvido devem concordar.
- Em schema vigente, o último `PhaseTransition.to` deve ser igual a
  `current_phase`.
- Em schema vigente, fases posteriores a `specify` exigem histórico presente e
  estruturalmente válido.

## PhaseTransition

Evento append-only em `phase-history.yaml`.

- `schema`: versão do evento.
- `at`: timestamp UTC.
- `from`: fase observada antes da operação.
- `to`: fase confirmada.
- `command`: task MOSK que executou a decisão humana.

Não existe evento para no-op idempotente ou tentativa recusada. A ordem física
é a ordem do histórico; timestamps não podem retroceder. Cada `from` posterior
deve repetir o `to` anterior, e toda aresta/comando precisa pertencer aos enums
da máquina de estados.

## PhaseContract

| Destino | Origem permitida | Pré/pós-condição mínima |
|---|---|---|
| `plan` | `specify` | `spec.md` existe, não está vazio e não contém marcador bloqueante |
| `tasks` | `plan` | `spec.md` e `plan.md` válidos |
| `implement` | `tasks`, `qa-gate` | `tasks.md` existe; no retorno, gate atual é corrigível |
| `qa-gate` | `implement` | tasks executáveis concluídas e evidência de validação disponível |
| `archived` | `qa-gate` | gate válido, evidência presente, tasks completas e promoções satisfeitas |

A mesma fase como origem e destino é no-op idempotente. Nenhuma outra aresta é
permitida.

## GateDecision

Projeção versionada em `gate.yaml`:

- identidade da spec/story;
- `gate`: `PASS`, `CONCERNS`, `FAIL` ou `WAIVED`;
- score e histórico de scores;
- findings estáveis;
- referência verificável de evidência;
- waiver completo quando aplicável.

Schema 1 continua legível para arquivos históricos. O schema vigente é exigido
para novas decisões e bloqueia `PASS`/`WAIVED` sem evidência. A compatibilidade
do schema 1 só é habilitada para specs fisicamente arquivadas.

## SpecLocator

Entrada aceita pelo resolvedor:

- número: `013`;
- `spec_id`: `013-feature-deterministic-pipeline-state`;
- branch: `feature/013-deterministic-pipeline-state`.

O resultado só é válido quando exatamente um diretório passa na confirmação de
metadata. O modo `active` não consulta archive; o modo `any` consulta ambos sem
preferência e falha em duplicidade. Diretórios ou raízes symlink são recusados,
e a contenção física é revalidada no momento da escrita.
