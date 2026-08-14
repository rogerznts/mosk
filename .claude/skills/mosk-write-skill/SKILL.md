---
name: mosk-write-skill
description: "Write Skill: cria uma nova skill MOSK (wrapper de agente ou direta de suporte) com estrutura, descrição com gatilhos e sincronização Codex correta."
argument-hint: "Que skill você quer criar?"
---

# Write a MOSK Skill

Create a new skill that fits the MOSK conventions. Skills are for
**actions/commands only — never project context** (context lives in
`.claude/rules/*.md`).

> **IMPORTANT — source of truth.** Author the skill under
> `mosk/.claude/skills/<name>/SKILL.md`. That is the only location that
> ships via `npx degit`. Never create the product skill at the repo
> root mirror (`.claude/skills/`) — that copy is local execution only.

---

## Step 1 — Pick the archetype

MOSK has two kinds of skills. Decide first:

| Archetype | When | Pattern |
|---|---|---|
| **Agent wrapper** (`mosk-<persona>`) | The skill activates one of the 11 personas (analyst, pm, architect, ux-expert, ui-expert, po, sm, dev, qa, security, bench). | A thin `SKILL.md` that points to `.claude/agents/mosk-<name>.md` as the single source of truth. Do not duplicate the persona content. Since spec 011 (ADR-0015) the CC agent IS the definition — the wrapper only carries front-matter and the pointer. |
| **Direct support skill** (e.g. `mosk-handoff`, `mosk-boot`, `tea-*`) | A self-contained utility/command with its own workflow, not tied to a persona. | A standalone `SKILL.md` containing the full workflow inline. |

If unsure which one the user needs, ask once.

## Step 2 — Gather requirements

Ask the user only what changes the result:

- What task/command does the skill perform?
- Which agent owns it, or is it standalone support?
- Does it run deterministic steps that belong in a script under `mosk/.claude/mosk/scripts/`, or just instructions?
- Where does its output go (must be a canonical `docs/` domain or an existing path)?

## Step 3 — Write the SKILL.md

Frontmatter is mandatory. The **description is the only thing the agent
sees when deciding to load the skill** — make it specific.

- Max ~1024 chars, third person.
- First sentence: what it does. Then: when to use it (concrete triggers).
- MOSK voice: keep it terse, low-menu, low-token. No greetings, no command-teaching, no quick-pick menus.

**Agent-wrapper body** (copy this shape):

```md
---
name: mosk-<persona>
description: "<Área>: <ações principais em PT-BR>."
---

CRITICAL: Read and fully execute the agent definition at `.claude/agents/mosk-<persona>.md`.
That file is the single source of truth — it contains the full persona, commands, dependencies,
and activation instructions. Follow ALL instructions defined there exactly.
```

> **For an agent wrapper, the description is authored in the agent, not
> here.** Put it on the agent's first line, one physical line, no double
> quotes:
>
> ```md
> <!-- skill-description: <Área>: <ações principais em PT-BR, com gatilhos>. -->
> ```
>
> `sync-agents-skills.sh` copies it into both the wrapper and the CC agent.
> It is deliberately separate from `## Mission`: the description is *routing*
> metadata (when to load me), the Mission is *persona prose* (what I do once
> loaded). Deriving one from the other truncated every curated description.
> The sync only ever rewrites the `description:` line of an existing wrapper —
> extra front-matter keys (`argument-hint:`) and hand-written bodies survive.

**Direct support body**: write the workflow inline (see `mosk-handoff`
or `tea-commit` as references) — numbered steps, explicit rules, an
`argument-hint` when it takes input.

## Step 4 — Wire a task (only for new agent capabilities)

If the skill adds a new *capability* to an existing agent, the real work
is usually a task: create `mosk/.claude/mosk/tasks/<task>.md` and
reference it under the agent's `## Task mapping`. The skill just
activates the persona; the agent maps the request to the task.

## Step 5 — Sync the layers

After creating or renaming a skill, run from the correct root:

```bash
# agent skills: keep agents <-> skills <-> CC agents in sync
bash mosk/.claude/mosk/scripts/sync-agents-skills.sh both --clean

# Codex parity (regenerates AGENTS.md + .codex symlinks)
bash mosk/.claude/mosk/scripts/link-codex-skills.sh
```

`AGENTS.md` is auto-generated — never hand-edit it.

## Step 6 — Review with the user

Present the draft and confirm it covers the use cases. Then verify:

- [ ] Lives under `mosk/.claude/skills/<name>/SKILL.md` (ships via degit).
- [ ] Description is specific and includes when-to-use triggers.
- [ ] Agent wrappers stay thin (delegate to `.claude/agents/mosk-<name>.md`); direct skills are self-contained.
- [ ] No project context baked into the skill (that belongs in `.claude/rules/`).
- [ ] New agent capability is backed by a task in `mosk/.claude/mosk/tasks/` and referenced in the agent's `## Task mapping`.
- [ ] Outputs target canonical `docs/` paths only.
- [ ] No time-sensitive info; consistent terminology; concrete examples.
- [ ] Catalogued in `TASKS.md`.
- [ ] Sync scripts run.
