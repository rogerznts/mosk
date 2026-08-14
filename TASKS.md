# MOSK Task & Skill Catalog

Every MOSK capability, grouped by the agent or skill that owns it. Each
agent maps natural-language requests to one of these tasks; you can also
name the task directly (e.g. `/mosk-architect grill`, `/mosk-po artefact`).

- **Pipeline agents** (`po`, `sm`, `dev`, `qa`) run the spec lifecycle.
- **Preamble agents** (`analyst`, `pm`, `architect`, `ux-expert`, `ui-expert`) ground the work before/around the pipeline.
- **Standalone skills** (`mosk-boot`, `mosk-handoff`, `mosk-help`) are utilities not tied to a persona.
- **Support tasks** are invoked by other tasks/templates, not directly.

See the [README](README.md) for the overall flow and document layout.

---

## Preamble agents

### `/mosk-analyst` — Maria · discovery & research

| Task | What it does |
|---|---|
| `create-brief` | Project brief → `docs/discovery/brief.md`. |
| `create-market-research` | Market research report → `docs/discovery/market-research.md`. |
| `create-competitor-analysis` | Competitor analysis → `docs/discovery/competitor-analysis.md`. |
| `facilitate-brainstorming-session` | Facilitated brainstorming workshop, captured to `docs/discovery/brainstorming/`. |
| `create-deep-research-prompt` | Builds a targeted deep-research prompt from briefs/research/questions. |
| `create-doc` | Generic document from any analyst template. |

### `/mosk-pm` — João · product & PRD

| Task | What it does |
|---|---|
| `create-doc` | PRDs and product docs from template → `docs/prd/`. |
| `execute-checklist` | Validates a product doc against the PM checklist. |
| `shard-doc` | Splits a monolithic PRD (`docs/prd/raw.md`) into `index.md` + section files. |
| `planner` | Maintains a **non-technical** tracking plan + dated update log for PO/stakeholders. Scope follows the branch: base branch → whole project (`docs/project/`); spec branch → that spec (`docs/specs/{id}/project/`) **plus** a refresh of the project plan. |

```
/mosk-pm planner                              # tracks the project (base branch) or the current spec (feature branch)
/mosk-pm planner "fechamos o épico de cupom"  # the comment guides the dated update's narrative
```

### `/mosk-architect` — Vinicius · architecture & technical design

| Task | What it does |
|---|---|
| `create-doc` | Architecture / technical design document → `docs/architecture/`. |
| `grill` | Relentless one-question-at-a-time interview that stress-tests a plan/design against the domain glossary and documented decisions; sharpens terminology inline (`docs/architecture/glossary.md`) and offers ADRs sparingly. |
| `execute-checklist` | Architecture checklist review. |
| `shard-doc` | Shards a large architecture doc (`docs/architecture/raw.md`). |

```
/mosk-architect design doc para o serviço de cupom
/mosk-architect grill o plano da spec 012
```

### `/mosk-ux-expert` — Salete · flows, wireframes, UX behavior

| Task | What it does |
|---|---|
| `create-doc` | UX / front-end spec document → `docs/ui/`. |
| `draft-frontend-prompt` | Generates a front-end build prompt for an external tool. |

### `/mosk-ui-expert` — Tiago · visual polish & design system

Built on the **[taste](https://github.com/Leonxlnx/taste-skill)** design
engineering system — opinionated rules that override default LLM biases
toward generic, template-like UI. The taste rules are embedded directly
in the agent and its tasks; no extra skill discovery is required. The
agent still loads `.claude/rules/*.md` via the standard MOSK context
loading protocol.

| Task | Style / effect | Example |
|---|---|---|
| *(no arg)* | Shows the menu with all options. | `/mosk-ui-expert` |
| `hallmark` | Anti-slop design system: picks one of 21 macrostructures + one of 20 themes, then runs 58 slop-test gates. Verbs: `audit` (score only, no edits), `redesign`, `study <url\|screenshot>`. | `hallmark landing page do produto` · `hallmark audit src/App.tsx` |
| `webdesign-brutalist` | Swiss typography, terminal aesthetics, rigid grids. | `/mosk-ui-expert brutalist dashboard de monitoramento` |
| `webdesign-minimalist` | Editorial, warm monochrome, flat bento grids. | `/mosk-ui-expert minimalist landing de analytics` |
| `webdesign-soft` | $150k+ agency feel, haptic depth, cinematic motion. | `/mosk-ui-expert soft pricing page` |
| `webdesign-redesign` | Audits and upgrades an existing interface. | `/mosk-ui-expert redesign da home atual` |
| `webdesign-stitch` | Generates a `DESIGN.md` for Google Stitch. | `/mosk-ui-expert stitch` |
| `webdesign-output` | Enforces full code generation, no truncation. | `/mosk-ui-expert output completo` |

**What taste enforces:**

- strict anti-AI-pattern rules (no Inter font, no neon glows, no 3-card grids, no generic names)
- metric-based design dials (variance, motion intensity, visual density)
- hardware-accelerated CSS animation constraints
- mandatory interaction states (loading, empty, error, active)
- responsive collapse guarantees
- dependency verification before any import

**Hallmark** is a second, independent rule-set living alongside taste —
vendored from [Nutlope/hallmark](https://github.com/Nutlope/hallmark) (MIT)
into `mosk/.claude/mosk/data/hallmark/`. Where taste governs *finish*,
Hallmark governs *structure*: it forces a different page shape, nav and
footer archetype on every run (project memory in `.hallmark/log.json`), so
two builds don't share a fingerprint. While the `hallmark` task is loaded its
rules **override** the taste baseline where they conflict — display serifs
and plain HTML + CSS output are legal there. Update the vendor with
`bash .claude/mosk/scripts/sync-hallmark.sh`; never edit `data/hallmark/` by
hand.

---

## Pipeline agents

### `/mosk-po` — Sara · specs, planning, task generation

| Task | What it does |
|---|---|
| `full-spec` | Runs `specify → plan → tasks` in one pass. |
| `specify` | Creates/updates only `spec.md` from a natural-language request. |
| `clarify` | Resolves only critical ambiguities in `spec.md` (≤3 questions, intentionally light — opposite of `grill`). |
| `plan` | Creates/updates `plan.md` plus supporting artifacts when they add value. |
| `analyze` | Focused consistency review across the spec artifacts. |
| `checklist` | Creates/updates a focused quality checklist for the active spec. |
| `tasks` | Generates a dependency-ordered `tasks.md` from the design artifacts. |
| `create-epic` / `create-story` | Epic or story for an existing project. |
| `artefact` | Creates a complementary addendum (small, planned scope addition) for an **active** spec, instead of opening a new branch/spec. |
| `review-story-draft` | Validates a draft story for completeness. |

```
/mosk-po full-spec login social para clientes B2B
/mosk-po specify checkout com cupom
/mosk-po plan para a spec atual
/mosk-po tasks para a spec atual
/mosk-po artefact ajuste de copy no checkout (spec 012)
```

`full-spec` stops at `tasks`; implementation stays with `/mosk-dev`.

### `/mosk-sm` — Roberto · story readiness & sequencing

| Task | What it does |
|---|---|
| `enrich-story` | Prepares the next story, enriching it with technical context. |
| `review-story-draft` | Validates a draft story before it goes to Dev. |
| `correct-course` | Re-plans/sequences when work drifts from the agreed path. |
| `execute-checklist` | Runs the readiness checklist. |

### `/mosk-dev` — Jaime · implementation, QA fixes, archive

| Task | What it does |
|---|---|
| `implement` | Executes the active `tasks.md`, keeping progress visible. |
| `apply-qa-fixes` | Consumes QA gate/assessments and applies code/test changes. |
| `archive` | Promotes canonical artifacts and moves the spec to `docs/specs/archive/`. |
| `execute-checklist` | Runs the delivery checklist. |
| `audit-docs-paths` | Path-integrity audit (5 rules, exit 1 on violations). Also `/mosk-dev audit`. |
| `index-docs` | Regenerates `docs/index.md`. |

```
/mosk-dev implement a spec 012
/mosk-dev archive a spec 012
/mosk-dev index-docs
/mosk-dev audit
```

### `/mosk-qa` — Joaquim · gates, test strategy, reviews

| Task | What it does |
|---|---|
| `qa-gate` | Creates/updates the quality gate decision (`gate.yaml`). |
| `review-story` | Comprehensive test-architecture review + gate decision. |
| `design-tests` | Test scenarios with recommended test levels. |
| `trace-spec` | Maps requirements to test cases (Given-When-Then) for traceability. |
| `assess-risk` | Risk matrix via probability × impact. |
| `assess-nfr` | NFR validation (security, performance, reliability, maintainability). |
| `apply-qa-fixes` | Applies QA-driven fixes (shared with Dev). |

```
/mosk-qa qa-gate a spec 012
/mosk-qa review a story 2.1
```

### `/mosk-security` — Heitor · vulnerability review & audit

On-demand security reviewer (inspired by Anthropic's `claude-code-security-review`): contextual, diff-aware analysis with a hard confidence threshold and an explicit false-positive exclusion list. Not a pipeline phase — its report **feeds the `qa-gate`** (a `SECURITY: FAIL`/`CONCERNS` verdict informs the gate).

| Task | What it does |
|---|---|
| `security-review` | Diff-aware review of the branch's pending changes (3 phases: repo context → comparative analysis → vulnerability assessment). Reports findings with severity + confidence to `docs/qa/security/`. |
| `assess-security` | Full-codebase security audit (same taxonomy, broader scope). On demand, outside the happy path. |

```
/mosk-security review the pending changes
/mosk-security audit the whole codebase
```

---

## Standalone skills

| Skill | What it does |
|---|---|
| `/mosk-bench` (Bento) | Self-contained **workbench mode** for non-technical users: grills a business briefing, then autonomously runs the SDD pipeline to build & iterate an internal tool — Docker-based, pt-BR, zero technical decisions for the user. Active stack: Payload (pluggable adapter). (task: `bench-mode`) |
| `/mosk-deploy` (Bento) | Publishes a `/mosk-bench` tool to a hosting provider (Railway today) using the **user's own account** — remote build (INV-4 preserved), managed Postgres/Redis, public URL, all in pt-BR. Opt-in, separate from the local bench flow (ADR-0005). Stack × provider pluggable. (task: `deploy-mode`) |
| `/mosk-boot` | Analyzes a consuming project and generates `.claude/rules/` + scaffolds the canonical `docs/` layout. Run first; re-run when structure changes. (task: `boot`) |
| `/mosk-handoff` | Compacts the current session into a handoff document saved to `docs/handoff/handoff-<YYYY-MM-DD>-<slug>.md` in the **current workspace** (never OS temp), anchored to the active spec/documentation. |
| `/mosk-suggestion` | Reads the current session state (active spec, `current_phase`, on-disk artifacts, conversation focus) and suggests the **next** MOSK agent to call, with a ready-to-paste prompt. Suggest-only — never invokes another agent. |
> **Agentes shipam em duas camadas** (ADR-0015): `.claude/agents/mosk-<n>.md` é a
> definição (e o que torna o agente invocável por outro, em contexto isolado);
> `.claude/skills/mosk-<n>/SKILL.md` é o wrapper gerado que dá o slash command.
> Edite o agente — o wrapper é regenerado por `sync-agents-skills.sh`.

| `/mosk-orq` (Mauro) | **Corrida autônoma de entrega.** Recebe uma spec com `tasks.md` pronto e a leva ao gate verde sozinho: um `mosk-dev` por user story em worktree isolado, merge, `mosk-qa` + `mosk-security` verificando, correção, repetição. **Opt-in por corrida** — nenhuma config liga isso. Para em dúvida real e em tudo irreversível; registra cada decisão autônoma em `run-log.md`. Não roda o `archive` (ADR-0019). |
| `/mosk-write-skill` | Scaffolds a new MOSK skill (agent wrapper or direct support) with proper structure, a trigger-rich description, optional backing task, and the sync steps. |
| `/mosk-update` | **Reinstalls** the toolkit from scratch (clean-tree guarded): downloads to a temp dir, shows an exact `--dry-run` preview of what will be deleted, waits for your `ok`, then resets and installs. Removes orphans left by past versions — `degit --force` overwrites but never deletes. Preserves `.claude/rules/`, settings, `docs/` and your own skills. |
| `/mosk-help` | Short MOSK guide: recommended flow, natural-language usage, and when to call each agent. |

```
/mosk-boot
/mosk-handoff próxima sessão vai implementar o checkout (spec 012)
/mosk-suggestion qual o próximo passo?
/mosk-orq 012                    # entrega a spec 012 sozinho, com agentes paralelos
/mosk-write-skill uma skill para exportar specs em PDF
/mosk-update
/mosk-help
```

Git helpers via the `tea` CLI ship alongside MOSK: `/tea-commit`,
`/tea-open-pr`, `/tea-open-fast-pr`, `/tea-prune-branches`.

---

## Support tasks (invoked indirectly)

These are building blocks called by other tasks/templates — you rarely
invoke them by name:

| Task | Used by |
|---|---|
| `create-doc` | The template-driven doc engine behind analyst/pm/architect/ux `create-doc` entries. |
| `execute-checklist` | Generic checklist validation engine (pm, architect, sm, dev). |
| `shard-doc` | Splits any monolithic `raw.md` into `index.md` + sections. |
| `advanced-elicitation` | Elicitation-method menu offered by document templates during `create-doc`. |
| `map-project` | Maps an existing project's structure; used by `create-story` and the existing-project PRD template. |
