# orq-run

Conduzir o arco de entrega de uma spec **sem supervisão**, do `tasks` até o gate
passar: implementar as unidades em paralelo, verificar, corrigir, repetir.

## Dependencies

```yaml
data:
  - output-contract.md # vocabulário de ids + formato de achado (obrigatório)
  - adaptive-work-contract.md
templates:
  - run-log-tmpl.md          # registro das decisões + estado da corrida
  - execution-plan-tmpl.yaml # o plano materializado no disco
scripts:
```

## Goal

Entregar a spec com o gate em `PASS`, e um relatório que permita reconstruir o
que foi decidido sem você ter assistido.

---

## Step 0 — Contrato de entrada. Recuse cedo, recuse claro.

Cheque, nesta ordem, e **pare na primeira falha** com a mensagem específica:

| Condição | Se falhar |
|---|---|
| estamos num branch de spec | "não há spec neste branch — o runner entrega uma spec, não trabalho solto" |
| `git status --porcelain` vazio | "working tree sujo. A corrida faz merge e commit; começar sujo mistura o seu trabalho com o dela" |
| `current_phase` ∈ {`tasks`, `implement`} | "a spec está em `<fase>`. O runner entra depois do `tasks` — antes disso falta o que executar" |
| `tasks.md` existe e tem itens | "sem `tasks.md`, não há unidades. Rode `/mosk-po tasks {spec-id}` antes" |

```bash
source .claude/mosk/scripts/common.sh
eval "$(get_feature_paths)"          # REPO_ROOT, CURRENT_BRANCH, FEATURE_DIR, TASKS…
read_spec_meta "$FEATURE_DIR" current_phase
```

**Consentimento não vem de config.** Se você não foi invocado explicitamente para
rodar autônomo, **não rode**. Nenhum valor de `core-config.yaml` liga este modo —
`runner.*` só diz *como* a corrida se comporta depois que você mandou.

---

## Step 1 — Descobrir as unidades de trabalho

A unidade é a **user story**, e ela não mora onde o nome sugere.

1. **`tasks.md` é a fonte do agrupamento.** As tarefas já vêm agrupadas por story
   no formato `[ID] [P?] [Story] Description` — ex.: `T004 [P] [US2] …`. Agrupe
   por `[US#]`.
2. **Os critérios vêm do `spec.md`**, na seção `### User Story N (Priority: Pn)`
   → `**Acceptance Scenarios**` (Given/When/Then), mais os `FR-###` / `SC-###`
   que a story cita.
3. **`stories/*.md` só quando existirem** — e resolva por **glob**, nunca por
   caminho montado: convivem três convenções de nome no toolkit
   (`{epic}.{story}.{título}.md`, `{epic}.{story}.story.md`,
   `epic-{n}-story-{m}.md`).

> Não procure só em `stories/`. Na maioria das specs essa pasta está vazia — o
> fluxo real põe as user stories dentro do `spec.md`. Um runner que exigisse
> arquivos de story não acharia trabalho nenhum e concluiria, errado, que não há
> o que fazer.

**A fase Foundational bloqueia tudo.** Se `tasks.md` tem uma fase marcada como
fundacional (`⚠️ CRITICAL: No user story work can begin until this phase is
complete`), ela roda **inteira, em série, antes da primeira onda**. Três workers
construindo sobre um alicerce inexistente é a forma mais cara de descobrir isso.

**`[P]` é honrado, nunca inferido.** Duas unidades só entram na mesma onda se o
`tasks.md` marcar `[P]`. Onde o marcador não está, é série. Não deduza
independência lendo o código: o custo é assimétrico — um par erradamente paralelo
escrevendo o mesmo arquivo corrompe trabalho que teria dado certo sozinho.

### Materialize o plano antes de pedir consentimento

Escreva `{spec_dir}/execution-plan.yaml` a partir de
`../templates/execution-plan-tmpl.yaml`: unidades, tasks de cada uma, arquivos
declarados, dependências, ondas, critérios de aceite, comandos de validação e
perfil adaptativo.

**Você escreve o plano — não existe gerador.** Ler `tasks.md` e `spec.md` e
decidir o que é unidade é leitura de conteúdo, e você tem parser (ADR-0021 §3).

O plano existe para ser conferido *antes* de a pessoa abrir mão de ser
consultada, e para que a corrida seja retomável: sem um plano no disco, não há a
que anexar tentativa, falha ou retomada. Se `tasks.md` não tiver nenhum
marcador `[US#]`, **falhe com mensagem específica e não escreva plano parcial** —
um plano pela metade é pior que nenhum, porque parece completo.

### Perfil adaptativo de cada unidade

Para cada unidade, selecione sinais observáveis e aplique
`.claude/mosk/data/adaptive-work-contract.md`. Registre no `run-log.md` uma
justificativa curta, o `context_budget`, o `validation_floor` e os
`specialists` resultantes. O perfil é piso de contexto e validação; não cria
fase, estado, worktree ou checkpoint.

- O worker começa pelo budget retornado e expande apenas pelos gatilhos do
  contrato.
- O QA independente continua obrigatório em toda onda; security também entra
  quando constar em `specialists` ou quando a revisão for pedida explicitamente.
- `human_pause: true` faz a corrida parar antes da ação quando houver dúvida
  material ou irreversibilidade. Perfil crítico nunca autoriza ultrapassar a
  lista fechada do Step 6.
- Reclassifique antes dos oráculos quando implementação, referência direta ou
  falha de teste revelar escopo maior, evidência mais fraca ou superfície mais
  sensível. Mantenha o resultado mais rigoroso e registre o gatilho.

---

## Step 2 — Preflight. O único momento em que você pergunta.

Imprima e **espere um `ok`**:

```markdown
**Corrida autônoma — spec {spec-id}**

Unidades detectadas: 5
- Fundacional (série, primeiro): T001–T003
- Onda 1 (paralelo): US-1 · US-2 · US-3
- Onda 2 (série, depende da 1): US-4, US-5

Como vou verificar:
- Testes: `npm test`  ← o oráculo mecânico
- Gate: `/mosk-qa` em contexto limpo, a cada onda

Perfis mínimos:
- US-1: `<perfil>` · contexto `<budget>` · validação `<piso>` · especialistas `<lista>`

Isolamento: **real** (worktree por worker) · paralelismo efetivo
Limites: 3 voltas por unidade · 3 worktrees simultâneos

Faço sozinho: implementar, rodar teste, corrigir, commitar por unidade.
Paro e devolvo: dúvida sobre critério, lacuna de decisão, conflito de merge,
teto de voltas, e **qualquer coisa irreversível** — migration, deploy, push,
apagar dado, dispensar gate.
```

**Declare o mecanismo de paralelismo, nunca o presuma.** A linha `Isolamento:`
diz o que este runtime de fato oferece, e é escrita em `execution.mode_effective`
no plano:

| o que o runtime oferece | linha do preflight | comportamento |
|---|---|---|
| isolamento por subagente | `**real** (worktree por worker)` | ondas em paralelo, worktrees isolados |
| sem isolamento, sem git | `**sequencial** (este runtime não isola)` | uma unidade por vez, sem worktree |

O ADR-0019 exigiu que o preflight fosse honesto sobre a força da *verificação*.
A mesma honestidade vale para a *execução*: paralelismo declarativo apresentado
como real é a diferença entre trabalho isolado e dois agentes escrevendo o mesmo
arquivo. Quando cair para sequencial, diga — a pessoa está consentindo com o que
vai acontecer, não com o que seria ideal.

**Sem suíte de testes, diga isso em letras claras**, no lugar da linha de testes:

> ⚠️ **Não há comando de teste configurado** (`runner.test_command` vazio). A
> única verificação será o julgamento do gate — é uma garantia mais fraca do que
> um teste que passa ou falha. Considere configurar antes de rodar desacompanhado.

Esse é o momento do consentimento. Depois dele: silêncio até a dúvida ou o fim.

---

## Step 3 — A onda

Para cada onda, um subagente `mosk-dev` por unidade, **em paralelo**, cada um em
worktree isolado. Batize cada worker pela unidade que ele carrega:

```
Agent(subagent_type: "mosk-dev", name: "dev-us1-fechamento",
      isolation: "worktree", prompt: <briefing da unidade>)
```

O nome é o que torna a onda legível enquanto roda — é a resposta ao "trabalho
fica invisível". Respeite `runner.max_parallel`.

**O briefing de cada worker** carrega: o `spec_dir`, as tarefas `[US#]` dele, os
Acceptance Scenarios da story, e a instrução de **ler e escrever no disco e
devolver só um status curto**. Nunca um transcript — o disco é a fronteira de
estado, e é isso que mantém o seu contexto utilizável até o fim da corrida.

### Join

Merge sequencial dos worktrees na branch da spec, na ordem em que terminaram.

**Conflito de merge → PARE.** Não resolva. Um conflito significa que duas
unidades tocaram o mesmo arquivo, o que significa que o `[P]` estava errado — e
isso é informação sobre o *planejamento*, não um obstáculo a contornar. Devolva
com os arquivos em conflito nomeados.

Depois do merge, **um commit por unidade**, descrevendo o que ela entregou.
Nada de push.

---

## Step 4 — Os dois oráculos, em série

1. **Mecânico e binário** — rode `runner.test_command`. Exit code, não opinião.
   Falhou? A unidade responsável volta na próxima onda.
2. **Crítico e independente** — `mosk-qa` num subagente de contexto limpo,
   verificando os Acceptance Scenarios de todas as unidades da onda contra o
   resultado entregue. Ele emite o `gate.yaml`.

Rode **`mosk-security`** em paralelo ao QA quando o diff acumulado tocar
superfície sensível (auth/authz, entrada de usuário, queries, segredos,
endpoints, desserialização, cripto, path). O verdicto `SECURITY:` alimenta o gate.
O especialista também é obrigatório quando o perfil adaptativo o listar, mesmo
que a superfície só tenha ficado evidente depois da implementação. Ausência de
evidência exigida pelo `validation_floor` volta como falha; nunca é convertida
em confiança implícita pelo runner.

> **Você nunca decide se o loop continua** — só *como* corrigir. Quem decide é o
> veredito. Um runner que julga o próprio trabalho não é um runner, é uma opinião
> em looping.

---

## Step 5 — A volta

Leia o `gate.yaml`: `gate`, `quality_score`, `score_history`, `top_issues`.

- **`PASS` / `WAIVED`** → a corrida acabou. Vá para o Step 7.
- **`CONCERNS` / `FAIL`** → nova onda, **só com as unidades que falharam**, via
  `apply-qa-fixes`. Incremente a volta daquelas unidades.

### Falha tem dono

"Só com as unidades que falharam" exige saber quais foram. Atribua por
**interseção com os arquivos declarados** de cada unidade no
`execution-plan.yaml`:

| origem da falha | como atribuir |
|---|---|
| teste quebrado | arquivo do teste ou do código sob teste → unidade que o declara em `files` |
| finding de QA/security com caminho | interseção dos caminhos citados com os `files` das unidades |
| finding sem caminho, ou caminho de nenhuma unidade | **não atribuível** |

**Não atribuível não se distribui por aproximação.** Registre no `run-log.md`
como não atribuível e **pare**, devolvendo com a pergunta formulada. Repartir uma
falha por palpite entre unidades produz duas correções erradas em vez de uma
pergunta certa, e consome volta de quem não falhou.

Uma unidade que atinge o teto sai da onda seguinte e a corrida para. As demais
**preservam suas contagens** — o teto é por unidade, e cobrar de quem não gastou
é o mesmo erro de atribuição, na direção oposta.

**Pare quando o score parar.** Se `score_history` mostra dois valores iguais
seguidos com o gate reprovando, mais uma volta não resolve: o problema está acima
da execução — design, PRD ou story ambígua. Devolva dizendo isso. Insistir aqui é
o erro que a série de score existe para evitar.

**Pare no teto.** `resolve_max_attempts` voltas por unidade. Estourou, para
aquela unidade — registre e devolva.

---

## Step 6 — Onde parar (a lista fechada)

### Dúvida — devolva com a pergunta formulada e o estado preservado

- critério de aceite ambíguo, ou que não dá para verificar objetivamente;
- decisão que `plan.md` / `docs/architecture/` não cobrem (lacuna de ADR);
- contradição entre a story e o PRD;
- **lacuna de regra de negócio** — você **não inventa regra**. Registra e devolve;
- teto de voltas atingido, ou score parado entre voltas;
- conflito de merge no join;
- a suíte não roda, o ambiente está quebrado;
- invocação falha repetida (worker morre, volta vazio).

### Irreversível — pare **antes**, mesmo sem dúvida nenhuma

migration ou mudança de schema · deploy, publish, release · apagar ou reescrever
dado · tocar arquivo fora do escopo da spec · qualquer git além do commit local
(push, force, rebase, tag) · credencial ou segredo · **dispensar um gate**.

> "Parar antes" é literal: se a tarefa **pede** uma migration, você para ao ler a
> tarefa, não depois de rodá-la.

### Como parar

Registre no `run-log.md`, emita o bloco de escalação
(`../templates/escalation-block-tmpl.md`) com a pergunta concreta, e **deixe o
disco consistente**: merge feito ou desfeito, nunca no meio; `current_phase`
refletindo onde a spec está de verdade.

---

## Step 7 — Fechar

1. Confirme a transição para `qa-gate` com o comando `qa-gate`, seguindo `../data/phase-transition-contract.md`
2. Execute `../tasks/index-docs.md`.
3. **Relatório final** — a única coisa que a pessoa vai ler:

```markdown
**Corrida concluída — spec {spec-id} · gate PASS · score 92**

5 unidades, 2 ondas, 7 commits. Série do score: 61 → 92.

Decisões que tomei sozinho (3) — detalhe em `run-log.md`:
- US-1: transação única em vez de duas etapas — `plan.md` §4 previa as duas e não
  escolhia; peguei a reversível.
- …

O que não fiz: o `archive`. Ele promove artefatos e fecha a spec — é seu.
Próximo passo: `/mosk-dev archive {spec-id}`.
```

Siga o contrato de saída (`../data/output-contract.md`): id citado carrega a
glossa, achado é bloco. Vale mais aqui do que em qualquer outro lugar — este
relatório é o substituto de você ter assistido.

**Não rode o `archive`.** Ele promove artefatos para a base e fecha a spec: é
decisão de rota, e rota continua sendo do humano.

---

## Registro e retomada

O estado da corrida vive em **dois lugares, e nenhum deles é um `run-state.yaml`**:

- **`execution-plan.yaml`** — o plano. Escrito uma vez, não muda durante a corrida.
- **`run-log.md`** — o andamento. O corpo é append-only (uma linha por decisão);
  o **front-matter** carrega o estado corrente:

```yaml
---
run_status: running        # running | paused | done
current_wave: 2
units_merged: ["US-1", "US-3"]
units_pending: ["US-2", "US-4"]
attempts: { US-2: 2 }
last_updated: "2026-08-20T19:41:07Z"
---
```

**Atualize o front-matter depois de cada merge**, antes de começar a unidade
seguinte. É o que torna a corrida retomável em vez de recomeçável: ao reabrir,
leia `units_merged` e não reimplemente nada que já está lá. Um commit duplicado
é o custo de confiar na memória do condutor em vez do disco.

Ao retomar: se uma unidade estiver em `units_pending` mas o worktree dela existir
com trabalho não mesclado, o merge é **pendente** — aplique uma vez e registre.
A contagem de `attempts` continua de onde parou; ela não reinicia.

Toda decisão autônoma vira linha:

```bash
source .claude/mosk/scripts/common.sh
append_run_log "$FEATURE_DIR" "1" "US-1" "dev-us1-fechamento" \
  "seguiu com transação única" "plan.md §4 previa as duas formas e não escolhia"
```

Ruído (output de teste, transcript de worker) vai para
`$FEATURE_DIR/run-noise.log`, que é efêmero — acrescente ao `.gitignore` do
projeto se ainda não estiver lá.

## Rules

- **Preâmbulo nunca é invocado.** `analyst`, `pm`, `architect`, `ux-expert`,
  `ui-expert` — lacuna de ADR, PRD ou fluxo é sinal de rota, e aqui rota **vira
  parada**, não vira chamada.
- **`[P]` é honrado, nunca inferido.**
- **Quem implementa não julga critério de aceite.** O `[x]` do worker é alegação;
  a prova é o gate, em contexto limpo.
- **Não edite o `gate.yaml`** — quem escreve é o QA.
- **Nunca crie branch.**
- **Profundidade 1**: os workers que você abre não abrem outros.
- **Um projeto por corrida.**
