# Helper Scripts (`mosk/.claude/mosk/scripts/`)

Bash helpers that ship with the MOSK template. All paths below are
relative to the installable template; once a project consumes MOSK,
they live at `.claude/mosk/scripts/` in that project.

All scripts: `set -e`, support `--help|-h`, source `common.sh` for
shared helpers when needed. Migration/destructive scripts support
`--dry-run`.

## Inventory

### `create-new-feature.sh`

Bootstraps a new spec: branch + folder + initial `spec-meta.yaml`,
then atomic `git push` with collision retry.

**Usage:**
```bash
bash .claude/mosk/scripts/create-new-feature.sh \
  [--json] [--type feature|fix|hotfix|gmud|refactor|experimental] \
  [--short-name <name>] [--number N] [--no-push] \
  <feature_description>
```

**Behavior:**
- Computes next spec number globally: `max(remote branches, **number
  reservations**, local branches, active spec dirs, archived spec dirs)
  + 1` (base-10 forced to avoid octal traps).
- **Atomic number reservation (collision-proof):** before creating the
  branch, it reserves the number on `origin` by pushing an immutable ref
  `refs/spec-numbers/<NNN>` (a unique dangling commit under a
  must-not-exist `--force-with-lease`). If a concurrent creator grabbed
  the same number first, git rejects the reservation and the script
  renumbers and retries (up to `MAX_RESERVE_ATTEMPTS=5`). This closes the
  old gap where two branches with the same number but different suffixes
  (e.g. `040-feature-x` and `040-chore-y`) both pushed successfully —
  the previous exact-branch-name push-rejection check never caught it.
- These reservation refs are invisible to `git branch`/`git tag`, form a
  **durable registry**, and are never deleted — so a number is never
  reused even after its branch is merged and deleted. Read them with
  `git ls-remote origin 'refs/spec-numbers/*'`.
- Remotes that reject custom ref namespaces (verified working on GitHub)
  degrade gracefully to best-effort branch/dir detection with a warning.
  `--no-push` / non-git installs skip reservation (local numbering only).
- `--number N` is honored strictly: if that number is already reserved
  or in use it **fails loudly** instead of silently duplicating.
- Refuses to create from environment/release/feature branches. Base
  branches allowed: `main master develop dev` — **or** any branch pointing
  at the *same commit* as one of them. That second rule is what makes it
  work from an Orca/agent worktree whose branch is personal (e.g.
  `rogerznts/master`) while the base itself is checked out elsewhere. The
  blocked-pattern list and the `^[0-9]{3}-` spec-branch rule still apply
  on top.
- Branch format: `{###}-{type}-{short-name}` (or `{###}-{short-name}`
  for backward compat). Truncates to 244 bytes (GitHub limit).
- Generates `spec-meta.yaml` with `status: active`,
  `current_phase: specify`, ISO 8601 timestamps.
- On branch push rejection (rare, exact-name race): re-fetches,
  renumbers + re-reserves, renames branch + folder, retries.
- Exports `SPECIFY_FEATURE=<branch>` in the calling shell.

**Called by:** `specify` task (and `full-spec`).

### `sync-agents-skills.sh`

Synchronizes the three layers: source agents (`.claude/mosk/agents/`),
skill wrappers (`.claude/skills/mosk-<name>/SKILL.md`), and Claude
Code agent files (`.claude/agents/mosk-<name>.md`).

**Usage:**
```bash
bash .claude/mosk/scripts/sync-agents-skills.sh \
  [agents-to-skills|skills-to-agents|both] [--dry-run] [--clean]
```

**Behavior:**
- `agents-to-skills` (default direction): for each
  `.claude/mosk/agents/<name>.md`, write `.claude/skills/mosk-<name>/SKILL.md`
  pointing back to the source. **Wrappers that already exist are edited in
  place — only the `description:` line is rewritten.** Extra front-matter keys
  (`argument-hint:` in `mosk-orq`) and hand-written bodies are preserved.
- `skills-to-agents`: generate `.claude/agents/mosk-<name>.md` when missing;
  when present, keep the body and refresh only the `description:` line.

**Description — fonte única (contrato).** A `description` de uma skill de
agente é declarada **no próprio agente**, na primeira linha, em uma linha
física e sem aspas duplas:

```md
<!-- skill-description: UI: interfaces premium, redesign, Hallmark (audit · redesign · study). -->
```

Ordem de resolução: `skill-description` → wrapper existente → CC agent →
primeira linha da `## Mission` → genérico.

Isso existe porque `description` e `## Mission` são coisas diferentes: a
primeira é string de **roteamento** (pt-BR, com gatilhos, lida pelo host para
decidir *quando* carregar a skill); a segunda é **prosa da persona** (inglês,
multi-linha, lida pelo modelo depois de carregada). Antes, o script derivava a
description da Mission via `head -1` — o que truncava as 11 descriptions
curadas do template no primeiro `sync`, sem erro visível.
- `--clean`: removes orphan skills and CC agents whose source agent
  no longer exists in `.claude/mosk/agents/`.
- Warns (non-blocking) when legacy `ctx-*` skills are still present;
  points to `migrate-ctx-skills-to-rules.sh`.

**Run when:** adding/removing/renaming an agent under
`.claude/mosk/agents/`, or whenever the three layers might drift.

### `link-codex-skills.sh`

Generates Codex CLI integration: symlinks `.claude/skills/`,
`.claude/agents/`, and `.claude/rules/` into `.codex/`, and rewrites
`AGENTS.md` with the current skill roster.

**Usage:**
```bash
bash .claude/mosk/scripts/link-codex-skills.sh [--force]
```

**Behavior:**
- Phase 0: removes orphan symlinks in `.codex/skills/` and
  `.codex/rules/`.
- Phase 1: symlinks each `.claude/skills/<name>/` → `.codex/skills/<name>`.
- Phase 2: wraps each `.claude/agents/<name>.md` as a Codex skill
  (`.codex/skills/<name>/SKILL.md` symlink).
- Phase 2b: symlinks each `.claude/rules/*.md` → `.codex/rules/`.
- Phase 3: regenerates `AGENTS.md` with reference to `CLAUDE.md`,
  the skill roster (with descriptions extracted from SKILL.md
  frontmatter), and the project-rules section.
- `--force`: recreates symlinks that point elsewhere. Without it,
  conflicting symlinks are skipped.
- Env overrides: `CODEX_SKILLS_DIR`, `CODEX_RULES_DIR`.

**Run when:** the skill/agent/rule rosters change. **`AGENTS.md` is
auto-generated — never hand-edit it.**

### `migrate-docs-structure.sh`

Migrates a brownfield project (pre-v2 `docs/` layout) to the canonical
MOSK structure in place.

**Usage:**
```bash
bash .claude/mosk/scripts/migrate-docs-structure.sh \
  [--keep-old] [--dry-run] [--help]
```

**Behavior (8 phases):**
1. Scaffold canonical `docs/` skeleton (idempotent).
2. Migrate monolithic `docs/prd.md` / `docs/architecture.md`.
3. Migrate loose files (`brainstorming-session-results.md`,
   `front-end-spec.md`, …).
4. Migrate `docs/stories/` into per-spec `stories/`.
5. Scaffold `README.md` per domain (only if missing).
6. Retroactively create `spec-meta.yaml` for existing specs
   (including archived ones).
7. Rewrite `core-config.yaml` to the v2 schema.
8. Regenerate `docs/index.md`.

Use `--dry-run` first. `--keep-old` preserves the originals
alongside the migrated copies.

### `migrate-ctx-skills-to-rules.sh`

Migrates legacy `.claude/skills/ctx-*` context skills into
`.claude/rules/*.md` (the v2 rule layout).

**Usage:**
```bash
bash .claude/mosk/scripts/migrate-ctx-skills-to-rules.sh \
  [--keep-old] [--dry-run] [--help]
```

**Run when:** you see a non-blocking warning from
`sync-agents-skills.sh` about legacy `ctx-*` skills, or when
upgrading a pre-rules MOSK install.

### `setup-plan.sh`

Plan-phase bootstrap: validates the current branch is a feature
branch, ensures the feature directory exists, copies the plan
template into place, and prints the resolved paths.

**Usage:**
```bash
bash .claude/mosk/scripts/setup-plan.sh [--json] [--help]
```

**Called by:** `plan` task.

### `update-agent-context.sh`

Parses `plan.md` for a feature and writes detected
language/framework/database/project-type metadata into agent context
files. Creates files from templates when missing; updates them
in place when they already exist. Tolerates missing/incomplete plan
data.

**Usage:**
```bash
bash .claude/mosk/scripts/update-agent-context.sh [--help]
```

**Called by:** `plan` task (after `setup-plan.sh`).

### `check-prerequisites.sh`

Unified prerequisite checker for the SpecKit pipeline. Replaces
several older single-purpose scripts.

**Usage:**
```bash
bash .claude/mosk/scripts/check-prerequisites.sh \
  [--json] [--require-tasks] [--include-tasks] [--paths-only] [--help]
```

**Behavior:**
- `--require-tasks`: fail if `tasks.md` is missing (gate for
  implementation phase).
- `--include-tasks`: include `tasks.md` in the `AVAILABLE_DOCS` list.
- `--paths-only`: emit only path variables, skip validation
  (`REPO_ROOT`, `BRANCH`, `FEATURE_DIR`, …).
- JSON mode: `{"FEATURE_DIR":"...", "AVAILABLE_DOCS":["..."]}`.

**Called by:** `plan`, `tasks`, `implement`, `qa-gate` tasks.

### `legal_moves.sh`

Computes the **legal next moves** from a pipeline phase, reading the single
source of truth `pipeline-graph.yaml` (ADR-0006/0007). **Never takes an
edge** — evaluates `fact` guards mechanically, flags `judgment` guards for
the agent, and presents; the human decides.

**Usage:**
```bash
bash .claude/mosk/scripts/legal_moves.sh <current_phase> [--json]
bash .claude/mosk/scripts/legal_moves.sh __start__      # pre-spec routing
```

**Behavior:**
- Lists edges leaving `<current_phase>` with the `default` marked; omits moves
  whose `fact` guard failed; surfaces `judgment` guards with their question.
- Lists escalations available from the phase (side-trips that return).
- **Delivery-loop aware at `qa-gate`** (ADR-0008): labels the correction
  loopback `tentativa N/max` while `N < max`; on the cap, swaps to the
  exhaustion menu (`escalar`/`waive`/`parar`). The counter is derived from
  `phase-history.log`; the cap from `resolve_max_retries`.

**Called by:** `mosk-suggestion` skill; `implement`/`qa-gate` tasks.

### `graph_mermaid.sh`

Renders a deterministic Mermaid flowchart **from** `pipeline-graph.yaml` (the
diagram is derived, not a parallel copy). Embedded into `docs/index.md` by
`index-docs`. Usage: `bash .claude/mosk/scripts/graph_mermaid.sh`.

### `lint-graph.sh`

Validates the **form** of `pipeline-graph.yaml` (ADR-0007): every record
(node/edge/escalation/guard) must be one line in flow style, so the `awk`
projections in `common.sh` stay simple. Usage:
`bash .claude/mosk/scripts/lint-graph.sh [--quiet]`. Exit 0 = clean;
exit 1 lists `path:line :: detail`.

### `panes.sh`

**Fachada única do atuador de panes do `/mosk-orq`** (ADR-0010). Resolve qual
backend está ativo (`herdr | orca | none`) e delega o argv inalterado ao driver.
É o único script que o agente chama — trocar de backend não muda o prompt.

**Usage:**
```bash
bash .claude/mosk/scripts/panes.sh driver [--json]   # backend ativo + motivo
bash .claude/mosk/scripts/panes.sh <subcomando> ...  # delega
```

**Precedência da escolha:** env `MOSK_ORQ_DRIVER` → `orchestration.driver` no
`core-config.yaml` (`auto|herdr|orca|none`) → em `auto`, o ambiente da sessão
(`ORCA_*` vs `HERDR_*`) → em `auto`, o primeiro backend cujo `check` passar →
`none` (degradação single-pane, com dica de instalação dos dois).

Subcomandos exclusivos do backend Orca (camada nativa) respondem `unsupported`
com **exit 3** nos demais — código próprio, para distinguir "este backend não
faz isso" de "isto falhou".

### `herdr.sh`

**Backend Herdr** do atuador. Wrapper mecânico da control API do
[Herdr](https://herdr.dev/): spawna/injeta/espera/lê/fecha panes e mede tokens.
Subcomandos: `check | tokens | spawn | send | wait-idle | read | close |
managed`. Degrada graciosamente sem o binário `herdr` (`check` falha com dica de
instalação). O `spawn` fixa a pane no space do orquestrador (env `HERDR_*`).
Prefira chamar via `panes.sh`. Usage:
`bash .claude/mosk/scripts/herdr.sh <subcomando> ...`.

### `orca.sh`

**Backend Orca** do atuador ([onorca.dev](https://www.onorca.dev/)). Implementa
o **mesmo contrato** do `herdr.sh` sobre `orca terminal …` — mesmos subcomandos,
mesmos flags, mesmo formato de saída; o "pane" é o handle de terminal do Orca.

**Resolução do executável (crítica):** `$ORCA_CLI_COMMAND` → `orca-dev` (quando
`$ORCA_DEV_REPO_ROOT`) → `orca-ide` → `orca`, e **recusa** `/usr/bin/orca` ou
`/bin/orca` — no Linux esse nome é o **leitor de tela do GNOME**, e executá-lo
inicia síntese de voz na máquina do usuário. Nunca invoque `orca` cru.

Diferenças absorvidas no wrapper: `--cwd` vira `--worktree path:<p>` (com
fallback para `active`); `send` usa o `--enter` atômico (sem o respiro que o
Herdr exige); `--split`/`--workspace`/`--tab` não têm equivalente e são
reportados em stderr; sem contador nativo de tokens, `tokens` faz o mesmo parse
da TUI (`over=unknown` quando não casa).

**Camada nativa (opt-in, `orchestration.orca.native_tasks: true`):**
`native | task-create | task-list | dispatch | await | gate-create |
gate-resolve` — mapeiam `orca orchestration …` (task DAG, dispatch com preâmbulo
de lifecycle, espera por `worker_done`, decision gates). Desligada por padrão; os
subcomandos falham com mensagem clara enquanto ela estiver off. A invariante do
ADR-0006 vale: o orquestrador **cria** o gate, o humano **resolve**, e
`orchestration run` (coordinator loop autônomo do Orca) nunca é usado.

### `check-ship-ready.sh`

**Guardrail de merge (fonte única de "spec fechada").** Valida se a spec ativa do
branch está pronta pra abrir/mergear PR: `current_phase == archived`, nenhum
artefato `promote:` (copy/append) com alvo faltando, `lint-graph` limpo, working
tree limpo. Branch sem spec ativa passa. Exit 0 = pronta; 1 = pontas soltas
(lista os motivos). Usage:
`bash .claude/mosk/scripts/check-ship-ready.sh [--json]`.
**Consumido por** camadas de guardrail (hook do Claude Code em `gh pr merge`,
CI/branch protection, `/tea-open-pr`).

### `sync-hallmark.sh`

**Re-sincroniza o vendor do Hallmark** em `.claude/mosk/data/hallmark/` — um
*fork* da skill MIT [Nutlope/hallmark](https://github.com/Nutlope/hallmark),
consumido pela task `hallmark.md` do `mosk-ui-expert`.

**Usage:**
```bash
bash .claude/mosk/scripts/sync-hallmark.sh [--ref <sha|tag|branch>] [--dry-run] [--help]
```

**Como funciona (diff/replay, não patch hardcoded):** baixa o upstream no ref
**pinado** (lido de `VENDOR.md`), tira um `git diff --no-index` contra o vendor
atual — esse diff *é* o conjunto de adequações MOSK — baixa o ref **novo** e
reaplica com `git apply -p2 --reject`. Sem `--ref`, os dois refs coincidem e a
rodada é um no-op verificado (round-trip idempotente).

**Garantias:** valida todos os links markdown internos e quatro invariantes
(blocos `MOSK-HEADER` / `MOSK-INTEGRATION` presentes em `hallmark.md`,
`references/themes/tokens.css` e `LICENSE` presentes, `SKILL.md` renomeado).
Qualquer conflito ou link quebrado **aborta sem tocar no vendor** e preserva a
área de trabalho em `$TMPDIR/mosk-hallmark-sync/` (com os `.rej` e o
`mosk.patch`) para resolução manual.

Usa tarball do `codeload` (aceita qualquer SHA, inclusive commits que não são
ponta de branch) — não depende de `npx`/degit. Requer `curl`, `git`, `tar`.

**Run when:** for atualizar a versão do Hallmark, ou para conferir que o vendor
ainda bate com o upstream pinado. **Nunca** copie o upstream por cima do
diretório na mão: isso apaga a integração MOSK.

### `common.sh`

Shared library — never executed directly, always `source`'d:

```bash
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
```

**Provides:**
- Repo-root + current-branch resolution with non-git fallbacks.
- `find_feature_dir_by_number` — locates a spec folder by numeric
  prefix (so `004-fix-bug` and `004-add-feature` resolve to the same
  spec).
- `spec-meta.yaml` helpers (top-level scalar keys only — no nested
  structures, no arrays): `read_spec_meta <dir> <key>`,
  `update_spec_phase <dir> <phase>` (also bumps `last_phase_change`,
  **validates the transition against `pipeline-graph.yaml` and appends to
  `<dir>/phase-history.log`** — off-graph warns but proceeds, never blocks;
  ADR-0006), `list_active_specs [<specs_root>]`,
  `write_spec_meta <dir> <number> <id> <type> <branch>`.
- **Graph projections** (ADR-0007, zero-dep awk): `graph_file`,
  `graph_edges_from <phase>`, `graph_edge_exists <from> <to>`,
  `guard_kind <name>`, `guard_question <name>`.
- **Delivery-loop helpers** (ADR-0008): `attempt_count <dir>` (gate loopbacks
  derived from `phase-history.log`), `resolve_max_retries <dir>` (spec-meta
  override → `core-config.yaml orchestration.max_retries` → 3),
  `core_config_file`.

---

## Conventions

- **Idempotent by default.** Re-running a script must not corrupt
  state. Migration/destructive helpers expose `--dry-run`.
- **POSIX-friendly.** Avoid `bash`-isms when not necessary; force
  base-10 with `$((10#$num))` when parsing zero-padded numbers.
- **Help is mandatory.** Every script supports `--help|-h` and
  documents flags inline.
- **Path resolution.** Scripts compute `INSTALL_ROOT` from their own
  location (`$SCRIPT_DIR/../../..`) — they do not depend on the
  caller's `cwd`.
- **No silent destruction.** When removing/renaming, log the action.
  When skipping due to conflict, log why.
- **Git-optional.** Where it makes sense, helpers fall back to
  filesystem inspection so the workflow still works in `--no-git`
  installs (see `find_repo_root` in `create-new-feature.sh`).

## When to run what

| Action | Script |
|---|---|
| Start a new spec | `create-new-feature.sh` (via `specify` task) |
| Added/removed an agent | `sync-agents-skills.sh --clean` |
| Edited rules or rosters and need Codex parity | `link-codex-skills.sh` |
| Upgrading pre-v2 `docs/` layout | `migrate-docs-structure.sh --dry-run` first |
| Upgrading pre-rules MOSK install | `migrate-ctx-skills-to-rules.sh --dry-run` first |
| Validate a feature branch can plan | `setup-plan.sh` (via `plan` task) |
| Refresh agent context after plan | `update-agent-context.sh` |
| Gate a pipeline phase | `check-prerequisites.sh --require-tasks` |
| Check a spec is ready to merge (guardrail) | `check-ship-ready.sh` |
| Atualizar/conferir o vendor do Hallmark | `sync-hallmark.sh --dry-run` primeiro |
| Orchestrate agents over panes | `panes.sh` (via `/mosk-orq`) |
| Descobrir qual backend de panes está ativo | `panes.sh driver --json` |
