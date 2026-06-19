# CLAUDE.md

Behavioral guidelines to reduce common LLM coding mistakes. Merge with the project-specific instructions below.

**Tradeoff:** these guidelines bias toward caution over speed. For trivial tasks, use judgment.

## 1. Think Before Coding

**Don't assume. Don't hide confusion. Surface tradeoffs.**

Before implementing:
- State your assumptions explicitly. If uncertain, ask.
- If multiple interpretations exist, present them — don't pick silently.
- If a simpler approach exists, say so. Push back when warranted.
- If something is unclear, stop. Name what's confusing. Ask.

## 2. Simplicity First

**Minimum code that solves the problem. Nothing speculative.**

- No features beyond what was asked.
- No abstractions for single-use code.
- No "flexibility" or "configurability" that wasn't requested.
- No error handling for impossible scenarios.
- If you write 200 lines and it could be 50, rewrite it.

Ask yourself: "Would a senior engineer say this is overcomplicated?" If yes, simplify.

## 3. Surgical Changes

**Touch only what you must. Clean up only your own mess.**

When editing existing code:
- Don't "improve" adjacent code, comments, or formatting.
- Don't refactor things that aren't broken.
- Match existing style, even if you'd do it differently.
- If you notice unrelated dead code, mention it — don't delete it.

When your changes create orphans:
- Remove imports/variables/functions that YOUR changes made unused.
- Don't remove pre-existing dead code unless asked.

The test: every changed line should trace directly to the user's request.

## 4. Goal-Driven Execution

**Define success criteria. Loop until verified.**

Transform tasks into verifiable goals:
- "Add validation" → "Write tests for invalid inputs, then make them pass"
- "Fix the bug" → "Write a test that reproduces it, then make it pass"
- "Refactor X" → "Ensure tests pass before and after"

For multi-step tasks, state a brief plan:
```
1. [Step] → verify: [check]
2. [Step] → verify: [check]
3. [Step] → verify: [check]
```

Strong success criteria let you loop independently. Weak criteria ("make it work") require constant clarification.

**These guidelines are working if:** fewer unnecessary changes in diffs, fewer rewrites due to overcomplication, and clarifying questions come before implementation rather than after mistakes.

---

# MOSK

This repository contains the MOSK template that is installed into other projects via:

```bash
npx degit rogerznts/mosk/mosk .
```

## Idioma

Os agentes e skills do MOSK respondem no **idioma de comunicação definido nas regras do projeto** (campo *Idioma de comunicação* em `.claude/rules/project.md`). Quando nenhum idioma está definido, o padrão é **português (pt-BR)**. Isso vale independentemente do idioma deste arquivo, dos prompts internos, dos templates ou das tasks (mantidos em inglês por convenção do template). Mantenha em forma literal apenas identificadores de código, comandos, caminhos e nomes de arquivo.

## Important Workspace Note

- The product source of truth is `mosk/`.
- The root `.claude/` directory in this repository is only the local execution environment for working on MOSK itself.
- When changing the installable toolkit, edit files under `mosk/`.

## Repository Shape

```text
mosk/
├── .claude/
│   ├── mosk/
│   │   ├── agents/
│   │   ├── tasks/
│   │   ├── templates/
│   │   ├── scripts/
│   │   └── core-config.yaml
│   └── skills/
```

## Product Model

MOSK is now optimized for:

- direct natural-language use of slash commands
- a short SpecKit happy path
- smaller agent prompts
- optional, not mandatory, helper steps

Conceptually, the toolkit is inspired by BMAD and SpecKit, but the shipped product should be treated as MOSK first. When editing prompts, docs, or templates, prefer MOSK language and only mention BMAD as inspiration or lineage when that context is useful.

The default path is:

```text
specify -> plan -> tasks -> implement -> qa-gate -> archive
```

`clarify`, `analyze`, and `checklist` are optional support tasks.

## Agent Design

Agents live in `mosk/.claude/mosk/agents/`.

Each agent should remain:

- concise
- direct
- low-menu
- low-token
- explicit about when to ask questions

The preferred UX is:

- user invokes `/mosk-{agent}` with natural language
- agent maps the request directly to the right task or output
- menu is only fallback when activation is empty

## Skills

Skills live in `mosk/.claude/skills/`.

They should:

- point directly to the real agent or task
- avoid extra wrapper layers
- avoid quick-pick flows

## Tasks

Tasks live in `mosk/.claude/mosk/tasks/`.

When editing tasks:

- optimize for the happy path first
- keep outputs implementation-oriented
- avoid mandatory elicitation unless the missing answer materially changes the result
- keep optional artifacts optional

## Validation

There is no compiled app or automated test suite for the template itself.

Validation here is mainly:

- reading the installed file structure
- checking prompt and workflow consistency
- ensuring documentation matches the shipped template
