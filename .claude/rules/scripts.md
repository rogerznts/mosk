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
- Refuses to create from environment/release/feature branches. Only
  base branches allowed: `main master develop dev`.
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
  `.claude/mosk/agents/<name>.md`, write/refresh
  `.claude/skills/mosk-<name>/SKILL.md` pointing back to the source.
- `skills-to-agents`: generate `.claude/agents/mosk-<name>.md` only
  when missing (preserves PT-BR content in existing files).
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
  `update_spec_phase <dir> <phase>` (also bumps
  `last_phase_change`), `list_active_specs [<specs_root>]`,
  `write_spec_meta <dir> <number> <id> <type> <branch>`.

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
