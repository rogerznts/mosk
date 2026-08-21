---
name: mosk-update
description: "Update: reinstala o toolkit MOSK do zero (reset + degit), apagando órfãos de versões anteriores, lê o README e o TASKS.md direto do GitHub e resume as mudanças. Use ao atualizar/sincronizar a versão do MOSK no projeto."
---

# Update MOSK

Reinstall the MOSK toolkit from scratch, then report what changed.

> **IMPORTANT — this is a reset, not an overwrite.** `.claude/mosk/`, the
> `mosk-*` skills and the `mosk-*` agents are **deleted and reinstalled**. Your
> `.claude/rules/`, `.claude/settings.json`, `docs/` and your own skills are
> **not touched**. Only run it from a clean git tree so the change is reviewable
> and reversible.

**Why a reset and not just `degit --force`:** `degit --force` overwrites file by
file and **never deletes**. A script, skill or agent that stopped existing
upstream would stay on disk forever — and MOSK agents would keep finding it and
trying to use it. Updating without a reset accumulates the debris of every past
version.

---

## Workflow

### Step 1 — Preflight (safety)

1. Confirm this is a git repository. If not, warn the user that the reset will
   not be reversible and ask whether to proceed.
2. Run `git status --short`. If the tree is dirty, **stop** and ask the user to
   commit or stash first — otherwise the reset may clobber uncommitted work and
   bury the update in unrelated changes.

### Step 2 — Download without touching the project

```bash
TMP="$(mktemp -d)"
npx degit rogerznts/mosk/mosk "$TMP"
```

Nothing in the project has changed yet.

### Step 3 — Preview (mandatory)

```bash
bash "$TMP/.claude/mosk/scripts/reset-install.sh" --dry-run --from "$TMP" --to .
```

> **Run the freshly-downloaded copy, never the installed one.** The script
> deletes the very directory it lives in. Running it from `$TMP` also means you
> always execute the newest reset logic, not the old version's.

The output separates *substituídos* · *órfãos removidos* · *preservados* ·
*possivelmente órfãos*.

### Step 4 — Warn and wait

Show the user the preview and state plainly, in one sentence, that
`.claude/mosk/`, the `mosk-*` skills and the `mosk-*` agents will be **deleted
and reinstalled**, while `rules/`, `docs/`, settings and their own skills are
preserved. Call out the **orphans** by name — those are the files disappearing
for good.

**Stop and wait for confirmation.** Do not continue on a "maybe".

### Step 5 — Execute

```bash
bash "$TMP/.claude/mosk/scripts/reset-install.sh" --from "$TMP" --to .
```

### Step 6 — Codex parity

```bash
bash .claude/mosk/scripts/sync.sh codex --force
```

This clears orphan symlinks under `.codex/` and regenerates `AGENTS.md`. Skip it
if the project has no `.codex/` and does not want one.

### Step 7 — Read the latest docs from GitHub

Fetch the current toolkit docs straight from the repo (they live at the repo
root and are **not** installed by degit), to learn the current capabilities and
task catalog:

- `https://raw.githubusercontent.com/rogerznts/mosk/master/README.md`
- `https://raw.githubusercontent.com/rogerznts/mosk/master/TASKS.md`

If `master` 404s, retry with `main`.

### Step 8 — Report

Concisely:

1. **Orphans removed** — list them. These are capabilities that no longer exist;
   if the user had workflows built on them, this is the line that tells them.
2. **What changed locally** — `git status --short` and `git diff --stat`.
3. **What's new in the toolkit** — cross-reference the diff with the freshly-read
   `README.md` / `TASKS.md`: new or renamed agents, skills, tasks, conventions,
   one line each.
4. **Possibly orphaned** — anything the script flagged as ambiguous (outside the
   `mosk-` namespace and absent upstream). It was **left on disk**; the user
   decides.
5. **Follow-ups**:
   - Re-run `/mosk-boot` if the rules/templates structure changed.
   - Review the diff before committing.

Finally, remove the temp directory: `rm -rf "$TMP"`.

## Rules

- **Never reset a dirty tree** without explicit confirmation.
- **Always show the `--dry-run` preview before deleting**, and wait for the
  user's `ok`. The preview is the warning — a generic "this will overwrite
  files" is not.
- **Run `reset-install.sh` from the downloaded copy** (`$TMP`), never the
  installed one.
- `degit --force` **overwrites but never deletes** — orphan removal is done by
  `reset-install.sh`, and only there.
- Do not auto-commit the update — leave the diff for the user to review.
- Read `README.md`/`TASKS.md` from GitHub, not from disk (degit does not
  install them).
- Never delete anything outside the set the script computes. Skills and agents
  the user wrote are not MOSK's to remove.
