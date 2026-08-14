# ADR-0019 — Entrega autônoma: a segunda exceção escopada, fundada em consentimento

- Status: aceito
- Data: 2026-08-14
- Autor: Vinicius (mosk-architect)
- Contexto: pedido de um modo que leve uma spec do `tasks` ao gate verde sem supervisão, com agentes paralelos.
- Emenda: [adr-0018](./adr-0018-remove-orchestration-layer.md) (alternativa 1) e [adr-0016](./adr-0016-agent-invocation-protocol.md) §2 (linha `orq` da matriz).
- Depende de: [adr-0002](./adr-0002-auto-escalation-exception.md) (o precedente de exceção escopada), [adr-0004](./adr-0004-runtime-agnostic-phase-orchestration.md) (o disco como fronteira de estado), [adr-0012](./adr-0012-route-decision-vs-phase-execution.md) (rota × execução), [adr-0016](./adr-0016-agent-invocation-protocol.md) (a matriz).

## Contexto

Horas atrás, o [adr-0018](./adr-0018-remove-orchestration-layer.md) removeu o
`/mosk-orq` e considerou explicitamente ressuscitá-lo sobre subagente nativo:

> **Manter o `/mosk-orq` reescrito sobre subagente nativo.** Tentador: o Mauro
> perderia o atuador e viraria um condutor de ~50 linhas na sessão do humano.
> Rejeitada porque o resultado seria um invólucro fino sobre o que os agentes já
> fazem pela matriz do ADR-0016 — nova superfície para manter, **sem capacidade
> nova**. Se um maestro voltar a fazer sentido, **ele nasce da matriz**, não do
> cadáver do atuador.

A rejeição fixou uma barra — *capacidade nova* — e escreveu a própria condição de
reabertura. Este ADR passa a barra e cumpre a condição.

**Por que o maestro anterior não tinha capacidade nova.** O delta entre os seus
dois modos era uma linha: em `semi-auto` ele pedia ok antes de trocar de fase, em
`full-auto` não pedia. Tudo o mais — transporte, spawn, monitoramento — era
igual, e ambos paravam nos mesmos lugares. Ele automatizava a *espera*, não a
*decisão*. E como o próprio ADR-0018 §2 observou, um maestro que não cruza
decisão humana automatiza pouco, porque as fases decisórias do MOSK são as
interativas.

**Qual é a capacidade nova.** Um runner que atravessa o arco de entrega inteiro —
`implement` → verificação → correção → repetição — **sem devolver a decisão de
continuar a cada volta**. Isso a matriz do ADR-0016 não entrega, e não entrega por
construção: ela autoriza `dev`→`dev`, `dev`→`qa`, `qa`→`security`, mas manda
parar em toda decisão de rota, e "continuar a volta" é rota (ADR-0012 §1). Cada
agente sozinho executa; nenhum deles pode encadear o ciclo.

## Decisão

**1. Criar o `/mosk-orq` como executor autônomo do arco de entrega.** Skill
invocada por um humano, que abre `mosk-dev` em paralelo (um por user story, em
worktrees isolados), junta, verifica com `mosk-qa` e `mosk-security`, e repete até
o gate passar ou até uma condição de parada.

**2. A exceção à política consultiva é fundada em consentimento, não em
audiência.** Esta é a diferença que impede a exceção de generalizar, e vale ser
explícito sobre ela.

O [adr-0002](./adr-0002-auto-escalation-exception.md) abriu a primeira exceção
porque aplicar a regra ali **produziria** o dano que a regra evita: perguntar
rota a um leigo é exatamente o que o modo bench promete não fazer. O fundamento é
**audiência** — aquele usuário *não pode* ser consultado.

Aqui o usuário **pode** ser consultado. Ele escolhe não ser, para uma corrida,
depois de ler o que abre mão. O fundamento é **consentimento explícito e
delimitado**, e ele impõe três exigências que a exceção do bench não tem:

- **Renovável a cada corrida.** Nenhum valor de configuração liga o modo. O bloco
  `runner:` no `core-config.yaml` diz *como* a corrida se comporta, nunca *se*
  ela acontece. Consentimento que se herda de um arquivo não é consentimento.
- **Informado.** Antes do primeiro worker, o runner declara o que fará sozinho, o
  que o fará parar, e — crucialmente — **qual é a força da verificação**. Sem
  suíte de testes configurada, ele diz em letras claras que a única garantia é o
  julgamento do gate, e que isso é mais fraco. É a mesma honestidade que o
  ADR-0004 §4 exigiu ao trocar "idêntica" por "equivalente".
- **Revogável na prática.** Toda parada devolve o controle com o disco
  consistente e o estado retomável.

**3. Escopo em três eixos**, como o ADR-0002 — é o que impede virar precedente:

| Eixo | Limite |
|---|---|
| **Runtime** | só dentro de uma corrida do `/mosk-orq`. Os mesmos agentes, chamados fora dali, continuam suspendendo e esperando. |
| **Matéria** | ambiguidade **técnica** o runner resolve pelo caminho mais reversível e registra. Lacuna de **regra de negócio** ele não inventa: registra e devolve. Herdado, literal, do ADR-0002. |
| **Artefato** | toda decisão autônoma vira linha em `run-log.md`, versionado. |

**4. Preâmbulo continua não sendo invocável — e aqui a nossa exceção é mais
estreita que a do bench.** O bench pode chamar `architect`/`pm` sozinho dentro da
Fase B. O runner **não pode**: lacuna de ADR, de PRD ou de fluxo vira **parada**.

A razão é o fundamento. O bench automatiza a rota porque o leigo não tem como
decidi-la; o nosso usuário tem, e está a uma mensagem de distância. Automatizar
ali seria trocar consentimento por conveniência — que é exatamente a forma de
argumento que o ADR-0002 rejeitou na sua alternativa 2.

**5. Dois oráculos em série, e o runner não é nenhum deles.** A suíte de testes
do projeto (mecânica, binária) e o `mosk-qa` em contexto limpo (crítico,
independente). O runner **nunca decide se o ciclo continua** — só *como* corrigir.
Quem decide continuar é o veredito. Copiado do bench, onde é a peça que impede o
loop de se auto-avaliar.

**6. Um teto que é orçamento, não apresentação.** `runner.max_attempts` (default
3) por unidade, mais a parada por score estagnado lida do `score_history`.

Isto merece nota, porque o ADR-0018 §1 removeu `resolve_max_retries` no mesmo dia.
A justificativa é outra: aquele era o teto de um ciclo **consultivo**, apresentado
a um humano que já estava decidindo cada volta — e nesse contexto ele era ornamento,
porque quem decidia era a pessoa. Este é **orçamento interno de um processo
autônomo**, e sem ele o ciclo não termina. Mesmo número, função oposta.

**7. Fecha as duas pontas soltas do precedente.** O `loop-until-green` do bench
deixou o `decisions-log.md` sem template e sem escritor (o formato só existia em
prosa, num plan arquivado) e o `MAX_FIX_ATTEMPTS` como convenção de prompt, sem
constante. Um processo desacompanhado não pode depender de o prompt lembrar:
`append_run_log` e `resolve_max_attempts` entram no `common.sh`, com teste.

**8. A linha `orq` do ADR-0016 §2 é atualizada.** Ela dizia "trocar de fase em
`semi-auto`" — vocabulário do agente que morreu. Passa a:

| Chamador | Pode invocar | Para quê | Não pode |
|---|---|---|---|
| `orq` | `dev`, `qa`, `security` | conduzir o arco de entrega de uma corrida consentida | invocar preâmbulo; dispensar gate; arquivar; agir sem consentimento explícito |

## Alternativas consideradas

1. **Deixar como está — cada agente se coordena pela matriz.** É o estado que o
   ADR-0018 deixou, e funciona para trabalho acompanhado. Rejeitada porque não
   entrega o que se pede aqui: com a matriz sozinha, alguém precisa apertar o
   botão a cada volta, e "entregar a spec sem acompanhar" é justamente não ter
   esse alguém.
2. **Estender a exceção do ADR-0002 ao pipeline técnico.** Menos superfície: uma
   exceção em vez de duas. Rejeitada porque os fundamentos são diferentes, e
   apagar a diferença apagaria o limite — a do bench autoriza invocar preâmbulo
   (o leigo não pode ser consultado), a nossa não pode autorizar isso. Uma
   exceção com dois fundamentos vira exceção sem fundamento.
3. **Autonomia total, incluindo `archive` e push.** Fim de linha sem intervenção.
   Rejeitada: `archive` promove artefatos para a base do projeto e fecha a spec —
   é o ato mais irreversível do pipeline. E push manda trabalho não revisado para
   onde outras pessoas o consomem.
4. **Paralelizar no mesmo working tree, sem worktrees.** Mais simples, sem merge.
   Rejeitada: dois agentes escrevendo o mesmo arquivo corrompem trabalho que teria
   dado certo em série, e essa é precisamente a falha que o ADR-0018 §5 chamou de
   "a única regra que protegia de corrupção real".
5. **Resolver conflito de merge automaticamente.** Rejeitada: um conflito no join
   significa que o `[P]` estava errado. Isso é informação sobre o *planejamento*,
   não um obstáculo a contornar — e resolver esconderia a informação.

## Consequências

**Positivas:**

- Endereça três perdas que o ADR-0018 assumiu ao remover a camada anterior: o
  ponto de parada mecânico (volta como orçamento), a prova de que houve
  orquestração (o `run-log.md`), e o trabalho invisível enquanto roda (cada worker
  é nomeado pela unidade que carrega).
- O paralelismo passa a ser real e não declarativo, usando o isolamento que o
  runtime já dá.
- Nenhum script novo de orquestração, nenhuma dependência externa. O maestro
  nasceu da matriz, como o ADR-0018 pediu.

**Negativas / trade-offs:**

- **Existem agora dois pontos no MOSK onde agentes se invocam sozinhos.** O
  ADR-0002 avisou que o risco do primeiro era *virar precedente*. Este ADR é o
  precedente se materializando, e a única defesa é que os fundamentos sejam
  distintos e escritos. Uma terceira exceção deve ser lida com desconfiança.
- **Sem suíte de testes, a garantia é fraca.** O runner avisa, mas quem consente
  pode ignorar o aviso. Um gate LLM avaliando trabalho de outro LLM, sem oráculo
  mecânico, é mais frágil do que a fluidez do processo sugere.
- **A fronteira técnico × negócio é conceitual**, como toda fronteira desta
  família. Nenhum mecanismo impede o runner de tratar uma lacuna de produto como
  ambiguidade técnica; só o prompt e o log posterior.
- Mais uma superfície: agente, task, template, dois helpers e um bloco de config.

**Risco residual:**

- Uma corrida longa consome contexto do condutor mesmo com status curtos. O
  mitigante é o disco como fronteira de estado (ADR-0004): a corrida é retomável,
  e retomar custa menos que não terminar.
- O `security-review` não é endurecido contra prompt injection, e numa corrida
  autônoma ninguém lê o diff antes dele. Rodar autônomo sobre código de
  contribuidor não confiável continua sendo má ideia.
