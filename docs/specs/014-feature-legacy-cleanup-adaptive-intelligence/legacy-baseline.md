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
