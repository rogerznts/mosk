# Implementation Plan: Driver Orca — `read` cego e `send` sem prova de entrega

**Branch**: `009-fix-orca-driver-read-send` | **Date**: 2026-07-29 | **Spec**: [spec.md](./spec.md)
**Input**: `docs/specs/009-fix-orca-driver-read-send/spec.md`

## Summary

Três correções no driver Orca, todas no mesmo defeito de fundo — `exit 0` sem ter
feito o que diz:

1. **`read` enxergar** — `_text_from_json` desconhece a chave `tail` (ramo Python
   devolve vazio) e o fallback sem `python3` devolve fragmento de JSON cru.
2. **`send` provar entrega** — confirmar por releitura que a injeção chegou, em
   vez de confiar no `exit 0` do `orca terminal send`.
3. **Registrar o desaparecimento de panes de agente** — investigação limitada,
   com saída escrita, sem correção especulativa.

A abordagem escolhida mantém o contrato da fachada intacto: nenhum subcomando ou
flag novo em `panes.sh`. A mecânica fica no script, o julgamento no prompt do
Mauro.

## Technical Context

**Linguagem**: Bash (POSIX-friendly) + heredocs Python 3 para parse de JSON
**Dependências**: `orca` CLI (runtime do app Orca) — apenas para o smoke real; `python3` no caminho principal, com degradação para `grep`/`sed`
**Armazenamento**: N/A
**Testes**: não há framework neste repositório. Esta spec **introduz** verificação por fixtures (`selftest-orca-driver.sh`), precedente em `lint-graph.sh`
**Plataforma**: macOS (o Orca é app macOS; o driver não roda em outro lugar)
**Tipo de projeto**: toolkit de arquivos — template instalável, sem build
**Restrições**: o custo da confirmação do `send` não pode mudar a experiência de orquestração no caminho feliz; nada pode quebrar o fluxo `bash`/Herdr que hoje funciona
**Escopo**: 1 script de driver (662 linhas) + 1 mirror idêntico + 1 script novo de selftest + 1 prompt de agente + 1 emenda de ADR

## Technical Approach

### A. Extração por semântica, não por comprimento (FR-001, FR-003, FR-004)

O helper hoje coleta todo campo textual do envelope e devolve
`max(out, key=len)` — o mais longo ganha. Adicionar `tail` à lista faria o caso
real passar e deixaria a regra errada de pé: qualquer campo maior que o conteúdo
do terminal vence.

**Decisão:** substituir a coleta-e-escolhe-o-maior por **precedência declarada,
primeiro match vence**:

1. Caminho conhecido `result.terminal.tail` (é o contrato de fato do
   `orca terminal read`).
2. Chaves de lista, nesta ordem: `tail`, `lines`, `rows` → itens unidos por `\n`
   (o `as_line` atual já cobre itens que são dict com `text`/`content`).
3. Chaves de string, nesta ordem: `text`, `output`, `content`.

Remover o `max(..., key=len)`. Sem match em nenhum degrau → string vazia.

**Estado "erro" já está resolvido:** `_orca_json` retorna 1 quando `ok != true`
(orca.sh:256-262), então `cmd_read` já falha em `terminal_handle_stale` antes de
chegar ao extrator. Os três estados do FR-004 se completam corrigindo apenas o
par conteúdo/vazio.

### B. Fallback sem `python3` que falha fechado (FR-002)

O `sed -E 's/.*"text":"//; s/"[,}].*$//'` é desancorado: quando `"text":"` não
existe no envelope, a substituição não casa, a linha inteira segue adiante e o
segundo `sed` corta no primeiro `",` — daí o `{"id":"x`.

Os outros três helpers do mesmo arquivo (`_json_ok`, `_json_error`,
`_handle_from_json`) já fazem o certo: `grep -o` **ancorado numa chave
específica**, que devolve vazio quando não casa. **A convenção correta já existe
no arquivo; o `_text_from_json` é o único fora dela.**

**Decisão (revista na implementação, QA-009-003):** **falhar sempre**, com exit
não-zero e mensagem explícita, quando não houver `python3` utilizável. Nenhuma
tentativa de extração.

A intenção original era tentar extração ancorada no array `"tail":[ ... ]` no
estilo dos outros helpers, e só falhar quando o casamento não fosse confiável.
Ao implementar ficou claro que "não confiável" **é o caso comum, não a exceção**:
a saída de terminal está cheia de colchetes — barras de progresso
(`compact [████░░]`), sequências ANSI, prompts de shell — e qualquer casamento de
array quebra neles. Um extrator que só funciona quando o terminal não imprime
colchetes é o mesmo tipo de armadilha que originou o defeito.

Alternativa rejeitada: manter parse best-effort com sed. Foi exatamente isso que
corrompeu — parsear JSON arbitrário com sed é o defeito, não o remédio.

Consequência aceita: numa máquina sem `python3`, o `read` para de funcionar (e o
`send` degrada para injeção sem confirmação, **avisando**). Preferimos remover o
caminho a manter um que corrompe em silêncio.

### C. `send` que confirma entrega (FR-005, FR-006, FR-007, FR-010)

**Predicado de confirmação (revisto após QA-009-001):** snapshot do `tail` antes
de injetar → injeta → relê até que **uma sonda distintiva do texto enviado apareça
mais vezes do que antes**, com deadline curto e backoff progressivo.

A primeira versão aceitava *qualquer* mudança de tela como prova, e o QA
reproduziu o falso positivo: pane que imprime sozinha + entrada descartada →
`send` retornava 0 com o texto ausente. **"O terminal mudou" não é prova de
entrega** — a TUI do Claude muda sozinha (spinner, contador de tokens, medidor de
compactação), e uma pane recém-spawnada, justamente o caso alvo, é a que mais
muda por conta própria. Pior: com exit 0 o degrau (b) nunca dispara, então o
falso positivo contornava toda a rede de proteção.

Detalhes que a sonda precisa respeitar: comparação **literal** (o texto injetado
pode conter metacaracteres), **normalização de espaços** (a TUI reflui e quebra
linha no meio do texto), **contagem de ocorrências** em vez de presença (reenviar
o mesmo texto ainda conta como entrega nova) e **modo fraco declarado** para
textos curtos demais para sondar, como um `y` de prompt de confiança — aí cai
para "mudou?" e avisa.

**A sonda é uma escada de candidatas, não um prefixo fixo (QA-009-006).** A TUI
não ecoa verbatim: ela reformata. Enviando `/mosk-zzz-probe-009 teste de sonda`,
a interface renderizou `⏺ Unknown command: /mosk-zzz-probe-009` — só o token do
comando, sem o argumento. Um prefixo fixo de 24 caracteres dava falso negativo
exatamente no formato que o `orq.md` Step 2 manda injetar. As candidatas, da mais
distintiva para a menos, e basta uma incrementar a contagem:

1. prefixo longo (24 caracteres),
2. **primeiro token** (cobre o eco só-do-comando),
3. prefixo de 16,
4. prefixo do piso (8 caracteres — `/mosk-po` e `/mosk-qa`, os comandos mais
   curtos, ainda se distinguem aí).

O piso é o que impede o afrouxamento de virar porta dos fundos: o prefixo comum
`/mosk-` tem 6 caracteres e **não** basta para confirmar, e o eco de um agente
diferente (`/mosk-qa`) não confirma o envio de `/mosk-dev`. Os dois casos estão
travados em fixture.

**Divisão de responsabilidade** (é o que evita flag nova):

| Degrau | Onde | O quê |
|---|---|---|
| (a) | `cmd_send` em `orca.sh` | Confirma; não confirmando, retorna exit não-zero com mensagem |
| (b) | `orq.md` (Mauro) | **Relê antes de retentar**; só reinjeta se a releitura mostrar que nada chegou |
| (c) | `orq.md` (Mauro) | Persistindo, para e devolve ao humano — nos dois modos de autonomia |

**O degrau (b) precisa reler antes de reenviar, e isso não é detalhe.** Quando a
confirmação falha, o `orca terminal send` já executou: o texto pode ter chegado e
só a confirmação ter sido lenta. Reenviar às cegas entrega o prompt **duas vezes**
ao worker. A releitura antes do retry é o que separa "não chegou" de "chegou
devagar".

**Falso negativo (FR-006):** pane que recebe o texto mas nunca o exibe (eco
desligado, ou TUI que consome sem renderizar). O predicado forte torna esse caso
mais provável do que o predicado fraco tornava — e essa é uma **troca deliberada**:
um falso negativo custa uma releitura (o degrau (b) resolve, sem reinjeção); um
falso positivo custa uma fase inteira do pipeline, em silêncio. O fluxo `bash` não
regride: o shell ecoa o comando. Verificado contra Orca vivo nas duas polaridades
— entrega real em pane `bash` e em TUI de agente confirma; entrega descartada em
pane que muda sozinha é rejeitada.

### D. Verificação offline por fixtures (FR-008)

O defeito existiu porque não havia como exercitar o extrator sem o Orca rodando.
Corrigir sem fechar isso convida o próximo campo novo do Orca a reintroduzir o
mesmo bug.

**Novo script shipped:** `mosk/.claude/mosk/scripts/selftest-orca-driver.sh` —
fixtures embutidas em heredoc, sem dependência de rede ou de runtime, `--help`,
exit 0 limpo / exit 1 listando falhas. Precedente: `lint-graph.sh`, que valida
forma sem app rodando.

**Casos de fixture (mínimo):**

| # | Envelope | Esperado |
|---|---|---|
| 1 | `tail` com 3 linhas | as 3 linhas, exit 0 |
| 2 | `tail: []` | string vazia, exit 0 |
| 3 | `ok: false` + `error` | exit ≠ 0, nada em stdout |
| 4 | `tail` curto + outro campo textual longo | vence o `tail` (regra de precedência) |
| 5 | `tail` com itens dict (`{"text": ...}`) | linhas extraídas via `as_line` |
| 6 | casos 1–4 **forçando o ramo sem `python3`** | mesmo conteúdo, ou falha explícita — nunca fragmento |

**Para exercitar o caso 6** é preciso desligar o ramo Python sem desinstalar
`python3`: `_has_py` passa a respeitar `MOSK_ORCA_NO_PY=1`. É variável de
ambiente de teste, não subcomando nem flag — **não** viola o FR-010.

### E. Paridade template ↔ mirror (FR-009)

`mosk/.claude/mosk/scripts/orca.sh` (publica) e `.claude/mosk/scripts/orca.sh`
(exec local) são hoje byte-a-byte idênticos. Editar o template, copiar para o
mirror, e usar `diff -q` entre os dois como checagem de conclusão. Mesmo
tratamento para o `selftest-orca-driver.sh` novo.

### F. Emenda ao ADR-0010 (FR-012)

Com o `send` do Orca garantindo entrega e o do Herdr não, a fachada deixa de
oferecer garantia uniforme — mesmo sem mudar a superfície de subcomandos, o que
o ADR-0010 chama de "paridade mecânica total" ganha uma exceção que precisa estar
escrita.

Artefato: `specs/009/architecture/adr-0010-amendment-send-delivery.md` com
front-matter `promote: docs/architecture/adr/adr-0010-orca-backend.md` e
`promote_mode: append`, aplicado no `archive`.

### G. Investigação limitada das panes que desaparecem (FR-011, US3)

Depende da US1 (sem `read` não há o que instrumentar). **Limite: uma sessão de
orquestração instrumentada** — não um número de horas. Registrar o estado do
terminal no momento do desaparecimento; não achando a causa, o entregável é o
documento de hipóteses testadas.

Saída: `specs/009/discovery/panes-de-agente-desaparecendo.md`. Não bloqueia o
`qa-gate`.

## Assumptions & Constraints

- **A causa presumida do achado 2 (`tui-idle` ≠ aplicação pronta) segue hipótese.**
  A correção ataca o ponto onde a perda é **detectável** (`send`), não a causa
  presumida (`wait`). Se a hipótese estiver errada, a confirmação continua
  valendo — ela prova entrega independentemente do motivo da não-entrega.
- **`herdr.sh` fora do escopo.** Tem `_read_text`/`_read_raw` próprios; não
  compartilha o helper defeituoso.
- **Ordem obrigatória US1 → US2.** Confirmar entrega exige ler o terminal. Não é
  preferência de sequenciamento, é dependência técnica.
- **Sem framework de teste.** A verificação é fixture + leitura cruzada + smoke
  manual. O selftest não substitui o smoke real, cobre a regressão.
- **`orca terminal wait --for tui-idle` é software de terceiro.** Contornar, não
  consertar.

## Dependencies

| Dependência | Necessária para |
|---|---|
| `python3` | caminho principal do extrator (fallback coberto por fixture) |
| `orca` CLI + runtime do app | apenas o smoke real e a US3; fixtures não precisam |
| US1 entregue | US2 (confirmação lê o terminal) e US3 (instrumentação) |
| `common.sh` (`extract_tokens`) | `cmd_tokens`, que consome `cmd_read` — se beneficia da correção sem alteração própria |

## Implementation Milestones

- **M1 — `read` enxerga (US1).** Precedência semântica no ramo Python; fallback
  ancorado que falha fechado; `MOSK_ORCA_NO_PY` para exercitar o fallback.
- **M2 — Verificação offline (FR-008).** `selftest-orca-driver.sh` com os 6 casos.
  Fecha junto com M1 — é o que prova o M1 sem Orca rodando.
- **M3 — `send` prova entrega (US2).** Confirmação em `cmd_send`; degraus (b) e
  (c) no `orq.md`, com a releitura-antes-do-retry explícita.
- **M4 — Paridade e documentação.** Mirror sincronizado (`diff` limpo), emenda do
  ADR-0010, `scripts.md` atualizado com o script novo.
- **M5 — Investigação US3.** Sessão instrumentada e documento em `discovery/`.

MVP defensável: **M1 + M2**. Devolve visão ao maestro e trava a regressão; o resto
é ganho incremental sobre uma base que já não engana.

## Validation Strategy

1. **Fixtures (automatizável, offline):** `bash .claude/mosk/scripts/selftest-orca-driver.sh`
   exit 0. É a única parte verificável sem Orca — e a que protege contra a
   próxima chave nova do CLI.
2. **Smoke real (manual, exige Orca):** ciclo `spawn → wait-idle → read → send →
   read → close`. O `read` devolve conteúdo; o `send` num worker de TUI recém-aberta
   é detectado em vez de reportar exit 0.
3. **Cenário do achado 2 reproduzido:** injetar antes de o input da TUI montar e
   confirmar que o `send` falha em vez de silenciar.
4. **Paridade:** `diff -q` entre template e mirror, para `orca.sh` e para o
   selftest.
5. **Leitura cruzada (convenção do repo):** `orq.md` descreve os degraus (b) e (c);
   `scripts.md` documenta o script novo; `ADR-0010` carrega a emenda.
6. **Anti-regressão do fluxo bash/Herdr:** um ciclo completo em pane `bash` sem
   falso negativo no `send`.

## Project Structure

```text
docs/specs/009-fix-orca-driver-read-send/
├── spec.md
├── plan.md                     # este arquivo
├── tasks.md                    # saída do *tasks
├── architecture/
│   └── adr-0010-amendment-send-delivery.md   # promote: append → ADR-0010
└── discovery/
    └── panes-de-agente-desaparecendo.md      # saída da US3
```

Arquivos de produto tocados:

```text
mosk/.claude/mosk/scripts/orca.sh                   # _text_from_json, _has_py, cmd_send
mosk/.claude/mosk/scripts/selftest-orca-driver.sh   # novo
mosk/.claude/mosk/agents/orq.md                     # degraus (b) e (c) do FR-007
.claude/mosk/scripts/orca.sh                        # mirror, manter idêntico
.claude/mosk/scripts/selftest-orca-driver.sh        # mirror, manter idêntico
.claude/rules/scripts.md                            # inventário do script novo
docs/architecture/adr/adr-0010-orca-backend.md      # via promote no archive
```

**Structure Decision:** nenhuma estrutura nova. O `selftest-orca-driver.sh` entra
em `scripts/` porque é onde vive o precedente (`lint-graph.sh`) e porque precisa
ser executável pelo consumidor, não só por nós.

Artefatos opcionais **não** gerados: `research.md` (não há escolha técnica em
aberto — as três decisões estão acima), `data-model.md` (sem entidades),
`contracts/` (o único contrato externo é o envelope do Orca, capturado nas
fixtures), `quickstart.md` (o fluxo de verificação cabe na seção acima).

## Complexity Tracking

| Violation | Why Needed | Simpler Alternative Rejected Because |
|---|---|---|
| Script novo (`selftest-orca-driver.sh`) num repo sem suíte de testes | O bug shipou porque o extrator não era exercitável offline; sem fixture, a próxima chave nova do Orca repete o defeito | Validação só manual foi o que permitiu o bug existir. Precedente de validador shipped já existe (`lint-graph.sh`) |
| `MOSK_ORCA_NO_PY` (env var só de teste) | O ramo de fallback é o mais perigoso dos dois e é inalcançável em máquina com `python3` | Confiar em inspeção visual do fallback — é o ramo que hoje corrompe justamente por nunca ter sido executado |
| Desvio da paridade mecânica do ADR-0010 | Garantia de entrega no `send` do Orca sem equivalente no Herdr | Levar o Herdr junto amplia a spec para um backend sem defeito relatado; deixar sem registro esconde a assimetria |
