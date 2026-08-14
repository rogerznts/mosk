# ADR-0018 — Remover a camada de orquestração: o subagente nativo tornou o atuador redundante

- Status: aceito
- Data: 2026-08-14
- Autor: Vinicius (mosk-architect)
- Contexto: revisão da camada acumulada entre as specs 004 e 010, à luz do que os runtimes passaram a oferecer.
- Supersede: [adr-0006](./adr-0006-consultative-orchestration-graph.md), ADR-0007 (schema do grafo, nunca promovido — vive em `specs/archive/004-feature-orchestration-graph/`), [adr-0008](./adr-0008-consultative-delivery-loop.md), [adr-0009](./adr-0009-herdr-orchestration.md), [adr-0010](./adr-0010-orca-backend.md) (e sua emenda), [adr-0013](./adr-0013-fanout-seam-three-tiers.md), [adr-0014](./adr-0014-orca-single-actuator.md).
- Emenda: [adr-0004](./adr-0004-runtime-agnostic-phase-orchestration.md) §2 (premissa de capacidade do Codex).
- Preserva intactos: [adr-0012](./adr-0012-route-decision-vs-phase-execution.md), [adr-0015](./adr-0015-agent-as-source-skill-as-wrapper.md), [adr-0016](./adr-0016-agent-invocation-protocol.md).

## Contexto

Entre julho e agosto de 2026 o MOSK ganhou uma camada de orquestração de cerca de
2.800 linhas:

| Peça | Spec | O que era |
|---|---|---|
| `pipeline-graph.yaml` + `legal_moves.sh` + `lint-graph.sh` + `graph_mermaid.sh` | 004 | o grafo como fonte única das jogadas |
| `attempt_count` + `phase-history.log` + `max_retries` | 005 | delivery-loop contado |
| `/mosk-orq` (Mauro) + `herdr.sh` → `orca.sh` + `panes.sh` | 006/007/009 | orquestrador multi-terminal e seu atuador |
| `fanout-seam.md` + `dispatch_wave` em três tiers | 010 | fan-out sobre unidades `[P]` |

Cada peça foi uma resposta correta ao problema que existia quando foi escrita.
Duas premissas as sustentavam, e as duas caíram.

**Premissa 1 — a assimetria de runtime.** O ADR-0004 (19/jul) fixou o desenho
sobre uma frase: *"No Codex não existe primitivo de subagente isolado
equivalente."* Foi verdade, e deixou de ser. Em 14/ago/2026, `codex-cli 0.146.0`
traz a feature `multi_agent` com estágio **stable** e habilitada por padrão, e o
runtime reconhece os eventos de hook `subagent_start` / `subagent_stop`. Do outro
lado, a spec 011 (ADR-0015/0016) fez os agentes MOSK shiparem como definições
nativas em `.claude/agents/`, invocáveis por `subagent_type` — o que se verifica
abrindo qualquer sessão do Claude Code neste repositório.

Os dois runtimes têm hoje o primitivo que o ADR-0013 chamava de **Tier 2**. O
atuador externo existia para suprir a falta dele. Sem a falta, ele é um
intermediário entre o agente e uma capacidade que o agente já tem.

**Premissa 2 — que o custo do atuador valia o que ele entregava.** O histórico
diz o contrário. Os três defeitos mais caros dessa camada são todos do atuador:

- `send` sem prova de entrega — spec 009 inteira, mais um `read` cego;
- `worker-start` que cria o dispatch mas **não submete o prompt** ao worker —
  descoberto só no smoke da spec 010, depois de ter sido adotado como caminho
  preferido por leitura de documentação;
- a necessidade de blindar o wrapper contra invocar `orca` cru, que no Linux é o
  **leitor de tela do GNOME**.

A spec 010 fechou com gate `WAIVED` e `quality_score` 40. Nenhum desses modos de
falha existe numa chamada de subagente nativo: não há terminal, não há injeção de
texto numa TUI, não há binário ambíguo no `PATH`.

## Decisão

**1. A camada de orquestração sai inteira.** São removidos, do template e do
espelho: `pipeline-graph.yaml`, `legal_moves.sh`, `lint-graph.sh`,
`graph_mermaid.sh`, `panes.sh`, `orca.sh`, `selftest-orca-driver.sh`,
`data/fanout-seam.md`, o agente `mosk-orq` e sua skill, e o bloco
`orchestration:` do `core-config.yaml`.

**2. A coordenação entre agentes é a matriz do ADR-0016, e só ela.** Ela já
shipava e já funcionava: `dev`→`dev` para unidades `[P]`, `dev`→`qa` para
verificação em contexto limpo, `qa`→`security` para insumo do gate, `po`→`sm`
para prontidão. O que a camada removida acrescentava a isso era transporte
(panes, handoff, tokens) e uma máquina de rota — e rota nunca foi delegável.

Essa é a razão de fundo, e vale registrar porque não é óbvia: **um maestro que
não pode cruzar decisão humana automatiza pouco.** As fases decisórias do MOSK
são justamente as interativas (`specify` elicita, o gate emite veredito que o
humano aceita ou contesta). O que sobrava para o Mauro automatizar — executar
`implement`, verificar, revisar segurança, paralelizar `[P]` — é exatamente o que
a matriz do ADR-0016 já permite cada agente fazer sozinho, sem camada nenhuma.

**3. `update_spec_phase` volta a ser burro.** Registra `current_phase` e
`last_phase_change`; não valida transição, não escreve `phase-history.log`. A
autoridade sobre qual fase vem depois é humana, e `spec-meta.yaml` é o único
lugar onde esse estado mora.

**4. O `quality_score` fica, e ganha memória própria.** O score calculado
(fórmula canônica, nunca estimado) e o verificador independente do QA são
entregas da spec 010 **independentes** do grafo e do loop: são disciplina de
gate. O que os prendia à camada removida era a fonte da série histórica — o
`phase-history.log`. A série passa a viver em `score_history:` no próprio
`gate.yaml`, que é onde ela sempre pertenceu.

**5. Fan-out deixa de ser construção formal.** Sem tiers, sem plano aprovado
formalmente, sem join com semântica própria. Fica a permissão do ADR-0016:
`dev` pode delegar unidades `[P]` a subagentes `mosk-dev`, declarando antes e
reportando depois, profundidade 1. A regra que **sobrevive intacta** é a única
que protegia de corrupção real: **`[P]` é honrado, nunca inferido.**

**6. `/mosk-update` passa a fazer reset.** `npx degit --force` sobrescreve e
**nunca apaga**. Sem um reset, todo projeto já instalado guardaria os arquivos
desta remoção para sempre, e os agentes continuariam encontrando-os. O novo
`reset-install.sh` calcula o conjunto a apagar — `.claude/mosk/` inteiro, o que o
template novo possui, e os órfãos do namespace `mosk-` — preservando `rules/`,
`settings`, `docs/` e as skills do próprio usuário. Ver `mosk-update/SKILL.md`.

**7. O ADR-0004 é emendado, não revogado.** O RAPC — contrato de fases dirigido
por disco, com um único seam runtime-específico — **continua válido e em
produção** no `bench-mode`. O que muda é a tabela de capacidade: o Codex sai do
Tier 2 (isolamento lógico por disciplina) e entra no Tier 1 (isolamento
estrutural) onde `multi_agent` estiver disponível. O Tier 2 permanece como
fallback para runtimes sem o primitivo.

**8. O ADR-0012 não é superseded.** A fronteira conceitual **rota × execução** é
o que sustenta o ADR-0016 e continua de pé, integralmente. O que sai é a
aplicação dela ao fan-out, não a distinção.

**9. O registro histórico é preservado.** Nenhuma spec arquivada, nenhum ADR
anterior e nenhum documento de discovery é apagado. Eles descrevem decisões que
foram corretas no contexto em que foram tomadas; apagá-los tornaria este ADR
incompreensível. Os superseded permanecem legíveis, marcados como tal.

## Alternativas consideradas

1. **Manter o `/mosk-orq` reescrito sobre subagente nativo.** Tentador: o Mauro
   perderia o atuador e viraria um condutor de ~50 linhas na sessão do humano.
   Rejeitada porque o resultado seria um invólucro fino sobre o que os agentes já
   fazem pela matriz do ADR-0016 — nova superfície para manter, sem capacidade
   nova. Se um maestro voltar a fazer sentido, ele nasce da matriz, não do
   cadáver do atuador.
2. **Manter o grafo e remover só o Orca.** O grafo era honesto: fonte única,
   consultivo, curava drift entre quatro cópias do fluxo. Rejeitada porque seus
   dois consumidores reais eram o `/mosk-orq` e o `/mosk-suggestion`; sem o
   primeiro, sobra manter um YAML, quatro scripts e um schema linteado para
   alimentar uma tabela de sugestão. O drift volta a ser risco — aceito
   conscientemente, e mitigado por o fluxo agora ter menos cópias.
3. **Manter o delivery-loop contado, sem o grafo.** O contador e o menu de
   esgotamento eram bons: davam ao humano um ponto de parada não-arbitrário.
   Rejeitada porque o contador derivava do `phase-history.log`, que derivava do
   reducer validado por grafo. O valor real — saber se vale mais uma volta — é
   preservado pela série de `quality_score`, que é um sinal melhor do que a
   contagem: mede convergência, não repetição.
4. **Preservar o fan-out em Tiers 2 e 3, removendo só o Tier 1.** Tecnicamente
   viável (nem 2 nem 3 precisam de Orca). Rejeitada porque o valor do seam era
   abstrair três mecanismos distintos; com um só sobrando, o contrato de 212
   linhas descreve o que uma frase descreve.
5. **Apagar ADRs e specs do tema.** Rejeitada — decisão 9.

## Consequências

**Positivas:**

- ~2.800 linhas a menos, em duplicata (template + espelho). `common.sh` cai de
  573 para 320 linhas.
- Some a única dependência externa opcional do toolkit. O MOSK volta a ser
  Markdown, YAML e Bash sem nada para instalar.
- O isolamento passa a vir do runtime, que o mantém — em vez de um wrapper que o
  MOSK mantinha contra uma superfície externa em evolução.
- Somem os três modos de falha do atuador, e com eles a classe inteira de bug
  "entrega sem prova".
- `/mosk-update` deixa de acumular lixo entre versões — um defeito que existia
  antes desta remoção e que ela obrigou a enxergar.

**Negativas / trade-offs:**

- **Perde-se o fluxo como dado.** O pipeline volta a ser descrito em prosa, em
  mais de um lugar (README, `mosk-suggestion`, `project-rule-tmpl.md`). O drift
  entre essas cópias volta a ser possível — foi exatamente o que o ADR-0006 §1
  curou. Mitigação: são menos cópias do que em 2026-07, e nenhuma delas é
  executável.
- **Perde-se o ponto de parada mecânico do delivery-loop.** O `tentativa N/max`
  dizia ao humano, sem julgamento, quando parar. A série de score informa melhor,
  mas não impõe: depende de o humano lê-la.
- **Perde-se a prova de orquestração.** Dentro do Orca dava para *provar* que uma
  onda aconteceu (`task-list`, `dispatch-show`). Com subagente nativo, a
  visibilidade é a narração do agente — que o ADR-0016 §4 exige, mas não força.
- **Trabalho fica invisível enquanto roda.** Uma pane era observável ao vivo; um
  subagente devolve só o resultado.

**Risco residual:**

- A fronteira rota × execução continua sendo conceitual, sem mecanismo que a
  imponha (ADR-0016, risco residual). Esta remoção não piora isso: o atuador
  também não impunha nada — o `/mosk-orq` respeitava a fronteira por prompt.
- Se um runtime remover seu primitivo de subagente, o Tier 2 do ADR-0004
  (disciplina + redirecionamento de log) é o fallback, e continua escrito.
