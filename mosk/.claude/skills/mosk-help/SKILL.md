---
name: mosk-help
description: Exibe o fluxo de trabalho MOSK e guia rápido de quando usar cada agente.
---

Output the following MOSK workflow guide to the user. Do not activate any agent persona — just display the content below exactly as written:

---

## Fluxo MOSK

```
/mosk-analyst → /mosk-ux-expert → /mosk-architect → /mosk-pm → /mosk-po → /mosk-sm → /mosk-dev → /mosk-qa
```

| # | Skill | O que faz |
|---|---|---|
| 1 | `/mosk-analyst` | Discovery: brief, pesquisa de mercado e análise competitiva |
| 2 | `/mosk-ux-expert` | User flows, wireframes e front-end specs |
| 3 | `/mosk-architect` | Arquitetura, stack, APIs e infraestrutura |
| 4 | `/mosk-pm` | PRD e `*spec-constitution` (executa uma vez por projeto) |
| 5 | `/mosk-po` | Épicos, stories com AC e SpecKit completo (`*spec-specify` → `*spec-tasks`) |
| 6 | `/mosk-sm` | Dev-readiness: clareza técnica das stories antes da implementação |
| 7 | `/mosk-dev` | Implementação: `*spec-implement`, `*develop-story`, Chore Mode |
| 8 | `/mosk-qa` | Quality gates, arquitetura de testes, NFR e revisões |

**Agentes de suporte** (sem posição fixa no fluxo):
- `/mosk-orchestrator` — coordenação de agentes e orientação de workflow
- `/mosk-master` — executor universal para tarefas pontuais

---

### SpecKit Pipeline (PO — passo 5)
`*spec-specify` → [`*spec-clarify`] → `*spec-plan` → [`*spec-analyze`] → [`*spec-checklist`] → `*spec-tasks`
→ Dev: `*spec-implement`

### Chore Mode (Dev — passo 7)
`*chore-proposal {id}` → `*chore-apply {id}` → `*chore-archive {id}`
