# QA Notes — Spec 014

## US1 — Fluxo documental direto (T015–T024)

Data: 2026-08-15

### Pedidos simulados

- `clear-request`: `clarification_rounds: 0`, sem menu, sem elicitação avançada
  e geração direta do artefato.
- `material-ambiguity`: `clarification_rounds: 1`, com público pagador,
  países/moedas e cancelamento agrupados na mesma mensagem.
- `explicit-advanced-elicitation`: `clarification_rounds: 0`; rota avançada
  disponível somente por ativação explícita e retorno sem seleção obrigatória.
- `irreversible-action`: `clarification_rounds: 0`; a escrita/publicação não é
  executada e `human_pause: true` permanece exigido.

Fonte dos cenários:
`mosk/.claude/mosk/data/direct-flow-fixtures.md`.

### Evidência automatizada

- `bash -n mosk/.claude/mosk/scripts/selftest-toolkit.sh`: exit 0.
- `/bin/zsh -n mosk/.claude/mosk/scripts/selftest-toolkit.sh`: exit 0.
- `bash mosk/.claude/mosk/scripts/selftest-toolkit.sh`: exit 0,
  64 asserções, incluindo 15 verificações do fluxo documental direto.

As verificações cobrem contagem 0/1 de rodadas, ausência de menus obrigatórios,
consumo do contrato adaptativo, ativação avançada explícita, pausa humana e
templates alvo em modo `direct`/`grouped-once`/`opt-in`.

## US3 — Perfil adaptativo compartilhado (T038–T045)

Data: 2026-08-15

### Matriz de concordância

Todos os consumidores apontam para
`mosk/.claude/mosk/data/adaptive-work-contract.md` e para o mesmo
`classify-change.sh`; nenhum mantém score ou pisos próprios.

- `implement`: 16/16 fixtures concordantes em Bash e zsh.
- `security-review`: 16/16 fixtures concordantes em Bash e zsh; chamada
  explícita continua válida e o veredito permanece independente.
- `qa-gate`: 16/16 fixtures concordantes em Bash e zsh; evidência abaixo do
  piso não permite `PASS`.
- `orq-run`: 16/16 fixtures concordantes em Bash e zsh; especialistas são piso
  de agendamento e `human_pause` preserva a parada humana.
- Crescimento simulado de escopo e risco: `compact → elevated → critical`, sem
  rebaixamento entre reclassificações.

### Evidência automatizada

- `bash mosk/.claude/mosk/scripts/selftest-adaptive-work.sh --verbose`: exit 0,
  92 asserções.
- `/bin/zsh mosk/.claude/mosk/scripts/selftest-adaptive-work.sh --verbose`:
  exit 0, 92 asserções.
- `bash mosk/.claude/mosk/scripts/selftest-pipeline-state.sh --verbose`: exit 0,
  201 asserções.
- `/bin/zsh mosk/.claude/mosk/scripts/selftest-pipeline-state.sh --verbose`:
  exit 0, 201 asserções.

As nove novas regressões de estado provam que o perfil não autoriza salto de
fase, não bloqueia uma aresta válida, não trunca histórico, não altera a
evidência adaptativa e não permite archive com gate sem evidência.

## US4 — prompts compactos e fontes únicas (T046–T053)

### Redução do corpus

Baseline 2641 → **618 linhas operacionais**, contra teto de 1848 (SC-004 exige
≥30%; entregue **76%**). A tabela por arquivo está em `legacy-baseline.md`. A
medição deixou de ser manual: `legacy-baseline-metrics.tsv` guarda a baseline em
forma legível por máquina e `audit-legacy-surface.sh` recalcula o corpus a cada
execução e falha acima do teto.

Provas de que o gate morde, executadas em cópia isolada da árvore:

- baseline adulterada para total 180 (teto 126) → `redução insuficiente no
  corpus: 662 linhas medidas > teto 126`, e restaurada em seguida;
- 4 linhas normativas do contrato adaptativo copiadas para uma task → `cópia
  divergente do contrato ... (4 linhas normativas verbatim)`;
- caso negativo: referência ao contrato pelo caminho mais uma linha citada
  isolada → `contract_duplications: 0`, sem falso positivo.

### Superfície legada

23 ocorrências → **0**. Eram 22 headers de atribuição e uma frase de prosa,
todas em produto ativo; nenhuma entrou na allowlist, que permanece restrita a
`license|attribution|archive` sobre o fork vendorizado e specs arquivadas.

`.claude/rules/` foi excluído da varredura de legado. Rules são contexto do
projeto consumidor, geradas por `boot` a partir do código dele — não são
superfície distribuível do toolkit, e um projeto que use a ferramenta legada tem
o direito de dizer isso na própria rule. Coberto por caso próprio no
`selftest-toolkit.sh`.

### Bateria completa (T057)

Executada com o produto (`mosk/.claude/`) e com o espelho local (`.claude/`):

| Verificação | Resultado |
|---|---|
| `bash -n` — 24 scripts | OK |
| `zsh -n` — 24 scripts | OK |
| `shellcheck -S error` | OK |
| JSON schemas (3) | válidos |
| `selftest-common.sh` | OK — 29 asserções |
| `selftest-toolkit.sh` | OK — 98 asserções |
| `selftest-pipeline-state.sh` | OK — 201 asserções |
| `selftest-adaptive-work.sh` | OK — 92 asserções |
| `audit-docs-paths.sh` | clean ✓ (R1..R5) |
| `audit-legacy-surface.sh --json` | `ok:true`, 0 violações |
| `doctor.sh` (produto) | íntegro — 8 verificações |
| `doctor.sh` (espelho) | íntegro — 8 verificações |

Nota de escopo: executar os selftests via `zsh <script>` não é modo de uso
suportado e falha na auto-localização — os 24 scripts têm shebang bash e usam
`BASH_SOURCE`. O requisito real de zsh é o `common.sh` **sourceado** pelo agente
(o shell padrão do macOS é zsh), e isso é coberto por `selftest-common.sh`. A
mesma quebra existe no `HEAD` anterior à spec, portanto não é regressão desta
entrega. `zsh -n` passa nos 24.

### Espelhamento (T056)

`sync-agents-skills.sh agents-to-skills --clean` → 12 wrappers, 0 criados, 0
atualizados (já mínimos, apontando ao agente como fonte única). Espelho local
sincronizado com remoção de órfãos: saíram `constitution.md`, `draft-story.md` e
as três tasks absorvidas (`map-project.md`, `review-story.md`,
`webdesign-output.md`), que sobreviviam apenas no espelho. `.claude/rules/` foi
preservado. `diff -rq` entre produto e espelho não acusa diferença.

### Quickstart (T058)

Executado integralmente em **produto**, **espelho local** e **instalação
isolada** (materialização contendo apenas `.claude/`, sem `docs/` e sem git).

| Passo | Resultado |
|---|---|
| 1 — baseline | 47 tasks em disco; catálogo com 50 decisões (29 `keep`, 18 `rewrite`, 3 `merge`), uma por item |
| 2 — classificador `compact` | `profile:compact`, `validation_floor:focused`, `specialists:[]` |
| 2 — classificador sob zsh | `profile:elevated`, `floor:data_security`, `specialists:["security","qa"]` |
| 4 — fusões e legado | `ok:true`, 0 órfã, 0 referência quebrada, 0 ocorrência legada |
| 5 — regressão completa | 29 + 98 + 201 + 92 asserções; `doctor` íntegro |
| 6 — redução | 618 ≤ 1848 (76%) |
| `doctor.sh` na instalação isolada | íntegro — 8 verificações |

**Inputs adversariais no classificador** — todos retornam status ≠ 0 sem emitir
JSON, e nenhum é avaliado como shell:

| Input | Resultado |
|---|---|
| argumento obrigatório ausente | `rc=2`, sem JSON |
| opção desconhecida (`--turbo`) | `rc=2`, sem JSON |
| valor fora do enum (`--scope teleport`) | `rc=2`, sem JSON |
| duplicado contraditório (`--scope localized --scope broad`) | `rc=2`, sem JSON |
| command substitution (`--scope '$(touch /tmp/pwn)'`) | `rc=2`, sem JSON, arquivo **não** criado |
| metacaractere (`--scope 'localized; rm -rf /'`) | `rc=2`, sem JSON |
| nenhum argumento | `rc=2`, sem JSON |

**Preservação byte a byte em falha** — `transition-spec-phase.sh --spec 014 --to
archived` sobre uma spec em `implement` é recusado (`transição proibida:
implement -> archived`) e o SHA-1 de `spec-meta.yaml` e `phase-history.yaml`
permanece idêntico antes e depois da tentativa.
