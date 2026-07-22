---
promote: docs/architecture/adr/adr-0007-graph-schema-shell-legible.md
promote_mode: copy
---

# ADR-0007 — Schema do `pipeline-graph.yaml` "shell-legível": um registro por linha, zero-dep

- Status: aceito
- Data: 2026-07-22
- Autor: Vinicius (mosk-architect)
- Contexto: escalação de prontidão do `/mosk-sm` na spec `004-feature-orchestration-graph` — gate dos T006 (`legal_moves.sh`) e T013 (`update_spec_phase`).
- Origem: blocker de readiness — como ler YAML aninhado/array em shell, em projetos consumidores arbitrários, sem dependência dura.
- Depende de: [adr-0006](../../../architecture/adr/adr-0006-consultative-orchestration-graph.md) (grafo consultivo — este ADR fecha o "open item" de parsing).

## Contexto

Dois consumidores em **shell** precisam ler o `pipeline-graph.yaml`:
`legal_moves.sh <phase>` e `update_spec_phase` (`common.sh`). Restrições
reais, verificadas no ambiente:

- O helper compartilhado atual (`read_spec_meta`, via `awk`) é
  **scalar-only** — não lê map aninhado nem array. O grafo é aninhado +
  arrays (`edges`, `escalations`, `from[]`).
- `yq` **não é dependência garantida** num projeto consumidor, e as major
  v3/v4 têm sintaxe incompatível (aqui: `yq 3.4.3`). O ethos MOSK é
  POSIX-friendly, git-optional, **sem dependência dura**.

Observação que destrava o problema: **o shell não precisa desserializar
YAML arbitrário.** Ele precisa de **projeções baratas e fixas**:

- `legal_moves.sh`: arestas com `from == <phase>` (+ `to`/`guard`/`default`)
  e o `kind` dos guards citados.
- `update_spec_phase`: teste de pertinência — `(from → to)` é aresta legal?

Os consumidores **ricos** (o agente do `mosk-suggestion`, o `index-docs`,
os blocos de escalação em `qa-gate`/`implement`) são **agentes LLM** que
leem o YAML nativamente — não precisam de parser em shell.

## Decisão

Adotar um **schema "shell-legível": todo registro cabe em uma linha**,
em *flow style* do YAML (mapas inline). Continua sendo YAML 100% válido
(agentes e `yq`, se houver, leem normalmente), mas cada registro é
**auto-contido numa linha**, então `awk`/`grep` extraem por padrão de
linha — sem parser de estado aninhado.

**1. Forma do schema (contrato de autoria).**

```yaml
version: 1

# Nós: block map, UM nó por linha, valor em flow style.
nodes:
  specify:         { kind: phase,     agent: mosk-po,       mode: skill }
  implement:       { kind: phase,     agent: mosk-dev,      mode: skill }
  security-review: { kind: side-trip, agent: mosk-security, mode: agent, optional: true }
  archived:        { kind: phase, terminal: true }

# Arestas: sequência, UMA aresta por linha (flow map).
edges:
  - { from: implement, to: qa-gate,         default: true }
  - { from: implement, to: security-review, guard: diff_security_sensitive }

# Escalações: sequência, UMA por linha; from = lista inline.
escalations:
  - { signal: missing_adr, from: [plan, tasks, implement], to: architecture, return_to: origin, scope: spec }

# Guards: block map, UM guard por linha.
guards:
  base_ready:              { kind: fact,     question: "Existe docs/prd/ não-vazio?" }
  diff_security_sensitive: { kind: judgment, question: "O diff toca superfície sensível (auth, query, cripto, path)?" }
```

Regra invariante do schema: **um registro por linha; nada de blocos
multi-linha aninhados.** É a única disciplina exigida do autor.

**2. Parser em shell = 3 projeções em `common.sh`, keadas à convenção
de linha (só `awk`/`grep`, zero-dep):**

- `graph_edges_from <phase>` → linhas de `edges:` cujo `from:` casa;
  devolve `to`/`guard`/`default`.
- `graph_edge_exists <from> <to>` → teste de pertinência (legal?).
- `guard_kind <name>` → `fact` | `judgment` a partir de `guards:`.

`legal_moves.sh` usa (1)+(3); `update_spec_phase` usa (2). Os agentes não
tocam o shell — leem o YAML direto.

**3. Degradação.** Arquivo ausente/ilegível → as projeções retornam vazio
+ warning; consumidores prosseguem (alinha com os Edge Cases da spec).
`update_spec_phase` nunca bloqueia (ADR-0006 #7).

**4. Lint de forma (barato, recomendado).** Um checador (novo ou dentro do
`audit-docs-paths.sh`) valida que cada item de `edges:`/`escalations:` e
cada entrada de `nodes:`/`guards:` é **uma linha** e casa o padrão — impede
que uma edição multi-linha quebre o `awk` silenciosamente.

## Alternativas consideradas

1. **YAML aninhado canônico + mini-parser awk de propósito geral.**
   Rejeitada: parsing de YAML aninhado/array em `awk` é frágil (quoting,
   multi-linha, anchors) — exatamente a superfície de bug que o
   `read_spec_meta` scalar-only evitou.
2. **Exigir `yq`.** Rejeitada: presença não garantida em consumidores;
   split v3/v4; fere o zero-dep.
3. **Cache flat gerado** (`edges.tsv` derivado do YAML rico). Rejeitada
   como primária: reintroduz artefato derivado que **pode divergir** da
   fonte — contra o princípio anti-drift do ADR-0006. Aceitável só como
   otimização futura com regeneração verificada.
4. **Estender o `read_spec_meta` para YAML geral.** Rejeitada: generaliza
   o parser (custo/bug) quando o certo é **restringir o schema** e manter
   o parser trivial.

## Consequências

**Positivas:**

- **Fonte única, zero-dep.** Um só arquivo YAML, válido e legível por
  agentes/`yq`, e trivialmente parseável por `awk` — sem cache derivado,
  sem `yq`, sem drift.
- **Parser mínimo.** Só 3 projeções em `common.sh`; superfície de bug
  baixa, no espírito do reader scalar existente (restringe o schema em vez
  de generalizar o parser).
- Destrava T006/T013 sem tocar o invariante consultivo.

**Negativas / trade-offs:**

- **Disciplina de autoria:** um registro por linha (sem aninhamento
  multi-linha). Mitigado pelo lint de forma (Decisão #4).
- Linhas de `nodes:`/`guards:` podem ficar longas — legibilidade menor que
  um bloco indentado. Aceito: previsibilidade de parsing > estética.

## Impacto na spec 004

- **T001** passa a incluir o **contrato de forma** acima (não só o
  conteúdo do grafo).
- **T006/T013** ganham as 3 projeções de `common.sh` como base — deixam de
  estar bloqueados.
- **T012** (mermaid): render por passo determinístico continua preferível;
  o agente pode gerar, mas a fonte é o mesmo YAML de linha previsível.
- Sugestão: adicionar uma tarefa de **lint de forma** (Decisão #4) à Fase 1.
