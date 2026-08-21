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

> **IMPORTANT — suggest only, never invoke.** It **proposes** the next agent
> and **waits**. Never activate another persona, run its task, or chain agents
> automatically. The user decides whether to run the prompt, skip, or redirect.

---

## Workflow

### Step 1 — Read the current state

1. Read every file in `.claude/rules/*.md` for durable project context.
2. Resolve the active spec and phase:
   - Run `bash .claude/mosk/scripts/validate.sh prerequisites --json --paths-only` (when available) to resolve `BRANCH`, `FEATURE_DIR`, and `AVAILABLE_DOCS`.
   - If a `FEATURE_DIR` resolves, read its `spec-meta.yaml`: `spec_id`, `type`, `status`, `current_phase`.
   - Note which artifacts exist on disk: `spec.md`, `plan.md`, `tasks.md`, `stories/`, `tests/`, `gate.yaml`.
   - If `current_phase` is `qa-gate`, read `gate.yaml` to learn the verdict (`PASS` | `CONCERNS` | `FAIL` | `WAIVED`) and the `score_history`.
   - **If there is no active spec yet**, route from the table's first two rows.
3. Read the **conversation focus**: what was just completed or discussed this session. The chat is authoritative when it is clearly ahead of the metadata (e.g. the user just finished implementing but `current_phase` still says `tasks`).
4. Reconcile: when the conversation and `current_phase` disagree, trust what actually happened in the session and say so in the suggestion.

### Step 2 — Locate the position in the MOSK lifecycle

Use the mapping table below. Pick **one primary** suggestion; add at most two
alternatives only when a real fork exists.

If grounding is missing — no PRD/discovery/architecture/UX for a decision the
next step depends on — recommend the agent that owns that ground instead, in the
same suggestion block. A gap in ADR, PRD or flow is a **routing** signal, and
routing belongs to the user.

Escreva a sugestão em palavras comuns. "Preâmbulo", "side-trip", "escalação" e
"fase" são vocabulário nosso: diga *o que fazer* e *por quê*, não em que caixa
do modelo aquilo cai.

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
| `current_phase: implement`, diff tocou superfície sensível | `/mosk-security` *(opcional)* | `/mosk-security review do diff da spec {spec-id}` |
| `current_phase: implement` (código entregue) | `/mosk-qa` | `/mosk-qa qa-gate {spec-id}` |
| `current_phase: qa-gate`, gate `PASS`/`WAIVED` | `/mosk-dev` | `/mosk-dev archive {spec-id}` |
| `current_phase: qa-gate`, gate `CONCERNS`/`FAIL`, score subindo | `/mosk-dev` | `/mosk-dev apply-qa-fixes {spec-id}` |
| `current_phase: qa-gate`, gate `FAIL` com score parado entre voltas | quem é dono da origem: `/mosk-architect`, `/mosk-pm` ou `/mosk-sm` | `/mosk-architect revisar a decisão X da spec {spec-id}` |
| `current_phase: archived` | `/mosk-po` | `/mosk-po full-spec <próxima demanda>` |
| Interface entregue, sem acabamento visual | `/mosk-ui-expert` *(opcional)* | `/mosk-ui-expert audit da tela X` |
| Fluxo de usuário sem especificação | `/mosk-ux-expert` *(opcional)* | `/mosk-ux-expert desenhar o fluxo de X` |

**Sobre a penúltima linha do gate.** Score parado entre duas voltas é o sinal de
que mais uma volta não resolve: o problema está acima da execução — design, PRD
ou story ambígua. Sugerir `apply-qa-fixes` de novo ali é o erro que a série de
score existe para evitar. Leia `score_history` no `gate.yaml` antes de decidir
entre as duas linhas.

---

## Notes

- `full-spec` cobre `specify → plan → tasks` de uma vez; depois dele o
  próximo passo é `/mosk-dev implement`.
- `/mosk-sm`, `/mosk-security`, `/mosk-ui-expert` e `/mosk-ux-expert` são
  **desvios opcionais**: entram quando algum sinal os justifica, nunca no
  caminho padrão, e devolvem o trabalho para a fase de onde saiu.
- Se o usuário passou um argumento, trate-o como a intenção do próximo passo
  e enviese a sugestão para ela (sem abandonar a checagem de fase).

---

## Rules

- **Apenas sugere.** Nunca ative outra persona nem rode a task dela. Pare
  após emitir o bloco e aguarde a decisão do usuário.
- **Uma sugestão primária.** Evite menus: escolha o passo mais provável e
  ofereça no máximo duas alternativas reais.
- **Prompt pronto, com dados reais.** Preencha `{spec-id}` e a descrição
  com o que foi detectado — o usuário deve conseguir copiar e colar.
- **A conversa vence a metadata** quando estiver claramente à frente; diga
  isso na linha "Onde estamos".
- **Saída no idioma de comunicação do projeto** (default pt-BR), exceto nomes
  de skill, comandos, caminhos e ids.
