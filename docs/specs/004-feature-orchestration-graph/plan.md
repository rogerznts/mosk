# Implementation Plan: Grafo de orquestração consultivo

**Spec**: `004-feature-orchestration-graph` · **Fonte de verdade**: [ADR-0006](../../architecture/adr/adr-0006-consultative-orchestration-graph.md)

## Summary

Introduzir `pipeline-graph.yaml` como fonte única do grafo de orquestração e
religar os consumidores para **derivar** dele, apagando as cópias hardcoded.
Tudo sob o invariante: o grafo computa e apresenta jogadas legais; o humano
decide; nada auto-executa. Entrega em três fatias sequenciadas (US1 → US2 →
US3), cada uma testável de forma independente.

## Technical Context

- **Linguagem/runtime**: Markdown + YAML + Bash. Sem app compilado, sem suíte
  de testes. Validação é manual (ler estrutura, checar consistência de
  prompt/workflow) + idempotência de scripts com `--dry-run`.
- **Invariante de distribuição**: tudo que embarca vive sob `mosk/`. O
  `pipeline-graph.yaml`, o `legal_moves.sh`, e as edições de task/template/
  script vão em `mosk/.claude/mosk/…`. O único item fora de `mosk/` é a nota
  de sync no `README.md` da raiz (FR-016), que **não** embarca.
- **Dependência de leitura de YAML em Bash**: `legal_moves.sh` e o validador
  em `common.sh` precisam ler o grafo. Preferir parsing minimalista sem
  depender de `yq` externo (o grafo tem forma simples e controlada);
  degradar com aviso se o arquivo faltar/malformar (Edge Cases).

## Abordagem por fatia

### Fase 1 — Grafo + legal_moves (US1, P1) — MVP

1. **Esquema do `pipeline-graph.yaml`** (`mosk/.claude/mosk/pipeline-graph.yaml`):
   - `nodes:` com atributo de classe explícito (`kind: phase | side-trip`),
     `agent`, `mode` (skill|agent), `optional`. Fases: `specify, plan, tasks,
     implement, qa-gate, archived`. Side-trips: `discovery, prd, architecture,
     ux, ui, readiness, security-review, clarify`.
   - `edges:` (`from`, `to`, `guard?`, `default?`) — só transições que avançam
     o ponteiro.
   - `escalations:` (`signal`, `from[]`, `to`, `return_to: origin`, `scope`) —
     saltos para side-trip com retorno.
   - `guards:` catálogo nomeado com `kind: fact | judgment` e `question`.
2. **`core-config.yaml`**: adicionar chave `orchestration.graph:
   .claude/mosk/pipeline-graph.yaml` (FR-014). Espelhar no mirror da raiz.
3. **`legal_moves.sh`** (`mosk/.claude/mosk/scripts/`): recebe
   `<current_phase>`, lê o grafo, filtra `edges` com `from == fase`, avalia os
   guards `fact` (ler `docs/prd/` para `base_ready`; ler `status` do
   `gate.yaml` para `gate_*`), imprime as arestas que passam com a `default`
   marcada e os guards `judgment` sinalizados como "avaliar". Nunca decide.
   `--help`, `set -e`, `source common.sh`. Saída legível + `--json` opcional.
4. **`mosk-suggestion/SKILL.md`**: remover a tabela "estado → próximo agente"
   (FR-006); reescrever o Workflow para chamar `legal_moves.sh` e apresentar
   as jogadas, o agente avaliando os guards `judgment`. Mantém "só sugere".
5. **`spec-meta-tmpl.yaml`**: remover `clarify` do comentário-enum de
   `current_phase` (FR-010).

### Fase 2 — Derivar as demais representações + auditoria (US2, P2)

6. **Blocos de escalação** em `qa-gate.md` e `implement.md`: substituir o
   texto fixo por uma instrução "consulte `escalations:` do grafo para esta
   fase e monte o bloco no formato padrão". Definir o **formato do bloco em um
   único lugar** (ex.: seção no `project-rule-tmpl.md` ou um snippet dedicado)
   e referenciá-lo (FR-007).
7. **`index-docs`**: acrescentar passo que renderiza um mermaid do fluxo em
   `docs/index.md` a partir do grafo (FR-008). Determinístico e idempotente.
8. **`common.sh` / `update_spec_phase`**: antes de escrever, validar
   `(current_phase → nova_fase)` contra `edges` do grafo. Se ilegal → warning
   + append em log de histórico + prosseguir. Transições legais também logadas
   (FR-009). Definir o log: `spec-meta` não suporta arrays (só escalares) →
   usar um arquivo separado por spec, ex.: `phase-history.log` no diretório da
   spec (linhas ISO 8601 + `from→to` + legal/ilegal). Nunca bloqueia.

### Fase 3 — Fusão parcial spec + plan (US3, P3) — por último

9. **Documento de design único**: definir o arquivo (recomendação:
   `spec.md` com seções `## Especificação` e `## Plano`, ou um `design.md`) e
   ajustar `specify.md`/`plan.md` para escrever em seções distintas do mesmo
   arquivo; `tasks.md` continua separado (FR-011).
10. **Ripple de scripts/templates** (FR-012): `setup-plan.sh` deixa de copiar
    um `plan.md` isolado; `check-prerequisites.sh` passa a checar a **seção de
    plano**; unir `spec-template.md` + `plan-template.md` num template de
    design; `tasks-template.md` intacto.
11. **Migração idempotente** (FR-013): script (ou extensão do
    `migrate-docs-structure.sh`) que funde `spec.md`+`plan.md` de specs
    legados no documento de design, preservando conteúdo; `--dry-run`.

## Decisões de projeto herdadas do ADR-0006

- Grafo **só orquestração**; artefatos ficam em `promotion.defaults`
  (`core-config.yaml`). Guards podem **consultar** existência de artefato,
  nunca possuir regra de promoção.
- Guards **híbridos**: só `base_ready` e status do `gate.yaml` são `fact`;
  `diff_security_sensitive` fica `judgment` (grep = falsa confiança).
- `edges` vs `escalations` em listas separadas.
- Transição fora do grafo: **avisa-e-segue**, nunca bloqueia.

## Open items (a resolver em `grill`/`clarify` se necessário)

- **Parser de YAML em Bash**: minimalista próprio vs exigir `yq`. Recomendação:
  minimalista, dado o esquema controlado; decidir na implementação.
- **Nome do documento de design** (Fase 3): reusar `spec.md` com seções vs
  novo `design.md`. Impacta a migração e os consumidores; decidir no início da
  Fase 3.
- **Local do formato único do bloco de escalação** (Fase 2): snippet dedicado
  vs seção no `project-rule-tmpl.md`.

## Validação

Manual, por fatia:

1. **Fase 1**: `legal_moves.sh` para cada fase de pipeline; grep confirmando
   ausência da tabela no `mosk-suggestion`; diff do enum tmpl↔README.
2. **Fase 2**: alterar um guard e ver bloco/mermaid refletirem; transição
   ilegal gera warning + log e prossegue.
3. **Fase 3**: smoke run do pipeline num spec de scratch; migração de um spec
   legado com `--dry-run` + idempotência (rodar 2x).
4. **Geral**: `bash mosk/.claude/mosk/scripts/audit-docs-paths.sh --quiet`.

## Project Structure — arquivos tocados

```
mosk/.claude/mosk/
├── pipeline-graph.yaml            # NOVO (FR-001..004,014)
├── core-config.yaml               # + chave orchestration.graph
├── scripts/
│   ├── legal_moves.sh             # NOVO (FR-005)
│   ├── common.sh                  # update_spec_phase valida + loga (FR-009)
│   ├── setup-plan.sh              # Fase 3 (FR-012)
│   └── check-prerequisites.sh     # Fase 3 (FR-012)
├── tasks/
│   ├── qa-gate.md                 # bloco derivado (FR-007)
│   ├── implement.md               # bloco derivado (FR-007)
│   ├── index-docs.md              # render mermaid do grafo (FR-008)
│   ├── specify.md                 # Fase 3 (FR-011)
│   └── plan.md                    # Fase 3 (FR-011)
├── templates/
│   ├── spec-meta-tmpl.yaml        # remove clarify do enum (FR-010)
│   ├── spec-template.md           # Fase 3: fundir em design (FR-012)
│   └── plan-template.md           # Fase 3: fundir em design (FR-012)
└── skills/mosk-suggestion/SKILL.md# deriva do grafo (FR-006)

README.md (raiz)                   # nota de sync, mão (FR-016) — não embarca
```
