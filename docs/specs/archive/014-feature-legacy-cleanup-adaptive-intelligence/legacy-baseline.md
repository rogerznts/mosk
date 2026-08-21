# Baseline do legado operacional

Data da medição: 2026-08-15

## Reconciliação do inventário

O diretório `mosk/.claude/mosk/tasks/` contém 50 arquivos Markdown. A lista de
nomes é idêntica à registrada em
`docs/specs/archive/012-feature-stabilize-toolkit-contracts/legacy-task-inventory.md`:
nenhuma task foi adicionada, removida ou renomeada entre as duas medições.

| Disposição na spec 012 | Quantidade |
|---|---:|
| `keep` (`manter`) | 29 |
| `rewrite` (`reescrever`) | 18 |
| `merge` (`fundir`) | 3 |
| `remove` (`remover`) | 0 |
| **Total** | **50** |

A reconciliação executável está em
`mosk/.claude/mosk/data/task-dispositions.tsv`. O arquivo mantém as 50 decisões
mesmo quando uma task fundida deixar de existir, para que a remoção continue
auditável.

## Fórmula de linhas operacionais

A baseline conta linhas não vazias de cada uma das 18 tasks `rewrite`, exclui
um frontmatter YAML inicial (quando existir) e exclui comentários HTML de
atribuição em linha única iniciados por `Inspired`, `Adapted` ou `Based`. Títulos,
regras, exemplos e blocos de código continuam na conta porque todos consomem
contexto operacional.

Comando reproduzível, executado a partir da raiz do repositório:

```bash
awk '
  BEGIN { front = 0 }
  /^---[[:space:]]*$/ {
    if (NR == 1 || front == 1) { front = !front; next }
  }
  front { next }
  /^[[:space:]]*$/ { next }
  /^<!--[[:space:]]*(Inspired|Adapted|Based)[^>]*-->[[:space:]]*$/ { next }
  { count++ }
  END { print count + 0 }
' "mosk/.claude/mosk/tasks/$task"
```

| Task `rewrite` | Linhas operacionais |
|---|---:|
| `advanced-elicitation.md` | 82 |
| `apply-qa-fixes.md` | 120 |
| `assess-nfr.md` | 249 |
| `assess-risk.md` | 266 |
| `bench-mode.md` | 249 |
| `correct-course.md` | 55 |
| `create-deep-research-prompt.md` | 190 |
| `create-doc.md` | 68 |
| `create-epic.md` | 105 |
| `create-story.md` | 206 |
| `design-tests.md` | 122 |
| `enrich-story.md` | 91 |
| `execute-checklist.md` | 66 |
| `facilitate-brainstorming-session.md` | 96 |
| `planner.md` | 257 |
| `review-story-draft.md` | 98 |
| `shard-doc.md` | 133 |
| `trace-spec.md` | 188 |
| **Total** | **2641** |

O alvo de SC-004 é no máximo 1848 linhas operacionais ao final da etapa (redução
mínima de 30%, arredondada para baixo a partir de 1848,7).

## Medição final

A mesma fórmula, aplicada ao fim da etapa. A tabela deixou de viver só nesta
prosa: `mosk/.claude/mosk/data/legacy-baseline-metrics.tsv` guarda a coluna
`baseline_lines` em forma legível por máquina, e `audit-legacy-surface.sh` mede
o corpus atual e falha quando o total excede o teto. A evidência abaixo é
reproduzível por `bash mosk/.claude/mosk/scripts/audit-legacy-surface.sh --json`.

| Task `rewrite` | Baseline | Final |
|---|---:|---:|
| `advanced-elicitation.md` | 82 | 32 |
| `apply-qa-fixes.md` | 120 | 36 |
| `assess-nfr.md` | 249 | 28 |
| `assess-risk.md` | 266 | 33 |
| `bench-mode.md` | 249 | 50 |
| `correct-course.md` | 55 | 26 |
| `create-deep-research-prompt.md` | 190 | 33 |
| `create-doc.md` | 68 | 44 |
| `create-epic.md` | 105 | 25 |
| `create-story.md` | 206 | 34 |
| `design-tests.md` | 122 | 31 |
| `enrich-story.md` | 91 | 37 |
| `execute-checklist.md` | 66 | 20 |
| `facilitate-brainstorming-session.md` | 96 | 46 |
| `planner.md` | 257 | 51 |
| `review-story-draft.md` | 98 | 37 |
| `shard-doc.md` | 133 | 25 |
| `trace-spec.md` | 188 | 30 |
| **Total** | **2641** | **618** |

Redução de **76%**, contra o mínimo de 30% exigido por SC-004 — 618 linhas
contra um teto de 1848.

O material que saiu do caminho principal não foi apagado: passou a ser carregado
sob demanda a partir de `mosk/.claude/mosk/data/`, em
`bench-runtime-reference.md`, `planner-reference.md` e
`brainstorming-session-reference.md`, além dos catálogos que já existiam
(`brainstorming-techniques.md`, `elicitation-methods.md`). O
`selftest-toolkit.sh` cobra as duas pontas dessa relação: dependência declarada
que não existe no disco falha, e arquivo de referência que nenhum consumidor
declara também falha.

## Inventário final e fusões

| Medida | Valor |
|---|---:|
| Decisões no catálogo | 50 |
| Tasks ativas em disco | 47 |
| Fusões aplicadas (`merge` + `covered`) | 3 |
| Referências a path removido | 0 |
| Ocorrências legadas fora da allowlist | 0 |

As três fusões preservam a capacidade pública em um novo entrypoint, cada uma
com fixture em `merged-task-fixtures.md` e marcador `Capability:` na rota:

| Task absorvida | Capability | Destino |
|---|---|---|
| `map-project.md` | `project-mapping` | `boot.md` + agente Architect |
| `review-story.md` | `post-implementation-story-review` | modo story de `qa-gate.md` + agente QA |
| `webdesign-output.md` | `complete-ui-delivery` | `hallmark.md` + agente UI Expert |

## Legado operacional

As 23 ocorrências restantes do termo legado eram 22 headers de atribuição
(`<!-- Inspired by BMAD and SpecKit -->`, em 11 arquivos `.md`, 10 `.yaml`
prefixados com `# ` e 1 com `## `) e uma frase de prosa em
`.claude/mosk/utils/doc-template.md`. Todas foram removidas — a prosa reescrita
em voz MOSK, não apagada.

Nenhuma entrou na allowlist. `legacy-reference-allowlist.tsv` é mínima por
contrato (`license|attribution|archive`) e T004 proíbe cobrir fonte operacional
ativa; esses 23 arquivos são todos produto ativo. A atribuição que permanece é a
do fork vendorizado em `data/hallmark/`, que é legal e continua allowlistada.
