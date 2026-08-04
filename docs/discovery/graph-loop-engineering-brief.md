# Brief — Graph & Loop Engineering + consolidação no Orca

- Autor: Maria (`mosk-analyst`)
- Data: 2026-08-04
- Origens:
  - vídeo "Como os Maiores Especialistas em IA do Mundo Estão Usando o Claude"
    (Maestros da IA, 04/08/2026, 26min) — transcrição fornecida pelo usuário;
  - skill `orchestration` do Orca — **guia real lido do binário**
    (`orca skills get orchestration`, ~35KB), não do `SKILL.md` público.
- Pedido: (1) operar com grafos/loop, com foco no desenvolvimento; (2) remover
  o Herdr e manter só o Orca; (3) plugar o MOSK na orquestração do Orca.

---

## 1. O que o vídeo defende

Três camadas, apresentadas como evolução lógica:

| Camada | Ideia central |
|---|---|
| **Harness engineering** | A teia de instruções em volta do modelo é o que dá autonomia confiável. Quebrar em skills > pipeline monolítico: controle por etapa + economia de tokens. |
| **Loop engineering** | Depois de executar, **verificar** e iterar até um critério (nota 0–100, corte ≥85). Tese forte: **quem executou não pode avaliar** — o autor justifica o resultado pelo contexto das decisões que tomou (analogia do editor-chefe, que só vê o resultado). |
| **Graph engineering** | Fan-out paralelo de unidades independentes, **um agente por parte do pipeline**, **contexto não-compartilhado**, cada ramo com seu verificador, **join** no fim. |

A frase que ordena a rota: **o loop foi o que tornou o paralelismo seguro.** Sem
verificador confiável, disparar N ramos é só queimar tokens.

---

## 2. Onde o MOSK está hoje

**O MOSK já tem grafo e já tem loop** — na granularidade errada e no regime
errado para o que o vídeo descreve.

### Já implementado

- **Grafo explícito e derivado** — `pipeline-graph.yaml` como fonte única; o
  mermaid e as jogadas (`legal_moves.sh`) derivam dele (ADR-0006/0007).
- **Loop contado e limitado** — `qa-gate → implement` com `tentativa N/max`,
  contador derivado do `phase-history.log`, teto `max_retries: 3` (ADR-0008).
- **Vocabulário de isolamento** — o grafo distingue `mode: skill` (contexto
  compartilhado) de `mode: agent` (isolado).
- **Isolamento estrutural funcionando** — o seam `invoke_phase_agent` do
  `bench-mode`, Tier 1 = subagente nativo, com a regra certa: *lê/escreve no
  disco e devolve só um status curto*. O disco é a fronteira de estado.
- **Loop automático funcionando** — `build-loop`, `MAX_FIX_ATTEMPTS=3`.
- **Atuador multi-pane** — `panes.sh` / `orca.sh` já spawnam N terminais.

### Lacunas (graph/loop)

**L1 — `implement` é sequencial e single-context.**
`implement.md` §4: *"Execute the plan in order"*. O `tasks.md` **já marca `[P]`**
para tarefas que não se bloqueiam e nenhum script lê esse marcador. **A
topologia de paralelismo já é produzida e descartada.** Gap mais barato, maior
payoff.

**L2 — O verificador compartilha contexto com quem implementou.**
`qa-gate` é `mode: skill` no grafo; pior, `implement.md` §5 manda o próprio dev
conferir os ACs do que acabou de escrever. É o anti-padrão do vídeo, literal.
`security-review` é o único nó `mode: agent` — a distinção existe, mas não foi
aplicada onde mais importa.

**L3 — O loop conta voltas, mas não mede progresso.**
PASS/CONCERNS/FAIL é degrau grosso: três FAILs parecem idênticos com ou sem
progresso. Sem escalar, a decisão no teto (`escalar`/`waive`/`parar`) é cega.

**L4 — Não há fan-out/join no vocabulário do grafo.**
Existe `parallel_with: ui/ux` em dois nós e **nada lê esse campo**.

**L5 — Dois mecanismos de loop que não se falam.**
Delivery-loop (técnico, consultivo, por-spec) × build-loop (bench, automático,
por-tarefa). ADR-0008 §5 registrou a unificação como fora de escopo — de
propósito. Este é o momento de reabrir.

**L6 — O paralelismo do `/mosk-orq` é entre fases, não dentro delas.**
O Mauro passa o bastão de pane em pane. É handoff, não fan-out.

---

## 3. Remoção do Herdr

### Superfície real

| Camada | Arquivos | Ação |
|---|---|---|
| Driver | `mosk/.claude/mosk/scripts/herdr.sh` (302 linhas) | remover |
| Fachada | `panes.sh` (22 menções) | simplificar (ver decisão abaixo) |
| Config | `core-config.yaml`: `driver: auto\|herdr\|orca\|none` + bloco `herdr:` | reduzir a `auto\|orca\|none` |
| Prompt | `agents/orq.md` (9), `skills/mosk-orq/SKILL.md` (1) | reescrever |
| Lib | `common.sh` (2) | limpar |
| Docs | `README.md`, `TASKS.md`, `docs/index.md`, `.claude/rules/scripts.md` | atualizar |
| Espelho local | mesmos arquivos sob a raiz `.claude/` | ressincronizar |

### Dois pontos que **não** devem ser apagados

1. **ADR-0009 (`herdr-orchestration`) é registro histórico aceito.** ADR não se
   deleta — se marca `superseded by`. O mesmo vale para a **decisão 7 do
   ADR-0010** ("Herdr permanece cidadão de primeira classe"), que está sendo
   explicitamente revertida. Isso pede um ADR de supersessão, não uma edição
   silenciosa.
2. **Specs arquivadas (006, 007, 009) são congeladas por design.** Não tocar.

### Decisão a tomar: a fachada sobrevive?

**Recomendo manter `panes.sh`**, mesmo com um único backend. Razões: é onde vive
a degradação `none` (MOSK precisa rodar sem Orca); o `orq.md` fala só com ela; e
o ADR-0010 provou empiricamente que ela barateia a troca de backend. O que sai é
o custo do *dual*: sondagem de dois backends, desempate por variável de sessão,
e o `unsupported`/exit 3 (com um só backend, todo subcomando é suportado).

---

## 4. Plugar no Orca orchestration — gap analysis

O guia real é servido **pelo binário**, não pelo repositório: o `SKILL.md`
público é um stub que diz para carregar a versão viva com `orca skills get
orchestration`, explicitamente *"to prevent version drift"*. Isso é a primeira
lição de arquitetura, e vale mais que qualquer comando isolado: **o MOSK não
pode memorizar a grammar do Orca no prompt.** A spec 009 existiu justamente
porque parsing acoplado a formato de saída quebrou.

Modelo do Orca: **Run** (namespace + inbox do coordenador) → **Task** (item de
trabalho, com `--deps` formando DAG) → **Dispatch** (uma tentativa de uma Task
num terminal). Autoridade de lifecycle vive no Dispatch.

### O que o `orca.sh` já faz

Camada nativa opt-in com 7 subcomandos: `native`, `task-create`, `task-list`,
`dispatch`, `await`, `gate-create`, `gate-resolve`. O desenho está certo e a
invariante do ADR-0006 está honrada — o `orchestration run` (coordinator loop
autônomo) é recusado por escrito.

### Gaps contra o contrato atual

**G1 — Task criada sem Run vinculada.** O guia é taxativo: *"the coordinator
must create or bind a Run, create the Task with `task-create`, then attach the
worker"*. O `cmd_task_create` chama direto, sem `run-create`/`run-use`. Sem Run
ligada, a caixa do coordenador não é a certa.

**G2 — `await` não faz `ack` da Delivery.** O `check` devolve *"the oldest FIFO
Delivery e repete exatamente aquele lote até `--ack <delivery_id>`"*. O
`cmd_await` chama `check --wait` e nunca faz ack. **A próxima janela reprocessa
o mesmo lote** — bug latente, não hipotético.

**G3 — `await` não escuta `question`.** Os tipos são
`worker_done,escalation,decision_gate`. Quando um worker usa `ask` (pergunta
bloqueante), gera mensagem tipo `question` — que **não acorda o Mauro**. O worker
fica pendurado até o timeout.

**G4 — `worker-start` não é usado.** O guia chama de *"the preferred supervised
path"*: compõe worktree + terminal + readiness + dispatch e devolve um recibo com
os efeitos exatos. O MOSK usa `spawn` próprio + `dispatch --inject`, que o guia
reserva para topologia que a composição não expressa.

**G5 — `worker-read` não é usado.** O MOSK lê terminal cru — a exata superfície
que quebrou na spec 009. `worker-read --dispatch` devolve transcript tipado com
cursor e `fallbackReason`.

**G6 — `ask`/`reply` ausentes do wrapper.** É o mecanismo estruturado de
pergunta bloqueante worker→coordenador. **É o par natural dos guards `judgment` e
do bloco "Escalation suggested"** — hoje ambos trafegam como texto solto num
pane, que o humano precisa ler e interpretar.

**G7 — `--deps` aceito, nunca preenchido.** O wrapper já expõe a flag. Ninguém
converte o `[P]` do `tasks.md` em DAG. **É a ponte entre L1 e o Orca, e ela está
a poucos metros de estar pronta.**

### Convergências que valem registrar

- **Circuit breaker do Orca = 3 falhas consecutivas → task `failed`.** Idêntico
  ao `max_retries: 3` do ADR-0008. Os dois tetos precisam ser conciliados
  conscientemente, não coexistir por acaso.
- **Ondas paralelas via `task-list --ready`** e a orientação de *não encadear
  dependências além de 3–4 níveis* — é graph engineering pronto, com a
  granularidade que o `tasks.md` já produz.
- **`gate-create` / `gate-resolve`** já batem com o ADR-0006: o orquestrador cria
  o gate, o humano resolve.

### Risco de vocabulário — sério

O guia do Orca classifica **"handoff" / "hand off" / "handover" como
transferência de posse**, e é explícito: nesses casos **não** usar orchestration,
**não** criar task, **não** esperar `worker_done`. O MOSK tem uma skill chamada
`/mosk-handoff` que faz o **oposto**: transporte de contexto *sob supervisão* do
Mauro. Um agente lendo os dois contratos desliga a supervisão exatamente quando
ela deveria continuar. Precisa de desambiguação explícita no `orq.md` — e vale
considerar renomear o conceito interno.

### Fronteira de ferramenta

O guia proíbe substituir orchestration por subagent tools genéricos quando a
tarefa pede Orca: *eles criam workers úteis, mas não criam provenance de
task/dispatch, preâmbulo de lifecycle, autoridade de `worker_done` nem decision
gates*. Isso **decide a arquitetura do fan-out**: não é "subagente OU Orca", é um
seam com tiers — e o MOSK já tem o padrão pronto (`invoke_phase_agent`).

---

## 5. As duas decisões que precedem qualquer código

**D1 — Consultivo × paralelo.** O ADR-0006 diz "nada auto-executa; o humano
decide cada aresta". Fan-out de 8 ramos × 3 voltas = dezenas de decisões — lido
ao pé da letra, o invariante **proíbe** graph engineering. A saída não é revogá-lo,
é separar o que ele mistura: **decisão de rota** (que aresta tomar, escalar,
aceitar o gate) permanece humana **sempre**; **execução de trabalho já decidido
dentro de uma fase** é mecânica. O humano aprova **o plano de fan-out uma vez**;
o join volta para ele. Uma aprovação por fan-out, não por ramo.

**D2 — Acoplamento ao Orca.** O MOSK precisa continuar rodando em Claude Code
puro, Codex e sem atuador nenhum. Então o fan-out não pode assumir Orca. Resposta
— o mesmo padrão que o bench já validou, agora com três tiers:

| Tier | Mecanismo | Ganha |
|---|---|---|
| 1 | Orca orchestration (Run → Task DAG → worker-start → check --wait) | provenance, gates, `worker_done`, `ask`/`reply` |
| 2 | Subagente nativo do runtime | isolamento de contexto |
| 3 | Sequencial | funciona em qualquer lugar |

Resultado observável idêntico nos três; muda só quanta estrutura se ganha.

> **Decidido em 2026-08-04** — este brief é discovery datado; as decisões vivem
> nos ADRs [0012](../architecture/adr/adr-0012-route-decision-vs-phase-execution.md),
> [0013](../architecture/adr/adr-0013-fanout-seam-three-tiers.md) e
> [0014](../architecture/adr/adr-0014-orca-single-actuator.md), que prevalecem
> sobre o que está escrito aqui. Duas precisões relevantes: o **Orca é opcional**
> — o pipeline não depende de atuador, e só o Tier 1 o usa; e o Tier 1 exige
> **sessão dentro da IDE do Orca**, não apenas o binário instalado.

---

## 6. Rota recomendada

Quatro specs. A ordem não é arbitrária: **A antes de C** porque o vídeo é
explícito que o verificador confiável é pré-condição do paralelismo.

### Spec A — Verificador independente + score no gate

- Tirar a auto-verificação de ACs do `implement.md` §5 e movê-la para um
  verificador de **contexto limpo**, via `invoke_phase_agent`.
- Promover `qa-gate` de `mode: skill` para `mode: agent` — o campo já existe,
  hoje só não é honrado.
- `score` 0–100 ao lado do `status` no `gate.yaml`, corte configurável (default
  85). **O status segue árbitro único de terminação** (ADR-0008 §3, intocado); o
  score serve para ver a trajetória e detectar estagnação.

### Spec B — Consolidação no Orca (remover Herdr + fechar G1–G7)

Independente de A; pode correr em paralelo.

- ADR de supersessão do ADR-0009 e da decisão 7 do ADR-0010.
- Remover `herdr.sh`; simplificar `panes.sh` mantendo a fachada e a degradação
  `none`.
- Fechar os gaps por severidade: **G2 (ack) e G3 (`question`) primeiro** — são
  defeitos de comportamento, não melhorias. Depois G1 (Run), G6 (`ask`/`reply`),
  G4 (`worker-start`), G5 (`worker-read`).
- **Regra de acoplamento:** o `orca.sh` fica fino e o `orq.md` **consulta o guia
  versionado** em vez de memorizar a grammar. Conciliar o circuit breaker de 3
  do Orca com o `max_retries` do MOSK, explicitamente.
- Desambiguar "handoff" (Orca = transferir posse; MOSK = transportar contexto sob
  supervisão).
- Estender `selftest-orca-driver.sh` para cobrir os caminhos novos — é o único
  verificador automatizável do repo e a lição da spec 009.

### Spec C — Fan-out no `implement` *(o coração do pedido)*

Depende de A e B.

- Tornar o `[P]` **executável**: converter o `tasks.md` num DAG (Tier 1:
  `task-create --deps`; Tiers 2/3: lotes internos), despachar ondas via
  `task-list --ready`.
- Cada ramo carrega seu mini-loop de verificação (Spec A) antes de reportar.
- **Join explícito**: `implement` só fecha quando todo Dispatch assentar.
- Um único ponto de aprovação humana: o **plano de fan-out**, antes de disparar.
- Guards `judgment` que surgirem dentro de um ramo viram `ask` → o Mauro
  apresenta ao humano → `reply`.

### Spec D — Consolidação do grafo

- Formalizar `fan-out` / `join` no `pipeline-graph.yaml`, dando semântica ao
  `parallel_with` hoje decorativo; estender `legal_moves.sh`.
- Reabrir a unificação dos dois loops (L5) sobre o seam `invoke_phase_agent`,
  parametrizado por audiência — o pendente declarado do ADR-0008 §5.

### Fora de escopo

Reimplementar o que o runtime já dá (`/workflows`, `ultracode`, coordinator loop
do Orca). O MOSK **aciona** o runtime; não compete com ele.

---

## 7. Riscos

| Risco | Mitigação |
|---|---|
| Fan-out vira auto-execução e corrói o ADR-0006 | D1 num ADR; uma aprovação por fan-out; join sempre volta ao humano |
| Acoplar o MOSK à grammar do Orca e repetir a spec 009 | `orca.sh` fino + consultar `orca skills get orchestration` versionado; selftest cobrindo os caminhos novos |
| "handoff" desligar a supervisão por colisão de vocabulário | Desambiguação explícita no `orq.md`; considerar renomear o conceito interno |
| Ramos paralelos em conflito de escrita | Honrar `[P]` estritamente (*"different files, no dependencies"*); em dúvida, sequencial |
| Dois tetos de retry (Orca 3 × MOSK `max_retries`) divergirem | Conciliar explicitamente na Spec B |
| Remover o Herdr quebrar instalação existente | ADR de supersessão + nota de migração; `driver: herdr` deve falhar com mensagem clara, não silenciosamente |
| Score no gate virar teatro de número | Score é observação, nunca gatilho de terminação |

---

## 8. Próximo passo

Duas decisões arquiteturais (seção 5) precedem a escrita de qualquer spec, e uma
supersessão de ADR precede a remoção do Herdr.

**Recomendado:** `/mosk-architect` — três ADRs:
1. fronteira entre *decisão de rota* (consultiva) e *execução de fase*
   (paralelizável), com o regime de aprovação do fan-out;
2. seam de fan-out em três tiers (Orca / subagente / sequencial);
3. supersessão do ADR-0009 e da decisão 7 do ADR-0010 (Orca como atuador único).

**Em seguida:** `/mosk-po specify` para a **Spec B** (consolidação no Orca) e a
**Spec A** (verificador independente) — independentes entre si.

**Higiene antes de começar:** a spec `004-feature-orchestration-graph` está
`active` em `current_phase: implement`, e o `adr-0007` ainda não foi promovido
para `docs/architecture/adr/`. Como B e D mexem no mesmo `pipeline-graph.yaml`,
convém fechar a 004 primeiro.
