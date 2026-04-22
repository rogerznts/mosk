# Plano — Refactor estrutural do MOSK v2

## Context

O MOSK hoje mistura três convenções herdadas sem uma visão unificada:

- **Pipeline SpecKit** (`specify → plan → tasks`) concentrado no `mosk-po`, junto com atribuições BMAD de backlog (epic/story) — o PO carrega 11 tarefas, sobrecarregado.
- **Paths em `core-config.yaml`** que suportam formato monolítico (`docs/prd.md`) E sharded (`docs/prd/`) ao mesmo tempo, criando redundância.
- **Stories em `docs/stories/`** vivendo órfãs das specs que as originaram (`docs/specs/{id}/`).
- **Dois fluxos concorrentes no README** ("From Zero" vs "Daily Flow") que são o mesmo pipeline em graus diferentes de maturidade, mas parecem paths distintos.
- **Artefatos de preâmbulo** (discovery, arquitetura, UI) sem pasta canônica — caem soltos na raiz de `docs/` ou somem.
- **Nenhum mecanismo de promoção** de artefatos de spec para a base: toda mudança de PRD/arquitetura/UI que nasce numa feature fica presa dentro dela ou polui a base antes da entrega.

O objetivo deste refactor é consolidar MOSK em uma estrutura única, espelhada e explícita:

1. **Um só fluxo** com preâmbulo opcional (elimina a falsa dicotomia From Zero × Daily).
2. **Duas camadas espelhadas de docs**: base canônica (`docs/<dominio>/`) + mini-docs por spec (`docs/specs/{id}/<dominio>/`).
3. **Promoção declarativa via front-matter** (`promote:` + `promote_mode:`) — artefato de spec vira canônico no archive, sem contaminar a base durante o desenvolvimento.
4. **Stories dentro das specs** (`specs/{id}/stories/`) em vez de pasta global.
5. **Rename `mosk-webdesigner` → `mosk-ui-expert`** (Tiago, dono do taste system, passa a se chamar UI Expert — responsável pelo acabamento visual, design system e páginas premium). **`mosk-ux-expert` (Salete) permanece intocado** — responsável por user flows, wireframes e front-end specs.
6. **Config enxuta** sem duplicação de formato (sharded-only por padrão; shard como ação opcional de transformação preservada).
7. **Patch de migração** para projetos brownfield rodável via Claude Code, que reorganiza `docs/` existente + atualiza config + migra stories.
8. **Numeração de specs resistente a concorrência** — múltiplos devs criando specs em paralelo não colidem; cada spec ganha `spec-meta.yaml` com número, branch, status e fase atual; `create-new-feature.sh` faz push atômico com retry automático.
9. **`docs/index.md` como porta de entrada** — gerado/atualizado automaticamente em pontos-chave do fluxo (boot, specify, archive) com Overview dos 5 domínios + tabela de specs ativas e arquivadas; aproveita a task `index-docs` que já existe mas está órfã.
10. **Handoffs dinâmicos de pipeline → preâmbulo** — agentes de pipeline (po, sm, dev, qa) passam a detectar sinais durante a execução que demandam a ajuda de um agente de preâmbulo (analyst, pm, architect, ux-expert, ui-expert) e sugerem explicitamente o handoff ao usuário, em formato padronizado, sem invocar por conta própria.

Resultado esperado: fluxo uniforme para greenfield e brownfield, menos confusão de paths, agentes com responsabilidades mais claras, e caminho reversível de adoção para instalações antigas.

---

## Arquitetura alvo

### Estrutura de `docs/` (base do projeto)

```
docs/
├── discovery/              # mosk-analyst (base)
│   ├── brief.md
│   ├── market-research.md
│   ├── competitor-analysis.md
│   └── brainstorming/
├── prd/                    # mosk-pm (sharded-only)
│   ├── index.md
│   ├── goals.md
│   ├── personas.md
│   ├── user-stories.md
│   ├── metrics.md
│   └── scope-out.md
├── architecture/           # mosk-architect (sharded-only)
│   ├── index.md
│   ├── tech-stack.md
│   ├── coding-standards.md
│   ├── source-tree.md
│   ├── data-models.md
│   └── adr/                # decision records
├── ui/                     # mosk-ux-expert (flows/wireframes) + mosk-ui-expert (design-system/styles)
│   ├── index.md
│   ├── flows/              # mosk-ux-expert
│   ├── wireframes/         # mosk-ux-expert
│   ├── design-system.md    # mosk-ui-expert (ex-webdesigner, taste system)
│   └── styles/             # mosk-ui-expert
├── qa/                     # mosk-qa (base)
│   └── gates/
└── specs/                  # coração — tudo por feature/fix/refactor/...
    ├── 001-feature-checkout-coupon/
    │   ├── spec.md
    │   ├── plan.md
    │   ├── tasks.md
    │   ├── prd-delta.md         # opcional — mudanças à PRD global
    │   ├── discovery/           # opcional — discovery específico
    │   ├── architecture/        # opcional — ADRs e decisões da feature
    │   ├── ui/                  # opcional — flows/wireframes da feature
    │   ├── stories/             # stories vivem AQUI (não em docs/stories/)
    │   ├── tests/               # e2e checklists do dev
    │   └── gate.yaml            # qa-gate desta spec
    └── archive/                 # specs concluídas
```

### Convenção front-matter `promote:`

Artefatos criados dentro de `specs/{id}/` que representam saber canônico emergente levam front-matter declarando destino:

```yaml
---
promote: docs/architecture/adr/adr-0007-coupon-service.md
promote_mode: copy
---
```

**Modos suportados:**

| `promote_mode` | Comportamento no archive |
|---|---|
| `copy` | Copia o arquivo inteiro para `promote:` (path absoluto do destino). Falha se destino já existe. |
| `append` | Concatena o corpo (sem front-matter) no final do arquivo em `promote:`. |
| `manual` | Não aplica automaticamente. Archive imprime o arquivo, o destino sugerido e pede aplicação manual. Usado pelo `prd-delta.md`. |

Sem front-matter `promote:`, o artefato fica congelado dentro da spec arquivada.

### Fluxo único (substitui From Zero + Daily Flow)

```
PREÂMBULO (opcional, usado quando a base está incompleta)
  mosk-analyst   → docs/discovery/     ou  specs/{id}/discovery/
  mosk-pm        → docs/prd/           ou  specs/{id}/prd-delta.md
  mosk-architect → docs/architecture/  ou  specs/{id}/architecture/
  mosk-ux-expert → docs/ui/flows/|wireframes/  ou  specs/{id}/ui/
  mosk-ui-expert → docs/ui/design-system.md|styles/  ou  specs/{id}/ui/

PIPELINE (sempre igual)
  mosk-po: specify → plan → tasks   (ou full-spec)
  mosk-sm: readiness dos stories em specs/{id}/stories/
  mosk-dev: implement
    ↳ loop com mosk-qa: qa-gate → apply-qa-fixes → qa-gate
  mosk-dev: archive
    ↳ fase de promoção aplica os front-matter promote:
    ↳ move specs/{id}/ → specs/archive/{id}/
```

---

## Execução — 10 workstreams

Executar na ordem. Cada workstream é auto-contido e tem critério de aceite claro.

### Workstream A — `core-config.yaml` + paths base

**Arquivo:** `mosk/.claude/mosk/core-config.yaml`

**Substituir conteúdo atual por:**

```yaml
markdownExploder: true
specs:
  root: docs/specs
  archive: docs/specs/archive
  storiesSubdir: stories
  testsSubdir: tests
  gateFile: gate.yaml
discovery:
  root: docs/discovery
prd:
  root: docs/prd
  indexFile: docs/prd/index.md
architecture:
  root: docs/architecture
  indexFile: docs/architecture/index.md
  adrDir: docs/architecture/adr
ui:
  root: docs/ui
  indexFile: docs/ui/index.md
qa:
  gatesDir: docs/qa/gates
promotion:
  defaults:
    "specs/*/architecture/adr-*.md": { target: docs/architecture/adr/, mode: copy }
    "specs/*/ui/flows/*.md":          { target: docs/ui/flows/,       mode: copy }
    "specs/*/prd-delta.md":           { target: docs/prd/,             mode: manual }
devLoadAlwaysFiles:
  - docs/architecture/coding-standards.md
  - docs/architecture/tech-stack.md
  - docs/architecture/source-tree.md
slashPrefix: MOSK
```

**Removido:** `prdFile`, `prdVersion`, `prdSharded`, `prdShardedLocation`, `architectureFile`, `architectureVersion`, `architectureSharded`, `architectureShardedLocation`, `epicFilePattern`, `customTechnicalDocuments`, `devDebugLog`, `devStoryLocation`.

**Critério de aceite:** `bash -n` (YAML válido via parse simples), arquivo < 30 linhas, nenhuma chave legada presente.

---

### Workstream B — Purge de paths antigos em tasks, templates e checklists

**Tasks a atualizar** (substituições conforme lista abaixo):

| Arquivo | Substituição |
|---|---|
| `tasks/shard-doc.md` | **Preservar** como ação opcional de transformação. Atualizar inputs: não opera mais em `docs/prd.md` na raiz. Novo fluxo: input é um arquivo monolítico dentro da pasta canônica (ex.: `docs/prd/raw.md` ou `docs/prd/draft.md` gerado por `mosk-pm`), output são shards na **mesma pasta** (`docs/prd/index.md` + seções). Ajustar também exemplos: `md-tree explode docs/prd/raw.md docs/prd` e `md-tree explode docs/architecture/raw.md docs/architecture`. |
| `tasks/create-story.md:31` | `Sharded PRD/Architecture (docs/prd/, docs/architecture/)` → `PRD in docs/prd/ and Architecture in docs/architecture/` |
| `tasks/create-story.md:38` | Remover linha sobre `docs/prd.md` monolítico na raiz (já não existe). |
| `tasks/create-story.md:251-252` | `docs/stories/epic-{n}-story-{m}.md` → `docs/specs/{spec-id}/stories/epic-{n}-story-{m}.md` |
| `tasks/draft-story.md:15` | Remover `devStoryLocation` do lookup; usar `specs.root` + `storiesSubdir` + spec corrente. |
| `tasks/draft-story.md:21` | Remover condicional `prdSharded` (agora sempre sharded). |
| `tasks/draft-story.md:22,80,109` | `{devStoryLocation}/{epicNum}.{storyNum}.story.md` → `{specs.root}/{currentSpec}/{storiesSubdir}/{epicNum}.{storyNum}.story.md` |
| `tasks/draft-story.md:44-45` | Remover condicional de monolítico/sharded; ler sempre `docs/architecture/index.md`. |
| `tasks/draft-story.md:74` | Manter `docs/architecture/unified-project-structure.md` (continua válido). |
| `tasks/review-story-draft.md:15,17` | Substituir `devStoryLocation` por referência a `specs.root` + `storiesSubdir`. |
| `tasks/design-tests.md:12` | `story_path: '{devStoryLocation}/{epic}.{story}.*.md'` → `story_path: '{specs.root}/{currentSpec}/{storiesSubdir}/{epic}.{story}.*.md'` |
| `tasks/review-story.md:12` | idem acima. |
| `tasks/assess-nfr.md:12,15,61` | Trocar `devStoryLocation` e `architecture.architectureFile` pelas novas chaves; `docs/architecture/*.md` permanece. |
| `tasks/assess-risk.md:12` | `docs/stories/{epic}.{story}.*.md` → `{specs.root}/{currentSpec}/{storiesSubdir}/{epic}.{story}.*.md` |
| `tasks/apply-qa-fixes.md:20` | `story_root: devStoryLocation` → `story_root: derivado de specs.root + currentSpec + storiesSubdir` |

**Templates a atualizar:**

| Arquivo | Mudança |
|---|---|
| `templates/prd-tmpl.yaml:8` | `filename: docs/prd.md` → `filename: docs/prd/index.md` |
| `templates/architecture-tmpl.yaml:8,19` | `filename: docs/architecture.md` → `filename: docs/architecture/index.md`; atualizar linha 19 para `docs/prd/index.md`. |
| `templates/existing-project-prd-tmpl.yaml:8` | `filename: docs/prd.md` → `filename: docs/prd/index.md` |
| `templates/existing-project-architecture-tmpl.yaml:8` | `filename: docs/architecture.md` → `filename: docs/architecture/index.md` |
| `templates/fullstack-architecture-tmpl.yaml:8,19` | Idem architecture + substituir `docs/front-end-spec.md` por `docs/ui/index.md` |
| `templates/story-tmpl.yaml:8` | `filename: docs/stories/{{epic_num}}.{{story_num}}.{{story_title_short}}.md` → `filename: {{specs_root}}/{{current_spec}}/stories/{{epic_num}}.{{story_num}}.{{story_title_short}}.md` |
| `templates/prd-tmpl.yaml:198` | `id: ux-expert-prompt` — **manter** (UX Expert continua intocado; este handoff continua apontando para ele). |

**Checklists a atualizar:**

| Arquivo | Mudança |
|---|---|
| `checklists/architect-checklist.md:11-12` | `docs/architecture.md` → `docs/architecture/index.md`; `docs/prd.md` → `docs/prd/index.md` |
| `checklists/pm-checklist.md:11` | `docs/prd.md` → `docs/prd/index.md` |
| `checklists/story-readiness-checklist.md:11` | `docs/stories/` → `docs/specs/{id}/stories/` |

**Critério de aceite:** `grep -rn "docs/prd\.md\|docs/architecture\.md\|devStoryLocation\|prdFile\|architectureFile\|prdSharded\|architectureSharded" mosk/.claude/mosk/` retorna vazio.

---

### Workstream C — Rename `mosk-webdesigner` → `mosk-ui-expert` (UX Expert permanece intocado)

**Intenção:** Tiago (ex-webdesigner, dono do taste system) passa a se chamar UI Expert — é o responsável por acabamento visual, design system, páginas premium e estilos. Salete (`mosk-ux-expert`) **permanece como está** — user flows, wireframes, front-end specs. Os dois agentes coexistem em `docs/ui/` com papéis distintos (UX = estrutura/comportamento; UI = visual/acabamento).

**Arquivos a renomear:**

1. `mosk/.claude/mosk/agents/webdesigner.md` → `mosk/.claude/mosk/agents/ui-expert.md`
2. `mosk/.claude/skills/mosk-webdesigner/` → `mosk/.claude/skills/mosk-ui-expert/`
3. `mosk/.claude/agents/mosk-webdesigner.md` → `mosk/.claude/agents/mosk-ui-expert.md`

**Tasks do agente** (`webdesign-*.md`) — decisão: **manter os nomes de task** (`webdesign-brutalist`, `webdesign-minimalist`, `webdesign-soft`, `webdesign-redesign`, `webdesign-stitch`, `webdesign-output`). São comandos do agente e renomear causaria ruído sem benefício prático. O agente UI Expert os referencia exatamente como hoje. Revisar só os textos internos que digam "webdesigner" como papel, substituindo por "UI Expert".

**Conteúdo a atualizar dentro dos arquivos renomeados:**

- `mosk-ui-expert/SKILL.md` — frontmatter `name: mosk-ui-expert`, `description: "UI: interfaces premium, redesign, estilos visuais e design systems."`; body aponta para `../../mosk/agents/ui-expert.md`.
- `agents/ui-expert.md` (ex-webdesigner.md) — título, persona e body trocam "Web Designer" / "webdesigner" por "UI Expert" / "ui-expert". Preservar integralmente o taste system, estilos e referências às tasks `webdesign-*.md`.
- `.claude/agents/mosk-ui-expert.md` — frontmatter atualizado; 6 linhas de mapeamento de tasks (`../mosk/tasks/webdesign-*.md`) permanecem apontando aos mesmos arquivos.

**Agentes que permanecem como estão:**

- `mosk-ux-expert` (Salete) — nenhuma alteração.
- `mosk/.claude/mosk/agents/ux-expert.md`, `mosk/.claude/skills/mosk-ux-expert/`, `mosk/.claude/agents/mosk-ux-expert.md` — intactos.

**Outras referências a ajustar** (apenas `webdesigner`, não `ux-expert`):

- `mosk/README.md` — seção `## Agents` (linha que descreve `/mosk-webdesigner`) passa a descrever `/mosk-ui-expert`; seção `## Web Designer and the Taste System` renomeada para `## UI Expert and the Taste System`; tabela de comandos (`/mosk-webdesigner brutalist`, etc.) vira `/mosk-ui-expert brutalist` etc.
- `mosk/.claude/README.md:47` — lista `- \`mosk-webdesigner\`` → `- \`mosk-ui-expert\``.
- `mosk/.claude/mosk/skills/mosk-help/SKILL.md` — qualquer menção a `/mosk-webdesigner`.
- `mosk/CLAUDE.md` — se citar webdesigner.
- `mosk/.claude/rules/project.md` (do repo MOSK, se mencionar).

**Sincronização final:**

- Rodar `bash mosk/.claude/mosk/scripts/sync-agents-skills.sh --clean --dry-run` para verificar órfãos (o `mosk-webdesigner` será detectado como órfão depois do rename do arquivo fonte).
- Rodar sem `--dry-run` após validação.
- Rodar `bash mosk/.claude/mosk/scripts/link-codex-skills.sh` para refrescar `.codex/`.

**Critério de aceite:**
- `grep -rn "webdesigner\|mosk-webdesigner" mosk/` retorna vazio (ou só em CHANGELOG/histórico).
- `grep -rn "ux-expert\|mosk-ux-expert" mosk/` **continua encontrando ocorrências** do UX Expert intocado (não é zero — é o esperado).
- `sync-agents-skills.sh` passa sem warnings após `--clean`.
- Os 6 arquivos `tasks/webdesign-*.md` permanecem nos seus locais e nomes originais.

---

### Workstream D — `archive.md` com fase de promoção

**Arquivo:** `mosk/.claude/mosk/tasks/archive.md`

**Reescrever** para inserir a fase 4 (promoção) antes do move. Esboço:

```markdown
# archive

Arquivar uma spec concluída: promover artefatos canônicos para a base
e mover a pasta para docs/specs/archive/.

## Steps

1. Determinar qual spec arquivar (igual ao atual).

2. Validar prontidão (igual ao atual: tasks.md todas [x]).

3. **Scan de promoção** — percorrer docs/specs/<id>/**/*.md buscando
   front-matter YAML com chave `promote:`. Para cada arquivo encontrado,
   ler também `promote_mode:` (default: copy).

4. **Aplicar promoções** (interativo — apresentar tabela e confirmar em bloco):

   | Arquivo | Modo | Destino | Status |
   |---|---|---|---|
   | specs/001-.../architecture/adr-0007-coupon-service.md | copy | docs/architecture/adr/adr-0007-coupon-service.md | novo |
   | specs/001-.../prd-delta.md | manual | docs/prd/ | manual |

   - `copy`: copia o arquivo (com front-matter intacto); falha se destino existe — pergunta ao usuário.
   - `append`: concatena corpo (sem front-matter) no final do destino.
   - `manual`: apenas lista o arquivo para o usuário aplicar a mão; não toca na base.

5. Criar `docs/specs/archive/` se não existir.

6. Mover a pasta: `mv docs/specs/<id> docs/specs/archive/<id>`.

7. Registrar nota de encerramento em `docs/specs/archive/<id>/spec.md` com
   data, status final e resumo das promoções aplicadas.

8. Oferecer criação de PR (mantém comportamento atual).

## Guardrails

- Nunca sobrescrever destino existente em `copy` sem confirmação.
- `manual` nunca edita a base — apenas imprime instruções.
- Se o scan encontrar `promote:` sem `promote_mode:`, assumir `copy`.
- Front-matter `promote:` é preservado no arquivo movido para archive
  (auditabilidade).
```

**Critério de aceite:** task roda num caso sintético em `/tmp` com 1 spec contendo 3 arquivos com diferentes modos; todos os destinos resultantes conferem; arquivo `manual` não é copiado; relatório final imprime contagem correta.

---

### Workstream E — Estender `boot.md` para scaffolding de `docs/`

**Arquivo:** `mosk/.claude/mosk/tasks/boot.md`

**Adicionar Phase 2.5 — Scaffold docs structure** entre Phase 2 e Phase 3:

```markdown
### Phase 2.5 - Scaffold docs/ structure

Create the canonical docs/ skeleton if it does not exist. Works for both
greenfield (empty docs/) and brownfield (partial docs/).

For each path below, create only if missing. Never overwrite existing files.

- docs/discovery/ (with README.md explaining the folder's purpose)
- docs/prd/ (with index.md placeholder)
- docs/architecture/ (with index.md placeholder + adr/ subdir)
- docs/ui/ (with index.md placeholder + flows/ subdir)
- docs/qa/gates/
- docs/specs/

Each README.md explains:
- which agent writes here (e.g., "mosk-analyst writes discovery artifacts here")
- the distinction between base and per-spec content (base = project-wide;
  per-spec = docs/specs/{id}/<domain>/)
- what gets promoted from spec to base at archive time

If the project is brownfield (has code but no .claude/rules/, or existing
docs/ layout), suggest running `migrate-docs-structure.sh` before
continuing. Do not run it automatically.
```

**Critério de aceite:** rodar `boot` em `/tmp/mock-project` vazio produz a estrutura completa sem erros; rodar em projeto com `docs/prd.md` existente avisa sobre migração sem sobrescrever nada.

---

### Workstream F — Novo script `migrate-docs-structure.sh`

**Arquivo novo:** `mosk/.claude/mosk/scripts/migrate-docs-structure.sh`

**Espelhar padrão de `migrate-ctx-skills-to-rules.sh`**: `set -e`, parse de `--dry-run`/`--keep-old`/`--help`, uso de `SCRIPT_DIR`/`INSTALL_ROOT`, logs com verbos `create`/`move`/`skip`/`would`, contadores finais. Reutilizar helpers de `common.sh` onde aplicável.

**Comportamento:**

1. **Detecção:** decide que há migração a fazer se qualquer um existir:
   - `docs/prd.md` (monolito)
   - `docs/architecture.md` (monolito)
   - `docs/stories/` (diretório global)
   - `docs/brainstorming-session-results.md` (solto na raiz)
   - `docs/front-end-spec.md` (solto na raiz)
   - `.claude/mosk/core-config.yaml` com chaves legadas (`prdFile`, `devStoryLocation`, etc.)

2. **Criar skeleton** (igual ao `boot.md Phase 2.5`):
   - `docs/discovery/`, `docs/discovery/brainstorming/`
   - `docs/prd/` (se já existe sharded, preserva conteúdo)
   - `docs/architecture/`, `docs/architecture/adr/`
   - `docs/ui/`, `docs/ui/flows/`
   - `docs/qa/gates/`
   - `docs/specs/`

3. **Migrar PRD:**
   - Se `docs/prd.md` existe E `docs/prd/` já tem conteúdo sharded: move `docs/prd.md` para `docs/prd/raw.md` (com log) — fica disponível como bruto caso o usuário queira re-sharded.
   - Se `docs/prd.md` existe E `docs/prd/` está vazio: move `docs/prd.md` → `docs/prd/raw.md`. Avisa o usuário que pode rodar `shard-doc` para gerar `index.md` + seções a partir desse bruto.
   - Sem monolito: nada a fazer.

4. **Migrar Architecture:** análogo ao PRD (destino `docs/architecture/raw.md`).

5. **Migrar Stories:**
   - Se `docs/stories/` existe:
     - Listar stories por prefixo epic (`epic-N-story-M.md` ou `N.M.*.md`).
     - Para cada epic N, tentar casar com spec em `docs/specs/` que contenha essa numeração (heurística: mesmo prefixo de 3 dígitos ou match por epic number nos títulos de specs).
     - Se casou: mover para `docs/specs/<spec-id>/stories/`.
     - Se não casou: mover para `docs/specs/_orphan-stories/` e avisar o usuário para redirecionar manualmente.
   - Com `--keep-old`: copia em vez de mover.

6. **Migrar arquivos soltos:**
   - `docs/brainstorming-session-results.md` → `docs/discovery/brainstorming/`
   - `docs/front-end-spec.md` → `docs/ui/index.md` (se `docs/ui/index.md` não existe)

7. **Reescrever `core-config.yaml`** para o novo schema (Workstream A). Antes de sobrescrever, salva backup em `.claude/mosk/core-config.yaml.legacy`.

8. **Gerar `spec-meta.yaml` retroativamente** para cada spec em `docs/specs/*/` que não tenha o arquivo: parse do nome da pasta (`###-type-short-name`), inferir `spec_number`, `type`, `spec_id`, `branch` (assume mesmo nome da pasta), `status: active` ou `archived` (baseado em estar em `archive/` ou não), `created_at: <data de mtime da pasta>`. `current_phase`: inferir pelo arquivo mais recente na spec (`tasks.md` presente → `implement`; sem `plan.md` → `specify`; etc.). Marcar com comentário `# generated by migrate-docs-structure.sh — please review`.

9. **Regenerar `docs/index.md`** chamando a task `index-docs` ao final (Workstream I). Gera overview + tabelas com as specs recém-migradas.

10. **Relatório final** com contagens: criado, movido, skipped, avisos (stories órfãs, conflitos resolvidos, specs sem meta-info), e próximos passos sugeridos (rodar `mosk-boot` para regerar `.claude/rules/`, revisar stories órfãs, auditar `spec-meta.yaml` gerados, etc.).

**Flags:**
- `--dry-run`: só imprime o que faria.
- `--keep-old`: preserva `docs/prd.md`, `docs/stories/`, etc. (copia em vez de mover).
- `--help|-h`: uso.

**Execução manual via Claude Code:** documentado no README como:

```bash
bash .claude/mosk/scripts/migrate-docs-structure.sh --dry-run   # revisar
bash .claude/mosk/scripts/migrate-docs-structure.sh              # aplicar
```

**Critério de aceite:**
- `bash -n` passa.
- Rodar contra `/tmp/mock-brownfield` com `docs/prd.md`, `docs/architecture.md`, `docs/stories/epic-1-story-1.md`, `docs/specs/001-feature-x/` produz a estrutura correta.
- Specs pré-existentes ganham `spec-meta.yaml` com comentário de revisão manual.
- `docs/index.md` é gerado ao final com tabelas refletindo as specs migradas.
- Rodar 2x é idempotente (no-op na segunda).
- `--dry-run` não escreve nada.
- Com `--help`, imprime uso e sai com 0.

---

### Workstream G — Documentação do framework

**`mosk/README.md`** — reescrever seções `## Flows`, `## Agents`, `## Installed Structure`:

- **Unificar os diagramas** em um único fluxo com preâmbulo opcional (remover "From Zero" e "Daily Flow" como headings distintos; substituir por "Flow" único com nota "use preâmbulo se a base do projeto ainda não existe/está incompleta").
- **Tabela de agentes** atualizada — remove linha `/mosk-webdesigner`, adiciona `/mosk-ui-expert` com a descrição do taste system; `/mosk-ux-expert` permanece na tabela inalterado.
- **Seção `## Web Designer and the Taste System`** renomeada para `## UI Expert and the Taste System`; exemplos `/mosk-webdesigner brutalist` → `/mosk-ui-expert brutalist` (etc.).
- **Installed Structure** atualizada com novo layout de `docs/` (discovery, prd, architecture, ui, qa, specs).
- **Nova seção `## Document Organization`** explicando as duas camadas (base vs spec), a convenção `promote:`, os três modos (`copy`/`append`/`manual`), e a regra de decisão base-vs-spec. Incluir nota sobre papel conjunto de UX Expert (flows/wireframes) e UI Expert (design system/styles) em `docs/ui/`.
- **Nova seção `## Migrating Existing Projects`** com instruções do `migrate-docs-structure.sh`.
- **Nota sobre `shard-doc` como transformação opcional** — referência rápida de quando usar (quando o PM gera `docs/prd/raw.md` ou o Architect gera `docs/architecture/raw.md` monolítico e o usuário quer quebrar em seções).

**`.claude/rules/project.md`** (do repo MOSK) — atualizar para refletir:
- A nova arquitetura de `docs/` como padrão do produto.
- A convenção `promote:` + `promote_mode:` como regra oficial do framework.
- Rename `mosk-webdesigner` → `mosk-ui-expert` (e registrar explicitamente que `mosk-ux-expert` continua distinto).

**`CLAUDE.md` do repo** — atualizar seção "Repository Shape" para refletir rename do webdesigner e nova estrutura.

**Template de `.claude/rules/project.md` gerado pelo boot** (dentro de `boot.md` ou um template em `templates/`) — incluir a matriz agente × artefato × local × momento como referência canônica para os agentes operarem.

**Critério de aceite:** `grep -n "From Zero\|Daily Flow\|webdesigner" mosk/README.md mosk/CLAUDE.md mosk/.claude/rules/*.md` retorna vazio. `grep -n "ux-expert" mosk/README.md` ainda encontra a linha do UX Expert na tabela de agentes (esperado). Novo README renderiza corretamente em preview (um único diagrama Mermaid, seções na ordem certa).

---

### Workstream H — Numeração de specs resistente a concorrência + vinculação branch↔spec

**Problema:** hoje `create-new-feature.sh` pega `max + 1` varrendo branches remotas, locais e pastas. Não tem push atômico nem retry. Dois devs rodando `/mosk-po full-spec` no mesmo instante pegam o mesmo número e criam pastas/branches colidentes.

**Solução em três camadas** (simples o suficiente para uso real, sem lock distribuído):

#### H1 — Push atômico imediato com retry automático

Atualizar `mosk/.claude/mosk/scripts/create-new-feature.sh` — função principal passa a:

1. `git fetch --all --prune` (já faz).
2. Calcular `next_number` (já faz).
3. Criar branch local `git checkout -b {###}-{type}-{name}` (já faz).
4. **NOVO:** criar diretório da spec + copiar template + commit inicial (`git add` + `git commit -m "spec({###}): bootstrap"`).
5. **NOVO:** `git push -u origin <branch>` imediatamente.
6. **NOVO:** se o push falhar com "already exists" ou "rejected":
   - `git fetch --all --prune`
   - recalcular `next_number`
   - renomear branch local: `git branch -m <novo-nome>`
   - renomear pasta: `mv docs/specs/<antigo> docs/specs/<novo>`
   - amendar commit se necessário e retentar push
   - até MAX_RETRIES=3; se continuar falhando, abortar e instruir o usuário a resolver manualmente.

**Controle via flag `--no-push`** para ambientes sem remote ou testes locais.

#### H2 — Meta-arquivo por spec (`spec-meta.yaml`)

Cada nova spec ganha `docs/specs/{id}/spec-meta.yaml` na criação:

```yaml
spec_number: "005"
spec_id: "005-feature-checkout-coupon"
type: feature
branch: "005-feature-checkout-coupon"
created_at: "2026-04-22T14:30:00Z"
created_by: "Roger <roger.santos@ballroom.com.br>"
status: active        # active | archived
current_phase: specify # specify | plan | tasks | implement | qa-gate | archived
```

**Uso:**
- Ferramentas externas (o index-docs em W-I) leem esse arquivo em vez de fazer parsing do nome da pasta.
- Tasks `plan.md`, `tasks.md`, `implement.md`, `qa-gate.md`, `archive.md` atualizam `current_phase` ao começarem.
- `archive.md` muda `status: active` → `status: archived` e registra `archived_at`.

**Template novo:** `mosk/.claude/mosk/templates/spec-meta-tmpl.yaml`.

**Criação:** `create-new-feature.sh` copia o template e preenche automaticamente.

#### H3 — `common.sh` ganha helpers para ler `spec-meta.yaml`

Novas funções:
- `read_spec_meta(spec_dir)` → emite variáveis shell (igual ao padrão de `get_feature_paths`).
- `update_spec_phase(spec_dir, phase)` → edita `current_phase:` no YAML (via `sed` ou `yq` se disponível; fallback shell).
- `list_active_specs(specs_root)` → ecoa `spec_id` de cada pasta com `status: active`.

**Compatibilidade:** se `spec-meta.yaml` não existe (specs antigas), funções retornam valores inferidos do nome da pasta (fallback comportamento atual).

#### Riscos cobertos

- **Colisão de número:** resolvida pelo retry em H1 — quem pushou primeiro ganha; o segundo renumera automaticamente.
- **Spec sem branch local:** `get_current_branch` em `common.sh` já tem fallback (últimadir mais alta); mantém.
- **Dev que esqueceu de puxar:** o `git fetch --all` no início de cada chamada garante estado fresh.

**Critério de aceite:**
- Smoke test com dois checkouts simultâneos em `/tmp` (dois clones locais do mesmo bare repo) rodando `create-new-feature.sh`: ambos sucedem com números distintos.
- Spec nova tem `spec-meta.yaml` populado corretamente.
- Rodar `list_active_specs` retorna todas as specs ativas.
- `bash -n create-new-feature.sh` passa.

---

### Workstream I — `docs/index.md` automatizado (ativação da task `index-docs`)

**Problema:** `mosk/.claude/mosk/tasks/index-docs.md` já existe e é completa (scan recursivo, organização por pasta, detecção de broken links), mas **nenhum agente a invoca**. Resultado: `docs/index.md` nunca existe em projetos MOSK.

**Objetivo:** transformar `docs/index.md` no **ponto único de entrada** para novos devs — um "vetor" que mostra onde estão discovery, PRD, arquitetura, UI, QA, specs ativas e arquivadas.

#### I1 — Enriquecer `index-docs.md` para conhecer a nova estrutura

Adicionar ao conteúdo da task (sem quebrar o que já faz):

- Seção fixa no topo do `docs/index.md` gerado: **"Project Overview"** com os 5 domínios da base como blocos linkados:

```markdown
# Project Documentation Index

Last updated: 2026-04-22 14:30 UTC

## Overview

- **[Discovery](./discovery/)** — research, briefs, brainstorming
- **[PRD](./prd/index.md)** — product requirements (sharded)
- **[Architecture](./architecture/index.md)** — system design + ADRs
- **[UI](./ui/index.md)** — design system, flows, wireframes
- **[QA](./qa/)** — quality gates

## Active Specs

| # | Spec | Phase | Branch | Created |
|---|---|---|---|---|
| 005 | [feature-checkout-coupon](./specs/005-feature-checkout-coupon/) | implement | 005-feature-checkout-coupon | 2026-04-22 |
| 004 | [fix-login-timeout](./specs/004-fix-login-timeout/) | qa-gate | 004-fix-login-timeout | 2026-04-20 |

## Archived Specs

- [003-feature-profile-settings](./specs/archive/003-feature-profile-settings/) — archived 2026-04-15
- [002-feature-payment-v2](./specs/archive/002-feature-payment-v2/) — archived 2026-04-10

## Domain Contents

{seções existentes de index-docs.md — arquivos por pasta, alfabéticos}
```

A tabela "Active Specs" é montada lendo `docs/specs/*/spec-meta.yaml` (Workstream H). A tabela "Archived Specs" lê `docs/specs/archive/*/spec-meta.yaml`.

#### I2 — Ativação automática em pontos do fluxo

Adicionar invocação de `index-docs` como **último passo** das seguintes tasks:

| Task | Quando dispara | Motivo |
|---|---|---|
| `boot.md` | Fim da Phase 5 (Report) | Gerar `docs/index.md` inicial quando o projeto é preparado. |
| `specify.md` | Após criar spec.md (branch + spec populados) | Nova spec entra na tabela "Active Specs". |
| `archive.md` | Após mover spec → archive/ e aplicar promoções | Spec migra de "Active" para "Archived". |
| `plan.md`, `tasks.md`, `implement.md`, `qa-gate.md` | Após rodar | Atualizar `current_phase` no `spec-meta.yaml` da spec + regenerar index (barato — só re-render). |
| `migrate-docs-structure.sh` | Fim da execução | Regenerar index após reorganização de brownfield. |

**Formato da invocação** dentro de cada task (ex.: no final de `specify.md`):

```markdown
## Final step

Update the global documentation index by executing
`../tasks/index-docs.md` with `docs/` as the target. This is an
automatic refresh — do not ask the user unless there are conflicts.
```

#### I3 — Skill explícito para regeneração manual

Adicionar ao mapeamento de tasks do `mosk-dev` (ou criar tarefa standalone no `mosk-po`):

- `/mosk-dev index-docs` → regenera `docs/index.md` manualmente quando o usuário precisa.

Isso serve de escape hatch quando o index fica desatualizado por edições manuais em `docs/`.

#### I4 — Template canônico para `docs/index.md`

Criar `mosk/.claude/mosk/templates/docs-index-tmpl.md` com a estrutura esperada (Overview + Active/Archived + Domain Contents). A task `index-docs` usa esse template como base quando está criando o arquivo pela primeira vez.

#### Integração com Workstream H

- `index-docs` lê `spec-meta.yaml` de cada spec para montar tabelas "Active Specs" e "Archived Specs" (número, phase, branch, datas).
- Se `spec-meta.yaml` não existe (spec antiga antes da migração), infere do nome da pasta e marca com `⚠️ meta missing` na tabela — sinal para o dev rodar `migrate-docs-structure.sh` de novo ou criar o meta manualmente.

#### Critério de aceite

- Rodar `index-docs` em projeto com 3 specs (2 ativas, 1 arquivada) gera `docs/index.md` com tabelas corretas, links navegáveis e timestamps.
- Após rodar `archive` numa spec ativa, `docs/index.md` reflete a mudança automaticamente (spec desce da tabela "Active" para "Archived").
- `grep -l "index-docs" mosk/.claude/mosk/tasks/specify.md mosk/.claude/mosk/tasks/archive.md mosk/.claude/mosk/tasks/boot.md` retorna todos eles.
- Novo dev abrindo `docs/index.md` em um projeto MOSK tem acesso em 1 clique às 5 bases + lista de specs vivas.

---

### Workstream J — Handoffs dinâmicos de pipeline para preâmbulo

**Problema:** hoje os agentes de pipeline (`po`, `sm`, `dev`, `qa`) não têm mapeamento explícito de escalonamento lateral. `mosk-dev` encontra uma decisão arquitetural ambígua durante `implement` e só "reporta blocker" — não diz ao usuário "chame `/mosk-architect` com este prompt". Isso gera trabalho refeito e subutilização dos agentes de preâmbulo.

**Objetivo:** cada agente de pipeline detecta sinais concretos que exigem a intervenção de um agente de preâmbulo, **sugere o handoff ao usuário** em formato padronizado, e **aguarda decisão** antes de continuar. Mantém o controle humano — nunca invoca outro agente autonomamente.

#### J1 — Seção nova `## Escalation signals` em cada agente de pipeline

Adicionar aos prompts de `mosk-po`, `mosk-sm`, `mosk-dev`, `mosk-qa` uma seção enxuta listando gatilhos → agente → motivo. Exemplo para `mosk-dev`:

```markdown
## Escalation signals

If during execution you detect any of the following, PAUSE the task,
present an "Escalation suggested" block to the user, and wait for
their decision. Never invoke another agent automatically.

- Ambiguity in architecture / data model / API contract not covered by
  `plan.md` or `docs/architecture/` → `/mosk-architect`.
- Missing UI behavior, flow, or interaction spec you need to implement
  → `/mosk-ux-expert` (flows/wireframes) or `/mosk-ui-expert` (visual
  acabamento / design system).
- Missing or contradictory product requirement → `/mosk-pm`.
- Discovery gap (assumption about user/market not backed by evidence)
  → `/mosk-analyst`.
- Story unclear enough that you cannot identify the next task deterministically
  → `/mosk-sm` to re-draft.

## Escalation block format

When you escalate, emit exactly this block to the user (adapt fields):

> **Escalation suggested**
> - Signal: <one line describing what you detected>
> - Recommended agent: `<skill>`
> - Suggested prompt: `<agent> <one-line ask>`
> - Scope: `feature {spec-id}` (answers written to `specs/{id}/<domain>/`)
> - On return: resume `<current task>` from where it paused.

Do not proceed with the blocked step until the user confirms ("go",
"escalate", "skip", or alternative instructions).
```

#### J2 — Matriz de sinais por agente de pipeline

| Agente | Sinal detectado | Agente sugerido | Destino dos outputs |
|---|---|---|---|
| **po** | Demanda vaga, sem brief/PRD coerente | `/mosk-analyst` → brief | `specs/{id}/discovery/` |
| **po** | PRD global defasada vs. pedido | `/mosk-pm` → `prd-delta` | `specs/{id}/prd-delta.md` |
| **po** | Decisão arquitetural não existe em `docs/architecture/` | `/mosk-architect` | `specs/{id}/architecture/` |
| **po** | Feature depende de fluxo/tela ainda não desenhada | `/mosk-ux-expert` | `specs/{id}/ui/` |
| **po** | Feature exige componente visual/acabamento premium | `/mosk-ui-expert` | `specs/{id}/ui/` |
| **sm** | Story depende de flow não especificado | `/mosk-ux-expert` | `specs/{id}/ui/` |
| **sm** | Story tem dependência técnica não resolvida | `/mosk-architect` | `specs/{id}/architecture/` |
| **sm** | Requisito da story conflita com PRD | `/mosk-pm` | `specs/{id}/prd-delta.md` |
| **dev** | Ambiguidade em data model / contrato / stack | `/mosk-architect` | `specs/{id}/architecture/` |
| **dev** | UI spec faltando para componente a implementar | `/mosk-ux-expert` ou `/mosk-ui-expert` | `specs/{id}/ui/` |
| **dev** | Requisito funcional contraditório | `/mosk-pm` | `specs/{id}/prd-delta.md` |
| **dev** | Falta evidência de uso real (assumption) | `/mosk-analyst` | `specs/{id}/discovery/` |
| **qa** | Risco identificado é de decisão arquitetural | `/mosk-architect` | `specs/{id}/architecture/` |
| **qa** | Findings indicam falha de UX (confusão de usuário) | `/mosk-ux-expert` | `specs/{id}/ui/` |
| **qa** | Gap de NFR que muda premissa de produto | `/mosk-pm` | `specs/{id}/prd-delta.md` |

#### J3 — Agentes de preâmbulo ganham awareness de "scope: feature"

Cada agente de preâmbulo (`analyst`, `pm`, `architect`, `ux-expert`, `ui-expert`) ganha uma nota curta no prompt:

```markdown
## When invoked from a pipeline escalation

If the user is redirecting you from a pipeline task (po/sm/dev/qa)
referencing an active spec, write your output INSIDE the spec folder
(`docs/specs/{id}/<your-domain>/`) with a `promote:` front-matter if
the artifact should later become canonical. When done, suggest the
user return to the originating agent to resume the paused task.
```

Onde `<your-domain>` é `discovery/` (analyst), `prd-delta.md` (pm), `architecture/` (architect), `ui/` (ux-expert e ui-expert).

#### J4 — Princípio de controle humano

Em `.claude/rules/project.md` fica registrado como regra do framework:

> **MOSK escalation policy** — agentes sempre sugerem handoff e aguardam confirmação do usuário. Nunca invocam outro agente autonomamente. O usuário é a autoridade que decide se escalona, pula ou pede outro caminho.

Isso protege contra loops de agentes se auto-chamando e mantém previsibilidade.

#### Critério de aceite

- Cada um dos 4 agentes de pipeline (`po.md`, `sm.md`, `dev.md`, `qa.md`) tem seção `## Escalation signals` com ≥ 3 sinais + formato de bloco.
- Cada um dos 5 agentes de preâmbulo (`analyst.md`, `pm.md`, `architect.md`, `ux-expert.md`, `ui-expert.md`) tem seção `## When invoked from a pipeline escalation`.
- Smoke conceitual: rodar um cenário hipotético com `mosk-dev` encontrando ambiguidade de data model produz o bloco de escalation correto, sem executar nada autonomamente.
- `.claude/rules/project.md` documenta o princípio de controle humano.

---

## Ordem de execução recomendada

Sequência pensada para minimizar risco de deixar o template em estado inconsistente:

1. **G-parcial**: criar novo `.claude/rules/project.md` do repo (documenta o alvo). Referência de verdade antes de mexer.
2. **A**: atualizar `core-config.yaml`. Isoladamente seguro.
3. **B**: purge de paths antigos em tasks/templates/checklists + atualização do `shard-doc.md` para operar com `raw.md` dentro da pasta canônica. Valida com `grep`.
4. **C**: rename `mosk-webdesigner` → `mosk-ui-expert` (UX Expert permanece). Roda `sync-agents-skills.sh --clean`.
5. **H**: numeração resistente — atualizar `create-new-feature.sh` (retry + push atômico), criar `spec-meta-tmpl.yaml`, adicionar helpers em `common.sh`. Base que as próximas tasks vão consumir.
6. **D**: reescrever `archive.md` com fase de promoção + atualização de `spec-meta.yaml` (status → archived).
7. **E**: estender `boot.md` com scaffolding + chamar `index-docs` no fim.
8. **I**: enriquecer `index-docs.md` (overview + tabelas de specs via `spec-meta.yaml`) + wire-up automático em `specify`/`plan`/`tasks`/`implement`/`qa-gate`/`archive` + template `docs-index-tmpl.md`.
9. **J**: adicionar `## Escalation signals` aos 4 agentes de pipeline + `## When invoked from a pipeline escalation` aos 5 agentes de preâmbulo + registrar a escalation policy em `.claude/rules/project.md`.
10. **F**: criar `migrate-docs-structure.sh`. Inclui criação retroativa de `spec-meta.yaml` para specs legadas (parse de nome de pasta). Testar em `/tmp/mock-brownfield`.
11. **G-final**: reescrever README, CLAUDE.md; ajustar rules restantes; documentar `docs/index.md` como porta de entrada e a escalation policy.
12. **Validação global** (ver seção abaixo).

---

## Arquivos críticos (resumo de paths)

**Editar:**
- `mosk/.claude/mosk/core-config.yaml` (substituição)
- `mosk/.claude/mosk/tasks/archive.md` (reescrita)
- `mosk/.claude/mosk/tasks/boot.md` (adição de Phase 2.5)
- `mosk/.claude/mosk/tasks/draft-story.md`
- `mosk/.claude/mosk/tasks/create-story.md`
- `mosk/.claude/mosk/tasks/review-story-draft.md`
- `mosk/.claude/mosk/tasks/design-tests.md`
- `mosk/.claude/mosk/tasks/review-story.md`
- `mosk/.claude/mosk/tasks/assess-nfr.md`
- `mosk/.claude/mosk/tasks/assess-risk.md`
- `mosk/.claude/mosk/tasks/apply-qa-fixes.md`
- `mosk/.claude/mosk/tasks/shard-doc.md` (mantido como transformação opcional — atualizar inputs para `docs/<dominio>/raw.md`)
- `mosk/.claude/mosk/tasks/index-docs.md` (enriquecer com Overview + tabelas Active/Archived lendo `spec-meta.yaml`)
- `mosk/.claude/mosk/tasks/specify.md` (chamar `index-docs` ao final + criar `spec-meta.yaml`)
- `mosk/.claude/mosk/tasks/plan.md`, `tasks.md`, `implement.md`, `qa-gate.md` (atualizar `current_phase` no `spec-meta.yaml` + chamar `index-docs`)
- `mosk/.claude/mosk/scripts/create-new-feature.sh` (Workstream H — push atômico + retry + criação de `spec-meta.yaml`)
- `mosk/.claude/mosk/scripts/common.sh` (helpers `read_spec_meta`, `update_spec_phase`, `list_active_specs`)
- `mosk/.claude/mosk/agents/po.md`, `sm.md`, `dev.md`, `qa.md` (Workstream J — seção `## Escalation signals`)
- `mosk/.claude/mosk/agents/analyst.md`, `pm.md`, `architect.md`, `ux-expert.md`, `ui-expert.md` (Workstream J — seção `## When invoked from a pipeline escalation`)
- `mosk/.claude/mosk/templates/prd-tmpl.yaml`
- `mosk/.claude/mosk/templates/architecture-tmpl.yaml`
- `mosk/.claude/mosk/templates/existing-project-prd-tmpl.yaml`
- `mosk/.claude/mosk/templates/existing-project-architecture-tmpl.yaml`
- `mosk/.claude/mosk/templates/fullstack-architecture-tmpl.yaml`
- `mosk/.claude/mosk/templates/story-tmpl.yaml`
- `mosk/.claude/mosk/checklists/architect-checklist.md`
- `mosk/.claude/mosk/checklists/pm-checklist.md`
- `mosk/.claude/mosk/checklists/story-readiness-checklist.md`
- `mosk/.claude/mosk/skills/mosk-help/SKILL.md` (citação do agente)
- `mosk/README.md`
- `mosk/.claude/README.md`
- `mosk/CLAUDE.md`
- `mosk/.claude/rules/project.md`
- `mosk/.claude/rules/coding-standards.md` (se referenciar paths)

**Renomear:**
- `mosk/.claude/mosk/agents/webdesigner.md` → `.../agents/ui-expert.md`
- `mosk/.claude/skills/mosk-webdesigner/` → `.../skills/mosk-ui-expert/`
- `mosk/.claude/agents/mosk-webdesigner.md` → `.../agents/mosk-ui-expert.md`

**Preservar sem alteração (UX Expert permanece intocado):**
- `mosk/.claude/mosk/agents/ux-expert.md`
- `mosk/.claude/skills/mosk-ux-expert/`
- `mosk/.claude/agents/mosk-ux-expert.md`
- `mosk/.claude/mosk/tasks/webdesign-*.md` (6 arquivos — `brutalist`, `minimalist`, `soft`, `redesign`, `stitch`, `output`; nomes de task preservados, consumidos pelo novo `mosk-ui-expert`)

**Deletar:** nenhum arquivo.

**Criar:**
- `mosk/.claude/mosk/scripts/migrate-docs-structure.sh` (novo)
- `mosk/.claude/mosk/templates/spec-meta-tmpl.yaml` (novo — template de metadados por spec)
- `mosk/.claude/mosk/templates/docs-index-tmpl.md` (novo — esqueleto canônico do `docs/index.md`)

**Reusar sem editar:**
- `mosk/.claude/mosk/scripts/common.sh` — helpers `get_repo_root`, `get_current_branch`, `find_feature_dir_by_prefix`, `get_feature_paths`.
- `mosk/.claude/mosk/scripts/migrate-ctx-skills-to-rules.sh` — template de padrão para o novo script.
- `mosk/.claude/mosk/scripts/sync-agents-skills.sh` — cuida do rename webdesigner → ui-expert automaticamente (detecta órfão de `mosk-webdesigner` com `--clean`).
- `mosk/.claude/mosk/scripts/link-codex-skills.sh` — refresh de symlinks após rename.

---

## Verificação end-to-end

### Checks de sanidade (por workstream)

```bash
# A — config parseia
python3 -c "import yaml; yaml.safe_load(open('mosk/.claude/mosk/core-config.yaml'))"

# B — nenhum path legado sobrou (shard-doc.md pode conter "docs/prd" como exemplo — esperado)
grep -rn "docs/prd\.md\|docs/architecture\.md\|devStoryLocation\|prdFile\|architectureFile\|prdSharded\|architectureSharded" mosk/.claude/mosk/ mosk/README.md mosk/.claude/README.md
grep -rn "docs/stories" mosk/.claude/mosk/ mosk/README.md mosk/.claude/README.md

# C — rename completo (deve retornar ZERO para webdesigner; UX Expert permanece)
grep -rn "webdesigner\|mosk-webdesigner" mosk/
grep -rn "mosk-ux-expert" mosk/     # não é zero — ux-expert continua válido

# F — script válido
bash -n mosk/.claude/mosk/scripts/migrate-docs-structure.sh

# Sync ainda passa
bash mosk/.claude/mosk/scripts/sync-agents-skills.sh --dry-run
bash mosk/.claude/mosk/scripts/sync-agents-skills.sh --clean --dry-run

# H — create-new-feature.sh com retry válido
bash -n mosk/.claude/mosk/scripts/create-new-feature.sh
bash -n mosk/.claude/mosk/scripts/common.sh

# I — index-docs está wired em specify, archive e boot
grep -l "index-docs" mosk/.claude/mosk/tasks/specify.md mosk/.claude/mosk/tasks/archive.md mosk/.claude/mosk/tasks/boot.md
```

### Smoke test — greenfield

```bash
mkdir -p /tmp/mosk-greenfield && cd /tmp/mosk-greenfield
cp -r /Users/admin/Projects/mosk/mosk/.claude .
# Simular /mosk-boot manualmente (ler boot.md e criar docs/)
# Verificar estrutura:
tree docs/
# Esperado:
#   docs/discovery/README.md
#   docs/prd/index.md
#   docs/architecture/index.md (+ adr/)
#   docs/ui/index.md (+ flows/)
#   docs/qa/gates/
#   docs/specs/
```

### Smoke test — brownfield

```bash
mkdir -p /tmp/mosk-brownfield && cd /tmp/mosk-brownfield
cp -r /Users/admin/Projects/mosk/mosk/.claude .
# Recriar estado legado
mkdir -p docs/stories docs/specs/001-feature-x
echo "# PRD" > docs/prd.md
echo "# Arch" > docs/architecture.md
echo "# Story" > docs/stories/epic-1-story-1.md
echo "# Brainstorm" > docs/brainstorming-session-results.md

# Rodar migração (dry-run primeiro)
bash .claude/mosk/scripts/migrate-docs-structure.sh --dry-run
# Aplicar
bash .claude/mosk/scripts/migrate-docs-structure.sh

# Verificar:
tree docs/
# Esperado:
#   docs/discovery/brainstorming/brainstorming-session-results.md
#   docs/prd/raw.md (conteúdo do antigo docs/prd.md — pode ser shardeado depois via shard-doc)
#   docs/architecture/raw.md (conteúdo do antigo docs/architecture.md)
#   docs/ui/ (criado; index.md pode estar vazio ou herdado de docs/front-end-spec.md se existia)
#   docs/specs/001-feature-x/ (intacto)
#   docs/specs/_orphan-stories/epic-1-story-1.md (não casou com spec)
#   .claude/mosk/core-config.yaml (novo schema)
#   .claude/mosk/core-config.yaml.legacy (backup)

# Idempotência
bash .claude/mosk/scripts/migrate-docs-structure.sh
# Esperado: "Nothing to migrate. Structure already up to date."
```

### Smoke test — archive com promoção

```bash
cd /tmp/mosk-brownfield
mkdir -p docs/specs/002-feature-y/{architecture/adr,ui/flows,stories,tests}
cat > docs/specs/002-feature-y/architecture/adr-0007.md <<'EOF'
---
promote: docs/architecture/adr/adr-0007.md
promote_mode: copy
---
# ADR 0007
EOF
cat > docs/specs/002-feature-y/prd-delta.md <<'EOF'
---
promote: docs/prd/
promote_mode: manual
---
# PRD delta
EOF
echo "- [x] task 1" > docs/specs/002-feature-y/tasks.md

# Simular /mosk-dev archive 002
# Verificar:
ls docs/architecture/adr/adr-0007.md          # deve existir (copy)
ls docs/specs/archive/002-feature-y/          # deve existir (movido)
# spec-meta.yaml deve ter status: archived
grep "status:" docs/specs/archive/002-feature-y/spec-meta.yaml
# docs/index.md deve ter 002 na tabela "Archived Specs"
grep "002-feature-y" docs/index.md
```

### Smoke test — concorrência de numeração (Workstream H)

```bash
# Setup: bare repo + dois clones
mkdir -p /tmp/mosk-concurrency/{origin,dev-a,dev-b}
cd /tmp/mosk-concurrency/origin && git init --bare
cd /tmp/mosk-concurrency
git clone origin dev-a && git clone origin dev-b
cp -r /Users/admin/Projects/mosk/mosk/.claude dev-a/
cp -r /Users/admin/Projects/mosk/mosk/.claude dev-b/

# Commit inicial
cd dev-a && git add . && git commit -m "init" && git push

cd /tmp/mosk-concurrency/dev-b && git pull

# Disparar criação SIMULTÂNEA
cd /tmp/mosk-concurrency/dev-a
bash .claude/mosk/scripts/create-new-feature.sh "feature A" &
cd /tmp/mosk-concurrency/dev-b
bash .claude/mosk/scripts/create-new-feature.sh "feature B" &
wait

# Verificar — esperado:
#   dev-a push primeiro: pega 001-feature-a
#   dev-b detecta conflito: refetcha, renumera para 002-feature-b, pushe
cd /tmp/mosk-concurrency/dev-a && git branch --list
cd /tmp/mosk-concurrency/dev-b && git branch --list
# Verificar no origin:
cd /tmp/mosk-concurrency/origin && git branch --list
# Esperado: 001-feature-a E 002-feature-b (sem colisão)
```

### Smoke test — `docs/index.md` automatizado (Workstream I)

```bash
cd /tmp/mosk-brownfield
# Criar 2 specs ativas + 1 arquivada
mkdir -p docs/specs/004-fix-login-timeout
cat > docs/specs/004-fix-login-timeout/spec-meta.yaml <<'EOF'
spec_number: "004"
spec_id: "004-fix-login-timeout"
type: fix
branch: "004-fix-login-timeout"
created_at: "2026-04-20T10:00:00Z"
created_by: "dev-a"
status: active
current_phase: qa-gate
EOF

# Rodar index-docs manualmente (simulando trigger de archive)
# Verificar docs/index.md:
cat docs/index.md | head -40
# Esperado: seções Overview, Active Specs (com 004), Archived Specs, Domain Contents
ls docs/prd/                                  # inalterado (manual)
# Output do archive deve listar prd-delta.md como pendente manual
```

---

## Pontos fora de escopo (deixar para v3)

- Implementação de `promote_mode: merge` com parse semântico de PRD-delta (por ora, `manual` resolve). Ficar atento se `manual` virar friction no uso real.
- Campanha de re-shard automático em projetos que migraram com `docs/prd.md` monolítico pesado — por ora, o migrate move para `docs/prd/raw.md` e o usuário decide se roda `shard-doc` para quebrar em `index.md` + seções.
- Suporte a múltiplos epics numa única spec (hoje 1 spec = 1 epic implícito). Se aparecer necessidade, virá em outro plano.
- Automação de mapping stories↔specs na migração além da heurística por número — usuário resolve manualmente as órfãs em `_orphan-stories/`.
- Lock distribuído para numeração de specs (ex.: via GitHub Actions com lease) — retry local em push é suficiente para 90% dos casos; lock distribuído só se virar problema recorrente.
- Dashboard web de specs ativas lendo `spec-meta.yaml` — `docs/index.md` markdown já resolve para o caso atual.
- Assinatura/validação de `spec-meta.yaml` (checksum, schema) — overkill por ora.

---

## Riscos e mitigações

| Risco | Mitigação |
|---|---|
| Quebra silenciosa em instalações antigas que atualizarem via `degit --force` sem rodar migração | README destaca o passo de migração; `boot.md` detecta estado legado e avisa. |
| Rename `mosk-webdesigner` → `mosk-ui-expert` quebra links em docs de usuários | Registrar no CHANGELOG; avaliar manter skill `mosk-webdesigner` como alias por 1 versão (SKILL.md apontando para `../../mosk/agents/ui-expert.md`). Decidir no momento do rename se compensa. |
| Confusão entre `mosk-ux-expert` e `mosk-ui-expert` após rename (nomes parecidos) | Documentar no README + `project.md` a diferença (UX = flows/wireframes; UI = acabamento visual/taste system); descriptions dos skills enfatizam o foco de cada um. |
| Archive deletar artefato por engano em `copy` sobre destino pré-existente | Proibido sobrescrever sem confirmação do usuário; fallback é `append` ou pular. |
| Stories órfãs na migração desorientarem o usuário | Relatório final lista explicitamente o que foi para `_orphan-stories/` e sugere redirecionamento manual. |
| `shard-doc.md` atualizado apontar para paths errados | Atualizar exemplos para `docs/prd/raw.md → docs/prd/` (mesma pasta) e `docs/architecture/raw.md → docs/architecture/`; smoke test com arquivo sintético. |
| Templates antigos em projetos instalados ainda apontarem para `docs/prd.md` | Usuários que rodarem o migrate terão `core-config.yaml` atualizado e os templates no `.claude/mosk/templates/` sobrescritos na próxima reinstalação via `degit --force`. |
| Retry de numeração (W-H) em loop infinito em caso de problema de rede | Limitar a MAX_RETRIES=3; se esgotar, abortar com mensagem clara instruindo rodar manualmente após estabilizar conexão. |
| Dev sem acesso de push (ex: forks) falhando no passo de push atômico | Flag `--no-push` explícita no `create-new-feature.sh` para ambientes sem remote gravável; task `specify` detecta ausência de remote e omite a etapa de push. |
| `spec-meta.yaml` corrompido/inválido após edição manual | Helpers `read_spec_meta` validam YAML antes de usar; fallback para inferência pelo nome da pasta quando parse falha; exibir aviso não-fatal. |
| `docs/index.md` editado manualmente e sobrescrito pela regeneração | Regeneração preserva blocos com marker especial (ex.: `<!-- custom -->`...`<!-- /custom -->`). Fora desses markers, tudo é gerado. |
| `index-docs` ser chamado excessivamente em loops tight (cada task fase) gerando ruído | Regeneração é idempotente e rápida (< 1s em projeto médio). Se virar friction, adicionar flag `--if-changed` que só regera se o hash de specs mudou. |
| Novos devs não saberem que `docs/index.md` existe | Menção destacada no README (seção "For New Contributors") apontando `docs/index.md` como primeira leitura; nota também em `.claude/rules/project.md`. |
| Escalation signals (W-J) virarem ruído ou loops se acionados em excesso | Regra explícita: só escalar quando há sinal concreto; nunca para incerteza genérica; cap de 1 sugestão por execução. Registrado no `.claude/rules/project.md`. |
| Agente de preâmbulo chamado via escalation esquecer de voltar a sugerir retorno ao agente que escalou | Seção `## When invoked from a pipeline escalation` impõe: último passo do agente de preâmbulo é sugerir `resume with /<origin-agent>`. Smoke test cobre esse caminho. |

---

## Formato de entrega

O patch solicitado pelo usuário é o próprio **`migrate-docs-structure.sh`** (Workstream F) + as versões atualizadas de `core-config.yaml` (Workstream A), `archive.md` (Workstream D), `boot.md` (Workstream E) e docs do framework. Todos os arquivos vivem dentro do próprio template MOSK; ao fazer `npx degit rogerznts/mosk/mosk .` (com `--force`) em projeto existente, o usuário recebe o novo código + o script de migração, e executa:

```bash
npx degit rogerznts/mosk/mosk . --force
bash .claude/mosk/scripts/migrate-docs-structure.sh --dry-run
bash .claude/mosk/scripts/migrate-docs-structure.sh
bash .claude/mosk/scripts/link-codex-skills.sh    # se usar Codex
```

Isso é o "patch" do ponto de vista do usuário final — um script instalável + guia de uso no README.
