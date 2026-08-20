# Relatório do corte (Phase 5)

Medido em 2026-08-20 contra [baseline.md](./baseline.md).

## Resultado

| | antes | depois | |
|---|---:|---:|---|
| Scripts (sem `payload-*`) | 7.912 | **2.730** | −66% |
| Número de scripts | 25 | **6** | −19 |
| Funções em `common.sh` | 39 | **18** | −21 |
| `selftest-*.sh` | 1.726 | **0** | SC-002 ✅ |
| Scripts sem chamador | 2.607 | **0** | SC-003 ✅ |

## SC-001 não foi atingido, e a meta é que estava errada

O critério pedia **≤ 1.500 linhas**. O resultado é **2.730**. Registro em vez de
forçar, porque forçar significaria cortar coisa que deve ficar.

Onde estão as 2.730:

| script | linhas | por que não encolhe mais |
|---|---:|---|
| `sync.sh` | 619 | gera 12 wrappers + 23 symlinks do Codex + `AGENTS.md`, cada um com regra própria de preservação (front-matter extra, corpo escrito à mão, symlink apontando para outro lugar) |
| `create-new-feature.sh` | 616 | é a corrida atômica: reserva no remoto, criação, commit, push e renumeração com retry. O laço inteiro é a razão de o script existir |
| `common.sh` | 586 | 18 funções, das quais `validate_promotion_target` (84) e `validate_spec_dir_containment` (46) resolvem symlink contra o disco |
| `validate.sh` | 511 | funde quatro auditores que somavam 717, com fixtures embutidas |
| `reset-install.sh` | 213 | cálculo do conjunto a apagar, incluindo órfãos |
| `sync-hallmark.sh` | 185 | diff/replay do vendor |

A meta de 1.500 foi estimada no `plan.md` **antes de os scripts terem sido
lidos**, e a mesma superestimativa apareceu duas vezes antes nesta spec: em
`create-new-feature.sh` (previsto ~300, real 616) e em `common.sh` (previstas ~6
funções, reais 18). O padrão é consistente — estimar corte sem abrir o arquivo
subestima quanto do arquivo é regra e não gordura.

**O que ainda daria para cortar, se o número importar mais que a clareza:**
`common.sh` tem quatro funções de resolução que se sobrepõem
(`get_feature_dir`, `find_feature_dir_by_prefix`, `find_feature_dir_by_prefix_any`,
`get_feature_paths` — 155 linhas somadas) e poderiam virar uma. `get_current_branch`
(43) carrega fallbacks para instalações sem git. Isso renderia ~150 linhas, não
1.200: não muda a ordem de grandeza, e é decisão de escopo do usuário, não minha.

## O que saiu

**15 scripts removidos na Phase 5 (4.738 linhas):**

`selftest-toolkit` (798), `selftest-pipeline-state` (567), `selftest-adaptive-work` (188),
`selftest-common` (173), `update-agent-context` (772), `audit-legacy-surface` (511),
`migrate-docs-structure` (501), `doctor` (220), `classify-change` (210),
`migrate-ctx-skills-to-rules` (183), `audit-docs-paths` (181),
`check-prerequisites` (166), `check-ship-ready` (150), `setup-plan` (61),
`transition-spec-phase` (57).

**2 fundidos em `sync.sh`:** `sync-agents-skills` (503) + `link-codex-skills` (304).

**`common.sh`:** 1.334 → 586.

## Onde cada capacidade foi parar

Nada foi removido sem destino. FR-009 exigia o equivalente declarativo **antes**
da remoção, e é o que a ordem das fases garantiu.

| capacidade | destino |
|---|---|
| regra de fase, gate, promoção, metadata, histórico | `pipeline.yaml` (Phase 2) |
| procedimento de transição | `data/phase-transition-contract.md` (Phase 3) |
| classificação adaptativa e `human_pause` | `data/adaptive-work-contract.md` (Phase 2) |
| interpretar `plan.md` e atualizar rules | prompt, dentro de `plan.md` (Phase 3) |
| migração brownfield e `ctx-*` → rules | task `migrate-install.md` (Phase 5) |
| integridade, pré-requisitos, ship-ready, docs-paths, fonte única | `validate.sh` (Phases 4 e 5) |
| geração de wrappers e do Codex | `sync.sh` (Phase 5) |

## Verificações

- `validate.sh all`: `install`, `self-check`, `docs-paths`, `single-source`, `fixtures` 14/14 — todos OK
- Equivalência conferida contra os originais **antes** de removê-los:
  `check-ship-ready` (mesmas 4 falhas, mesma ordem), `audit-docs-paths` (ambos limpos),
  `sync` (`AGENTS.md` byte a byte idêntico, mesmas 23 skills)
- Regressão de criação de spec em fixture: metadata aprovado, três locators de
  `resolve_spec_dir` resolvendo, sem arquivo temporário vazado
- Nenhum script remanescente sem chamador nominal

## Fora de escopo, sinalizado (T028)

`payload-infra.sh` (366 linhas) **não tem chamador** e pertence ao modo bench,
não ao pipeline. Não foi cortado porque está fora do escopo desta spec. Fica
registrado como pendência: ou o modo bench o invoca em algum caminho que a busca
por citação nominal não vê, ou ele é órfão e deve sair numa spec própria.
