---
description: "Lista de tarefas — driver Orca: read cego e send sem prova de entrega"
---

# Tasks: Driver Orca — `read` cego e `send` sem prova de entrega

**Input**: [spec.md](./spec.md), [plan.md](./plan.md)
**Branch**: `009-fix-orca-driver-read-send`

## Format: `[ID] [P?] [Story] Descrição`

- **[P]**: pode rodar em paralelo (arquivos distintos, sem dependência)
- **[US1|US2|US3]**: história a que a tarefa pertence

## Convenção de caminhos

Duas cópias, mantidas idênticas (FR-009):

- `mosk/.claude/mosk/scripts/` — **o que publica** via degit. Edite aqui.
- `.claude/mosk/scripts/` — mirror de execução local. Sincronize depois.

---

## Fase 1: Fundação da verificação

**Propósito**: tornar o defeito reproduzível offline **antes** de corrigi-lo. Esta
fase inverte a ordem natural de propósito: a fixture que falha é a prova de que a
correção corrigiu algo.

- [x] T001 Criar `mosk/.claude/mosk/scripts/selftest-orca-driver.sh` com o esqueleto do runner: `--help`, contagem de casos, exit 0 limpo / exit 1 listando `caso :: esperado :: obtido`. Seguir o estilo de `lint-graph.sh`.
- [x] T002 Adicionar em `mosk/.claude/mosk/scripts/selftest-orca-driver.sh` as 6 fixtures de envelope em heredoc (tabela da seção D do plano): `tail` com 3 linhas; `tail: []`; `ok: false` + `error`; `tail` curto competindo com campo textual longo; `tail` com itens dict `{"text":...}`; e os casos 1–4 repetidos no ramo sem `python3`.
- [x] T003 Fazer `_has_py` em `mosk/.claude/mosk/scripts/orca.sh` respeitar `MOSK_ORCA_NO_PY=1` (retorna falso sem desinstalar nada), para o caso 6 ser alcançável em máquina com `python3`.
- [x] T004 Rodar o selftest e **registrar o baseline de falha** no corpo do PR ou em nota da spec: confirmar que os casos 1, 4 e 6 falham hoje — o 6 devolvendo `{"id":"x` em vez de vazio. Sem esse registro não há prova de que a correção mudou algo.

**Checkpoint**: o defeito está capturado em fixture e reproduzível sem o Orca rodando.

---

## Fase 2: US1 — o maestro enxerga o worker (P1)

- [x] T005 [US1] Reescrever o ramo Python de `_text_from_json` em `mosk/.claude/mosk/scripts/orca.sh` (~linha 220): trocar coleta-e-escolhe-o-maior por **precedência declarada, primeiro match vence** — caminho `result.terminal.tail`, depois listas `tail`/`lines`/`rows`, depois strings `text`/`output`/`content`. **Remover o `max(out, key=len)`** (FR-003). Preservar `as_line` para itens dict.
- [x] T006 [US1] Substituir o fallback `sed -E 's/.*"text":"//; s/"[,}].*$//'` (~linha 246) por extração **ancorada** no array `"tail":[...]`, no estilo de `_handle_from_json`. Não casando com confiança, **falhar com exit não-zero e mensagem explícita** — nunca emitir fragmento do envelope (FR-002).
- [x] T007 [US1] Rodar `bash mosk/.claude/mosk/scripts/selftest-orca-driver.sh` e obter exit 0 nos 6 casos. Falha aqui bloqueia a Fase 3.

**Checkpoint**: `read` devolve conteúdo, vazio legítimo ou erro — os três estados distinguíveis (FR-004). **A US1 é entregável sozinha**: já devolve visão ao Mauro mesmo que nada mais seja feito.

---

## Fase 3: US2 — o `send` prova que entregou (P2)

Depende da Fase 2: confirmar entrega exige ler o terminal.

- [x] T008 [US2] Extrair o predicado de confirmação num helper puro em `mosk/.claude/mosk/scripts/orca.sh` — recebe `tail` de antes e de depois, responde confirmado/não. Puro de propósito: é a parte da US2 que **é** testável por fixture, sem terminal vivo.
- [x] T009 [US2] Cobrir o predicado no selftest: `tail` mudou → confirmado; `tail` idêntico → não confirmado; `tail` vazio antes e depois → não confirmado.
- [x] T010 [US2] Implementar em `cmd_send` (~linha 405) o degrau (a) do FR-007: snapshot do `tail` → injeta → relê até diferir, com deadline curto → não confirmando, retorna **exit não-zero** com mensagem. Nenhuma flag nova (FR-010).
- [x] T011 [US2] Atualizar `mosk/.claude/mosk/agents/orq.md` (Step 2 e Step 3.4) com os degraus (b) e (c): **reler antes de retentar** — se a releitura mostra que chegou, tratar como entregue e **não** reinjetar; só reinjetar quando nada chegou; persistindo, parar e devolver ao humano, nos dois modos de autonomia. O aviso contra reinjeção cega precisa estar explícito: o `orca terminal send` já executou quando a confirmação falha, e reenviar entrega o prompt duas vezes.

**Checkpoint**: o cenário que custou uma fase em campo passa a falhar alto em vez de reportar `exit 0`.

---

## Fase 4: US3 — instrumentar as panes que desaparecem (P3)

Depende da Fase 2. **Limite: uma sessão de orquestração instrumentada** — não um número de horas. Não bloqueia o `qa-gate`.

- [x] T012 [P] [US3] Levar uma pane de agente (`claude --dangerously-skip-permissions`) até a conclusão do trabalho com `read` funcionando e capturar o estado do terminal no momento em que `wait` retorna `terminal_handle_stale` / `close` retorna `tab_not_found`.
- [x] T013 [P] [US3] Escrever `docs/specs/009-fix-orca-driver-read-send/discovery/panes-de-agente-desaparecendo.md` com o que foi observado. Não achando a causa, o entregável é o registro das hipóteses testadas e do traço que as descartou — **sem alteração especulativa no driver** (FR-011).

---

## Fase 5: Paridade, documentação e validação

- [x] T014 Sincronizar o mirror: copiar `orca.sh` e `selftest-orca-driver.sh` de `mosk/.claude/mosk/scripts/` para `.claude/mosk/scripts/` e provar com `diff -q` limpo nos dois pares (FR-009).
- [x] T015 [P] Escrever `docs/specs/009-fix-orca-driver-read-send/architecture/adr-0010-amendment-send-delivery.md` com front-matter `promote: docs/architecture/adr/adr-0010-orca-backend.md` e `promote_mode: append`, registrando que a garantia de entrega do `send` no Orca não tem equivalente no Herdr — exceção à "paridade mecânica total" do ADR-0010 (FR-012).
- [x] T016 [P] Documentar `selftest-orca-driver.sh` no inventário de `.claude/rules/scripts.md` (uso, flags, quando rodar) e na lista de scripts de `CLAUDE.md`.
- [x] T017 Smoke real com Orca: ciclo `spawn → wait-idle → read → send → read → close`. O `read` devolve as linhas visíveis; o `send` num worker de TUI recém-aberta é detectado em vez de silenciar.
- [x] T018 Anti-regressão: um ciclo completo em pane `bash`, confirmando que a confirmação do `send` **não** produz falso negativo no fluxo que hoje funciona (FR-006).

---

---

## Fase 6: `common.sh` — resolução de caminho quebrada em zsh

**Escopo adicionado durante o `implement`** por decisão do usuário (sem spec
nova). Achado independente do driver Orca, descoberto quando a própria transição
`specify → plan` desta spec foi gravada como `off-graph`.

`common.sh` resolve três caminhos via `${BASH_SOURCE[0]}` (linhas 11, 300, 391).
Em **zsh** essa variável não existe: `dirname ""` → `.` → tudo resolve a partir do
cwd. As tasks do MOSK mandam o agente fazer `source common.sh`, e o shell padrão
do macOS é zsh. Efeito: `graph_file` aponta para fora do repo, `graph_edge_exists`
sempre falha, e **toda transição legal de fase é gravada como `off-graph`** no
`phase-history.log` — o log de onde `attempt_count` deriva o contador do
delivery-loop (ADR-0008).

- [x] T019 Corrigir a resolução de caminho em `mosk/.claude/mosk/scripts/common.sh` (linhas 11, 300, 391) para funcionar em bash **e** zsh, sem depender de `BASH_SOURCE`.
- [x] T020 Cobrir a regressão: o selftest (ou script irmão) executa os helpers de caminho sob `zsh -c` e sob `bash -c` e exige o mesmo resultado nos dois.
- [x] T021 Sincronizar o mirror `.claude/mosk/scripts/common.sh` e provar com `diff -q` limpo.

**Checkpoint**: `graph_edge_exists specify plan` responde `TRUE` sob zsh e sob bash.

---

---

## Fase 7: `apply-qa-fixes` — rodada 1 (gate CONCERNS de 2026-07-29)

Origem: `gate.yaml`, tentativa 1/3 do delivery-loop. `QA-009-004` (deriva de mirror
pré-existente) ficou **fora** por instrução explícita do QA: "não misturar no 009".

- [x] T022 **QA-009-001 (high)** — trocar o predicado de confirmação em `mosk/.claude/mosk/scripts/orca.sh`: exigir que uma sonda distintiva do texto enviado apareça **mais vezes** no depois do que no antes, em vez de aceitar qualquer mudança de tela. Busca literal (o texto pode ter metacaracteres), normalização de espaços (a TUI reflui e quebra linha), contagem de ocorrências (reenvio do mesmo texto conta), e modo fraco declarado + avisado para textos curtos demais para sondar (ex.: `y` de prompt de confiança).
- [x] T023 **QA-009-002 (medium)** — cobrir a regressão no selftest (`7d`: mudou mas sem o texto → não confirmado) mais os casos de borda `7e`–`7i`; refazer o T017 contra **TUI de agente real** (dinâmica), nas duas polaridades.
- [x] T024 **QA-009-003 (low)** — corrigir a deriva plan ↔ código no `plan.md`: seção B (falha sempre sem `python3`, com o motivo) e seção C (predicado forte).
- [x] T025 **QA-009-005 (low)** — backoff progressivo no laço de confirmação (150→800ms), cortando as invocações do CLI no pior caso, que é o caminho de falha.
- [x] T026 Atualizar o aditivo do ADR-0010: a força do predicado é parte da decisão, não detalhe de implementação — quem portar a garantia precisa portar o predicado forte.
- [x] T027 Ressincronizar mirrors e revalidar (selftest nas duas cópias, `diff -q`, smoke real).

**Checkpoint**: o teste adversarial do QA (pane que muda sozinha + entrada descartada) devolve exit ≠ 0; entrega real em pane `bash` **e** em TUI de agente segue devolvendo 0.

---

---

## Fase 8: `apply-qa-fixes` — rodada 2 (gate CONCERNS de 2026-07-29, 2ª revisão)

Alvo único: **QA-009-006**. A sonda de 24 caracteres pressupunha eco verbatim; a
TUI reformata e ecoa só o token do comando, dando falso negativo no formato que o
`orq.md` Step 2 injeta.

- [x] T028 **QA-009-006 (medium)** — trocar o prefixo fixo por **escada de candidatas** em `_delivery_confirmed`: prefixo longo → primeiro token → prefixo 16 → prefixo do piso (8). Basta uma incrementar a contagem. O piso mantém `/mosk-po` e `/mosk-qa` distinguíveis e impede que o prefixo comum `/mosk-` confirme qualquer coisa.
- [x] T029 Fixtures do achado: `7j` (eco parcial real capturado pelo QA), `7k` (slash command com argumento longo). E os guardas contra afrouxamento: `7l` (eco de `/mosk-qa` não confirma envio de `/mosk-dev`) e `7m` (`/mosk-` sozinho não basta).
- [x] T030 Reescrever `_count_occurrences` em bash puro — casamento literal por construção, sem regex, sem subprocesso, e imune a bytes inválidos que faziam o `grep` abortar (o QA esbarrou nisso ao inspecionar a pane).
- [x] T031 Matriz ao vivo nas quatro células: TUI+`/mosk-…`, pane dinâmica com entrada descartada, `bash`, TUI+prosa.
- [x] T032 Alinhar `plan.md` seção C e o aditivo do ADR-0010 à escada de sondas.

**Checkpoint**: TUI + `/mosk-…` com entrega real → rc=0; pane dinâmica com entrada descartada → rc≠0. As duas ao mesmo tempo.

---

## Dependências

```text
Fase 1 (T001–T004)  →  Fase 2 (T005–T007)  →  Fase 3 (T008–T011)
                                            ↘  Fase 4 (T012–T013)
Fase 2 + Fase 3     →  Fase 5 (T014–T018)
Fase 6 (T019–T021)  independente — não bloqueia nem é bloqueada
Fase 7 (T022–T027)  loopback do gate 1; T022 precede T023
Fase 8 (T028–T032)  loopback do gate 2; T028 precede T029
```

- **T004 antes de T005** não é burocracia: é o que separa "corrigi" de "acho que corrigi".
- **T007 trava a Fase 3.** Sem `read` correto a confirmação do `send` não é verificável.
- **T014 depois de tudo que edita script.** Sincronizar antes garante mirror defasado.

## Paralelismo real

- T012 e T013 (US3) correm em paralelo à Fase 5 — investigação não bloqueia documentação.
- T015 e T016 são arquivos distintos, sem sobreposição.
- **T005 e T006 não são paralelos**: mesmo helper, mesmo arquivo.

## Corte de MVP

**T001–T007** (Fases 1 e 2). Devolve visão ao maestro e trava a regressão por
fixture. É defensável parar aqui: o `send` continua podendo perder tarefa, mas
com o `read` funcionando a perda deixa de ser invisível — que era o que impedia
perceber o problema em tempo real.

O acréscimo mais valioso depois do MVP é **T010 + T011**: transforma a perda
detectável em perda impedida.
