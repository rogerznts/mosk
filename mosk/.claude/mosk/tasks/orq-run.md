# orq-run

Conduzir o arco de entrega de uma spec **sem supervisão**, do `tasks` até o gate
passar: implementar as unidades em paralelo, verificar, corrigir, repetir.

## Dependencies

```yaml
data:
  - output-contract.md # vocabulário de ids + formato de achado (obrigatório)
templates:
  - run-log-tmpl.md    # o registro das decisões autônomas
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

Limites: 3 voltas por unidade · 3 worktrees simultâneos

Faço sozinho: implementar, rodar teste, corrigir, commitar por unidade.
Paro e devolvo: dúvida sobre critério, lacuna de decisão, conflito de merge,
teto de voltas, e **qualquer coisa irreversível** — migration, deploy, push,
apagar dado, dispensar gate.
```

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

> **Você nunca decide se o loop continua** — só *como* corrigir. Quem decide é o
> veredito. Um runner que julga o próprio trabalho não é um runner, é uma opinião
> em looping.

---

## Step 5 — A volta

Leia o `gate.yaml`: `gate`, `quality_score`, `score_history`, `top_issues`.

- **`PASS` / `WAIVED`** → a corrida acabou. Vá para o Step 7.
- **`CONCERNS` / `FAIL`** → nova onda, **só com as unidades que falharam**, via
  `apply-qa-fixes`. Incremente a volta daquelas unidades.

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

1. `bash .claude/mosk/scripts/transition-spec-phase.sh --spec "$(basename "$FEATURE_DIR")" --to qa-gate --command qa-gate`
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

## Registro

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
