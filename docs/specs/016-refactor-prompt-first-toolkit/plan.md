# Implementation Plan: Toolkit prompt-first

**Branch**: `refactor/016-prompt-first-toolkit` | **Date**: 2026-08-19 | **Spec**: [spec.md](./spec.md)
**Input**: [spec.md](./spec.md), [ADR-0021](./architecture/adr-0021-declarative-rule-minimal-shell.md)

## Summary

Mover a regra do pipeline de shell para `pipeline.yaml`, tornar o agente o único leitor de dado estruturado, fundir os quatro auditores num `validate.sh` com chamador nomeado, e cortar o Bash de 7.912 para no máximo 1.500 linhas — nessa ordem, porque cada passo é o que torna o seguinte barato.

## Technical Context

**Linguagem/formato**: Markdown, YAML, Bash. Sem app compilado, sem gerenciador de pacotes.
**Distribuição**: `npx degit rogerznts/mosk/mosk .` — tudo que muda vive em `mosk/`.
**Dependências permitidas**: nenhuma externa. `validate.sh` roda sem PyYAML, npm ou pip.
**Alvo de plataforma**: bash e zsh, macOS e Linux, com e sem git.
**Validação**: fixtures de contrato dentro do `validate.sh`; sem suíte de self-test de shell (ADR-0021, decisão 6).
**Restrição herdada**: `payload-*.sh` (737 linhas) e o vendor Hallmark seguem regime próprio, fora do escopo.

### Regra de decisão aplicada (ADR-0021 §4)

Toda peça abaixo foi classificada por três perguntas, na ordem: *(1)* o fato precisa ser lido por mais de um consumidor ou sobreviver à sessão → **YAML**; *(2)* é julgamento sobre conteúdo → **prompt**; *(3)* exige algo da lista fechada — corrida no remoto, geração de derivados em massa, execução fora da sessão → **script**.

## Inventário do corte

Linha de base: **7.912 linhas** em 25 scripts (excluído `payload-*`).

### Fica — 6 scripts, alvo ~1.450 linhas

| script | hoje | alvo | caso da lista fechada | chamador |
|---|---:|---:|---|---|
| `create-new-feature.sh` | 646 | ~600 | corrida no remoto (reserva em `refs/spec-numbers/`) | `specify.md`, `artefact.md` |
| `sync.sh` *(funde `sync-agents-skills` + `link-codex-skills`)* | 807 | ~450 | geração de derivados em massa | `/mosk-write-skill`, `/mosk-update` |
| `validate.sh` *(funde `doctor` + `check-prerequisites` + `check-ship-ready` + `audit-docs-paths`)* | 717 | ~300 | execução fora da sessão (hook/CI) | hook de `gh pr merge`, tasks de fase |
| `reset-install.sh` | 213 | 213 | geração de derivados em massa | `/mosk-update` |
| `sync-hallmark.sh` | 185 | 185 | geração de derivados (diff/replay do vendor) | `hallmark.md` |
| `common.sh` | 1.323 | ~250 | suporte aos 5 acima | os 5 acima |

**A previsão de 646 → ~300 para o `create-new-feature.sh` estava errada, e a Phase 3 corrigiu a rota.** A ideia era mover a emissão do `spec-meta.yaml` para o `specify.md`. Mas o emissor está **dentro do laço de retry da corrida de numeração** — o ciclo branch → pasta → commit → push, que renumera e refaz tudo quando o push é rejeitado. Tirar o emissor dali obrigaria o script a parar no meio para o agente escrever, quebrando a atomicidade que é a razão de o script existir (caso 1 da lista fechada).

O que a Phase 3 fez em vez disso foi eliminar uma duplicação real: **havia dois emissores do mesmo arquivo** — `write_initial_spec_meta` no script e `write_spec_meta` no `common.sh` — e eles já divergiam (um aplicava default em `type:`, o outro não). Sobrou um, com escrita atômica e suporte a `extends`. Ganho: 37 linhas e uma fonte a menos para divergir.

**`common.sh` cai de 39 funções para ~14**: resolução de raiz, branch atual, diretório da spec, contenção física de caminho e as primitivas de git da reserva. As ~25 restantes são leitores de YAML, validadores de gramática e a máquina de estados — todas eliminadas pelas decisões 2 e 3 do ADR-0021.

> A estimativa original era ~6. A conferência da T008 mostrou que estava otimista: as funções de contenção precisam resolver symlink contra o disco, o que um agente não pode afirmar sem consultá-lo. O alvo de **linhas** (SC-001) não muda.

### Sai — 19 scripts, ~6.460 linhas

| script | linhas | destino | por quê |
|---|---:|---|---|
| `selftest-toolkit.sh` | 798 | removido | ADR-0021 §6 — testa shell que deixa de existir |
| `selftest-pipeline-state.sh` | 567 | removido | idem |
| `selftest-adaptive-work.sh` | 188 | removido | idem |
| `selftest-common.sh` | 173 | removido | idem |
| `update-agent-context.sh` | 772 | `plan.md` (prompt) | pergunta 2 — interpretar `plan.md` é julgamento sobre conteúdo |
| `audit-legacy-surface.sh` | 511 | removido | sem chamador; a auditoria vira passo do `validate.sh` |
| `migrate-docs-structure.sh` | 501 | task `migrate-docs.md` | pergunta 2 — migração brownfield é caso a caso |
| `classify-change.sh` | 210 | `data/adaptive-work-contract.md` | pergunta 1 — é tabela de classificação, não algoritmo |
| `migrate-ctx-skills-to-rules.sh` | 183 | task | pergunta 2 |
| `transition-spec-phase.sh` | 57 | `pipeline.yaml` | pergunta 1 — a regra é dado |
| `setup-plan.sh` | 61 | `validate.sh` | validação trivial já coberta |
| `doctor.sh` | 220 | `validate.sh` | fusão |
| `check-prerequisites.sh` | 166 | `validate.sh` | fusão |
| `check-ship-ready.sh` | 150 | `validate.sh` | fusão |
| `audit-docs-paths.sh` | 181 | `validate.sh` | fusão |
| `payload-infra.sh` | 366 | — | **fora de escopo**, sem chamador; sinalizar, não cortar |

### Regras hoje presas em shell que precisam migrar antes da remoção

Isto é FR-009 e é a parte que não pode ser pulada. Cada linha aqui é regra real, não código. **A tabela nasceu com 7 linhas e fechou com 9** — a conferência da T008 ([rule-migration-audit.md](./rule-migration-audit.md)) encontrou duas regras que este plano não previa:

| regra | origem | destino |
|---|---|---|
| arestas válidas entre as 6 fases | `phase_transition_allowed` | `pipeline.yaml: phases[].transitions_to` |
| `qa-gate -> implement` só por `apply-qa-fixes` | `phase_command_matches_destination` | `pipeline.yaml`, atributo `allowed_commands` da aresta |
| artefatos exigidos por fase | `validate_phase_preconditions` | `pipeline.yaml: phases[].requires` |
| vereditos de gate e forma do waiver | `validate_gate_contract`, `validate_gate_for_completion` | `pipeline.yaml: gate` |
| promoções pendentes impedem archive | `validate_spec_promotions_satisfied` | `pipeline.yaml: phases.archived.requires` |
| schema do `spec-meta.yaml` + identidade cruzada número/id/tipo/branch (ADR-0017) | `validate_spec_metadata` | `pipeline.yaml: spec_meta` |
| continuidade da cadeia, timestamps monotônicos e consistência de `origin` | `validate_phase_history` | `pipeline.yaml: phase_history` |
| contenção de destino de `promote:` | `validate_promotion_target` | permanece em `common.sh` — é caminho de sistema de arquivos, não dado de domínio |
| classificação de risco/escopo e `human_pause` | `classify-change.sh` | `data/adaptive-work-contract.md` |

## Sequenciamento

A ordem não é arbitrária; cada fase remove o que torna a seguinte cara.

**Fase A — declarar a regra.** Escrever `pipeline.yaml` com as nove regras acima. Nada é removido ainda; o YAML e o shell coexistem e devem concordar. É a única fase em que a duplicação é aceitável, e é temporária por construção.

**Fase B — inverter o leitor (ADR-0021 §3).** Tasks passam a ler o `pipeline.yaml` e a passar valores resolvidos por argumento. É aqui que 33 funções de `common.sh` perdem chamador — e é por isso que esta fase vem antes do corte, não depois: cortar antes de inverter o leitor obriga a reescrever o leitor.

**Fase C — fundir os auditores e dar-lhes chamador (ADR-0021 §5).** `validate.sh` nasce cobrindo os quatro casos, e o hook de merge passa a invocá-lo. O caso da 014 vira fixture.

**Fase D — cortar.** Remoção dos 19 scripts. Só agora, porque a esta altura nenhum deles tem chamador.

**Fase E — alinhar os documentos.** Roadmap (Etapas 2 a 5), `.claude/rules/scripts.md`, `CLAUDE.md` e o que a 015 deixa. Sem isso o roadmap vigente continua instruindo o contrário.

## Project Structure

### Documentation (this feature)

```
docs/specs/016-refactor-prompt-first-toolkit/
├── spec.md
├── plan.md                 # este arquivo
├── tasks.md
├── spec-meta.yaml
├── baseline.md             # T001 — linha de base do corte
├── rule-migration-audit.md # T008 — conferência regra a regra (FR-009)
├── harvest/                # T029 — material colhido da 015
└── architecture/
    └── adr-0021-declarative-rule-minimal-shell.md   # promote: copy
```

### Source (dentro de `mosk/`, o que ship)

```
mosk/.claude/mosk/
├── pipeline.yaml                     # NOVO — fonte única da regra
├── core-config.yaml                  # ajustado
├── scripts/                          # 25 -> 6 arquivos
│   ├── create-new-feature.sh         # reduzido
│   ├── sync.sh                       # NOVO (fusão de 2)
│   ├── validate.sh                   # NOVO (fusão de 4)
│   ├── reset-install.sh
│   ├── sync-hallmark.sh
│   └── common.sh                     # 39 -> ~6 funções
├── tasks/                            # leem o pipeline.yaml
└── data/
    └── adaptive-work-contract.md     # recebe a classificação
```

## Colheita da spec 015

Transportar antes de a branch ser abandonada:

| artefato | ação |
|---|---|
| `templates/execution-plan-tmpl.yaml` (99) | copiar inteiro — é o formato declarativo que a US4 usa |
| `data/runner-contract.md` (518) | colher só o schema do `execution-plan`; descartar schema de `run-state`, trailers e máquina de estados da unidade |
| `spec.md` da 015 (5 user stories) | os requisitos migram para a US4 desta spec; o mecanismo é substituído |
| `adr-0020` | permanece na 015, sem promoção — já referenciado como superseded pelo ADR-0021 |
| `contracts/runner-cli.md`, `run-state-tmpl.yaml`, `build-execution-plan.sh`, `run-state.sh`, `run-worktree.sh`, `selftest-runner.sh` | descartar |

## Complexity Tracking

| desvio | por quê é necessário | alternativa descartada |
|---|---|---|
| `pipeline.yaml` e shell coexistem durante a Fase A | FR-009 proíbe remover regra antes de existir equivalente declarativo | cortar primeiro e migrar depois — foi assim que a 014 passou sem gate |
| `validate.sh` continua sendo shell | lista fechada, caso 3: precisa rodar em hook e CI, fora da sessão do agente | validação só por prompt — não roda em `gh pr merge` |
| `common.sh` sobrevive com ~200 linhas | os 5 scripts remanescentes precisam resolver raiz e branch | duplicar a resolução em cada script |

## Riscos

- **Regra perdida na tradução.** Mitigação: a tabela de regras presas em shell é exaustiva e cada linha vira task com verificação própria.
- **`validate.sh` nasce sem chamador**, repetindo o erro da 014. Mitigação: o chamador é task da mesma fase, não posterior.
- **A 015 tem trabalho não mesclado** que se perde se a branch for apagada antes da colheita. Mitigação: colheita é a primeira task da Fase E, e a branch não é apagada nesta spec.
- **A 014 está no `master` em `qa-gate`.** Não é causado por esta spec, mas o `master` só volta a ser válido pela própria regra quando ela for fechada. Fora do escopo aqui; registrado para decisão do usuário.
