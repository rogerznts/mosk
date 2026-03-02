---
name: mosk-team-ide
description: Activate the MOSK Team IDE Minimal — the lean PO→SM→Dev→QA cycle for implementation in the IDE.
---

Read the file `../../mosk/agent-teams/team-ide-minimal.yaml` to understand this team's composition, then execute the following activation sequence:

1. **Display team info**:
   - Nome: ⚡ Team IDE Minimal
   - Descrição: Ciclo mínimo para implementação no IDE — PO, SM, Dev e QA.
   - Agentes disponíveis:
     - Sara 📊 (po) — Backlog, SpecKit pipeline e stories com AC → `/mosk-po`
     - Roberto 🏃 (sm) — Dev-readiness e clareza técnica → `/mosk-sm`
     - Jaime 💻 (dev) — Implementação, spec-implement e Chore Mode → `/mosk-dev`
     - Joaquim 🔬 (qa) — Qualidade, testes e NFR → `/mosk-qa`
   - Workflows: N/A (time focado em execução no IDE)

2. **Apresentar quick-pick via AskUserQuestion**:
   - Pergunta: "Qual agente você quer ativar?"
   - Opções:
     - Sara 📊 — PO: Backlog e SpecKit
     - Roberto 🏃 — SM: Dev-Readiness
     - Jaime 💻 — Dev: Implementação e Chore
     - Joaquim 🔬 — QA: Qualidade e Testes

3. **Ao confirmar a seleção**, instrua o usuário a rodar o skill command correspondente:
   - Sara → `/mosk-po`
   - Roberto → `/mosk-sm`
   - Jaime → `/mosk-dev`
   - Joaquim → `/mosk-qa`
