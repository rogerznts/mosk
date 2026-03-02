---
name: mosk-team-no-ui
description: Activate the MOSK Team No UI — backend, APIs and system development without UX planning.
---

Read the file `../../mosk/agent-teams/team-no-ui.yaml` to understand this team's composition, then execute the following activation sequence:

1. **Display team info**:
   - Nome: 🔧 Team No UI
   - Descrição: Time sem UX para serviços backend, APIs e desenvolvimento de sistemas.
   - Agentes disponíveis:
     - Maestro 🎭 (orchestrator) — Coordenação de workflow e troca de agentes → `/mosk-orchestrator`
     - Maria 🔍 (analyst) — Discovery, pesquisa e brainstorming → `/mosk-analyst`
     - João 📋 (pm) — PRD e estratégia de produto → `/mosk-pm`
     - Vinicius 🏗️ (architect) — Arquitetura e stack técnica → `/mosk-architect`
     - Sara 📊 (po) — Backlog e SpecKit pipeline → `/mosk-po`
   - Workflows suportados: greenfield-service, brownfield-service

2. **Apresentar quick-pick via AskUserQuestion**:
   - Pergunta: "Qual agente você quer ativar?"
   - Opções:
     - Maestro 🎭 — Orchestrator: Coordenação de Workflow
     - Maria 🔍 — Analyst: Discovery e Pesquisa
     - João 📋 — PM: PRD e Estratégia
     - Vinicius 🏗️ — Architect: Arquitetura e Stack
     - Sara 📊 — PO: Backlog e SpecKit

3. **Ao confirmar a seleção**, instrua o usuário a rodar o skill command correspondente:
   - Maestro → `/mosk-orchestrator`
   - Maria → `/mosk-analyst`
   - João → `/mosk-pm`
   - Vinicius → `/mosk-architect`
   - Sara → `/mosk-po`
