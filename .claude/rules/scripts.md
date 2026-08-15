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
- **Duas armadilhas de numeração já corrigidas (spec 010) — não reintroduza:**
  - O prefixo dos **branches locais** é lido **ancorado no início** do nome,
    aceitando os dois formatos (`^([a-z][a-z-]*/)?([0-9]{3})-`, via `sed -nE`
    com captura). Sem a âncora, qualquer branch comum
    com dígitos no meio — `docs/adr-0012-0014-x`, `fix/issue-123-foo` — é lido
    como spec e desvia a numeração. As outras quatro fontes sempre foram
    ancoradas; só esta não era.
  - `--number` é normalizado com `$((10#$n))` **no parse e de novo em
    `rebuild_branch_name`** (o funil por onde todo caminho passa). Sem isso,
    `--number 010` chega ao `printf` como constante octal e reserva **008**.
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
  work from an agent worktree whose branch is personal (e.g.
  `rogerznts/master`) while the base itself is checked out elsewhere. The
  blocked-pattern list and the `^[0-9]{3}-` spec-branch rule still apply
  on top.
- **Branch format (ADR-0017): `{tipo}/{NNN}-{nome}`** — ex.: `feature/012-algo`.
  A **pasta** continua plana: `docs/specs/{NNN}-{tipo}-{nome}`. Branch e pasta
  deixaram de ser a mesma string; a ponte é o campo `branch` do `spec-meta.yaml`.
  Formato legado `{NNN}-{tipo}-{nome}` continua sendo resolvido. Trunca em 244
  bytes (limite do GitHub).
- **`--type` é validado**: por extenso apenas. `feat`/`bug`/`hf`/`chore`/`docs`
  recusados com mensagem — o tipo agora é segmento de caminho no branch, e valor
  inválido produz branch estruturalmente errado.
- Generates `spec-meta.yaml` with `status: active`,
  `current_phase: specify`, ISO 8601 timestamps.
- On branch push rejection (rare, exact-name race): re-fetches,
  renumbers + re-reserves, renames branch + folder, retries.
- Exports `SPECIFY_FEATURE=<branch>` in the calling shell.

**Called by:** `specify` task (and `full-spec`).

### `sync-agents-skills.sh`

Materializa a skill a partir do agente. **Uma direção só** desde a spec 011
(ADR-0015): `.claude/agents/mosk-<name>.md` é a **fonte** — a definição completa
— e `.claude/skills/mosk-<name>/SKILL.md` é o wrapper gerado.

A camada intermediária `.claude/mosk/agents/` **deixou de existir**. Instalação
anterior à 011 recebe um NOTE apontando o diretório antigo, em vez de falhar em
silêncio quando a fonte some.

`skills-to-agents` foi **removido** e falha com mensagem: depois da inversão ele
sobrescreveria a definição completa do agente com um ponteiro de três linhas.
`both` segue aceito como alias de `agents-to-skills`.

**Usage:**
```bash
bash .claude/mosk/scripts/sync-agents-skills.sh \
  [agents-to-skills|skills-to-agents|both] [--dry-run] [--clean]
```

**Behavior:**
- `agents-to-skills` (única direção): para cada
  `.claude/agents/mosk-<name>.md`, escreve `.claude/skills/mosk-<name>/SKILL.md`
  pointing back to the source. **Wrappers that already exist are edited in
  place — only the `description:` line is rewritten.** Extra front-matter keys
  (`argument-hint:` in `mosk-suggestion`) and hand-written bodies are preserved.
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
  no longer exists in `.claude/agents/`.
- Warns (non-blocking) when legacy `ctx-*` skills are still present;
  points to `migrate-ctx-skills-to-rules.sh`.

**Run when:** adding/removing/renaming an agent under
`.claude/agents/`, ou quando as duas camadas puderem divergir.

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

### `doctor.sh`

**Diagnóstico central e read-only da instalação.** Compõe `bash -n`, todos os
`selftest-*.sh`, referências internas literais, `audit-docs-paths.sh`, sync
agente → skill em dry-run, roster de 12 agentes e arquivos obrigatórios.

**Usage:** `bash .claude/mosk/scripts/doctor.sh [--json] [--help]`.
Exit 0 = íntegro; 1 = uma ou mais violações; 2 = erro de uso. Não depende de
PyYAML, npm ou pip e pode rodar numa materialização contendo apenas o conteúdo
distribuível de `mosk/`.

**Run when:** antes de publicar uma versão do toolkit e depois de alterar
agents, skills, tasks, templates, scripts ou `core-config.yaml`.

### `check-ship-ready.sh`

**Guardrail de merge (fonte única de "spec fechada").** Valida se a spec do
branch está pronta pra abrir/mergear PR: `current_phase == archived`, gate
`PASS` ou `WAIVED` com justificativa, aprovador e timestamp UTC, nenhum
artefato `promote:` (copy/append) com alvo faltando e working tree limpo. A
resolução procura a spec ativa e a já movida para `docs/specs/archive/`; branch
sem prefixo de spec passa. Branch numerado com spec ausente, ambígua ou sem
metadata falha. Todo `promote:` passa por `validate_promotion_target`, que
restringe o destino a `docs/` e bloqueia traversal, modo inválido e escape por
symlink. Exit 0 = pronta; 1 = pontas soltas (lista os motivos). Usage:
`bash .claude/mosk/scripts/check-ship-ready.sh [--json]`.
**Consumido por** camadas de guardrail (hook do Claude Code em `gh pr merge`,
CI/branch protection, `/tea-open-pr`).

### `reset-install.sh`

**Reinstala o toolkit do zero num projeto consumidor**: apaga a instalação
anterior antes de copiar a nova. Consumido pela skill `/mosk-update`.

Existe porque **`npx degit --force` sobrescreve arquivo por arquivo e nunca
apaga**. Script, skill ou agente que deixou de existir upstream fica no disco do
projeto para sempre — e os agentes MOSK continuam encontrando e tentando usar.
Atualizar sem reset acumula o lixo de todas as versões passadas.

**Usage:**
```bash
bash <tmp>/.claude/mosk/scripts/reset-install.sh \
  --from <tmp> --to <raiz_do_projeto> [--dry-run] [--json]
```

**Rode sempre a cópia recém-baixada, nunca a instalada** — o script apaga o
diretório onde ele mesmo mora. Rodar de `$TMP` também garante que a lógica de
reset executada é a mais nova, não a da versão velha. Uma guarda recusa
`--from` e `--to` apontando para o mesmo diretório.

**O conjunto apagado é calculado, nunca adivinhado:** (1) `.claude/mosk/`
inteiro; (2) cada skill/agente que o template novo possui, lido do `--from`;
(3) os **órfãos** — `skills/mosk-*` e `agents/mosk-*.md` instalados que sumiram
upstream. É a regra 3 que remove o que uma versão anterior deixou.

**Nunca tocados:** `.claude/rules/`, `settings.json`, `settings.local.json`,
`docs/`, `CLAUDE.md`, `AGENTS.md`, `.codex/` — e qualquer skill/agente fora do
conjunto acima. Skill sem prefixo `mosk-` que sumiu upstream é **reportada como
"possivelmente órfã" e deixada no disco**: varrer o namespace inteiro apagaria
skills próprias do usuário, e o preço de não varrer é uma linha de relatório.

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

### `selftest-common.sh`

**Self-test dos helpers compartilhados.** Cobre duas regras que já quebraram em
produção:

1. **Resolução do próprio diretório do `common.sh`, em bash E em zsh.** As tasks
   mandam o agente rodar `source common.sh` no shell dele, e o shell padrão do
   macOS é zsh — onde `BASH_SOURCE` não existe. O teste sourceia de um cwd
   diferente de propósito: se a detecção usar o cwd por engano, ele falha.
2. **As duas regras de numeração de spec** que o `create-new-feature.sh` aplica:
   a regex ancorada no início do nome do branch e o `10#` que impede
   `--number 010` de virar constante octal. Exercita as regras, não o script —
   ele executa ao ser sourceado, então não dá para chamar suas funções offline.

**Usage:** `bash .claude/mosk/scripts/selftest-common.sh [--verbose] [--help]`.
Exit 0 = limpo; 1 lista `caso :: esperado :: obtido`.

**Run when:** ao mexer nos helpers de caminho do `common.sh` ou na numeração de
spec.

### `selftest-toolkit.sh`

Fixtures dos contratos centrais do toolkit: gates bloqueantes e permitidos,
waiver formalizado, resolução fail-closed de spec ativa/arquivada, referências
internas absolutas e relativas, paths canônicos, chaves do `core-config.yaml`,
templates referenciados, contenção de `promote:` e `check-ship-ready.sh` sobre
spec arquivada. A contenção roda em Bash e zsh, incluindo fixtures para `//`,
segmento `.`, traversal e destino válido.

**Usage:** `bash .claude/mosk/scripts/selftest-toolkit.sh [--verbose] [--help]`.
Exit 0 = todas as fixtures passaram; 1 = falha de contrato; 2 = erro de uso.

**Run when:** ao mexer em gate, archive, ship-ready, auditoria ou diagnóstico.

### `common.sh`

Shared library — never executed directly, always `source`'d:

```bash
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
```

**Resolução do próprio diretório (`MOSK_SCRIPTS_DIR`).** `common.sh` calcula uma
única vez, no escopo de topo, o diretório onde ele mesmo vive, e os helpers de
caminho (`get_repo_root`, `core_config_file`) leem daí. A detecção
cobre **bash e zsh**: `${BASH_SOURCE[0]}` no primeiro, `${(%):-%x}` no segundo.
Isso importa porque as tasks mandam o agente rodar `source common.sh` **no shell
dele**, e o shell padrão do macOS é zsh — onde `BASH_SOURCE` não existe. Antes,
`dirname ""` virava `.` e todo caminho resolvia a partir do cwd, em silêncio: o
todo helper de caminho apontava para fora do repo sem que nada reclamasse
(spec 009) — falha coberta hoje pelo `selftest-common.sh`, que sourceia este
arquivo de um cwd diferente nos dois shells. Exporte `MOSK_SCRIPTS_DIR` para forçar o
caminho; a lib avisa em stderr se não conseguir se localizar.

**Provides:**
- Repo-root + current-branch resolution with non-git fallbacks.
- `validate_promotion_target <repo_root> <target> <mode>` — aceita somente
  `copy|append|manual`, exige destino de arquivo sob `docs/` e rejeita caminho
  absoluto, traversal e escapes por symlink; imprime o destino absoluto seguro.
- `find_feature_dir_by_number` — locates a spec folder by numeric
  prefix (so `004-fix-bug` and `004-add-feature` resolve to the same
  spec).
- `spec-meta.yaml` helpers (top-level scalar keys only — no nested
  structures, no arrays): `read_spec_meta <dir> <key>`,
  `update_spec_phase <dir> <phase>` (also bumps `last_phase_change`,
  registra apenas `current_phase` + `last_phase_change`, sem validar nada:
  a autoridade sobre qual fase vem depois é humana, e o `spec-meta.yaml` é o
  único lugar onde esse estado mora),
  `list_active_specs [<specs_root>]`,
  `write_spec_meta <dir> <number> <id> <type> <branch>`,
  `core_config_file`.
- **Helpers do runner autônomo** (ADR-0019, consumidos pelo `/mosk-orq`):
  - `resolve_max_attempts` — teto de voltas por unidade: `runner.max_attempts` do
    `core-config.yaml` → 3. Valor não-numérico **avisa em stderr** e cai no
    default; um teto lido errado em silêncio é um loop que não termina.
  - `append_run_log <spec_dir> <onda> <unidade> <agente> <decisão> <porquê>` —
    append-only em `<spec_dir>/run-log.md`, escreve o cabeçalho da tabela na
    primeira chamada e escapa `|` no texto (um pipe cru quebraria a tabela
    inteira). Falha explicitamente se o `spec_dir` não existir.

  Existem como **função**, e não como convenção de prompt, porque o precedente —
  o `loop-until-green` do bench — deixou as duas pontas soltas: o
  `decisions-log.md` nunca teve escritor nem template, e o `MAX_FIX_ATTEMPTS`
  nunca foi constante. Um processo que roda desacompanhado não pode depender de
  o prompt lembrar.

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
| Auditar a integridade completa do toolkit | `doctor.sh` |
| Atualizar o toolkit num projeto consumidor | `reset-install.sh` (via `/mosk-update`) |
| Mexeu nos helpers de caminho do `common.sh` ou na numeração de spec | `selftest-common.sh` |
| Mexeu em gate, referências, paths ou templates | `selftest-toolkit.sh` |
| Atualizar/conferir o vendor do Hallmark | `sync-hallmark.sh --dry-run` primeiro |
