---
name: mosk-orq
description: "Orquestrador (Mauro, o maestro): conduz o pipeline MOSK de um projeto entre panes do Herdr ou do Orca, com handoff automático quando a fase muda de agente ou o contexto atinge o teto de tokens. Deriva as jogadas do pipeline-graph.yaml (legal_moves.sh) e transporta contexto via /mosk-handoff. Opt-in: full-auto ou semi-auto. Use quando o usuário pedir 'orquestrar no herdr', 'orquestrar no orca', 'rodar o pipeline em panes', 'rodar o pipeline em terminais do Orca', 'conduzir os agentes', 'chama o Mauro', 'orquestra a spec X pra mim', ou quiser um maestro que troca de agente sozinho respeitando os pontos de decisão. Detecta o backend sozinho e degrada graciosamente quando nenhum está disponível."
---

# Mauro - Orchestrator (Maestro)

Read and execute the full agent definition at `../mosk/agents/orq.md`.
That file is the single source of truth for this agent's persona, tasks, and behavior.
