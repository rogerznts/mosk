---
name: tea-open-pr
description: Opens a Pull Request on Gitea using the `tea` CLI. Auto-detects branch type, generates PR text, applies label and assignee automatically.
---

# Open Pull Request (tea)

Your goal is to open a Pull Request on Gitea using the `tea` CLI, generating clear, professional, and well-structured PR text that facilitates efficient code reviews.

## Prerequisites

`tea` must be configured with a login for this server. If not yet done, run:

```bash
tea login add --name=<alias> --url=<gitea-url> --token=<your-token>
```

When run inside a git repository that has a Gitea remote, `tea` auto-detects the login and repo — no flags or env vars needed.

---

## Workflow

### Step 1 — Identify the branches and type

- Use the current git branch as the **source** (head).
- Auto-detect the branch type from its name prefix. MOSK spec branches are
  `{tipo}/{NNN}-{nome}` (e.g. `fix/013-carrinho-vazio`), so the prefix **is**
  the type:
  - `feature/` → **Feature**
  - `fix/` (or the legacy `bugfix/`) → **Bugfix**
  - `hotfix/` → **Hotfix**
  - `refactor/`, `gmud/`, `experimental/` → **Feature** (single PR to integration)
  - Legacy MOSK shape `{NNN}-{tipo}-{nome}` (e.g. `013-fix-carrinho`) → read the
    type from the **second** segment
  - Otherwise → treat as **Feature**
- Based on the type, determine targets:
  - **Feature / Bugfix** → single PR to the integration branch (typically `hml` or `develop`)
  - **Hotfix** → two PRs: first to the stable branch (typically `main`), second to the integration branch

Confirm with the user which base branches apply if the repo does not follow the `main`/`hml` pattern.

---

### Step 2 — Read the diff

Run:
```bash
git log <integration-branch>..<head> --oneline
git diff <integration-branch>..<head> --stat
```

(Use `<stable-branch>..<head>` for hotfix.)

- Alert the user if debug logs (`console.log`, `var_dump`, `dd()`) or temporary test code are present.

---

### Step 3 — Generate the PR text

**Title:** Conventional Commits format (e.g., `feat(module): short description`, `fix(module): short description`).

**Body (Standard PR — Feature / Bugfix / Hotfix → stable branch):**

```
## Summary

- <bullet: what this PR does, high level>

## Details

**How:** <explanation of how the changes were implemented>

- <bullet per relevant change group>

**Why:** <motivation, business rule, or problem being solved>

## Impact

- <bullet: effect on the user or system>
```

**Body (Hotfix → integration branch — always use exactly this):**

```
Applying hotfix changes to the integration branch.
```

- All text must be in English.
- Be clear and professional.

---

### Step 4 — Determine the label

Run to list available labels:
```bash
tea labels list
```

Auto-suggest based on branch prefix:

| Branch prefix | Suggested label |
|---------------|-----------------|
| `feature/`    | `Kind/Feature` (or equivalent) |
| `bugfix/`     | `Kind/Bug` (or equivalent) |
| `hotfix/`     | `Kind/Hot` (or equivalent) |

- Match against the actual labels returned by `tea labels list`.
- If a clear match exists, inform the user and proceed. If not, show the list and ask the user to choose.
- The same label applies to **both PRs** on a hotfix.

---

### Step 5 — Determine the assignee

Ask the user who to assign, or skip if unneeded. `tea` accepts usernames directly — no ID lookups required.

---

### Step 6 — Create the PR(s)

**Feature / Bugfix — single PR to integration branch:**
```bash
tea pr create \
  --title "<title>" \
  --description "<body>" \
  --base <integration-branch> \
  --labels "<label-name>" \
  --assignees "<username>"
```

**Hotfix — two PRs:**

First, PR to stable branch:
```bash
tea pr create \
  --title "<title>" \
  --description "<standard body>" \
  --base <stable-branch> \
  --labels "<label-name>" \
  --assignees "<username>"
```

Then, PR to integration branch:
```bash
tea pr create \
  --title "<title>" \
  --description "Applying hotfix changes to the integration branch." \
  --base <integration-branch> \
  --labels "<label-name>" \
  --assignees "<username>"
```

`tea` auto-detects the repo from the git remote. Use `--login <alias>` if you have multiple logins configured.

---

### Step 7 — Return the URL(s)

`tea pr create` outputs the PR URL on success. Show it to the user:

- **Feature / Bugfix:** the single PR URL
- **Hotfix:** both PR URLs with their respective targets

---

## Notes

- `tea` resolves label names and assignee usernames automatically — no ID lookups needed.
- `tea` auto-detects server and repo from the git remote when run inside the repository.
- For hotfixes, both PRs share the same title and label, but have different bodies and base branches.
- Never skip label selection — always use `tea labels list` to validate names.
- Branch type is always auto-detected from the branch name — never ask. In MOSK spec branches the prefix is the type (`fix/013-…`); in the legacy shape it is the second segment (`013-fix-…`).
