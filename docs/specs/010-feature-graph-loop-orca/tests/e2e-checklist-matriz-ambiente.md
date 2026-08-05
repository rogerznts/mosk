# E2E Test Checklist — matriz de ambiente (T034 · SC-005/SC-006)

Verifica que a mesma spec produz o **mesmo conjunto de artefatos e o mesmo
veredito** em três ambientes, e que **nenhum caminho de degradação é fatal**.

Não foi possível executar durante a implementação: exige rodar fora da IDE do
Orca e num runtime sem subagente nativo — dois contextos que a sessão de
desenvolvimento não alcança. As demais validações (`lint-graph`,
`selftest-orca-driver`, `audit-docs-paths`) rodaram e estão limpas.

Cada passo diz a ação e o resultado esperado. Um agente de automação consegue
executar tudo abaixo por linha de comando.

## Execução parcial — 2026-08-05 (durante o `qa-gate`)

**Legenda:** `[x]` executado e passou · `[~]` **simulado**, não literal ·
`[!]` executado e **reprovou** · `[ ]` não executado.

10 dos 22 passos rodaram. O Ambiente B foi simulado removendo as variáveis
`ORCA_*`: exercita a lógica de detecção, que é o que decide o comportamento, mas
o processo seguia dentro da IDE — não é o contexto literal, e está marcado como
tal. O Ambiente C não rodou (sem acesso a runtime Codex). Os passos 4–8, 12, 21 e
22 exigem worker vivo ou spec de teste.

O passo 19 **reprovou** e virou o achado QA-010-006 do gate.

## Ambiente A — dentro da IDE do Orca

- [x] **1. Abrir o projeto no Orca e rodar `bash .claude/mosk/scripts/panes.sh driver --json`**
  Esperado: `"driver":"orca"` com `"reason":"sessao dentro do Orca"`.

- [x] **2. Rodar `bash .claude/mosk/scripts/panes.sh tier --json`**
  Esperado: `"tier":"1"` e `"runtime_decides":false`, se a orquestração
  experimental estiver habilitada. Se estiver desligada: `"tier":"2+"` e um
  `actionable` mandando habilitar em Settings > Experimental — **sem erro**.

- [x] **3. Rodar `bash .claude/mosk/scripts/legal_moves.sh implement`**
  Esperado: o bloco `fan-out disponível nesta fase (modo: unit)` aparece.

- [ ] **4. Numa spec pequena com 2+ tarefas `[P]`, invocar `/mosk-dev implement`**
  Esperado: apresenta o **plano de fan-out** (unidades, agrupamento, critério de
  aceite, teto, equivalente sequencial) e **para**, aguardando aprovação.

- [ ] **5. Aprovar o plano**
  Esperado: as unidades são despachadas; **nenhuma confirmação adicional por
  ramo** é pedida.

- [ ] **6. Ao término, conferir `orca orchestration task-list --json`**
  Esperado: as tasks existem com id — é a prova de provenance que só o Tier 1 dá.

- [ ] **7. Conferir o `phase-history.log` da spec**
  Esperado: **uma** entrada para a onda inteira, não uma por unidade.

- [ ] **8. Rodar `/mosk-qa qa-gate` e abrir o `gate.yaml`**
  Esperado: contém `gate` **e** `quality_score` (0–100).

## Ambiente B — Claude Code, fora da IDE do Orca

- [~] **9. Num terminal comum (fora do Orca), rodar `panes.sh driver --json`**
  Esperado: `"driver":"none"` com `"reason":"sessao fora da IDE do Orca"` e um
  `actionable` mandando abrir o projeto no Orca. **Não** pode eleger o Orca só
  porque o binário está no PATH.

- [~] **10. Rodar `panes.sh tier --json`**
  Esperado: `"tier":"2+"` com `"runtime_decides":true`.

- [~] **11. Rodar `MOSK_ORQ_DRIVER=orca panes.sh driver --json`**
  Esperado: o override explícito é honrado (`"driver":"orca"`) — quem força,
  assume.

- [ ] **12. Rodar a mesma spec do passo 4 com `/mosk-dev implement`**
  Esperado: plano de fan-out apresentado, aprovação única, execução via subagente
  nativo. Mesmos artefatos no disco que no Ambiente A.

- [ ] **13. Rodar `/mosk-qa qa-gate` e comparar com o passo 8**
  Esperado: **mesmo veredito e mesmo `quality_score`** — o score vem de contagem
  de achados, então não deve variar por ambiente.

## Ambiente C — runtime sem subagente nativo (Codex)

- [ ] **14. Rodar `panes.sh tier`**
  Esperado: `2+` com `runtime_decides` — a escolha entre 2 e 3 é do runtime.

- [ ] **15. Rodar `/mosk-dev implement` na mesma spec**
  Esperado: o plano de fan-out **declara explicitamente** que o paralelismo aqui
  é organizacional, não temporal (o ganho é verificação isolada, não tempo).

- [ ] **16. Conferir os artefatos e o gate**
  Esperado: mesmo conjunto de artefatos e mesmo veredito dos Ambientes A e B.

## Degradações — nenhuma pode ser fatal (SC-006)

- [x] **17. Rodar com `orchestration.driver: herdr` no core-config**
  Esperado: falha com **mensagem de migração** citando o ADR-0014, indicando
  ajustar para `auto`. Nunca degrada em silêncio.

- [x] **18. Rodar com `orchestration.driver: none`**
  Esperado: fluxo single-pane, sem erro; o pipeline roda ponta a ponta.

- [!] **19. Renomear temporariamente o binário do Orca e rodar `panes.sh driver`**
  Esperado: motivo `CLI do Orca nao encontrada` e `actionable` de instalação.
  Restaure o binário ao fim.

- [x] **20. Rodar `panes.sh await` sem a camada nativa disponível**
  Esperado: mensagem clara apontando a configuração a habilitar — nunca stack
  trace nem saída vazia.

## Contadores — não devem se contaminar (FR-028)

- [ ] **21. Provocar falha de dispatch numa unidade (fechar o terminal do worker)**
  Esperado: a unidade volta ao join como **unidade falha**, o humano decide, e o
  contador `tentativa N/max` do delivery-loop **não** é incrementado.

- [ ] **22. Rodar `legal_moves.sh qa-gate` depois de um FAIL**
  Esperado: `tentativa N/max` reflete apenas voltas do gate, com a série de
  `quality_score` ao lado.
