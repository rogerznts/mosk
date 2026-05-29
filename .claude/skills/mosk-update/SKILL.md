---
name: mosk-update
description: "Update: atualiza o toolkit MOSK instalado via `npx degit --force`, lê o README e o TASKS.md direto do GitHub e resume as mudanças. Use ao atualizar/sincronizar a versão do MOSK no projeto."
---

# Update MOSK

Pull the latest MOSK toolkit into this project, then report what changed.

> **IMPORTANT — `--force` overwrites files.** `degit --force` replaces the
> installed MOSK files (`.claude/mosk/`, `.claude/skills/mosk-*`,
> `.claude/agents/`) with the upstream versions, discarding any local
> edits to them. It does **not** touch generated `.claude/rules/` or your
> `docs/`. Only run it from a clean git tree so the change is reviewable
> and reversible.

---

## Workflow

### Step 1 — Preflight (safety)

1. Confirm this is a git repository. If not, warn the user that the
   overwrite will not be reversible and ask whether to proceed.
2. Run `git status --short`. If the tree is dirty, **stop** and ask the
   user to commit or stash first — otherwise `--force` may clobber
   uncommitted work and bury the update in unrelated changes.
3. State plainly that you are about to overwrite the installed MOSK files
   and wait for the user's confirmation before continuing.

### Step 2 — Update the toolkit

Run from the project root:

```bash
npx degit rogerznts/mosk/mosk . --force
```

This copies the contents of the upstream `mosk/` directory over the
current install.

### Step 3 — Read the latest docs from GitHub

Fetch the current toolkit docs straight from the repo (they live at the
repo root and are **not** installed by degit), to learn the current
capabilities and task catalog:

- `https://raw.githubusercontent.com/rogerznts/mosk/master/README.md`
- `https://raw.githubusercontent.com/rogerznts/mosk/master/TASKS.md`

If `master` 404s, retry with `main`. Use these to understand what the
updated toolkit now offers (new agents, skills, tasks, conventions).

### Step 4 — Specify the changes

Report at the end, concisely:

1. **What the update changed locally** — run `git status --short` and
   `git diff --stat` to list the MOSK files that were added, modified, or
   removed by the overwrite.
2. **What's new in the toolkit** — cross-reference the diff with the
   freshly-read `README.md` / `TASKS.md`: new or renamed agents, skills,
   tasks, or conventions, each in one line.
3. **Follow-ups the user may need**:
   - Re-run `/mosk-boot` if the rules/templates structure changed.
   - Run `bash .claude/mosk/scripts/link-codex-skills.sh` for Codex parity
     (regenerates `AGENTS.md`).
   - Review the diff before committing the update.

## Rules

- Never run `degit --force` on a dirty tree without explicit confirmation.
- Do not auto-commit the update — leave the diff for the user to review.
- Read `README.md`/`TASKS.md` from GitHub, not from disk (degit does not
  install them).
- Report removed files too — a `--force` update can delete toolkit files
  that no longer exist upstream.
