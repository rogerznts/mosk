---
name: mosk-orq
description: "Orquestrador (Mauro, o maestro): conduz o pipeline MOSK de um projeto entre panes do Herdr, com handoff automático quando a fase muda de agente ou o contexto atinge o teto de tokens. Deriva as jogadas do pipeline-graph.yaml (legal_moves.sh) e transporta contexto via /mosk-handoff. Opt-in: full-auto ou semi-auto. Use quando o usuário pedir 'orquestrar no herdr', 'rodar o pipeline em panes', 'conduzir os agentes', 'chama o Mauro', 'orquestra a spec X pra mim', ou quiser um maestro que troca de agente sozinho respeitando os pontos de decisão. Degrada graciosamente sem o herdr."
argument-hint: "full-auto | semi-auto  [+ spec/projeto alvo]  (vazio abre o menu)"
---

CRITICAL: Read and fully execute the agent definition at `../../mosk/agents/orq.md`.
That file is the single source of truth — it contains the full persona (Mauro, the
maestro), the orchestration workflow, autonomy modes, degradation, and guardrails.
Follow ALL instructions defined there exactly.
