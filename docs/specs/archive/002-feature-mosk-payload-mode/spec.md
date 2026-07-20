# Feature Specification: Modo `/mosk-bench` (persona Bento)

**Feature Branch**: `002-feature-mosk-payload-mode`
**Created**: 2026-07-19
**Status**: Draft
**Input**: User description: "Novo modo de trabalho MOSK `/mosk-bench` (persona Bento) que permite a usuários leigos criar e testar ferramentas internas sobre Payload CMS sem tocar em decisão técnica, cobrindo grill interativo (Fase A) e build autônomo headless (Fase B)."

> Fontes de verdade (decisões já fechadas — não reabrir):
> - Brief: `docs/discovery/mosk-payload-mode-brief.md` (13 decisões)
> - Arquitetura: `docs/architecture/mosk-payload-mode.md`
> - ADRs: `adr-0001-shared-infra-model`, `adr-0002-auto-escalation-exception`, `adr-0003-versioned-golden-starter`

## Overview

`/mosk-bench` é um modo de trabalho MOSK, encarnado pela persona **Bento**, que leva um **usuário leigo** de "quero uma ferramenta interna" a "ferramenta rodando e testada no navegador" sem que ele tome nenhuma decisão técnica. Toda a parte técnica é resolvida por convenção (determinística) ou headless (Fase B). Toda peça de produto vive sob `mosk/` e shipa via `npx degit`; apenas a rule `payload.md` é gerada por projeto.

Espinha dorsal:

```
ativar → validar ambiente → provisionar infra → scaffold → grill (Fase A) →
congelar briefing → derivar testes → build headless (Fase B) → ferramenta pronta
```

Dois loops distintos:
- **Fase A — Grill interativo**: loop agêntico na sessão principal (reusa `tasks/grill.md`), humano nas respostas, convergência por checklist de completude com escape manual.
- **Fase B — Build autônomo**: tool `Workflow` headless, SDD encadeado + loop `implement → testes → conserta até verde` + `qa-gate`, com escalonamento automático dos subagentes escopado a este runtime.

## Invariantes não-negociáveis (do produto gerado)

Estes valem por construção em todo projeto criado pelo modo (não são requisitos opcionais — são o contrato):

- **INV-1**: Admin do Payload **sempre em pt-BR**, com **menu completo** (nada escondido/agrupado que oculte entradas).
- **INV-2**: Módulo customizado = **collection** do Payload. Sem exceção.
- **INV-3**: **Postgres** como banco, **Redis** para fila.
- **INV-4**: **Zero build local, zero instalação** na máquina além do Docker (e Docker só com confirmação explícita).
- **INV-5**: O grill pergunta **só regra de negócio**; tudo técnico é convenção. Nunca fazer um leigo tomar decisão técnica.
- **INV-6**: Toda saída ao usuário **sempre em pt-BR simples**, sem jargão.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Criar a primeira ferramenta interna do zero (Priority: P1)

Um usuário leigo digita `/mosk-bench`, é acolhido pela persona Bento, responde a uma entrevista em pt-BR sobre o que a ferramenta precisa fazer, e ao final recebe um endereço `http://localhost:<porta>` com o admin do Payload no ar, em português, já com as collections que descreveu e login funcionando.

**Why this priority**: É o coração do modo e a razão de existir — sem este fluxo end-to-end não há produto. Entrega valor completo sozinha (MVP).

**Independent Test**: Rodar `/mosk-bench` numa máquina limpa (só com Docker), passar por validação de ambiente, grill e build, e confirmar que a ferramenta sobe, loga e responde às regras descritas — tudo sem o usuário ver YAML, porta ou nome de container.

**Acceptance Scenarios**:

1. **Given** máquina com Docker e sem nenhuma infra MOSK, **When** o usuário ativa `/mosk-bench`, **Then** o modo valida Docker, sobe a infra compartilhada (`mosk-net` + Postgres + Redis) e avisa em pt-BR que está subindo os serviços pela primeira vez.
2. **Given** ambiente validado, **When** o modo cria um projeto novo, **Then** copia o `payload-starter/` para `~/projects/<nome>`, faz `git init`, gera `.env` com DB/porta/Redis próprios e gera `.claude/rules/payload.md`.
3. **Given** projeto scaffoldado, **When** inicia a Fase A, **Then** Bento conduz o grill em pt-BR, uma pergunta por vez, perguntando **apenas** regras de negócio.
4. **Given** o checklist obrigatório 100% resolvido, **When** o grill converge, **Then** o modo congela `briefing.md` + `checklist.yaml` e deriva os testes a partir do checklist.
5. **Given** briefing congelado, **When** a Fase B roda headless, **Then** executa `specify → plan → tasks → loop-until-green → qa-gate` sem expor barulho de build ao usuário.
6. **Given** build verde + gate `PASS`, **When** entrega, **Then** informa em pt-BR o endereço `http://localhost:<porta>`, resumo do que foi criado e credenciais de login.

---

### User Story 2 - Iterar sobre uma ferramenta existente (ciclo aditivo) (Priority: P2)

Um usuário reativa `/mosk-bench` dentro de um projeto que já existe para adicionar/mudar algo (nova collection, novo campo, nova regra). O modo detecta o bootstrap, **pula o scaffold**, e roda um novo ciclo SDD aditivo — uma spec por mudança, rastreável no git.

**Why this priority**: Ferramentas internas evoluem; sem iteração o modo só serve para o dia zero. Depende do P1 existir, por isso P2.

**Independent Test**: Em um projeto já criado pelo modo, reativar `/mosk-bench`, pedir uma mudança de regra de negócio e confirmar que uma nova spec incremental é criada (via `create-new-feature.sh`), o scaffold não é recopiado, e a mudança sobe sem quebrar o que já existia.

**Acceptance Scenarios**:

1. **Given** um projeto com bootstrap detectado, **When** o usuário reativa o modo, **Then** o scaffold é pulado e o modo entra direto no grill do incremento.
2. **Given** um incremento descrito, **When** a Fase B roda, **Then** cria uma **spec aditiva N** (não a 001) reusando o contrato SDD e `create-new-feature.sh`, e a mudança fica rastreável no git.
3. **Given** a infra compartilhada já de pé, **When** o modo reativa, **Then** reusa a infra e o provisionamento existentes (mesmo DB/porta/Redis do `registry.yaml`), sem reprovisionar.

---

### User Story 3 - Ambiente sem Docker: instalação guiada com uma confirmação (Priority: P2)

Um usuário leigo ativa o modo numa máquina sem Docker. O modo detecta o SO, mostra o comando oficial de instalação, pede **uma confirmação** ("sim") antes de executar (Linux usa `sudo`), e nunca instala nada silenciosamente. Se recusado, para com instrução amigável.

**Why this priority**: É a porta de entrada para leigos; sem tratar a ausência de Docker o P1 falha logo no primeiro passo. Separado do P1 porque é um caminho de exceção testável isoladamente.

**Independent Test**: Rodar em máquina sem Docker (ou simular a ausência), verificar a ordem de checagem, a confirmação obrigatória e o comportamento em caso de recusa.

**Acceptance Scenarios**:

1. **Given** máquina sem Docker, **When** o modo valida ambiente, **Then** checa na ordem `docker --version` → `docker info` (daemon) → `docker compose version` e detecta a ausência.
2. **Given** ausência detectada, **When** o modo propõe instalar, **Then** detecta o SO, mostra o comando oficial e pede confirmação explícita antes de executar.
3. **Given** o usuário recusa a instalação, **When** confirma "não", **Then** o modo para com uma instrução amigável em pt-BR, sem instalar nada.

---

### Edge Cases

- **Grill não converge / usuário cansa**: escape manual "chega" congela o briefing com o que houver, **registrando as lacunas**.
- **Bifurcação técnica durante o grill**: o modo escolhe o **default seguro** e **avisa** (não pergunta).
- **Loop-until-green não converge**: `MAX_FIX_ATTEMPTS` (default 3) por tarefa; ao estourar, marca gate `CONCERNS` + lacuna, nunca loop infinito.
- **Lacuna de regra de negócio na Fase B**: o Workflow **não inventa** regra — para, registra a lacuna e devolve ao grill (Fase A) ou entrega com gate `CONCERNS` explicando em pt-BR o que faltou.
- **Infra global cai**: dados persistem em volumes nomeados; `payload-infra.sh` religa idempotente; mensagem pt-BR clara.
- **Colisão de porta/DB entre projetos**: `registry.yaml` é a fonte da verdade; bind-test antes de alocar porta; DB derivado do slug sanitizado (`[a-z0-9_]`).
- **Redis esgotou índices (0–15)**: cai para prefixo de chave (`<projeto>:`).
- **Primeira subida lenta** (`pnpm install` no `command`): volume nomeado para `node_modules` + lockfile; avisar "a primeira subida demora".
- **Codex vs Claude Code**: o modo funciona de forma equivalente nos dois runtimes (mesmo transcript e entrega); o isolamento da Fase B é capacidade do runtime — estrutural no Claude Code, lógico no Codex (ADR-0004).

## Requirements *(mandatory)*

### Ativação e persona

- **FR-001**: O sistema DEVE expor o gatilho `/mosk-bench` que ativa a persona **Bento**, a qual fala em pt-BR simples, conduz o grill com paciência e **nunca** joga termo técnico no usuário.
- **FR-002**: Ao ativar, Bento DEVE ler `.claude/rules/*.md` (incluindo `payload.md` quando existir) antes de executar.

### Validação de ambiente (determinística)

- **FR-003**: O sistema DEVE validar Docker na ordem `docker --version` → `docker info` → `docker compose version` antes de qualquer provisionamento.
- **FR-004**: Faltando Docker, o sistema DEVE oferecer instalação guiada: detectar SO, mostrar comando oficial, exigir **uma confirmação explícita** antes de executar (Linux com `sudo`); nunca instalar silenciosamente; se recusado, parar com instrução amigável em pt-BR.

### Infra compartilhada e provisionamento (determinístico)

- **FR-005**: O sistema DEVE detectar/criar/reusar a infra compartilhada de forma idempotente: se `mosk-net` não existe, copiar `.mosk-infra/` para `~/projects/.mosk-infra/` e `docker compose up -d` (cria rede + Postgres + Redis); se existe e roda, reusar sem tocar; se parada, `up -d`.
- **FR-006**: O sistema DEVE aplicar um health gate (`pg_isready` + `redis-cli ping` via `docker compose exec`) antes de liberar a Fase B.
- **FR-007**: Por projeto, o sistema DEVE provisionar de forma determinística: **banco próprio** (`CREATE DATABASE <slug sanitizado>`, checando `pg_database` antes), **índice Redis próprio** (0–15, com fallback para prefixo de chave), e **porta livre do admin** (varredura a partir de 3000 com bind-test).
- **FR-008**: O sistema DEVE registrar toda alocação (db, redis_index, admin_port) em `~/projects/.mosk-infra/registry.yaml` como fonte da verdade.

### Scaffold do projeto (determinístico)

- **FR-009**: Para projeto novo, o sistema DEVE copiar o `payload-starter/` **as-is** para `~/projects/<nome-projeto>`, rodar `git init`, gerar `.env` (com `DATABASE_URI`, `REDIS_URL`, `PAYLOAD_SECRET`, `ADMIN_PORT`) e gerar `.claude/rules/payload.md`.
- **FR-010**: O compose do projeto DEVE descrever **apenas o serviço `app`** (Node, imagem pinada `node:22-bookworm-slim`, sem build), montando o código como volume, entrando na `mosk-net` (`external: true`), publicando `${ADMIN_PORT}:3000`.
- **FR-011**: O LLM DEVE customizar apenas `src/collections/` e labels; **nunca** reescrever compose, infra ou a base do `payload.config.ts`.
- **FR-012**: Para projeto existente, o sistema DEVE detectar o bootstrap, **pular o scaffold** e entrar em ciclo SDD aditivo.

### Fase A — Grill interativo (LLM, humano nas respostas)

- **FR-013**: O sistema DEVE conduzir o grill reusando `tasks/grill.md`, uma pergunta por vez, **apenas sobre regras de negócio/domínio** em pt-BR simples.
- **FR-014**: Em qualquer bifurcação técnica, o sistema DEVE escolher o **default seguro** e **avisar** o usuário — nunca perguntar.
- **FR-015**: O grill DEVE convergir **somente** quando todos os itens obrigatórios do checklist estiverem resolvidos (collections+campos, papéis/permissões, integrações de fábrica, labels pt-BR, regras de negócio, critério de "pronto").
- **FR-016**: O sistema DEVE oferecer escape manual ("chega") que congela o briefing com o que houver, **registrando as lacunas**.

### Congelamento e derivação de testes (determinístico + LLM nos asserts)

- **FR-017**: Ao convergir, o sistema DEVE congelar `briefing.md` + `checklist.yaml`.
- **FR-018**: O sistema DEVE derivar os testes a partir do checklist (simetria: o checklist de completude **é** a especificação dos testes). Camadas: base/smoke (herdados do starter), por collection (existe, campos, CRUD, papéis) e regras de negócio (asserts).
- **FR-019**: Os testes DEVEM rodar **dentro do container** via **Local API do Payload** (`payload.find/create/update/delete`), sem HTTP e sem browser (`docker compose exec app pnpm test`, framework Vitest por convenção do starter).

### Fase B — Build autônomo headless (Workflow)

- **FR-020**: O sistema DEVE executar a Fase B via tool `Workflow` **headless**, fora da sessão do leigo, reusando integralmente o contrato SDD do MOSK: `specify → plan → tasks → loop-until-green → qa-gate → entrega`.
- **FR-021**: O `specify` da Fase B DEVE usar `create-new-feature.sh` (numeração/branch/spec-meta atômicos): projeto novo = spec 001; reativação = spec aditiva N.
- **FR-022**: O núcleo da Fase B DEVE ser o loop `implement → testes → conserta` por tarefa, com teto obrigatório `MAX_FIX_ATTEMPTS` (default 3, configurável via env do Workflow, nunca perguntado ao leigo); ao estourar, registrar falha persistente e escalar ou marcar gate `CONCERNS`.
- **FR-023**: "Verde" DEVE significar smoke + testes por collection + asserts de regra de negócio, todos passando via Local API no container.
- **FR-024**: Ao sair verde (ou esgotar tentativas), o sistema DEVE rodar `tasks/qa-gate.md` e emitir `gate.yaml` (`PASS`/`CONCERNS`/`FAIL`) na pasta da spec.
- **FR-025**: Dentro do Workflow da Fase B, os agentes MOSK DEVEM entrar como subagentes headless (`po → dev → qa`, e destes para `architect`/`pm`) com **escalonamento automático** — exceção escopada à Escalation Policy (ADR-0002): o Workflow invoca o subagente necessário, resolve por default seguro e **registra** a decisão no log da spec, sem pausar para o leigo.
- **FR-026**: O escalonamento automático DEVE resolver **apenas questões técnicas**. Lacuna de **regra de negócio** ausente no briefing NÃO DEVE ser inventada — o Workflow para, registra a lacuna e devolve ao grill ou entrega com gate `CONCERNS` explicando em pt-BR.
- **FR-027**: O contrato global da Escalation Policy do MOSK DEVE permanecer intocado: nenhum agente shipa com auto-escalação fora deste Workflow.

### Entrega e iteração

- **FR-028**: Ao concluir, o sistema DEVE entregar em pt-BR: endereço `http://localhost:<porta>`, resumo do que foi criado, credenciais de login e lacunas (se houver).
- **FR-029**: Gate não-`PASS` DEVE gerar resumo em pt-BR (sem jargão) do que ficou pendente, com lacunas registradas.
- **FR-030**: O modo DEVE funcionar de forma **equivalente** no Claude Code e no Codex — mesmo transcript pt-BR visível ao leigo, mesma entrega, mesmo resultado e mesmas invariantes. O **mecanismo de isolamento** da Fase B é uma **capacidade do runtime** (isolamento estrutural via subagente nativo no Claude Code; isolamento lógico por supressão de output + `build-log.md` no Codex), não uma promessa de igualdade de implementação. Ver ADR-0004.

### Anatomia de arquivos no template `mosk/` (o que esta feature cria)

- **FR-031**: A feature DEVE criar a skill `mosk/.claude/skills/mosk-bench/SKILL.md` (wrapper `/mosk-bench` → agente Bento, padrão dos demais skills).
- **FR-032**: A feature DEVE criar a task `mosk/.claude/mosk/tasks/bench-mode.md` (fluxo end-to-end: valida ambiente, provisiona, scaffold, chama grill, congela briefing, dispara Workflow).
- **FR-033**: A feature DEVE criar o agente `mosk/.claude/mosk/agents/bench.md` (persona Bento, `Task mapping → bench-mode.md`).
- **FR-034**: A feature DEVE criar o starter versionado `mosk/.claude/mosk/templates/payload-starter/` (compose do projeto só `app`, código Payload mínimo com admin pt-BR + menu completo + `Users` auth, testes Local API, `.mosk-infra/docker-compose.yml`, `package.json` + `pnpm-lock.yaml` pinados, `.env.example`, `.gitignore`).
- **FR-035**: A feature DEVE criar os scripts `mosk/.claude/mosk/scripts/payload-env.sh` e `payload-infra.sh` (idempotentes, `--help`, `--dry-run`, `source common.sh`).
- **FR-036**: A feature DEVE criar o template-fonte da rule `mosk/.claude/mosk/templates/payload-rule-tmpl.md` (base para gerar `.claude/rules/payload.md` por projeto).
- **FR-037**: Após criar `bench.md`, a feature DEVE rodar `sync-agents-skills.sh --clean` e, após rosters mudarem, `link-codex-skills.sh` (paridade Codex; `AGENTS.md` auto-gerado, nunca editado à mão). Cross-refs skill→agente→task devem permanecer válidas.

### Key Entities *(dados e artefatos)*

- **Starter versionado (`payload-starter/`)**: golden starter Payload+Docker que já sobe e loga; base copiada as-is; contém compose do projeto, código Payload mínimo, testes smoke e a infra compartilhada embutida.
- **Infra compartilhada (`~/projects/.mosk-infra/`)**: Postgres + Redis + rede `mosk-net`, uma vez por máquina, dados em volumes nomeados persistentes.
- **`registry.yaml`**: fonte da verdade da alocação por projeto (db, redis_index, admin_port).
- **`briefing.md` + `checklist.yaml`**: saída congelada do grill; o checklist é também a especificação dos testes.
- **Spec MOSK (per-spec)**: cada build/incremento gera uma spec via `create-new-feature.sh` com `spec-meta.yaml` e `gate.yaml`.
- **Rule `payload.md`**: contexto pt-BR gerado por projeto (menu completo, collections=módulos, convenções, portas/DB alocados).

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Um usuário leigo, em máquina só com Docker, leva `/mosk-bench` do zero a uma ferramenta rodando em `http://localhost:<porta>` **sem tomar nenhuma decisão técnica** (0 perguntas técnicas registradas no grill).
- **SC-002**: 100% dos projetos criados nascem dentro das invariantes por construção: admin em pt-BR, menu completo, módulos=collections, Postgres+Redis, zero build local.
- **SC-003**: A infra de dados sobe **uma vez por máquina** e é reusada por todos os projetos; N ferramentas não sobem N Postgres/Redis.
- **SC-004**: A Fase B nunca entra em loop infinito: todo build termina em verde+`PASS` ou em `CONCERNS`/`FAIL` com lacunas registradas em, no máximo, `MAX_FIX_ATTEMPTS` tentativas por tarefa.
- **SC-005**: Reativar o modo num projeto existente pula o scaffold e produz uma spec aditiva rastreável no git, sem reprovisionar infra.
- **SC-006**: Toda saída ao usuário é pt-BR simples; nenhum YAML, porta, migration ou nome de container é exposto ao leigo em fluxo normal.
- **SC-007**: O modo funciona de forma equivalente no Claude Code e no Codex.

## Assumptions & Defaults chosen

- Type da spec: **feature** (feature substancial do próprio MOSK, construída dentro de `mosk/`).
- Imagens Docker: `node:22-bookworm-slim`, `postgres:16-alpine`, `redis:7-alpine` (pinadas no starter; envelhecem → manutenção versionada pelo time MOSK).
- Framework de teste: **Vitest** via Local API (convenção do starter, nunca perguntado ao leigo).
- `MAX_FIX_ATTEMPTS` default = **3** (convenção; configurável via env do Workflow).
- Varredura de porta a partir de **3000**; índice Redis 0–15 com fallback para prefixo.
- Credenciais Postgres do starter: `mosk:mosk` (ambiente de desenvolvimento, não produção).
- Escopo desta spec: **construir o modo dentro de `mosk/`** (não gerar uma ferramenta real de exemplo).

## Open items for `plan`

- **[NEEDS CLARIFICATION: mecanismo de encadeamento de subagentes headless]** — O ADR-0002 e a arquitetura (§5.4) definem *o contrato* do escalonamento automático dos subagentes (`po → dev → qa`, e destes para `architect`/`pm`) dentro do `Workflow` da Fase B, mas **o mecanismo técnico exato** de como o MOSK encadeia esses subagentes headless (qual tool/runtime orquestra o fan-out, como o estado da spec é passado entre eles, como o log de decisões automáticas é capturado, e como isso se comporta identicamente em Claude Code e Codex) é o principal item aberto a ser resolvido no `plan`. Este é o maior risco de implementação da Fase B.

> Demais decisões estão fechadas no brief (13 decisões) e nos ADRs; o `plan` deve consumi-las como dadas e focar em como implementar, especialmente o item aberto acima.

---
**Arquivado em:** 2026-07-20
**Status final:** Concluído
**Promoções aplicadas:** 1 `copy` — `architecture/adr-0004-runtime-agnostic-phase-orchestration.md` → `docs/architecture/adr/adr-0004-runtime-agnostic-phase-orchestration.md`. Nenhuma `append`, nenhuma `manual` pendente.
