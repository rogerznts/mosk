# Implementation Plan: Operação em loops e grafos + Orca como atuador único

**Branch**: `010-feature-graph-loop-orca` | **Date**: 2026-08-04 | **Spec**: [spec.md](./spec.md)
**Input**: `docs/specs/010-feature-graph-loop-orca/spec.md`

## Summary

Descer o grafo e o loop do MOSK da granularidade de **fase** para a de
**trabalho**: tornar executável o `[P]` que o `tasks.md` já produz e descarta,
tornar o verificador independente de quem implementou, e consolidar o atuador
multi-pane no Orca — removendo o Herdr e corrigindo dois defeitos ativos de
comportamento na camada de orquestração.

Nada aqui inventa mecanismo novo: o seam de tiers reusa o padrão que o ADR-0004
já validou no `bench-mode`, e o Tier 1 se apoia em primitivas que o Orca já
oferece (Task DAG com dependências, `worker_done`, `ask`/`reply`, decision gates).

## Technical Context

**Linguagem**: Markdown (prompts/tasks), YAML (grafo/config/templates), Bash
(scripts). Sem aplicação compilada.
**Dependências**: nenhuma obrigatória. O Orca é **opcional** e só habilita o
Tier 1 (ADR-0014 §1).
**Armazenamento**: filesystem — o disco é a fronteira de estado (ADR-0004 §1).
**Testes**: não há suíte. Validação é `lint-graph.sh`, `selftest-orca-driver.sh`
(único verificador automatizável de comportamento), `audit-docs-paths.sh` e
smoke manual em spec real.
**Plataforma-alvo**: Claude Code e Codex; dentro e fora da IDE do Orca.
**Escopo**: ~15 arquivos sob `mosk/.claude/`, mais o espelho local e docs.

## Onde o código vai — regra que precede tudo

**Todo produto vai sob `mosk/`.** É o único diretório que `npx degit` envia. A
raiz `.claude/` é ambiente de execução local deste repo e **não** faz ship;
editar lá não chega a nenhum consumidor.

Ordem operacional para cada mudança: editar em `mosk/.claude/…` → ressincronizar
o espelho da raiz apenas quando for necessário exercitar a mudança nesta sessão →
nunca o contrário.

```text
mosk/.claude/mosk/
├── scripts/
│   ├── panes.sh              # fachada: remover backend dual, + `tier`, + diagnóstico
│   ├── orca.sh               # + ack, question, run bind, ask/reply, worker-start, worker-read
│   ├── herdr.sh              # REMOVIDO
│   ├── create-new-feature.sh # US5: regex ancorada + base-10 em --number
│   ├── legal_moves.sh        # US4: apresentar jogada paralela
│   ├── common.sh             # limpeza de resíduo Herdr
│   └── selftest-orca-driver.sh # cobertura dos caminhos novos
├── tasks/
│   ├── implement.md          # -§5 auto-verificação; +plano de fan-out e join
│   └── qa-gate.md            # +score; verificação de ACs migra para cá
├── agents/orq.md             # backend único; guia versionado; desambiguar handoff
├── data/fanout-seam.md       # NOVO: contrato dispatch_wave + tiers
├── templates/qa-gate-tmpl.yaml # +score
├── pipeline-graph.yaml       # qa-gate → mode: agent; fan-out/join
└── core-config.yaml          # driver reduzido; native_tasks: auto; score_threshold
```

Fora de `mosk/`: `docs/architecture/glossary.md` (verbetes) e docs do repo
(README, TASKS.md, `.claude/rules/scripts.md`, `docs/index.md`).

## Abordagem técnica

### 1. O seam `dispatch_wave` é contrato de prompt, não binário

Segue o precedente do ADR-0004: o `invoke_phase_agent` vive descrito em prosa
(`bench-mode.md`), não como executável. `dispatch_wave(plan) → results` recebe o
mesmo tratamento — descrito em `data/fanout-seam.md` e referenciado pelo
`implement.md`, mantendo o prompt da task curto (regra do MOSK: conciso,
low-token).

O que **é** mecânico e vira script: a **detecção de tier**, que já tem lugar
natural na fachada.

### 2. Detecção de tier na fachada: `panes.sh tier`

`panes.sh` já é o ponto único de resolução de capacidade. Ganha um subcomando:

```bash
panes.sh tier [--json]   # {"tier":1|2|3,"reason":"...","actionable":"..."}
```

Resolve pela tabela do ADR-0013 §3 e devolve, junto do tier, a **ação corretiva**
quando o ambiente poderia oferecer mais (ex.: "dentro da IDE, orquestração
experimental desligada → habilite em Settings > Experimental"). Isso satisfaz
FR-005 e FR-026 no mesmo lugar, sem espalhar detecção por prompts.

### 3. Simplificação da fachada é subtrativa

`resolve_driver` perde a sondagem dual, o desempate por variável de sessão entre
dois backends e o mecanismo `unsupported`/exit 3. Ganha uma condição: em `auto`,
**sessão dentro da IDE `E` check** — substituindo o fallback "primeiro backend
cujo `check` passar", que com um só backend passou a significar "binário no PATH,
logo orquestre" (ADR-0014 §3.1).

### 4. Gaps do Orca em ordem de severidade

Primeiro os dois que são **defeito**, não melhoria — porque mudam
comportamento observável hoje:

| Ordem | Gap | Natureza |
|---|---|---|
| 1 | `ack` da Delivery antes da próxima janela | defeito: lote reentregue |
| 2 | `question` entre os tipos que despertam a espera | defeito: worker pendurado |
| 3 | Run criada/vinculada antes de Task | contrato |
| 4 | `ask`/`reply` expostos no wrapper | capacidade (habilita US3) |
| 5 | caminho supervisionado composto para iniciar worker | caminho preferido |
| 6 | leitura tipada de transcript em vez de terminal cru | robustez (lição da 009) |

### 5. Verificador independente é menor do que parece

Na prática, chamar `/mosk-qa qa-gate` numa sessão já dá contexto separado. Os dois
pontos que realmente violam a independência são: o `implement.md` §5, que manda o
próprio dev conferir os ACs do que acabou de escrever; e o grafo, que declara
`qa-gate` como `mode: skill` — dizendo o contrário do que se quer.

A mudança é: remover §5 do `implement.md`, migrar a checagem de ACs para o
`qa-gate.md`, e corrigir o grafo. **No fan-out (US3) é que a verificação por ramo
passa a exigir subagente de fato** — cada unidade verifica antes de reportar.

### 6. Score é aditivo e não decide nada

`score: 0..100` entra ao lado de `status` no `gate.yaml` e no template. O corte
vai para `core-config.yaml` (`qa.score_threshold: 85`). A apresentação do loop
passa a mostrar o score das voltas anteriores junto de `tentativa N/max` — dois
FAILs com score idêntico sinalizam estagnação, não teimosia. **O `status` segue
árbitro único de terminação** (ADR-0008 §3, intocado).

## Premissas e restrições

- Nenhuma mudança pode tornar o Orca obrigatório. O caminho default —
  sessão única, sem atuador — permanece intacto.
- `current_phase` não ramifica; uma onda = uma entrada no `phase-history.log`.
  É o que preserva o contador do ADR-0008 (FR-027).
- O `[P]` não é redefinido: mantém "arquivos distintos, sem dependências". O
  plano passa a honrá-lo; em dúvida, sequencial.
- Prompts permanecem concisos. Contrato longo vai para `data/`, não para a task.
- `AGENTS.md` é gerado — regenerar via `link-codex-skills.sh`, nunca editar.
- ADRs e specs arquivadas não são tocados (registro histórico).

## Dependências

- **Internas**: US3 depende de US1 (Tier 1) e US2 (verificação por ramo). US4
  depende de US3. US1, US2 e US5 são mutuamente independentes.
- **Externas**: Orca (opcional; orquestração é feature experimental do app).
- **Cruzada**: a spec `004` está `active` em `implement` com as pendentes
  T015–T022 tocando templates de spec/plan e docs. A sobreposição com esta spec é
  **apenas em docs** (T021). O `pipeline-graph.yaml` já foi implementado pela 004
  e não está entre as pendentes dela — sem conflito estrutural.

## Marcos de implementação

**M1 — Atuador único e correto** (US1 + US5) · *entregável sozinho*
Remoção do Herdr, fachada simplificada, `tier`, detecção por sessão, os seis gaps
em ordem de severidade, guia versionado no `orq.md`, selftest estendido. US5 entra
aqui por ser trivial e por afetar toda criação de spec futura.

**M2 — Loop confiável** (US2) · *entregável sozinho*
Auto-verificação sai do `implement`, ACs migram para o `qa-gate`, `qa-gate` vira
`mode: agent`, `score` no gate e no template, corte configurável, apresentação com
histórico de scores.

**M3 — Fan-out** (US3) · *depende de M1 + M2*
`data/fanout-seam.md`, derivação do plano a partir do `[P]`, aprovação única,
join, suspensão por ramo, mapeamento nos três tiers, regra de tier único por onda.

**M4 — Grafo e vocabulário** (US4)
`fan-out`/`join` no `pipeline-graph.yaml`, `parallel_with` com semântica,
`legal_moves.sh`, verbetes "onda" e *handoff* no glossário, docs do repo.

## Estratégia de validação

Não há suíte de testes; a validação é deliberada e em quatro camadas:

1. **Automatizável** — `selftest-orca-driver.sh` estendido para os caminhos novos
   (ack, `question`, resolução de tier, base-10 em `--number`, regex ancorada) e
   `lint-graph.sh` após tocar o `pipeline-graph.yaml`.
2. **Estrutural** — abrir cada arquivo alterado junto de quem o referencia;
   `grep -r` nos agentes para toda task tocada; `audit-docs-paths.sh` no fim.
3. **Smoke em spec real** — conduzir uma spec pequena ponta a ponta com
   `/mosk-orq` dentro da IDE, e a mesma fora dela, confirmando degradação sem erro.
4. **Matriz de ambiente (SC-005/SC-006)** — três ambientes: dentro da IDE do
   Orca · Claude Code sem Orca · runtime sem subagente. Mesmo conjunto de
   artefatos e mesmo veredito nos três; nenhum caminho de degradação fatal.

## Artefatos de apoio

**Nenhum criado.** `research.md` não se justifica — o contrato do Orca já foi
lido do binário e destilado nos ADR-0013/0014. `data-model.md` não se aplica: as
entidades (plano de fan-out, onda, unidade, score) são de prompt e já estão
definidas no `spec.md`. `contracts/` não se aplica: o contrato do seam é
entregável de implementação (`data/fanout-seam.md`), não de planejamento.

## Complexity Tracking

| Complexidade | Por que é necessária | Alternativa simples rejeitada porque |
|---|---|---|
| Três tiers em vez de um | Os ambientes-alvo têm capacidades assimétricas | Acoplar ao Orca quebra Codex e Claude puro; nivelar por baixo joga fora isolamento que já existe de graça (ADR-0013, Alt. 1–2 e 4) |
| Seam novo em vez de estender `invoke_phase_agent` | Join e plano de onda não cabem em "uma fase, um agente" | Sobrecarregar a assinatura empurra a barreira para todo consumidor (ADR-0013, Alt. 3) |
| Dois contadores de retry coexistindo | Medem coisas diferentes: falha de dispatch × não-convergência de qualidade | Unificar faria instabilidade de terminal consumir tentativas de correção da spec (ADR-0013 §6) |
| Fachada mantida com um só backend | É onde vive a degradação `none`, requisito do toolkit | Colapsar em `orca.sh` reacopla o prompt ao CLI e desfaz o ponto de extensão dos tiers (ADR-0014, Alt. 2) |
