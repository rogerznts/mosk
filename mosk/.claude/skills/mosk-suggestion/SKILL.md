---
name: mosk-suggestion
description: "Suggestion: interpreta o ponto atual da sessão (spec ativa, current_phase, artefatos no disco e foco da conversa) e sugere o próximo agente MOSK a chamar, já com um prompt pronto para colar. Deriva as jogadas legais do pipeline-graph.yaml (fonte única) via legal_moves.sh — não há tabela hardcoded. Use quando o usuário perguntar 'e agora?', 'qual o próximo passo?', 'qual agente devo chamar?' ou quiser orientação para avançar no pipeline (specify → plan → tasks → implement → qa-gate → archive). Apenas sugere — nunca invoca outro agente automaticamente."
argument-hint: "O que você quer fazer a seguir? (opcional)"
---

# Suggestion (MOSK)

Read the current session state and recommend the **single next MOSK
agent** to call, with a ready-to-paste prompt. This is the inverse of a
handoff: instead of writing a document, you produce one concrete next
step the user can run immediately.

As jogadas possíveis **derivam do grafo** (`pipeline-graph.yaml`), a fonte
única de verdade — computadas por `legal_moves.sh`. Este skill não carrega
nenhuma tabela "estado → agente": ela seria uma cópia que divergiria do
grafo (ver ADR-0006).

> **Idioma:** responda no idioma de comunicação do projeto (campo *Idioma de
> comunicação* em `.claude/rules/project.md`); o padrão é **português (pt-BR)**
> quando nenhum estiver definido. Mantenha em forma literal apenas nomes de
> skill, comandos, caminhos e ids de spec.

> **IMPORTANT — suggest only, never invoke.** This skill follows the MOSK
> Escalation Policy: it **proposes** the next agent and **waits**. Never
> activate another persona, run its task, or chain agents automatically.
> The user decides whether to run the prompt, skip, or redirect.

---

## Workflow

### Step 1 — Read the current state

1. Read every file in `.claude/rules/*.md` for durable project context.
2. Resolve the active spec and phase:
   - Run `bash .claude/mosk/scripts/check-prerequisites.sh --json --paths-only` (when available) to resolve `BRANCH`, `FEATURE_DIR`, and `AVAILABLE_DOCS`.
   - If a `FEATURE_DIR` resolves, read its `spec-meta.yaml`: `spec_id`, `type`, `status`, `current_phase`.
   - Note which artifacts exist on disk: `spec.md`, `plan.md`, `tasks.md`, `stories/`, `tests/`, `gate.yaml`.
   - If `current_phase` is `qa-gate`, read `gate.yaml` to learn the verdict (`PASS` | `CONCERNS` | `FAIL` | `WAIVED`).
   - **If there is no active spec yet**, treat the phase as `__start__` (pre-spec routing).
3. Read the **conversation focus**: what was just completed or discussed this session. The chat is authoritative when it is clearly ahead of the metadata (e.g. the user just finished implementing but `current_phase` still says `tasks`).
4. Reconcile: when the conversation and `current_phase` disagree, trust what actually happened in the session and say so in the suggestion.

### Step 2 — Compute the legal moves from the graph

Run the single source of truth instead of guessing from a table:

```bash
bash .claude/mosk/scripts/legal_moves.sh <current_phase>
# ex.: legal_moves.sh implement   |   legal_moves.sh __start__
```

The script reads `pipeline-graph.yaml` and returns:

- **moves** — edges leaving `<current_phase>`, with the `default` (happy
  path) marked. Each move maps to the node's owning agent/skill in the graph
  (`nodes:` → `agent`).
- Guards of kind **`fact`** are already evaluated (disk-checked) — moves whose
  fact guard failed are omitted.
- Guards of kind **`judgment`** are surfaced with their `question` — **you**
  evaluate them against the conversation focus and the diff (e.g.
  `diff_security_sensitive`, `request_vague`). Offer the move only when your
  judgment says the guard holds.
- **escalations** — side-trips to a preamble agent available from this phase
  (`missing_adr → architecture`, `prd_conflict → prd`, …), each returning to
  the current phase.

Pick **one primary** suggestion — normally the `default` move. Add at most two
alternatives only when a real fork exists (a satisfied judgment guard, an
optional `readiness` pass, or a relevant escalation).

To map a move's target node to its agent/skill, read `nodes:` in
`pipeline-graph.yaml` (`agent:` field). Fill the ready-to-paste prompt with
the **real** `spec_id` / description.

### Step 3 — Emit the suggestion block

Output exactly one block. Fill the prompt with the **real** `spec_id` /
description, not placeholders:

```markdown
> **Próximo passo sugerido**
> - Onde estamos: <fase atual ou o que acabou de ser concluído>
> - Próximo agente: `/mosk-<x>`
> - Prompt pronto: `/mosk-<x> <ação com o spec-id/descrição reais>`
> - Por quê: <uma linha justificando, citando o guard/escala quando relevante>
> - Alternativas: <0–2 opções, ou "nenhuma">
```

Then stop. End with one short line telling the user to colar o prompt
para prosseguir (ou pedir outra direção). **Do not run anything.**

---

## Notes

- `full-spec` cobre `specify → plan → tasks` de uma vez; depois dele o
  próximo passo é `/mosk-dev implement`.
- `/mosk-sm` (readiness) e `/mosk-security` (security-review) são
  **side-trips** no grafo: opcionais e sugeridos por guard, nunca no
  ponteiro. Sugira-os quando o guard correspondente vale.
- Se `legal_moves.sh` não estiver disponível (instalação antiga) ou o grafo
  faltar, degrade para o caminho feliz textual
  `specify → plan → tasks → implement → qa-gate → archive` e avise que o
  grafo não foi encontrado — mas prefira sempre o script.
- Se o usuário passou um argumento, trate-o como a intenção do próximo passo
  e enviese a sugestão para ela (sem abandonar a checagem de fase).

---

## Rules

- **Apenas sugere.** Nunca ative outra persona nem rode a task dela. Pare
  após emitir o bloco e aguarde a decisão do usuário.
- **Deriva do grafo.** A fonte das jogadas é `legal_moves.sh` /
  `pipeline-graph.yaml` — nunca uma tabela mantida à mão aqui.
- **Uma sugestão primária.** Evite menus: escolha o passo mais provável (o
  `default`) e ofereça no máximo duas alternativas reais.
- **Prompt pronto, com dados reais.** Preencha `{spec-id}` e a descrição
  com o que foi detectado — o usuário deve conseguir copiar e colar.
- **A conversa vence a metadata** quando estiver claramente à frente; diga
  isso na linha "Onde estamos".
- **Saída no idioma de comunicação do projeto** (default pt-BR), exceto nomes
  de skill, comandos, caminhos e ids.
