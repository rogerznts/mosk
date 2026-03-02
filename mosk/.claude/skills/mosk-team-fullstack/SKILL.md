---
name: mosk-team-fullstack
description: Activate the MOSK Team Fullstack — capable of full stack, front end only, or service development.
---

Read the file `../../mosk/agent-teams/team-fullstack.yaml` to understand this team's composition, then execute the following activation sequence:

1. **Display team info**:
   - Nome: 🚀 Team Fullstack
   - Descrição: Time completo para desenvolvimento full stack, front end ou serviços.
   - Agentes disponíveis:
     - Maestro 🎭 (orchestrator) — Coordenação de workflow e troca de agentes → `/mosk-orchestrator`
     - Maria 🔍 (analyst) — Discovery, pesquisa e brainstorming → `/mosk-analyst`
     - João 📋 (pm) — PRD e estratégia de produto → `/mosk-pm`
     - Salete 🎨 (ux-expert) — UX e front-end specs → `/mosk-ux-expert`
     - Vinicius 🏗️ (architect) — Arquitetura e stack técnica → `/mosk-architect`
     - Sara 📊 (po) — Backlog e SpecKit pipeline → `/mosk-po`
   - Workflows suportados: greenfield-fullstack, greenfield-service, greenfield-ui, brownfield-fullstack, brownfield-service, brownfield-ui

2. **Apresentar quick-pick via AskUserQuestion**:
   - Pergunta: "Qual agente você quer ativar?"
   - Opções:
     - Maestro 🎭 — Orchestrator: Coordenação de Workflow
     - Maria 🔍 — Analyst: Discovery e Pesquisa
     - João 📋 — PM: PRD e Estratégia
     - Salete 🎨 — UX Expert: Front-End Specs

3. **Se precisar ver mais agentes**, o usuário pode escolher "Ver mais..." para exibir:
   - Vinicius 🏗️ — Architect: Arquitetura e Stack
   - Sara 📊 — PO: Backlog e SpecKit

4. **Ao confirmar a seleção**, instrua o usuário a rodar o skill command correspondente:
   - Maestro → `/mosk-orchestrator`
   - Maria → `/mosk-analyst`
   - João → `/mosk-pm`
   - Salete → `/mosk-ux-expert`
   - Vinicius → `/mosk-architect`
   - Sara → `/mosk-po`
