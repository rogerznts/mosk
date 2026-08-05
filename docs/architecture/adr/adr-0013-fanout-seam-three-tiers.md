# ADR-0013 — Seam de fan-out em três tiers (Orca · subagente · sequencial)

- Status: aceito
- Data: 2026-08-04
- Autor: Vinicius (mosk-architect)
- Contexto: brief `docs/discovery/graph-loop-engineering-brief.md` §5 (D2) — o fan-out não pode acoplar o pipeline ao Orca, e não pode nivelar por baixo.
- Origem: contrato real da skill `orchestration` do Orca, lido do binário (`orca skills get orchestration`), confrontado com o seam que o ADR-0004 já validou.
- Depende de: [adr-0004](./adr-0004-runtime-agnostic-phase-orchestration.md) (contrato de fases agnóstico de runtime + `invoke_phase_agent` — este ADR o estende para N unidades), [adr-0012](./adr-0012-route-decision-vs-phase-execution.md) (o que pode ser delegado), [adr-0008](./adr-0008-consultative-delivery-loop.md) (teto de tentativas), [adr-0010](./adr-0010-orca-backend.md) (fachada do atuador e camada nativa).

## Contexto

O ADR-0012 tornou o fan-out legítimo. Falta decidir **por onde ele passa**.

O MOSK roda em quatro ambientes que oferecem capacidades muito diferentes:
Claude Code (tem subagente isolado nativo), Codex (não tem), dentro do Orca (tem
uma camada de orquestração completa: Run, Task DAG, Dispatch, `worker_done`,
`ask`/`reply`, decision gates) e sem atuador algum. Acoplar o `implement` a
qualquer um desses quebra os outros três.

Este problema já foi resolvido uma vez. O ADR-0004 enfrentou exatamente a mesma
assimetria — isolamento nativo no Claude Code, ausente no Codex — e recusou as
duas saídas fáceis: nem acoplar ao runtime mais rico, nem nivelar por baixo. A
síntese foi um contrato agnóstico dirigido por disco, com **um único seam
runtime-específico** (`invoke_phase_agent`) e tiers de degradação. O padrão está
validado e em produção no `bench-mode`.

Duas restrições novas, que o ADR-0004 não conhecia:

1. **Fronteira de ferramenta do Orca.** O guia é explícito ao proibir substituir
   a orquestração por ferramentas genéricas de subagente quando a tarefa pede
   Orca: elas criam workers úteis, mas não criam provenance de task/dispatch,
   preâmbulo de lifecycle, autoridade de `worker_done` nem decision gates. Ou
   seja, "subagente OU Orca" não é uma escolha livre de consequências.
2. **Semântica de barreira.** `invoke_phase_agent` chama *uma* unidade e devolve
   *um* status. Fan-out precisa de N chamadas, um agrupamento com dependências e
   um join. Isso não cabe na assinatura existente.

## Decisão

**1. Um seam novo e irmão do ADR-0004: `dispatch_wave(plan) → results`.**
Recebe o plano de fan-out aprovado pelo humano (ADR-0012 §3), executa suas
unidades e devolve o consolidado do join. Não substitui `invoke_phase_agent` —
nos tiers 2 e 3 é **implementado sobre ele**, uma chamada por unidade. Manter
dois seams com semânticas limpas é a mesma escolha que o ADR-0006 §6 fez ao
separar `edges` de `escalations`: sobrecarregar uma assinatura só empurraria a
distinção "uma unidade × uma onda com barreira" para dentro de cada consumidor.

**2. Três tiers, do mais estruturado ao mais universal.**

| Tier | Mecanismo | O que ganha |
|---|---|---|
| 1 | **Orca orchestration** — Run → Task DAG (`--deps`) → `worker-start` → `check --wait`/`--ack` | provenance verificável, preâmbulo de lifecycle, `worker_done` com `--outcome`, `ask`/`reply` estruturado, decision gates |
| 2 | **Subagente nativo do runtime** (Claude Code `Agent`) | isolamento real de contexto e processo |
| 3 | **Sequencial na sessão**, com supressão de output e log em arquivo | funciona em qualquer lugar |

O Tier 3 é o Tier 2 do ADR-0004 reusado sem alteração: mesma disciplina, mesmo
redirecionamento de log verboso, mesmo disco como fronteira de estado.

**3. Seleção por capacidade detectada, não por preferência de prompt.**
A ordem de preferência é 1 → 2 → 3, resolvida em tempo de execução pela detecção
de capacidade — nunca por uma escolha escrita no prompt do agente. Override
explícito via configuração é permitido; adivinhação não. A degradação **nunca
falha**: cai um tier, avisa qual e por quê, e segue.

**O Tier 1 é a exceção, não a base.** Ele exige que a sessão corrente rode
**dentro da IDE do Orca** — não basta o binário estar instalado
([adr-0014](./adr-0014-orca-single-actuator.md) §3.1), porque as primitivas que
ele usa (`worker-start`, `terminal create`) materializam terminais dentro do
aplicativo. Fora dali, o Tier 1 simplesmente não se aplica.

Condições de degradação, todas silenciosas e sem erro:

| Situação | Tier |
|---|---|
| Dentro da IDE do Orca, orquestração habilitada | 1 |
| Dentro da IDE, orquestração experimental **desligada** | 2 |
| Orca instalado, sessão **fora** da IDE | 2 |
| Orca ausente, runtime com subagente nativo (Claude Code) | 2 |
| Sem subagente nativo (Codex e demais) | 3 |

**Fan-out não requer Orca.** Os Tiers 2 e 3 cobrem todo ambiente onde o MOSK
roda, com o mesmo resultado observável (decisão 5). O Orca acrescenta provenance,
`ask`/`reply` e gates — não a capacidade de paralelizar.

**4. Um único tier por onda — sem mistura.**
Todas as unidades de uma mesma onda correm no mesmo tier. Metade no Orca e
metade em subagente produziria provenance parcial — pior que nenhuma, porque
convida a afirmar que a onda foi orquestrada quando só parte dela foi — e daria
ao join duas semânticas distintas de conclusão (`worker_done` × retorno de
subagente). Se uma unidade não couber no tier escolhido, a onda inteira desce um
tier.

**5. Contrato invariante entre tiers.** Isto é o que **não** muda, e é o que
torna o resultado observável idêntico nos três:

- **o disco é a fronteira de estado** (herdado do ADR-0004 §1);
- **cada unidade devolve um status curto**, nunca um transcript — o barulho vai
  para arquivo;
- **o join só fecha quando toda unidade assentar** (concluída, falha ou
  suspensa); um timeout de espera é checkpoint, não falha;
- **`current_phase` não se ramifica** e o `phase-history.log` recebe uma entrada
  por onda (ADR-0012 §7);
- **os três sinais de suspensão** — guard `judgment`, escalação, esgotamento de
  teto — devolvem o ramo ao humano em qualquer tier. No Tier 1 isso trafega como
  `ask`/`escalation`; nos Tiers 2 e 3, como campo do status de retorno.

**6. Os dois contadores de retry são de coisas diferentes e não se unificam.**
O Orca tem circuit breaker próprio: após 3 falhas consecutivas numa task, o
contexto de dispatch é interrompido e a task é marcada `failed`. O MOSK tem
`max_retries: 3` (ADR-0008), que conta **voltas do gate por spec**. A coincidência
do número é acidental.

- O contador do Orca mede **falha de dispatch** — infraestrutura: o worker não
  chegou a produzir resultado.
- O contador do MOSK mede **não-convergência de qualidade** — produto: o
  resultado existe e não passou no gate.

Decisão: **não unificar, e não deixar o do Orca alimentar o do MOSK.** Uma task
que estoura o circuit breaker do Orca é reportada ao join como **unidade
falha**, e o humano decide (ADR-0012 §5) — isso **não** conta como volta do
delivery-loop. Conflacionar os dois faria uma instabilidade de terminal consumir
as tentativas de correção da spec.

**7. O plano de fan-out é derivado do `tasks.md`, não inventado.**
A fonte das unidades e do seu agrupamento são os marcadores `[P]` que o
`tasks.md` já produz — cujo contrato, no template, é *tarefas em arquivos
diferentes, sem dependências entre si*. Onde o `[P]` não afirma independência, a
unidade entra sequencialmente. No Tier 1 esse agrupamento vira `--deps` do DAG;
nos Tiers 2 e 3, lotes internos. Nenhum tier infere paralelismo por conta
própria: em caso de dúvida, sequencial.

## Alternativas consideradas

1. **Acoplar direto ao Orca, sem tiers.** Entregaria o melhor mecanismo
   rapidamente e quebraria Claude Code puro, Codex e instalações sem atuador —
   contra o ethos de um toolkit que roda onde o projeto já está. Rejeitada.
2. **Usar apenas subagente nativo e ignorar a camada do Orca.** Desperdiça DAG,
   gates e `ask`/`reply` já prontos e testados, e viola a fronteira de
   ferramenta do guia quando se está justamente dentro do Orca. Rejeitada.
3. **Estender `invoke_phase_agent` com um parâmetro `parallel: true`.** Menos
   superfície nova, mas esconde a barreira: o join e o plano de onda não cabem
   numa assinatura de "uma fase, um agente", e todo consumidor passaria a
   inspecionar o retorno para saber se houve barreira. Rejeitada — é a mesma
   armadilha que o ADR-0006 §6 recusou ao não unificar `edges` e `escalations`.
4. **Nivelar por baixo: tudo sequencial, para garantir paridade exata.** Já
   rejeitada pelo ADR-0004 §Alternativas 1–2 pelo mesmo motivo, e o motivo não
   mudou: abrir mão do isolamento que um runtime oferece de graça não é paridade,
   é perda.
5. **Deixar o agente escolher o tier no prompt.** Rejeitada: reintroduz a
   dependência de julgamento onde existe detecção mecânica, e produz
   comportamento não-reproduzível entre sessões.
6. **Unificar os dois contadores de retry num só.** Rejeitada — decisão 6.

## Consequências

**Positivas:**

- Um só `implement`, com um só contrato de fan-out; o único galho é o seam,
  exatamente como no ADR-0004.
- Cada ambiente usa o melhor isolamento que tem, sem que o mais pobre limite o
  mais rico.
- Dentro do Orca, o fan-out ganha provenance verificável — dá para **provar** que
  houve orquestração (`task-list`, `dispatch-show`) em vez de afirmar.
- Os guards `judgment` do ADR-0006 e os blocos "Escalation suggested" ganham, no
  Tier 1, um canal estruturado (`ask`/`reply`) em vez de texto solto num
  terminal.

**Negativas / trade-offs:**

- Três caminhos de execução para manter em equivalência observável. Mitigado por
  o contrato invariante (decisão 5) ser pequeno e fechado, e por só o Tier 1
  depender de superfície externa.
- No Tier 3 o "paralelismo" é apenas organizacional — as unidades correm em
  sequência. O ganho ali é a verificação isolada, não a velocidade. Isso precisa
  ser dito ao usuário no plano de fan-out, não escondido.
- A regra de tier único por onda (decisão 4) pode forçar uma onda inteira a
  descer de tier por causa de uma única unidade. É o preço de um join com
  semântica única.

**Risco residual:**

- O Tier 1 depende de uma superfície externa em evolução. Mitigação em
  [adr-0014](./adr-0014-orca-single-actuator.md) §6: o wrapper permanece fino e
  a grammar é consultada na versão servida pelo binário, nunca memorizada no
  prompt.

---

## Emenda (spec 010, volta 2) — `worker-start` deixa de ser o caminho padrão

- Data: 2026-08-05
- Autor: Vinicius (mosk-architect), a partir do gate `010` (QA-010-008)
- Altera: a decisão 2 (tabela de tiers) e o §4 de `data/fanout-seam.md`, que
  descreviam `worker-start` como **preferido**. Não altera nada mais deste ADR.

### O que a execução mostrou

O `worker-start` foi adotado como caminho preferido porque a documentação do
Orca o descreve assim — composição de worktree, terminal, readiness e dispatch
num passo, com recibo dos efeitos. Nunca havia sido exercitado.

Ao ser exercitado, em quatro rodadas de smoke:

- **cria o terminal e o dispatch corretamente** — a task vai para `dispatched` e
  o dispatch existe e é rastreável;
- **mas o prompt não é submetido** ao agente `claude`. O texto chega ao buffer de
  input da TUI e fica lá: worker `running` com **0 tokens**, task presa em
  `dispatched`, nenhum `worker_done`.

Duas mitigações falharam: enviar `Enter` logo após `tui-idle`, e aguardar o
buffer estabilizar antes de enviar (`_wait_buffer_settled`). O que **funcionou**
foi um `Enter` enviado manualmente minutos depois — o worker então processou e
concluiu a tarefa. Ou seja: o mecanismo de submissão do terminal funciona; o que
não funciona é o `worker-start` deixá-lo submetido.

Isso refuta, para este caminho, a premissa registrada em
[adr-0010](./adr-0010-orca-backend.md) §2 de que o `--enter` atômico do Orca
dispensa o "respiro" que o backend anterior exigia: **é verdade para `send`, e
falso para `worker-start`**, que não injeta pela mesma via.

### Decisão

**1. O caminho padrão do Tier 1 passa a ser `spawn` + `send` com prova de
entrega.** É o par que a spec 009 blindou: o `send` tira snapshot do terminal,
injeta, e relê até uma sonda distintiva do texto aparecer mais vezes do que
antes — devolvendo erro quando não confirma. Nunca falhou em nenhuma rodada.

**2. `worker-start` continua disponível, rebaixado a opcional.** Não é removido:
suas vantagens são reais (um passo em vez de três, recibo com os efeitos exatos,
placement remoto via `--on`). Passa a ser usado apenas quando a submissão for
**comprovada** naquele ambiente — nunca assumida.

**3. Entrega sem prova é falha, não sucesso.** Generalizando a lição da spec 009
para além do `send`: qualquer caminho que entregue trabalho a um worker precisa
confirmar que o worker o recebeu. Um dispatch criado não é prova de prompt
submetido — foi exatamente essa confusão que fez `worker-start` parecer
funcionar por leitura de código.

**4. O resto do Tier 1 permanece intacto e validado.** Run, `task-create` com
`--deps`, `task-list` com provenance, `worker-read` tipado, `worker-stop`, e o
`check --wait` com `--ack` — todos exercitados e funcionando. O que falhou foi
um elo, não a camada.

### Consequências

- **Positiva:** o Tier 1 passa a se apoiar no único caminho com prova de entrega,
  e o fan-out deixa de depender de um elo que não entrega.
- **Custo:** perde-se a composição num passo; `spawn` + `send` exige orquestrar
  terminal e injeção separadamente, e o recibo de efeitos do `worker-start` não
  tem equivalente direto.
- **Registrado:** se o Orca corrigir a submissão do `worker-start`, a decisão 2
  permite voltar a preferi-lo sem nova emenda — o critério é comprovar, não a
  documentação afirmar.
