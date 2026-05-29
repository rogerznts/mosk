---
name: mosk-handoff
description: "Handoff: compacta a sessão atual em um documento de transição salvo em docs/handoff/ do workspace, amarrado à spec/documentação ativa."
argument-hint: "Para que servirá a próxima sessão?"
---

# Handoff (MOSK)

Compact the current conversation into a handoff document so a fresh agent can pick up the work.

> **IMPORTANT — write to the current workspace, not the OS temp directory.**
> Unlike a generic handoff, this MOSK skill always saves the document inside
> the project at `docs/handoff/`. Never write to `/tmp`, `%TEMP%`, or any
> directory outside the repository. The handoff is a project artifact and
> must live in the workspace alongside the work it describes.

---

## Workflow

### Step 1 — Load project + active context

1. Read every file in `.claude/rules/*.md` for durable project context.
2. Detect the documentation the user is currently working on:
   - Run `bash .claude/mosk/scripts/check-prerequisites.sh --json --paths-only` (when available) to resolve `BRANCH`, `FEATURE_DIR`, and `AVAILABLE_DOCS`.
   - If a `FEATURE_DIR` resolves, read its `spec-meta.yaml` (`spec_id`, `type`, `status`, `current_phase`) and note which artifacts exist (`spec.md`, `plan.md`, `tasks.md`, `stories/`, `gate.yaml`).
   - If no active spec, identify the base domain in play from the conversation (`docs/prd/`, `docs/architecture/`, `docs/ui/`, `docs/qa/`, …).
3. Note which files were actually touched or discussed this session (`git status`, `git diff --stat`).

### Step 2 — Resolve the target path

1. Ensure the folder exists: `mkdir -p docs/handoff`.
2. Compute the date: `date +%Y-%m-%d` (day, month, year).
3. Build the filename: `docs/handoff/handoff-<YYYY-MM-DD>-<slug>.md`, where `<slug>` is the active `spec_id` when there is one (e.g. `005-feature-checkout-coupon`), otherwise a short kebab-case slug from the session focus or the user's argument.
4. If the target already exists, append a short suffix (`-2`, `-3`, …) — never overwrite a previous handoff.

### Step 3 — Write the handoff document

Use the template below. Fill the **Active documentation** section first: this is what differentiates a MOSK handoff — it must state the relationship to the spec/documentation in play, not just the session context.

```markdown
# Handoff — <YYYY-MM-DD>

> Próxima sessão: <argument, ou "continuação geral do trabalho">

## Active documentation
- Spec / domain: <spec_id + type, ou domínio base; "none" se for trabalho avulso>
- Branch: <branch>
- Phase: <current_phase, quando houver spec>
- Linked artifacts:
  - <path/para/spec.md>
  - <path/para/plan.md, tasks.md, ADR, PRD delta… os que existirem>

## Session context
- Goal: <o que esta sessão tentou alcançar>
- What changed: <resumo das mudanças; referencie arquivos/commits por path, não cole diffs>
- Decisions made: <decisões e o porquê — apenas o que NÃO está já registrado em ADR/plan/spec>
- Open threads: <perguntas em aberto, ambiguidades, bloqueios>

## Next steps
1. <próximo passo concreto>
2. <…>

## Suggested skills
- `/<skill>` — <por que invocar a seguir; ex.: /mosk-dev implement, /mosk-architect grill, /mosk-qa qa-gate>

## References
- <links/paths para PRDs, plans, ADRs, issues, commits — referencie, não duplique>
```

### Step 4 — Confirm

Report the saved path and a one-line summary of what the next agent should do first.

---

## Rules

- **Always write inside the workspace** at `docs/handoff/` — never the OS temp directory.
- **Anchor to the active documentation.** If a spec/PRD/architecture doc is in play, the handoff must name it and link its artifacts by path. This relationship is mandatory, not optional.
- **Do not duplicate** content already captured in PRDs, plans, ADRs, issues, commits, or diffs — reference them by path or URL instead.
- **Redact secrets** — API keys, passwords, tokens, and PII must never appear in the document.
- Keep it compact: a fresh agent should be able to resume from this file plus the referenced artifacts, nothing more.
- If the user passed an argument, treat it as the focus of the next session and tailor "Next steps" and "Suggested skills" accordingly.
