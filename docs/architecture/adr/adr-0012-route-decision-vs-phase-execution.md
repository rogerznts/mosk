# ADR-0012 — Fronteira entre decisão de rota e execução de fase (regime de aprovação do fan-out)

- Status: aceito
- Data: 2026-08-04
- Autor: Vinicius (mosk-architect)
- Contexto: brief `docs/discovery/graph-loop-engineering-brief.md` §5 (D1) — o invariante consultivo do ADR-0006, lido ao pé da letra, proíbe fan-out paralelo.
- Origem: estudo de *graph engineering* (vídeo Maestros da IA, 04/08/2026) confrontado com o pipeline atual.
- Depende de: [adr-0006](./adr-0006-consultative-orchestration-graph.md) (grafo consultivo — este ADR refina o que o invariante governa), [adr-0008](./adr-0008-consultative-delivery-loop.md) (delivery-loop e contador derivado do log), [adr-0009](./adr-0009-herdr-orchestration.md) (primeira exceção opt-in ao invariante).

## Contexto

O ADR-0006 fixou o contrato central do MOSK: *o grafo nunca toma a aresta; o
humano decide `go`/`escalate`/`skip`/override*. É o que impede o toolkit de
virar um executor autônomo e o que sustenta a auditabilidade do pipeline.

O fan-out paralelo colide com ele de frente. Uma onda de 8 unidades de trabalho,
cada uma com até 3 voltas de verificação, produz dezenas de pontos de
confirmação. Aplicado literalmente, o invariante torna *graph engineering*
impossível — não por uma decisão de design, mas por um efeito colateral de
redação.

O próprio ADR-0009 já tinha esbarrado nisso e resolvido parcialmente, na sua
decisão 2: o `/mosk-orq` "automatiza transporte e caminho feliz; nunca cruza
decisão humana". Aquilo foi tratado como **exceção opt-in** a um invariante.
Não é. É a evidência de que o invariante nunca governou o que parecia governar.

Reler o ADR-0006 mostra o que ele de fato protege: *"o humano é a autoridade que
**roteia**"*. Roteamento — não execução. A ambiguidade nunca importou porque,
até aqui, cada fase tinha exatamente uma unidade de trabalho e as duas coisas
coincidiam. O fan-out separa as duas pela primeira vez, e a fronteira precisa
ser escrita antes que dois mecanismos a interpretem de formas diferentes.

## Decisão

Distinguir explicitamente **duas classes de ato** e declarar que o invariante do
ADR-0006 governa apenas a primeira.

**1. Decisão de rota — sempre humana, jamais delegada.**
Escolher qual aresta ou escalação tomar; aceitar, contestar ou dispensar um
veredito de gate; decidir `corrigir`/`escalar`/`waive`/`parar` no delivery-loop;
sair do trilho do grafo. Nenhum modo de autonomia, nenhum atuador e nenhum tier
de execução pode tomar um desses atos. É aqui que o ADR-0006 vale integralmente.

**2. Execução de fase — mecânica, delegável sem nova aprovação.**
O trabalho *dentro* de um nó, uma vez que a rota até ele foi decidida por um
humano. Pode ser paralelizado, isolado em processos/contextos separados e
distribuído entre agentes. Isso nunca foi objeto do invariante: um agente que
executa `implement` já lê arquivos, roda testes e escreve código sem pedir
confirmação a cada passo. Fan-out é a mesma categoria de ato, em N cópias.

**3. Regime de aprovação: uma aprovação por onda, não por ramo.**
A unidade de aprovação é o **plano de fan-out** — um artefato explícito,
apresentado ao humano antes de qualquer disparo, contendo:

- as unidades de trabalho e seu agrupamento (quais correm juntas, quais dependem
  de quais);
- o critério de aceite de cada unidade;
- o teto de tentativas aplicável;
- o caminho sequencial equivalente, caso o humano recuse o paralelismo.

Aprovar o plano **é** uma decisão de rota (classe 1) e obedece ao ADR-0006. O que
acontece depois dele, até o join, é execução (classe 2).

**4. O join é ponto de decisão obrigatório.**
Toda onda termina voltando ao humano com o consolidado — o que convergiu, o que
falhou, o que ficou pendente. **Não existe encadeamento automático de ondas.**
Uma onda cujo resultado dispara outra exige novo plano e nova aprovação. É a
mesma recusa que o ADR-0010 §5 já fez ao coordinator loop autônomo do Orca,
agora como regra geral e não como detalhe de backend.

**5. O que reabre a decisão humana no meio da onda.**
Três sinais suspendem **o ramo** que os produziu e o devolvem ao humano, sem
parar os demais: um guard `judgment` que aparece dentro da unidade, uma
escalação, e o esgotamento do teto de tentativas daquela unidade. Os outros
ramos seguem — suspender a onda inteira transformaria qualquer dúvida local numa
barreira global e destruiria o ganho do paralelismo.

**6. Replanejar é uma nova decisão de rota.**
Se o plano aprovado deixa de descrever o que está sendo feito — um ramo falhou e
o trabalho precisa ser redistribuído, uma unidade se revelou dependente de outra
— a onda não se auto-corrige. Ela reporta e pede um plano novo.

**7. O ponteiro de fase não se ramifica.**
`current_phase` continua sendo um único valor por spec. Os ramos vivem *dentro*
de uma fase e não aparecem no ponteiro. O `phase-history.log` registra **a onda**
(uma entrada), não cada ramo. Isso é o que preserva intacto o contador do
ADR-0008 §4 — que deriva `tentativa N/max` da contagem de loopbacks no log — e a
regra do ADR-0006 §3 de que o ponteiro ocupa apenas nós de fase. Um log que
ganhasse uma entrada por ramo inflaria o contador e faria o delivery-loop
declarar esgotamento na primeira onda.

**8. Fan-out é sempre opcional.**
Todo plano de fan-out carrega seu equivalente sequencial. Recusar o paralelismo
nunca bloqueia a fase — degrada o tempo, não a capacidade.

## Alternativas consideradas

1. **Aprovar cada ramo individualmente.** Fiel à leitura literal do ADR-0006 e
   inútil na prática: o custo de interação cresce com o paralelismo, que é
   exatamente o que se queria comprar. Rejeitada.
2. **Revogar o invariante e permitir auto-execução de rota.** Resolveria o
   problema destruindo o contrato central e o ethos de "toolkit que desaparece".
   Rejeitada — é o over-engineering que o ADR-0006 existia para evitar.
3. **Resolver por modo de autonomia (`full-auto` aprova tudo).** O mecanismo já
   existe no ADR-0009 §3 e não endereça a questão: o problema não é *quantas*
   confirmações são pedidas, é *quais atos são delegáveis*. Um `full-auto` sem
   esta fronteira delegaria julgamento junto com trabalho. Rejeitada — confunde
   política com fronteira.
4. **Manter o fan-out inteiramente manual (o humano dispara cada ramo).** É o
   status quo com passos extras; não entrega paralelismo. Rejeitada.
5. **Ramificar `current_phase` por ramo.** Daria visibilidade por ramo, ao custo
   de quebrar o contador do ADR-0008 e a semântica de ponteiro único do
   ADR-0006. Rejeitada; visibilidade por ramo é problema de apresentação, não de
   estado.

## Consequências

**Positivas:**

- Grafo consultivo e paralelismo deixam de ser contraditórios, sem que nenhum
  dos dois seja enfraquecido.
- O **plano de fan-out** vira artefato explícito e auditável — o humano aprova
  algo concreto, não uma intenção vaga de "rodar em paralelo".
- A exceção opt-in do ADR-0009 §2 deixa de ser exceção e passa a ser instância
  de uma regra geral. Um invariante a menos para relaxar caso a caso.
- O contador do delivery-loop (ADR-0008) sobrevive sem alteração.

**Negativas / trade-offs:**

- O humano aprova um plano que pode estar errado **em escala** — oito ramos
  errados custam mais que um. Mitigação: join obrigatório, tetos por unidade, e
  o equivalente sequencial sempre disponível.
- Um conceito novo no vocabulário (a **onda**), que precisa aparecer no
  glossário para não se confundir com fase, tentativa ou dispatch.
- A distinção rota × execução é conceitual e depende do prompt respeitá-la; não
  há mecanismo que a imponha. É a mesma natureza dos guards `judgment` do
  ADR-0006 §5, e o mesmo trade-off aceito lá.

## Fora de escopo

Como o plano de fan-out é derivado (a partir dos marcadores `[P]` do `tasks.md`)
e como cada tier o executa são decisões do [adr-0013](./adr-0013-fanout-seam-three-tiers.md).
Este ADR fixa apenas quem aprova o quê, e quando.
