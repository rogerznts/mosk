# Conferência das user stories da spec 015 (T033)

Cumpre o **FR-016**: os requisitos da 015 permanecem atendidos ao fim da 016.
O que foi substituído é o **mecanismo**, não a exigência.

Conferido item a item contra a spec da branch `feature/015-structured-autonomous-runner` (`7b050e0`).

---

## US1 — Plano de execução legível por humano e máquina (P1)

**Atendida.** `orq-run.md` Step 1 ganhou "Materialize o plano antes de pedir
consentimento": o agente escreve `{spec_dir}/execution-plan.yaml` a partir de
`templates/execution-plan-tmpl.yaml`.

| cenário da 015 | como fica |
|---|---|
| 1. uma unidade por story, com tasks, critérios, arquivos e perfil | mesma estrutura do template, campo a campo |
| 2. fase fundacional vira unidade em onda 0, em série | Step 1 já exigia; `kind: foundational`, `wave: 0` |
| 3. `[P]` honrado, nunca inferido | regra preservada literalmente no Step 1 |
| 4. geração idempotente exceto por timestamp | `generated_at` é o único campo volátil |
| 5. `tasks.md` sem `[US#]` falha sem escrever plano parcial | explícito: "falhe com mensagem específica e não escreva plano parcial" |

**Mudou:** o plano era gerado por `build-execution-plan.sh` (358 linhas); agora é
escrito pelo agente. O `sources.tasks_digest` saiu — existia para o script
detectar plano vencido sem reler os arquivos, e quem relê não precisa de digest.

---

## US2 — A corrida é retomável, não recomeçável (P1)

**Atendida.** O estado saiu do `run-state.yaml` para o **front-matter do
`run-log.md`**: `run_status`, `current_wave`, `units_merged`, `units_pending`,
`attempts`, `last_updated`.

| cenário da 015 | como fica |
|---|---|
| 1. unidades mescladas não são reimplementadas | "leia `units_merged` e não reimplemente nada que já está lá" |
| 2. merge pendente é identificado e aplicado uma vez | regra explícita para worktree existente com trabalho não mesclado |
| 3. interrupção no join deixa disco em estado válido | o merge é sequencial e o front-matter só é atualizado **depois** do merge |
| 4. contagem de tentativas continua, não reinicia | "a contagem de `attempts` continua de onde parou" |
| 5. relatório cobre as duas sessões | `run-log.md` é append-only e é a fonte, não a memória do condutor |

**Mudou:** um arquivo a menos, e o estado passou a viver ao lado do histórico que
o explica.

---

## US3 — Ciclo de vida do worktree (P1)

**Atendida por outro caminho, e é a mudança mais profunda.**

A 015 pedia que criar, juntar, limpar e recuperar worktrees fossem **comandos
determinísticos**, porque em prosa "o isolamento depende de o roteiro ser
lembrado corretamente". A premissa estava certa para o runtime de 2026-08-16.

Hoje o Claude Code oferece `isolation: "worktree"` por subagente: criação,
isolamento e limpeza são da plataforma, e o `orq-run.md` já os usa. Um
`run-worktree.sh` reimplementaria em shell o que o runtime entrega pronto — que
é exatamente o diagnóstico do ADR-0018 sobre a camada de orquestração.

| cenário da 015 | como fica |
|---|---|
| 1. worktree isolado, nomeado pela unidade, sem tocar a árvore principal | `Agent(name: "dev-us1-...", isolation: "worktree")` |
| 2. merges sequenciais, um commit por unidade, sem push | Step 3 § Join, preservado |
| 3. conflito aborta, nomeia arquivos, sinaliza `[P]` errado | preservado literalmente: "Conflito de merge → PARE" |
| 4. recuperação distingue trabalho não mesclado de vazio | US2: worktree com trabalho não mesclado = merge pendente |
| 5. cleanup idempotente | do runtime — o worktree é removido se não houver mudança |

**Risco declarado:** onde o runtime **não** oferecer isolamento, não há
equivalente. É por isso que a US4 abaixo passou a exigir a declaração do modo
efetivo — a degradação fica visível para quem consente, em vez de silenciosa.

---

## US4 — Paralelismo declarado, não presumido (P2)

**Atendida, e reforçada.** O preflight ganhou a linha `Isolamento:` e o plano
ganhou `execution.mode_effective`.

| o que o runtime oferece | linha do preflight |
|---|---|
| isolamento por subagente | `**real** (worktree por worker)` |
| sem isolamento, sem git | `**sequencial** (este runtime não isola)` |

O texto preserva a razão do ADR-0019: o preflight já era honesto sobre a força
da *verificação*; agora é sobre a da *execução*.

---

## US5 — Falha tem dono (P2)

**Atendida.** Era a única sem nenhuma cobertura na 016 antes desta conferência —
o Step 5 mandava repetir "só com as unidades que falharam" sem dizer como
descobri-las, exatamente a lacuna que a 015 apontou.

Step 5 ganhou "Falha tem dono": atribuição por interseção com os `files`
declarados de cada unidade no `execution-plan.yaml`.

| cenário da 015 | como fica |
|---|---|
| 1. teste quebrado → unidade que declara o arquivo | tabela de atribuição |
| 2. finding com caminhos → interseção com `files` | tabela de atribuição |
| 3. falha não atribuível → registrada e vira parada | "não se distribui por aproximação"; para e devolve |
| 4. unidade no teto sai da onda; demais preservam contagem | explícito |

---

## Resumo

| US | prioridade | situação | mecanismo |
|---|---|---|---|
| US1 plano no disco | P1 | ✅ | agente escreve, sem gerador |
| US2 retomável | P1 | ✅ | front-matter do `run-log.md` |
| US3 worktree | P1 | ✅ | primitiva do runtime |
| US4 paralelismo declarado | P2 | ✅ | `mode_effective` + preflight |
| US5 falha tem dono | P2 | ✅ | interseção com `files` declarados |

**Nenhum requisito foi perdido.** Os 4.093 linhas de shell da 015 que não vieram
junto implementavam mecanismos que o runtime ou o agente já oferecem — não
exigências que deixaram de valer.

A US5 é a que justifica esta conferência ter sido uma task e não uma formalidade:
ela estava descoberta, e só apareceu ao ler os cenários um a um.
