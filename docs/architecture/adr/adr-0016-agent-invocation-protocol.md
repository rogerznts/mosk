# ADR-0016 — Protocolo de invocação entre agentes: execução delega, rota não

- Status: aceito
- Data: 2026-08-05
- Autor: Vinicius (mosk-architect)
- Contexto: com o CC agent shipando ([adr-0015](./adr-0015-agent-as-source-skill-as-wrapper.md)), agentes passam a poder invocar agentes. Falta dizer **quem chama quem, para quê, e o que continua sendo do humano**.
- Depende de: [adr-0012](./adr-0012-route-decision-vs-phase-execution.md) (a fronteira rota × execução — este ADR é sua aplicação operacional), [adr-0006](./adr-0006-consultative-orchestration-graph.md) (invariante consultiva), [adr-0013](./adr-0013-fanout-seam-three-tiers.md) (o seam que executa), [adr-0002](./adr-0002-auto-escalation-exception.md) (a exceção escopada do bench).

## Contexto

Os agentes que mais aparecem no ciclo de entrega — `sm`, `dev`, `qa`, `security`,
`ux-expert`, `ui-expert` — hoje se coordenam por **texto**: um emite um bloco
"Escalation suggested", o humano lê, copia um comando, cola noutra sessão. Isso
funciona, e é deliberadamente lento: era o único jeito de garantir que ninguém
roteasse sozinho.

O ADR-0012 mostrou que o invariante do ADR-0006 nunca proibiu delegar
**execução** — só **roteamento**. Com o CC agent shipando, a delegação passa a
ser possível de fato. Sem uma regra explícita de quem pode chamar quem, cada
prompt vai inventar a sua, e a fronteira se dissolve por acúmulo de exceções
razoáveis.

## Decisão

**1. Um agente pode invocar outro para EXECUTAR; nunca para ROTEAR.**

Delegável (execução, ADR-0012 §2):

- verificar um resultado contra critérios, em contexto limpo;
- implementar uma unidade de trabalho de uma onda já aprovada;
- produzir um artefato de apoio pedido explicitamente pelo humano;
- analisar um diff e **reportar** achados.

Nunca delegável (rota, ADR-0012 §1) — permanece humano, sem exceção:

- mudar de fase (`current_phase`);
- aceitar, contestar ou dispensar um veredito de gate;
- decidir `corrigir` / `escalar` / `waive` / `parar` no delivery-loop;
- aprovar um plano de fan-out;
- sair do trilho do grafo.

O teste prático: **se a resposta muda por onde o pipeline vai, é rota.** Se muda
só o conteúdo do que já foi decidido produzir, é execução.

**2. Matriz de invocação.** Quem pode chamar quem, e para quê:

| Chamador | Pode invocar | Para quê | Não pode |
|---|---|---|---|
| `dev` | `qa` | verificar ACs de uma unidade em contexto limpo | emitir o gate da fase |
| `dev` | `dev` | unidades `[P]` de uma onda aprovada | criar onda nova sem aprovação |
| `dev` | `security` | **reportar** achados de um diff | decidir se o gate reprova |
| `qa` | `security` | insumo para o gate (relatório) | resolver o veredito |
| `po` | `sm` | checar clareza de story antes de gerar tasks | pular readiness |
| `orq` | qualquer agente de fase | conduzir a fase corrente | trocar de fase em `semi-auto` |
| qualquer | `analyst`/`pm`/`architect`/`ux`/`ui` | **nada automático** — são preâmbulo | invocar por escalação |

A última linha é a mais importante e a mais tentadora de violar: uma lacuna de
ADR, de fluxo ou de PRD é **sinal de rota**. O agente **suspende e apresenta** o
bloco de escalação; quem decide chamar o preâmbulo é o humano (ADR-0006 §6). Um
`dev` que chama `architect` sozinho não está economizando um passo — está
decidindo que a arquitetura precisa mudar, que é a decisão mais cara do pipeline.

**3. O chamador não vira o chamado.** A invocação devolve **status curto**, não
transcript e não posse do trabalho. O chamador segue dono da fase e responsável
por consolidar. Isso é o contrato do
[adr-0013](./adr-0013-fanout-seam-three-tiers.md) §2 aplicado a chamadas
avulsas: o disco é a fronteira de estado, o retorno é um resumo.

**4. Toda invocação é declarada antes e reportada depois.** O agente diz o que
vai delegar e por quê antes de chamar, e o que voltou depois. Sem isso a
delegação vira caixa-preta: o humano perde a única coisa que o mantém no comando
— saber o que está acontecendo. Isso **não** é pedir permissão a cada chamada;
é narrar execução, que é diferente de pedir rota.

**5. Profundidade máxima 1.** Um agente invocado **não invoca outro**. Cadeias
`dev → qa → security` são proibidas: cada nível a mais afasta o humano do que
está sendo decidido e torna o rastro ilegível. Se o invocado precisa de terceiro,
ele **reporta a necessidade** e o chamador — que está no nível do humano —
decide. É a mesma razão pela qual o guia do Orca recomenda não encadear
dependências além de poucos passos.

**6. Falha de invocação não é falha de qualidade.** Um subagente que morre, sai
sem resultado ou estoura o próprio teto é reportado como **invocação falha** — o
chamador decide se tenta de novo, cai para execução própria, ou devolve ao
humano. Não consome volta do delivery-loop, pela mesma razão do ADR-0013 §6:
instabilidade de infraestrutura não é não-convergência de produto.

**7. O bench continua com sua exceção.** O `loop-until-green` do ADR-0002 já
permite ao `dev` invocar `architect`/`pm` automaticamente, sem pausar o leigo,
registrando em `decisions-log.md`. Aquilo permanece **intacto e escopado ao
bench**: audiência diferente (leigo, que não pode ser consultado), automação
diferente. Este ADR governa o pipeline técnico; não relaxa nem estende a exceção
do bench para fora dele.

## Alternativas consideradas

1. **Loop fechado `dev ↔ qa` automático até convergir.** Rápido e a coisa mais
   próxima do que "agentes se chamando" sugere. Rejeitada: quem decide corrigir,
   escalar ou dispensar é o humano (ADR-0008 §1), e um loop fechado toma essa
   decisão por omissão a cada volta. Precisaria revogar o invariante consultivo,
   que continua valendo.
2. **Liberar qualquer agente a chamar qualquer agente.** Máxima flexibilidade.
   Rejeitada: a escalação para preâmbulo é decisão de rota disfarçada de
   conveniência, e sem matriz cada prompt inventa a sua.
3. **Sem matriz: só a regra "execução sim, rota não".** Elegante, mas o limite
   entre as duas é justamente o que se discute caso a caso. A matriz existe para
   que a fronteira não seja renegociada em cada prompt.
4. **Profundidade ilimitada, com log.** Rejeitada: o log registra, mas não
   devolve o controle. Cadeias longas produzem trabalho que ninguém acompanhou.
5. **Pedir confirmação a cada invocação.** Rejeitada: transforma delegação de
   execução em decisão de rota, anulando o ganho do ADR-0012. A decisão 4
   (declarar e reportar) dá visibilidade sem custo de interação.

## Consequências

**Positivas:**

- Os agentes do ciclo passam a se coordenar sem o humano servir de transporte,
  **sem** que ninguém decida rota sozinho.
- O verificador independente do `qa-gate` fica mecanicamente possível: `dev`
  invoca `qa` num contexto que não herda seus trade-offs.
- A escalação para preâmbulo continua sendo o ponto de parada — que é onde ela
  sempre teve valor.

**Negativas / trade-offs:**

- A matriz é mais uma coisa a manter em sincronia com o roster de agentes.
- Profundidade 1 impede composições legítimas (um verificador que quisesse
  consultar segurança); o preço é rastro legível, e o contorno é reportar ao
  chamador.
- "Declarar antes, reportar depois" aumenta o texto que o humano lê. É o custo
  de não ter caixa-preta.

**Risco residual:**

- A fronteira rota × execução é conceitual: nenhum mecanismo a impõe. Mesma
  natureza dos guards `judgment` do ADR-0006 §5, e o mesmo trade-off aceito lá.
  A matriz reduz a superfície de interpretação, não a elimina.
