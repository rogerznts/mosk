# Implementation Plan: Agentes diretos — o template ship a camada de agentes

**Branch**: `011-feature-direct-agents` | **Date**: 2026-08-05 | **Spec**: [spec.md](./spec.md)
**Input**: `docs/specs/011-feature-direct-agents/spec.md`

## Summary

Fazer o MOSK entregar agentes **invocáveis** a quem o instala. Hoje o template
ship 23 skills e zero agentes: o `mode: agent` do grafo não tem lastro, o Tier 2
do fan-out não existe fora deste repositório, e nenhum agente pode chamar outro.

Três frentes independentes em risco e acopladas em ordem: shipar a camada (US1),
dar-lhe protocolo (US2), e padronizar o nome de branch (US3).

## Technical Context

**Linguagem**: Markdown (agentes/tasks), YAML (config/templates), Bash (scripts).
**Dependências**: nenhuma nova. O Tier 2 usa o primitivo de subagente do runtime.
**Testes**: sem suíte. Validação por `selftest-orca-driver.sh` (48 asserções),
`lint-graph.sh`, `audit-docs-paths.sh` e smoke de instalação via degit.
**Escopo**: 12 agentes migrados, 2 scripts alterados, ~63 caminhos reescritos.

## Onde o código vai

**Todo produto sob `mosk/`.** A raiz `.claude/` é ambiente local e não ship.
Esta spec cria um diretório novo **no template**:

```text
mosk/.claude/
├── agents/                   # NOVO — passa a existir e a shipar
│   └── mosk-<n>.md           # definição completa (era mosk/agents/<n>.md)
├── skills/mosk-<n>/SKILL.md  # wrapper fino, gerado
└── mosk/
    ├── agents/               # REMOVIDO como fonte (conteúdo migra)
    ├── tasks/ templates/ data/ scripts/   # inalterados
    └── scripts/
        ├── sync-agents-skills.sh   # direção invertida
        └── create-new-feature.sh   # formato de branch
```

## Abordagem técnica

### 1. Mover os agentes quebra 63 caminhos — e a correção é uma melhoria

Os agentes referenciam `../tasks/`, `../scripts/`, `../data/` — 63 ocorrências.
Hoje `mosk/.claude/mosk/agents/dev.md` + `../tasks/` resolve para
`mosk/.claude/mosk/tasks/`. Depois da migração, `mosk/.claude/agents/mosk-dev.md`
+ `../tasks/` resolveria para `mosk/.claude/tasks/`, que não existe.

**Decisão: converter para caminhos relativos à raiz do install**
(`.claude/mosk/tasks/implement.md`), que é o padrão **já usado pelas tasks**
(`.claude/mosk/scripts/check-prerequisites.sh`). Isso não é adaptação, é
correção: caminho relativo-ao-arquivo quebra quando o arquivo muda de lugar;
relativo-à-raiz não. É reescrita mecânica, verificável por contagem.

### 2. Migração é de conteúdo, não de reescrita

Cada `mosk/.claude/mosk/agents/<n>.md` vira `mosk/.claude/agents/mosk-<n>.md`
com front-matter (`name`, `description`) no topo e o corpo preservado. A
`skill-description` declarada continua sendo a fonte da `description` — só muda
de arquivo. **Nada de reescrever persona**: mudança de local e de caminho, mais
front-matter. Qualquer alteração de conteúdo é escopo de outra spec.

### 3. O sync inverte a direção

`sync-agents-skills.sh` deixa de ter dois modos concorrentes. Passa a: ler
`agents/mosk-<n>.md` → gerar `skills/mosk-<n>/SKILL.md`. O modo
`skills-to-agents` perde o referente e sai. O `--clean` passa a considerar órfão
o que não tem agente correspondente.

**Compatibilidade:** instalação antiga tem skills apontando para
`mosk/agents/<n>.md`. Rodar o sync novo reaponta. O que não pode acontecer é
falhar em silêncio quando a fonte antiga sumiu — daí o AC 6 da US1.

### 4. O protocolo vive nos prompts, não em código

Não há mecanismo que imponha a fronteira rota × execução (ADR-0016, risco
residual). O que existe é: a matriz declarada em cada agente que pode invocar, e
a instrução de suspender diante de sinal de rota. Vai para o corpo do agente
migrado, na mesma passada da US1 — abrir os 12 arquivos duas vezes seria
desperdício.

### 5. Branch e pasta deixam de ser a mesma string

Hoje `rebuild_branch_name` produz um nome usado para as duas coisas. Passa a
produzir **duas**: `BRANCH_NAME` (`{tipo}/{NNN}-{nome}`) e `SPEC_DIR_NAME`
(`{NNN}-{tipo}-{nome}`). É a mudança estrutural da US3; o resto é consequência.

A detecção de número precisa aceitar `^([a-z]+/)?([0-9]{3})-` — **mantendo a
âncora** que a spec 010 introduziu. Perder a âncora reintroduz o bug em que
`docs/adr-0012-0014-x` contava como spec 014.

## Premissas e restrições

- Migração é mecânica; conteúdo de persona não muda.
- Branches existentes não são renomeados.
- `AGENTS.md` é gerado — regenerar, nunca editar.
- O bench (ADR-0002) não é tocado.
- A spec 004 segue ativa; não há sobreposição de arquivos com esta.

## Dependências

- **Internas**: US2 depende de US1 (não há o que invocar antes). US3 é
  independente e pode entregar a qualquer momento.
- **Externas**: nenhuma. Ao contrário da 010, nada aqui depende do Orca.
- **Herdada**: este branch carrega o merge da 010. O PR revisará ambas.

## Marcos

**M1 — Camada de agentes** (US1) · *desbloqueia o resto*
Criar `mosk/.claude/agents/`, migrar os 12 agentes com front-matter, converter os
63 caminhos, inverter o sync, validar o roster 12/11.

**M2 — Protocolo** (US2) · *mesma passada dos arquivos de M1*
Matriz de invocação nos agentes que podem invocar; regra de suspensão diante de
sinal de rota; profundidade 1; declarar-antes/reportar-depois.

**M3 — Nome de branch** (US3) · *independente*
Separar `BRANCH_NAME` de `SPEC_DIR_NAME`; detecção nos dois formatos; validação
de tipo na criação; selftest estendido.

**M4 — Fechamento**
Smoke de instalação via degit em diretório limpo (é o único jeito de provar
SC-001), ressincronizar espelho e camadas geradas, auditorias.

## Estratégia de validação

1. **Automatizável** — `selftest-orca-driver.sh` estendido para a numeração nos
   dois formatos, sem regredir as 48 asserções; `lint-graph.sh`.
2. **Contagem** — zero ocorrências de `../tasks/` nos agentes migrados; 12
   agentes e 11 skills puras; toda skill apontando para agente existente.
3. **Smoke de instalação** — `npx degit` num diretório limpo e verificar
   `.claude/agents/` populado. **É a única prova de SC-001**, porque é o único
   teste que enxerga o que o consumidor recebe.
4. **Invocação real** — invocar um agente migrado por `subagent_type` e confirmar
   retorno em contexto isolado.
5. **Estrutural** — `audit-docs-paths.sh`; abrir cada agente junto da skill
   correspondente.

## Artefatos de apoio

**Nenhum.** Os três ADRs já carregam o desenho; `research.md` não tem pergunta
aberta; as entidades cabem no `spec.md`; não há contrato externo novo.

## Complexity Tracking

| Complexidade | Por que | Alternativa rejeitada porque |
|---|---|---|
| Duas camadas por agente | Slash command e invocabilidade são primitivos distintos do runtime | Só agents mata `/mosk-dev`; só skills mantém o gap atual (ADR-0015, Alt. 1) |
| Reescrever 63 caminhos | Mover o arquivo quebra caminho relativo-ao-arquivo | Manter a camada intermediária preserva três camadas para servir duas (ADR-0015, Alt. 2) |
| Branch ≠ pasta | Barra criaria hierarquia e quebraria o glob `specs/*/` | Pasta seguindo o branch quebra ordenação e todo consumidor do glob (ADR-0017, Alt. 4) |
| Dois formatos de branch convivendo | Renomear quebra PR aberto e referência de CI | Renomear tudo: ganho cosmético, custo real (ADR-0017, Alt. 3) |
