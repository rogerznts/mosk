# MOSK Skills

MOSK is a compact toolkit inspired by BMAD and SpecKit, but the shipped skills and prompts should present themselves as MOSK, not as a renamed legacy bundle.

MOSK installs Claude Code skills under:

```text
.claude/skills/<skill>/SKILL.md
```

Each skill becomes a slash command based on its frontmatter `name`.

Example:

```text
name: mosk-po
```

becomes:

```text
/mosk-po
```

## Preferred Usage

Use agents with natural language, not menu navigation:

```text
/mosk-po full-spec checkout com cupom
/mosk-dev implementar a spec 012
/mosk-qa revisar a spec 012
```

Advanced `*commands` still work, but they are compatibility shortcuts rather than the primary UX.

## Main Skills

- `mosk-analyst`
- `mosk-pm`
- `mosk-ux-expert`
- `mosk-architect`
- `mosk-po`
- `mosk-sm`
- `mosk-dev`
- `mosk-qa`
- `mosk-ui-expert`

## Helper Skills

- `mosk-help`
- `mosk-boot`

## Project Rules

Project context lives in `.claude/rules/*.md` as plain markdown files. MOSK agents read every file there before executing any task. The `mosk-boot` skill generates a compact rule pack (`project.md`, and `frontend.md` when applicable). To migrate legacy `ctx-*` context skills from older projects into the new rule layout, run:

```bash
bash .claude/mosk/scripts/migrate-ctx-skills-to-rules.sh
```

## Daily Flow

```text
full-spec -> implement -> qa-gate -> archive
```

Granular path:

```text
specify -> plan -> tasks -> implement -> qa-gate -> archive
```

Optional helpers:

- `clarify`
- `analyze`
- `checklist`

`full-spec` stops at `tasks` and keeps implementation with `mosk-dev`.

## Scripts

### sync-agents-skills.sh

Synchronizes agents, skills, and Claude Code agent files. Run after adding or removing agents:

```bash
bash .claude/mosk/scripts/sync-agents-skills.sh              # both directions
bash .claude/mosk/scripts/sync-agents-skills.sh --dry-run     # preview only
bash .claude/mosk/scripts/sync-agents-skills.sh --clean       # also remove orphans
bash .claude/mosk/scripts/sync-agents-skills.sh --clean --dry-run  # preview orphan removal
```

By default the script only **creates or updates** — it never deletes files.
Use `--clean` to remove orphan skills and CC agents whose source agent no longer exists.

### link-codex-skills.sh

Creates symlinks for Codex CLI compatibility (skills **and** rules):

```bash
bash .claude/mosk/scripts/link-codex-skills.sh
```

### migrate-ctx-skills-to-rules.sh

Converts legacy `.claude/skills/ctx-*/SKILL.md` into `.claude/rules/*.md`. Default behavior deletes the old `ctx-*` skill directories after a successful conversion.

```bash
bash .claude/mosk/scripts/migrate-ctx-skills-to-rules.sh              # convert + delete old
bash .claude/mosk/scripts/migrate-ctx-skills-to-rules.sh --keep-old   # convert, keep old
bash .claude/mosk/scripts/migrate-ctx-skills-to-rules.sh --dry-run    # preview only
```
