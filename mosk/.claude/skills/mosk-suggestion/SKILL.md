---
name: mosk-suggestion
description: "Suggestion: interpreta o ponto atual da sessão (spec ativa, current_phase, artefatos no disco e foco da conversa) e sugere o próximo agente MOSK a chamar, já com um prompt pronto para colar. Use quando o usuário perguntar 'e agora?', 'qual o próximo passo?', 'qual agente devo chamar?' ou quiser orientação para avançar no pipeline (specify → plan → tasks → implement → qa-gate → archive). Apenas sugere — nunca invoca outro agente automaticamente."
argument-hint: "O que você quer fazer a seguir? (opcional)"
---

# Suggestion (MOSK)

Read the current session state and recommend the **single next MOSK
agent** to call, with a ready-to-paste prompt. This is the inverse of a
handoff: instead of writing a document, you produce one concrete next
step the user can run immediately.

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
3. Read the **conversation focus**: what was just completed or discussed this session. The chat is authoritative when it is clearly ahead of the metadata (e.g. the user just finished implementing but `current_phase` still says `tasks`).
4. Reconcile: when the conversation and `current_phase` disagree, trust what actually happened in the session and say so in the suggestion.

### Step 2 — Locate the position in the MOSK lifecycle

Use the mapping table below to pick the next agent. Pick **one primary**
suggestion; add at most two alternatives only when a real fork exists
(e.g. an optional `/mosk-sm` readiness pass, or a preamble gap).

If grounding is missing — no PRD/discovery/architecture/UX for a decision
the next step depends on — recommend the matching **preamble** agent
instead, in the same suggestion block (this mirrors the Escalation Policy).

### Step 3 — Emit the suggestion block

Output exactly one block. Fill the prompt with the **real** `spec_id` /
description, not placeholders:

```markdown
> **Próximo passo sugerido**
> - Onde estamos: <fase atual ou o que acabou de ser concluído>
> - Próximo agente: `/mosk-<x>`
> - Prompt pronto: `/mosk-<x> <ação com o spec-id/descrição reais>`
> - Por quê: <uma linha justificando>
> - Alternativas: <0–2 opções, ou "nenhuma">
```

Then stop. End with one short line telling the user to colar o prompt
para prosseguir (ou pedir outra direção). **Do not run anything.**

---

## Mapping — estado → próximo agente

| Estado detectado | Próximo agente | Prompt pronto (modelo) |
|---|---|---|
| Sem spec ativa **e** ideia ainda não aterrada (sem PRD/discovery) | `/mosk-analyst` ou `/mosk-pm` | `/mosk-pm criar PRD para <ideia>` |
| Sem spec ativa, escopo claro | `/mosk-po` | `/mosk-po full-spec <descrição>` |
| `current_phase: specify` (existe `spec.md`) | `/mosk-po` | `/mosk-po plan {spec-id}` |
| `current_phase: plan` (existe `plan.md`) | `/mosk-po` | `/mosk-po tasks {spec-id}` |
| `current_phase: tasks`, stories ainda não revisadas | `/mosk-sm` *(opcional)* | `/mosk-sm revisar prontidão das stories da spec {spec-id}` |
| `current_phase: tasks` (pronto para codar) | `/mosk-dev` | `/mosk-dev implement {spec-id}` |
| `current_phase: implement` (código entregue) | `/mosk-qa` | `/mosk-qa qa-gate {spec-id}` |
| `current_phase: qa-gate`, gate `PASS`/`WAIVED` | `/mosk-dev` | `/mosk-dev archive {spec-id}` |
| `current_phase: qa-gate`, gate `CONCERNS`/`FAIL` | `/mosk-dev` | `/mosk-dev apply-qa-fixes {spec-id}` |
| `current_phase: archived` | `/mosk-po` | `/mosk-po full-spec <próxima descrição>` |
| Lacuna de arquitetura/integração bloqueia o passo | `/mosk-architect` | `/mosk-architect resolver <lacuna> na spec {spec-id}` |
| Falta fluxo/wireframe ou acabamento visual | `/mosk-ux-expert` / `/mosk-ui-expert` | `/mosk-ux-expert definir o fluxo de <tela> na spec {spec-id}` |

Notes:
- `full-spec` cobre `specify → plan → tasks` de uma vez; depois dele o
  próximo passo é `/mosk-dev implement`.
- `/mosk-sm` é **opcional**: sugira-o quando as stories existirem mas
  ainda não tiverem passado por revisão de prontidão.
- Se o usuário passou um argumento, trate-o como a intenção do próximo
  passo e enviese a sugestão para ela (sem abandonar a checagem de fase).

---

## Rules

- **Apenas sugere.** Nunca ative outra persona nem rode a task dela.
  Pare após emitir o bloco e aguarde a decisão do usuário.
- **Uma sugestão primária.** Evite menus: escolha o passo mais provável e
  ofereça no máximo duas alternativas reais.
- **Prompt pronto, com dados reais.** Preencha `{spec-id}` e a descrição
  com o que foi detectado — o usuário deve conseguir copiar e colar.
- **A conversa vence a metadata** quando estiver claramente à frente;
  diga isso na linha "Onde estamos".
- **Sem spec, sem chute.** Se nada estiver aterrado, recomende o preâmbulo
  (`analyst`/`pm`/`architect`/`ux-expert`/`ui-expert`) ou `full-spec`,
  conforme a maturidade da ideia.
- **Saída no idioma de comunicação do projeto** (default pt-BR), exceto nomes de skill, comandos, caminhos e ids.
