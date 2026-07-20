# Implementation Plan: Modo `/mosk-bench` (persona Bento)

**Branch**: `002-feature-mosk-payload-mode` | **Date**: 2026-07-19 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `docs/specs/002-feature-mosk-payload-mode/spec.md`

## Summary

Construir, **dentro do template `mosk/`**, o modo de trabalho `/mosk-bench` (persona Bento): um fluxo que leva um usuário leigo de "quero uma ferramenta interna" a "ferramenta Payload rodando e testada" sem nenhuma decisão técnica exposta. A entrega é composta de **peças de prompt MOSK** (skill, task, agente, template de rule) + um **starter versionado** (Payload+Docker) + **scripts Bash determinísticos** (validação de ambiente, infra compartilhada, provisionamento). A Fase A (grill) reusa `tasks/grill.md`; a Fase B (build headless) reusa o contrato SDD do MOSK (`specify → plan → tasks → loop-until-green → qa-gate`) com escalonamento automático escopado (ADR-0002).

Este plano cobre **como** implementar as peças em `mosk/`. As 13 decisões do brief e os ADRs 0001–0003 são consumidos como dados. O único item de arquitetura aberto (mecanismo de orquestração headless da Fase B) é resolvido abaixo com um default seguro que reusa primitivas existentes, com a fronteira residual (paridade Codex) explicitamente sinalizada para confirmação do architect (ver §Open Architecture Decision).

## Technical Context

**Linguagem/Runtime (o que construímos)**: Markdown (prompts/tasks/agentes/rule template) + YAML (spec-meta, registry, compose) + Bash (scripts) — o toolkit MOSK não tem app compilado.
**Stack do produto gerado (o starter)**: Payload CMS (TypeScript) sobre `node:22-bookworm-slim`, Postgres `16-alpine`, Redis `7-alpine`, pnpm, Vitest via Local API. Imagens pinadas, zero build local.
**Storage**: N/A para o toolkit. Para o gerado: Postgres (banco por projeto) + Redis (índice/prefixo por projeto), volumes nomeados persistentes.
**Testing**: Toolkit — validação manual (leitura estrutural, consistência de cross-refs, smoke-install via degit, idempotência dos scripts com `--dry-run`). Gerado — Vitest via Local API do Payload dentro do container.
**Target Platform**: Claude Code **e** Codex CLI (paridade obrigatória — FR-030). Host Linux/macOS com Docker.
**Project Type**: Extensão do toolkit MOSK (prompt-engineering + scaffolding), não app single/web.
**Constraints**: Todas as peças de produto vivem sob `mosk/` e shipam via degit; a rule `payload.md` é gerada por projeto. Scripts idempotentes, `--help`, `--dry-run`, `source common.sh`. Invariantes INV-1..6 travadas por construção no starter.
**Scale/Scope**: 6 artefatos novos em `mosk/` + 1 starter multi-arquivo + 2 scripts. Um leigo roda várias ferramentas na mesma máquina (infra compartilhada, ADR-0001).

## Scope Summary

**In scope** (construir em `mosk/`):
- Skill `mosk-bench`, task `bench-mode.md`, agente `bench.md`.
- Starter `payload-starter/` (compose do projeto, código Payload mínimo, testes Local API, `.mosk-infra/`, `.env.example`, `.gitignore`, `package.json`+lockfile).
- Scripts `payload-env.sh` (validação Docker + instalação guiada) e `payload-infra.sh` (detecção/subida/provisionamento + `registry.yaml`).
- Template-fonte `payload-rule-tmpl.md`.
- Contrato da Fase A (reuso `grill.md`) e da Fase B (orquestração headless SDD).
- Sincronização das camadas (`sync-agents-skills.sh`, `link-codex-skills.sh`).

**Out of scope**:
- Gerar uma ferramenta real de exemplo (isso é uso do modo, não a construção dele).
- Alterar o contrato global da Escalation Policy fora do runtime da Fase B (ADR-0002 mantém o global intocado).
- Produção/deploy do Payload (o starter é ambiente de desenvolvimento).

## Technical Approach

### A. Peças de prompt (determinístico na estrutura, redação em pt-BR)

- `mosk/.claude/skills/mosk-bench/SKILL.md`: wrapper `/mosk-bench` → agente Bento, no padrão dos demais skills MOSK (FR-031).
- `mosk/.claude/mosk/agents/bench.md`: persona; fala pt-BR simples, conduz grill com paciência, nunca expõe termo técnico; `## Task mapping → bench-mode.md`; lê `.claude/rules/*.md` (incl. `payload.md`) na ativação (FR-001/002, FR-033).
- `mosk/.claude/mosk/tasks/bench-mode.md`: orquestra o fluxo end-to-end (§6 da arquitetura): validar ambiente → provisionar infra → scaffold/detectar bootstrap → Fase A → congelar briefing → derivar testes → disparar Fase B → entregar em pt-BR (FR-032).
- `mosk/.claude/mosk/templates/payload-rule-tmpl.md`: base para gerar `.claude/rules/payload.md` por projeto (menu completo, collections=módulos, convenções, portas/DB alocados), no molde do que `boot.md` faz (FR-036).

### B. Starter versionado (golden starter — ADR-0003)

`mosk/.claude/mosk/templates/payload-starter/` copiado as-is (FR-009/034). Invariantes travadas no starter, não no LLM:
- `docker-compose.yml`: só serviço `app`, imagem pinada, código como volume, `mosk-net` externa, `${ADMIN_PORT}:3000`, sem build (FR-010).
- `payload.config.ts`: i18n `fallbackLanguage: 'pt'`, admin sem `hidden`/agrupamentos → menu completo (INV-1); registra collections.
- `src/collections/Users.ts` (`auth: true`): login funciona no primeiro `pnpm dev`.
- `src/tests/smoke.test.ts`: base/smoke via Local API.
- `.mosk-infra/docker-compose.yml`: Postgres+Redis+`mosk-net` (ADR-0001, FR-005).
- `package.json` + `pnpm-lock.yaml` pinados; `.env.example`; `.gitignore` (ignora `.env`, `node_modules`, `dist`).
- LLM só edita `src/collections/` e labels (FR-011).

### C. Scripts determinísticos

- `payload-env.sh`: ordem `docker --version` → `docker info` → `docker compose version`; faltando Docker, instalação guiada com **uma confirmação** (detecta SO, comando oficial, Linux `sudo`), nunca silenciosa, recusa → para amigável (FR-003/004). Idempotente, `--help`, `--dry-run`, `source common.sh`.
- `payload-infra.sh`: detecção/criação/reuso da infra (idempotente, §4.2), health gate `pg_isready`+`redis-cli ping` (FR-006), e `--provision <projeto>`: DB próprio (checa `pg_database`), índice Redis livre (0–15, fallback prefixo), porta livre por bind-test a partir de 3000, tudo gravado em `registry.yaml` (FR-007/008).

### D. Fase A — Grill (reuso de `grill.md`)

`bench-mode.md` invoca `tasks/grill.md` com um **checklist obrigatório** (collections+campos, papéis/permissões, integrações, labels pt-BR, regras de negócio, critério de "pronto"). Pergunta só regra de negócio (FR-013); bifurcação técnica → default seguro + aviso (FR-014); converge só com checklist 100% (FR-015); escape "chega" congela com lacunas (FR-016). Saída: `briefing.md` + `checklist.yaml` congelados (FR-017).

### E. Derivação de testes (simetria checklist=testes)

Estrutura das camadas é template (smoke herdado; por collection: existe/campos/CRUD/papéis); asserts de regra de negócio são redigidos pelo LLM a partir do checklist (FR-018). Rodam via Local API no container (`docker compose exec app pnpm test`, Vitest) (FR-019).

### F. Fase B — Build headless (orquestração SDD + loop-until-green)

Reusa o contrato SDD do MOSK integralmente (FR-020): `specify` (via `create-new-feature.sh`; novo=001, reativação=spec aditiva N — FR-012/021), `plan`, `tasks`, loop `implement→testes→conserta` com `MAX_FIX_ATTEMPTS=3` (FR-022/023), `qa-gate` → `gate.yaml` (FR-024). Escalonamento automático dos subagentes escopado a este runtime (FR-025/026/027, ADR-0002); lacuna de negócio nunca inventada → volta ao grill ou `CONCERNS`. Entrega pt-BR (FR-028/029).

## Open Architecture Decision (item aberto do spec, endereçado aqui)

**Item**: mecanismo exato de encadeamento de subagentes headless da Fase B — qual tool/runtime orquestra o fan-out `po→dev→qa`, como o estado da spec transita, como o log de decisões automáticas é capturado, e como manter paridade Claude Code ↔ Codex.

**Default seguro adotado (reusa primitivas existentes; não inventa engine novo):**

1. **Orquestrador = a própria `bench-mode.md`** rodando na sessão principal. A "tool `Workflow`" do brief/arquitetura é tratada como **contrato lógico**, não como um primitivo novo a ser construído. `bench-mode.md` dispara a Fase B como uma sequência determinística de fases SDD.
2. **Fan-out `po→dev→qa` (Claude Code)** = tool nativa de subagente (`Agent` com `subagent_type: mosk-po → mosk-dev → mosk-qa`), lançados sequencialmente. Isso já entrega a propriedade "headless / barulho de build fora da sessão do leigo": o output de ferramentas do subagente não polui o contexto pai; só o resultado volta.
3. **Transição de estado entre fases/subagentes = filesystem**, que já é o contrato MOSK: o diretório da spec + `spec-meta.yaml` (`current_phase`) + artefatos (`spec.md`/`plan.md`/`tasks.md`/`gate.yaml`). Nenhum estado novo em memória; cada subagente lê/escreve o disco. Zero invenção.
4. **Log de decisões automáticas** = arquivo append-only `decisions-log.md` na pasta da spec (mesmo padrão de `gate.yaml`/`spec-meta.yaml`): cada auto-escalação registra sinal, subagente invocado, default escolhido e justificativa (auditoria exigida por ADR-0002).
5. **Loop-until-green** = laço determinístico dentro do runtime (rodar teste → comparar → decidir), LLM só no `implement/conserta`, teto `MAX_FIX_ATTEMPTS=3`.

**Fronteira residual que NÃO fecho unilateralmente (recomendo ADR-0004 do architect):**
Codex **não tem** primitivo de subagente isolado equivalente ao `Agent` do Claude Code. Nele, a propriedade "headless/invisível" da Fase B não é nativa. Duas saídas plausíveis, ambas com trade-off real:
- (a) **Degradar em Codex**: rodar a Fase B como pipeline linear **na mesma sessão**, reusando os mesmos arquivos de task, e apenas **resumir** de forma compacta (o leigo vê menos, mas não zero, do build).
- (b) **Padronizar por baixo**: definir um contrato de orquestração agnóstico de runtime (ex.: cada fase como invocação de task discreta com hand-off por filesystem) que ambos os runtimes executam igual, aceitando que em Codex o "headless" é lógico (mesma sessão, output suprimido/resumido) e não por isolamento de processo.

Como isso é uma **decisão de arquitetura difícil de reverter** (molda o prompt de `bench-mode.md` e a promessa de paridade FR-030), **não a fabrico**: adoto os pontos 1–5 como base sólida e **sinalizo (a)/(b) para o architect fechar em ADR-0004** antes do `implement`. Os pontos 1–5 são suficientes para gerar `tasks.md`; apenas a **redação final da seção de orquestração em `bench-mode.md`** (1 tarefa) depende do desfecho (a)/(b).

## Assumptions & Constraints

- Escopo = construir o modo em `mosk/`; não gerar ferramenta de exemplo.
- Imagens/versões pinadas no starter (envelhecem → manutenção versionada do time MOSK, ADR-0003).
- `MAX_FIX_ATTEMPTS=3`, varredura de porta desde 3000, Redis 0–15+fallback, credenciais dev `mosk:mosk` — convenções, nunca perguntadas ao leigo.
- Sem test suite automatizado do toolkit; validação manual + smoke-install.
- ADR-0002: auto-escalação vive só no runtime da Fase B; global intocado.

## Dependencies

- `tasks/grill.md` (Fase A) — deve existir/ser referenciável.
- Contrato SDD existente: `specify`/`plan`/`tasks`/`implement`/`qa-gate`/`create-new-feature.sh`.
- `common.sh` (helpers Bash) e `boot.md` (molde da geração de rule).
- Scripts de sincronização: `sync-agents-skills.sh`, `link-codex-skills.sh`.
- Docker no host do usuário (validado/instalado pelo próprio modo).
- **Bloqueia `implement`**: confirmação da orquestração Fase B em Codex (ADR-0004) — ver Open Architecture Decision.

## Implementation Milestones

1. **M1 — Starter versionado**: `payload-starter/` completo, sobe e loga (smoke verde) num teste manual local. Invariantes travadas.
2. **M2 — Scripts determinísticos**: `payload-env.sh` + `payload-infra.sh` idempotentes, `--dry-run` limpos, `registry.yaml` alocando DB/porta/Redis.
3. **M3 — Peças de prompt**: `bench.md`, `bench-mode.md`, skill `mosk-bench`, `payload-rule-tmpl.md`; cross-refs válidas; camadas sincronizadas.
4. **M4 — Fase A**: integração com `grill.md` + checklist obrigatório + congelamento (`briefing.md`/`checklist.yaml`) + derivação de testes.
5. **M5 — Fase B**: orquestração headless (pontos 1–5), loop-until-green, auto-escalação + `decisions-log.md`, `qa-gate`. *(Redação final da orquestração aguarda ADR-0004.)*
6. **M6 — Paridade & validação**: smoke-install via degit, paridade Claude Code/Codex, docs/index atualizado.

## Validation Strategy

- **Estrutural**: cada artefato lido com os adjacentes; cross-refs skill↔agente↔task válidas; `sync-agents-skills.sh --clean` + `link-codex-skills.sh` sem órfãos.
- **Scripts**: `--dry-run` primeiro; idempotência (rodar 2x não corrompe); health gate testado.
- **Starter**: smoke-install em diretório scratch (`npx degit`), depois subir o starter e confirmar admin pt-BR + login + smoke Local API verde.
- **Fase B**: teste manual do loop-until-green com um caso simples; verificar teto `MAX_FIX_ATTEMPTS` e geração de `gate.yaml`/`decisions-log.md`.
- **Paridade**: rodar o gatilho nos dois runtimes; confirmar comportamento equivalente (com a ressalva de orquestração headless pendente de ADR-0004).

## Complexity Tracking

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| Auto-escalação de subagentes (exceção à Escalation Policy) | Fase B headless não pode pausar para o leigo decidir técnica (regra de ouro) | Manter "sugerir e esperar" travaria o build e exporia decisão técnica — rejeitado (ADR-0002) |
| Infra Docker compartilhada por máquina (acoplamento) | Leigo roda várias ferramentas; N Postgres/Redis afundaria a máquina | Postgres/Redis por projeto: peso/startup inviáveis — rejeitado (ADR-0001) |
| Starter versionado grande dentro de `mosk/` | Garante "sobe e loga" determinístico para leigo | Geração on-the-fly: frágil, "às vezes não sobe" sem quem debugue — rejeitado (ADR-0003) |
