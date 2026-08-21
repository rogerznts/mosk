# Linha de base — antes do corte

Medido em 2026-08-19 no `master` (`6bcacf2`), branch `refactor/016-prompt-first-toolkit`.
É contra este arquivo que **SC-001** (≤ 1.500 linhas) e **SC-003** (todo script com chamador) são verificados na T027.

## Totais

| camada | linhas |
|---|---:|
| Bash total | 8649 |
| Bash sem `payload-*` (escopo desta spec) | 7912 |
| `payload-*` (fora de escopo) | 737 |
| Tasks | 3584 |
| Agentes | 1461 |
| Templates | 5658 |

`common.sh`: **39 funções**.

## Scripts, linhas e chamador

Chamador = citação nominal em `tasks/`, `agents/`, `skills/`, `settings.json` ou `.github/`.

| script | linhas | chamador |
|---|---:|---|
| `audit-docs-paths.sh` | 181 | audit-docs-paths.md index-docs.md |
| `audit-legacy-surface.sh` | 511 | **nenhum** |
| `check-prerequisites.sh` | 166 | analyze.md artefact.md checklist.md clarify.md implement.md SKILL.md tasks.md |
| `check-ship-ready.sh` | 150 | **nenhum** |
| `classify-change.sh` | 210 | assess-security.md implement.md mosk-dev.md mosk-orq.md mosk-qa.md mosk-security.md orq-run.md qa-gate.md security-review.md |
| `common.sh` | 1323 | archive.md index-docs.md mosk-orq.md orq-run.md planner.md specify.md |
| `create-new-feature.sh` | 646 | artefact.md SKILL.md specify.md |
| `doctor.sh` | 220 | **nenhum** |
| `link-codex-skills.sh` | 304 | mosk-orq.md SKILL.md |
| `migrate-ctx-skills-to-rules.sh` | 183 | mosk-analyst.md mosk-architect.md mosk-dev.md mosk-pm.md mosk-po.md mosk-qa.md mosk-security.md mosk-sm.md mosk-ui-expert.md mosk-ux-expert.md |
| `migrate-docs-structure.sh` | 501 | boot.md index-docs.md |
| `payload-deploy.sh` | 190 | deploy-mode.md |
| `payload-env.sh` | 181 | deploy-mode.md |
| `payload-infra.sh` | 366 | **nenhum** |
| `reset-install.sh` | 213 | SKILL.md |
| `selftest-adaptive-work.sh` | 188 | **nenhum** |
| `selftest-common.sh` | 173 | **nenhum** |
| `selftest-pipeline-state.sh` | 567 | **nenhum** |
| `selftest-toolkit.sh` | 798 | **nenhum** |
| `setup-plan.sh` | 61 | plan.md |
| `sync-agents-skills.sh` | 503 | SKILL.md |
| `sync-hallmark.sh` | 185 | hallmark.md |
| `transition-spec-phase.sh` | 57 | apply-qa-fixes.md archive.md implement.md orq-run.md plan.md qa-gate.md tasks.md |
| `update-agent-context.sh` | 772 | plan.md |
