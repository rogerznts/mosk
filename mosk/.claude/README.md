# MOSK no Claude Code (Skills)

No Claude Code, os comandos do MOSK são skills em:
- `.claude/skills/<skill>/SKILL.md`

Cada skill vira um comando slash com o nome definido no frontmatter (`name`).
Exemplo: `name: mosk-pm` → comando `/mosk-pm`.

## Skills MOSK — Agentes Especialistas

- `mosk-analyst`       → Maria (Analista de Negócios)
- `mosk-architect`     → Vinicius (Arquiteto de Sistemas)
- `mosk-pm`            → João (Product Manager)
- `mosk-po`            → Sara (Product Owner / SpecKit pipeline)
- `mosk-sm`            → Roberto (Scrum Master / dev-readiness)
- `mosk-dev`           → Jaime (Dev / spec-implement / spec-archive)
- `mosk-qa`            → Joaquim (QA / quality gates)
- `mosk-ux-expert`     → Salete (UX / wireframes / front-end specs)
- `mosk-master`        → Mestre (executor universal)
- `mosk-orchestrator`  → Maestro (coordenação de agentes e workflows)

## Skills MOSK — Ajuda e Times

- `mosk-help`          → Exibe fluxo MOSK e guia rápido de agentes
- `mosk-team-all`      → Ativa todos os agentes do time
- `mosk-team-fullstack`→ Time fullstack (analyst, pm, ux, architect, po)
- `mosk-team-ide`      → Time otimizado para uso em IDE
- `mosk-team-no-ui`    → Time sem agentes de UI/UX

## Nota

As tasks do SpecKit (`*spec-specify`, `*spec-plan`, `*spec-implement`, `*spec-archive`, etc.)
são executadas **dentro dos agentes** via comandos com prefixo `*`, e não como skills independentes.

Todo tipo de mudança — features, fixes, hotfixes, GMUDs e refatorações — usa o mesmo pipeline
SpecKit com o tipo adequado (`feature`, `fix`, `hotfix`, `gmud`, `refactor`, `experimental`)
refletido no nome da branch e pasta: `{###}-{tipo}-{nome}/`.
