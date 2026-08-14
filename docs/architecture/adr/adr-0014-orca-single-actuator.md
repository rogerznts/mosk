# ADR-0014 — Orca como atuador único (substitui ADR-0009 e a decisão 7 do ADR-0010)

- Status: **superseded** por [adr-0018](./adr-0018-remove-orchestration-layer.md) (2026-08-14) — o subagente nativo dos runtimes tornou a camada de orquestração redundante. Preservado como registro.
- Data: 2026-08-04
- Autor: Vinicius (mosk-architect)
- Contexto: brief `docs/discovery/graph-loop-engineering-brief.md` §3 — remover o Herdr e consolidar a orquestração multi-pane no Orca.
- Substitui: [adr-0009](./adr-0009-herdr-orchestration.md) integralmente; a **decisão 7** do [adr-0010](./adr-0010-orca-backend.md) ("Herdr permanece cidadão de primeira classe"). O restante do ADR-0010 permanece vigente.
- Depende de: [adr-0013](./adr-0013-fanout-seam-three-tiers.md) (o Tier 1 do fan-out é construído sobre a camada nativa do Orca), [adr-0006](./adr-0006-consultative-orchestration-graph.md) (invariante consultiva), [adr-0012](./adr-0012-route-decision-vs-phase-execution.md) (fronteira rota × execução).

## Contexto

O ADR-0009 escolheu o Herdr como atuador de panes do `/mosk-orq`. O ADR-0010
generalizou o atuador, introduziu a fachada `panes.sh`, acrescentou o Orca como
segundo backend e — na sua decisão 7 — declarou que o Herdr permaneceria cidadão
de primeira classe, para não quebrar instalações existentes.

Três fatos mudaram desde então:

1. **O ambiente real de trabalho é o Orca.** O Herdr sobrevive como paridade
   teórica, não como uso.
2. **Os dois backends não são equivalentes.** O Orca tem uma camada de
   orquestração nativa — Run, Task DAG com dependências, Dispatch, `worker_done`,
   `ask`/`reply`, decision gates — que o Herdr não tem e não pretende ter. O
   ADR-0013 constrói o Tier 1 do fan-out exatamente sobre ela.
3. **O contrato de paridade passou a custar capacidade, não só manutenção.** O
   ADR-0010 §2 fixou que `orca.sh` espelharia o contrato do `herdr.sh`. Enquanto
   esse contrato for o mínimo comum, o Tier 1 não pode oferecer o que só o Orca
   tem. A paridade deixou de ser uma disciplina saudável e virou um teto.

O ADR-0010 já registrava o custo do arranjo dual — "dois wrappers a manter em
paridade" e o risco de um backend divergir silenciosamente no formato de saída.
O que mudou não é o custo; é que agora existe também um benefício sacrificado.

## Decisão

**1. O Orca é o único atuador suportado — e permanece inteiramente opcional.**
`scripts/herdr.sh` é removido. O ADR-0009 passa a `substituído`; a decisão 7 do
ADR-0010 é revogada. Todas as demais decisões do ADR-0010 permanecem vigentes e
não são reabertas aqui: fachada (§1), resolução defensiva do binário (§3),
camada nativa que nunca resolve julgamento (§5) e base-branch por commit (§6).

**"Único suportado" não significa "requerido".** As duas afirmações são
independentes e a confusão entre elas seria a leitura mais danosa deste ADR:

- O **pipeline MOSK não depende de atuador nenhum.** `specify → plan → tasks →
  implement → qa-gate → archive` roda numa sessão única, em qualquer runtime,
  sem Orca instalado. É o modo default e continua sendo.
- O **`/mosk-orq` é um papel meta, opt-in**, fora do pipeline (ADR-0009 §1). Sem
  atuador, ele degrada para o fluxo single-pane estilo `/mosk-suggestion` — não
  falha (ADR-0009 §6, preservado).
- O **fan-out do [adr-0013](./adr-0013-fanout-seam-three-tiers.md) não requer
  Orca.** Só o Tier 1 o usa; os Tiers 2 e 3 cobrem todos os demais ambientes com
  resultado observável equivalente.

O que este ADR decide é qual atuador o MOSK suporta **quando há um** — não que
passe a haver um.

**2. A fachada `panes.sh` permanece — com um backend só.**
Ela não existe por causa da pluralidade de backends. Existe porque:

- é onde vive a degradação `none`, que é **requisito**, não conveniência: o MOSK
  precisa rodar em projetos sem nenhum atuador;
- mantém o `orq.md` desacoplado do CLI do Orca, que é a mitigação central do
  risco de acoplamento (ver §6);
- é o ponto de extensão natural para a seleção de tier do ADR-0013 §3.

O que sai é o custo do *dual*: sondagem de dois backends, desempate por variável
de ambiente de sessão, e o mecanismo `unsupported`/exit 3 — com um backend
único, todo subcomando do contrato é suportado, e um código de saída para "este
backend não faz isso" deixa de ter referente.

**3. `orchestration.driver` reduz a `auto | orca | none`.**
Uma instalação existente com `driver: herdr` **falha com mensagem clara de
migração**. Não degrada em silêncio para `auto` e não é reescrita
automaticamente: uma configuração que aponta para um backend inexistente é um
erro do operador, e adivinhar a intenção dele produziria um atuador diferente do
que ele pediu, sem aviso.

**3.1. O sinal de ativação é estar *dentro* da IDE — não ter o binário.**
Em `auto`, o Orca só é eleito quando a sessão corrente roda dentro de um
terminal do Orca (variáveis `ORCA_*` do ambiente), **e** o `check` do binário
passa. Fora disso, `auto` resolve para `none`.

Isto corrige um furo real herdado do arranjo dual. A precedência do ADR-0010 §4
terminava em *"o primeiro backend cujo `check` passar"* — um desempate que fazia
sentido com dois backends instalados e a sessão fora de ambos. Com um backend
único, essa regra passa a significar **"o binário está no PATH, logo orquestre"**,
que é falso e ativo: `spawn`/`worker-start` criam terminais **dentro do app**.
Numa sessão fora da IDE isso abre painéis num aplicativo que o usuário não está
olhando — sequestra foco, ou falha depois de já ter criado recursos. Presença de
binário é prova de instalação, não de contexto.

Consequências práticas da regra:

- `driver: orca` **explícito** continua sendo honrado fora da IDE — override do
  operador vence detecção, como já valia no ADR-0010 §4. Quem força, assume.
- O diagnóstico precisa distinguir os casos, porque as ações do usuário são
  diferentes: *binário ausente* (instalar) × *fora da IDE* (abrir o projeto no
  Orca) × *dentro da IDE, orquestração experimental desligada* (habilitar nas
  configurações) × *desligado por config* (mudar `driver`). `panes.sh driver`
  é onde essa distinção é reportada.

**4. A camada nativa passa a `auto`.**
Hoje `orchestration.orca.native_tasks` é `false` por padrão (ADR-0010 §5), porque
era um extra sobre um contrato que já funcionava sem ela. Com o Orca único, ela
deixa de ser extra: sem ela não existe Tier 1 do ADR-0013, e o `orq.md` perde
`ask`/`reply` e decision gates. O default vira `auto` — ligada quando o runtime a
suporta, desligada quando não —, com `on`/`off` explícitos preservados.

Isto **não** relaxa a invariante: continua valendo integralmente que o
orquestrador **cria** o gate, apresenta ao humano e só então resolve com a
resposta recebida, e que o coordinator loop autônomo do Orca **nunca** é usado
(ADR-0010 §5, ADR-0012 §4).

**5. História não se apaga.**
O ADR-0009 e o ADR-0010 permanecem no repositório; muda o `Status` do 0009 e
acrescenta-se uma nota de revogação na decisão 7 do 0010. As specs arquivadas
`006-feature-mosk-orq`, `007-feature-mosk-orca` e `009-fix-orca-driver-read-send`
são congeladas por design e não são tocadas. Supersessão é o mecanismo; deleção
seria perda de rastro.

**6. Regra de acoplamento: o wrapper é fino e a grammar não se memoriza.**
O guia da skill `orchestration` do Orca é servido **pelo binário**
(`orca skills get orchestration`) precisamente para evitar *version drift* — o
arquivo público do repositório é um stub que diz isso. Portanto:

- `orca.sh` permanece um wrapper mecânico, sem lógica de pipeline;
- o `orq.md` **consulta o guia versionado** em vez de reproduzir comandos e
  formatos de saída no prompt;
- todo parsing de envelope tem caminho de degradação explícito e é coberto por
  `selftest-orca-driver.sh`.

Esta é a lição da spec `009` — parsing acoplado a formato de saída quebrou em
silêncio — elevada de correção pontual a regra de arquitetura.

## Alternativas consideradas

1. **Manter os dois backends.** Preserva instalações existentes e mantém o teto
   de capacidade descrito no Contexto §3, além do custo de paridade que o próprio
   ADR-0010 registrou. Rejeitada.
2. **Colapsar `panes.sh` dentro de `orca.sh`.** Com um backend só, a indireção
   parece supérflua. Rejeitada: elimina o lugar onde a degradação `none` vive,
   reacopla o prompt ao CLI e desfaz o ponto de extensão do ADR-0013 §3 — trocaria
   ~230 linhas de fachada por acoplamento em três lugares.
3. **Deletar o ADR-0009 e as menções ao Herdr na história.** Rejeitada: ADR é
   registro de decisão datada; apagá-lo tornaria inexplicável por que o
   `/mosk-orq` tem a forma que tem.
4. **Depreciar sem remover** (manter `herdr.sh` sem suporte). Rejeitada: código
   morto que aparenta estar vivo, e a fachada continuaria pagando o custo do
   dual para servir um caminho que ninguém deve tomar.
5. **Manter `native_tasks: false` por padrão.** Conservador, mas entregaria um
   `/mosk-orq` sem Tier 1, sem `ask` e sem gates por default — a configuração
   padrão seria a menos capaz, num backend escolhido justamente pela capacidade.
   Rejeitada.

## Consequências

**Positivas:**

- Um wrapper em vez de dois; o `selftest-orca-driver.sh` passa a ser o único
  selftest de atuador do repositório.
- O Tier 1 do ADR-0013 pode usar o melhor do Orca sem travar num mínimo comum.
- O `orq.md` encolhe: some a explicação de qual backend está ativo e por quê.
- A configuração padrão passa a ser a mais capaz disponível no ambiente.

**Negativas / trade-offs:**

- **Instalações que usam o Herdr quebram.** É uma quebra deliberada, mitigada
  por mensagem de migração explícita (§3) — e não por degradação silenciosa, que
  seria pior.
- O acoplamento a um fornecedor externo aumenta. Mitigações: a fachada (§2), a
  degradação `none` sempre disponível, a regra de não memorizar a grammar (§6) e
  o fato de que **o pipeline MOSK não depende do atuador** — `/mosk-orq` é um
  papel meta, opt-in, fora do pipeline.

**Risco residual:**

- A camada de orquestração do Orca é uma **feature experimental do app**, que
  pode estar desligada nas configurações do usuário. A detecção de capacidade do
  ADR-0013 §3 precisa tratar "Orca presente, orquestração desligada" como
  degradação para o Tier 2 — nunca como erro.
