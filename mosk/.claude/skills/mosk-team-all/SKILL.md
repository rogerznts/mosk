---
name: mosk-team-all
description: Activate the MOSK Team All — includes every core system agent for complete project coverage.
---

Read the file `../../mosk/agent-teams/team-all.yaml` to understand this team's composition, then execute the following activation sequence:

1. **Display team info**:
   - Nome: 👥 Team All
   - Descrição: Todos os agentes do sistema MOSK para cobertura completa de projeto.
   - Agentes disponíveis:
     - Maestro 🎭 (orchestrator) — Coordenação de workflow e troca de agentes → `/mosk-orchestrator`
     - Maria 🔍 (analyst) — Discovery, pesquisa e brainstorming → `/mosk-analyst`
     - João 📋 (pm) — PRD e estratégia de produto → `/mosk-pm`
     - Salete 🎨 (ux-expert) — UX e front-end specs → `/mosk-ux-expert`
     - Vinicius 🏗️ (architect) — Arquitetura e stack técnica → `/mosk-architect`
     - Sara 📊 (po) — Backlog e SpecKit pipeline → `/mosk-po`
     - Roberto 🏃 (sm) — Dev-readiness e clareza técnica → `/mosk-sm`
     - Jaime 💻 (dev) — Implementação, spec-implement e Chore Mode → `/mosk-dev`
     - Joaquim 🔬 (qa) — Qualidade, testes e NFR → `/mosk-qa`
     - Mestre 🧙 (master) — Executor universal de todas as capacidades → `/mosk-master`
   - Workflows suportados: greenfield-fullstack, greenfield-service, greenfield-ui, brownfield-fullstack, brownfield-service, brownfield-ui

2. **Apresentar quick-pick via AskUserQuestion** (nível 1 — por área):
   - Pergunta: "Qual área de atuação?"
   - Opções:
     - Discovery & Planejamento (Maria, João, Salete, Vinicius)
     - Especificação & Backlog (Sara, Roberto)
     - Implementação & Qualidade (Jaime, Joaquim)
     - Coordenação & Universal (Maestro, Mestre)

3. **No nível 2**, exibir os agentes da área selecionada com nome brasileiro, papel e skill command.

4. **Ao confirmar a seleção**, instrua o usuário a rodar o skill command correspondente:
   - Maestro → `/mosk-orchestrator`
   - Maria → `/mosk-analyst`
   - João → `/mosk-pm`
   - Salete → `/mosk-ux-expert`
   - Vinicius → `/mosk-architect`
   - Sara → `/mosk-po`
   - Roberto → `/mosk-sm`
   - Jaime → `/mosk-dev`
   - Joaquim → `/mosk-qa`
   - Mestre → `/mosk-master`
