---
name: tea-commit
description: Stages and commits pending changes using Conventional Commits format. Reads the diff, alerts for debug code, generates a clear commit message, and commits without skipping hooks.
model: haiku
---

# Commit (tea)

Your goal is to stage and commit pending changes with a well-formed Conventional Commits message.

---

## Workflow

### Step 1 — Read the pending changes

Run:
```bash
git status
git diff
```

- Summarize the changes for the user.
- Alert if debug code is present (`console.log`, `var_dump`, `dd()`, `print_r`, `debugger`).
- If the working tree is clean, inform the user and stop — there is nothing to commit.

---

### Step 2 — Generate the commit message

Produce a message in **Conventional Commits** format:

```
<type>(<scope>): <short description>
```

Common types: `feat`, `fix`, `refactor`, `chore`, `docs`, `test`, `style`, `perf`, `ci`.

- Scope is optional but recommended when the change is scoped to a module, component, or package.
- Short description: imperative mood, lowercase, no trailing period, max 72 characters.
- If the change warrants it, add a body after a blank line explaining **what** and **why**.

Show the proposed message to the user before committing.

---

### Step 3 — Stage and commit

```bash
git add -A
git commit -m "<commit-message>"
```

- Never use `--no-verify`.
- If a pre-commit hook fails, report the failure output to the user and stop — do not retry or bypass the hook.

---

### Step 4 — Confirm

Show the result of `git log --oneline -1` so the user can verify the commit was created.

---

## Notes

- Always read the diff before generating the message — never guess from filenames alone.
- Never skip hooks (`--no-verify`).
- If debug code is detected, warn the user and ask whether to proceed or clean it up first.
- If the user provides a message or scope hint as an argument, use it as the basis for the generated message instead of inferring from scratch.
