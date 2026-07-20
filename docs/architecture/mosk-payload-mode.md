# Arquitetura — Modo `/mosk-payload` (persona Bento)

> Autor: Vinicius (mosk-architect) · Data: 2026-07-19 · Status: design
> aprovado para spec.
> Base: `docs/discovery/mosk-payload-mode-brief.md` (13 decisões fechadas).
> ADRs relacionados: [adr-0001](./adr/adr-0001-shared-infra-model.md),
> [adr-0002](./adr/adr-0002-auto-escalation-exception.md),
> [adr-0003](./adr/adr-0003-versioned-golden-starter.md).

## 1. Escopo e princípio orientador

Modo MOSK que deixa um **usuário leigo** criar e testar ferramentas
internas sobre Payload CMS sem tocar em decisão técnica. Toda peça de
produto vive sob `mosk/` e shipa via `npx degit`. A rule `payload.md` é
**gerada por projeto** (não shipa pronta).

**Invariantes não-negociáveis** (herdadas do brief, valem em todo o
design abaixo):

- Admin **sempre em pt-BR**, com **menu completo** do Payload.
- Módulo customizado = **collection**. Sem exceção.
- **Postgres** como banco, **Redis** para fila.
- **Zero build local, zero instalação** na máquina além do Docker
  (instalado só com confirmação explícita).
- Grill pergunta **só regra de negócio**; tudo técnico é convenção.
- Saída ao usuário **sempre em pt-BR simples**.

**Deriva desses princípios uma regra de arquitetura central:** o leigo
nunca vê YAML, migration, porta ou nome de container. Toda essa camada é
**determinística** (scripts + starter versionado) ou **headless**
(`Workflow` da Fase B). O LLM só aparece em dois pontos: conduzir o grill
(Fase A) e customizar collections/regras (Fase B). Ver §7 para o corte
determinístico vs LLM.

## 2. Visão de componentes

```
┌──────────────────────────────────────────────────────────────┐
│ Sessão principal (Claude Code / Codex) — persona Bento         │
│                                                                │
│  /mosk-payload  →  task payload-mode.md                         │
│     │                                                           │
│     ├─ [det]  validar ambiente  → scripts payload-env.sh        │
│     ├─ [det]  provisionar infra → scripts payload-infra.sh      │
│     ├─ [det]  scaffold projeto  → copia payload-starter/        │
│     ├─ [LLM]  Fase A: grill      → tasks/grill.md (loop humano)  │
│     ├─ [det]  congelar briefing  → briefing.md + checklist.yaml  │
│     ├─ [det]  derivar testes     → do checklist                 │
│     └─ [Workflow] Fase B: build headless (§5)                   │
│                                                                 │
└───────────────────────────────┬─────────────────────────────┘
                                 │  docker
        ┌────────────────────────┴─────────────────────────┐
        │  rede externa  mosk-net                           │
        │                                                   │
        │  ┌─ ~/projects/.mosk-infra ─┐   ┌─ ~/projects/X ─┐ │
        │  │  postgres  (1x/máquina)  │   │  app (Node)     │ │
        │  │  redis     (1x/máquina)  │◄──┤  pnpm dev       │ │
        │  └──────────────────────────┘   │  volume: código │ │
        │                                  │  db próprio     │ │
        │                                  │  porta livre    │ │
        │                                  └─────────────────┘ │
        └───────────────────────────────────────────────────┘
```

Três planos:

1. **Plano de orquestração** (sessão Bento) — LLM + scripts determinísticos.
2. **Plano de infra compartilhada** — Postgres + Redis, uma vez por máquina (§4).
3. **Plano de projeto** — um container `app` por ferramenta (§3).

## 3. Starter Payload+Docker versionado

Vive em `mosk/.claude/mosk/templates/payload-starter/` e é copiado
**as-is** no início de um projeto novo (decisão 3). O LLM só edita
`src/collections/` e labels; **nunca** reescreve compose, Dockerfile
ausente (não há build) ou infra. É um *golden starter*: já sobe, já loga.

### 3.1 `docker-compose.yml` do projeto (só serviço `app`)

Contrato (decisão 4 + 13):

- **Um único serviço**, `app` (Node). Postgres/Redis vêm da infra global.
- **Imagem pronta e pinada** — `node:22-bookworm-slim` (sem build de
  imagem; `pnpm` habilitado via `corepack enable` no `command`).
- **Código montado como volume** (`.:/app`) + volume nomeado para
  `node_modules` (evita I/O cruzado host/container). Hot-reload do
  `pnpm dev` reflete no admin.
- **Command:** `corepack enable && pnpm install && pnpm dev` (dev server,
  não produção).
- **Rede:** entra na rede **externa** `mosk-net` (não a cria).
- **Sem porta fixa hardcoded:** a porta do admin é injetada por env
  (`ADMIN_PORT`, alocada pelo modo — §4.3) e publicada como
  `${ADMIN_PORT}:3000`.
- **Conexões apontam para os hostnames da rede:** `postgres` e `redis`
  (nomes de serviço da infra global), banco e prefixo próprios via env.

Esqueleto (placeholders resolvidos pelo `.env` que o modo gera):

```yaml
services:
  app:
    image: node:22-bookworm-slim
    working_dir: /app
    command: sh -c "corepack enable && pnpm install && pnpm dev"
    env_file: [.env]
    ports:
      - "${ADMIN_PORT}:3000"
    volumes:
      - .:/app
      - app_node_modules:/app/node_modules
    networks: [mosk-net]
    restart: unless-stopped

volumes:
  app_node_modules:

networks:
  mosk-net:
    external: true
```

O `.env` (gerado, não versionado — entra no `.gitignore` do starter):

```
DATABASE_URI=postgres://mosk:mosk@postgres:5432/${PROJECT_DB}
REDIS_URL=redis://redis:6379/${REDIS_DB_INDEX}
PAYLOAD_SECRET=<gerado>
ADMIN_PORT=<porta livre alocada>
```

### 3.2 Estrutura mínima de código Payload

```
payload-starter/
├── docker-compose.yml          # §3.1 (só serviço app)
├── .env.example                # documenta as chaves; .env é gerado
├── .gitignore                  # ignora .env, node_modules, dist
├── package.json                # deps pinadas; scripts dev/test/migrate
├── pnpm-lock.yaml              # lockfile versionado (reprodutível)
├── tsconfig.json
├── payload.config.ts           # admin pt-BR + menu completo + i18n
└── src/
    ├── collections/
    │   └── Users.ts            # collection base de auth (auth: true)
    └── tests/
        └── smoke.test.ts       # base/smoke via Local API (§3.3)
```

Invariantes travadas **no starter**, não deixadas para o LLM decidir:

- `payload.config.ts` já define `i18n` com `fallbackLanguage: 'pt'` e
  `admin` sem `hidden`/agrupamentos que escondam entradas — **menu
  completo** por construção.
- `Users.ts` (`auth: true`) é a **collection base de auth**; login já
  funciona no primeiro `pnpm dev`.
- Toda collection nova gerada pelo LLM herda o padrão de `labels`
  pt-BR (singular/plural) e vai para `src/collections/`, registrada em
  `payload.config.ts`.

### 3.3 Testes via Local API

Testes rodam **dentro do container** (`docker compose exec app pnpm test`),
usando a **Local API do Payload** (`payload.find/create/update/delete`) —
sem HTTP, sem browser, rápido e determinístico. Ficam em
`src/tests/`:

- `smoke.test.ts` — herdado do starter: admin instancia, login funciona,
  Postgres e Redis conectam. (Base/smoke da decisão 8.)
- `collections/<nome>.test.ts` — **gerados** na Fase B a partir do
  checklist: collection existe, campos definidos, CRUD, papéis.
- `rules/<slug>.test.ts` — **gerados**: asserts das regras de negócio do
  briefing.

Framework de teste é **convenção do starter** (Vitest, já no
`package.json`), nunca perguntado ao leigo (decisão 9).

## 4. Modelo de infra compartilhada (decisão 13)

Ver [adr-0001](./adr/adr-0001-shared-infra-model.md) para o trade-off.

### 4.1 `~/projects/.mosk-infra/docker-compose.yml`

Serviços de dados, **uma vez por máquina**, reusados por todos os
projetos. Também versionado no starter, em
`payload-starter/.mosk-infra/docker-compose.yml`, e copiado para
`~/projects/.mosk-infra/` na primeira vez.

```yaml
services:
  postgres:
    image: postgres:16-alpine
    environment:
      POSTGRES_USER: mosk
      POSTGRES_PASSWORD: mosk
      POSTGRES_DB: mosk_root      # DB âncora; projetos criam os seus
    volumes: [mosk_pgdata:/var/lib/postgresql/data]
    networks: [mosk-net]
    restart: unless-stopped

  redis:
    image: redis:7-alpine
    volumes: [mosk_redisdata:/data]
    networks: [mosk-net]
    restart: unless-stopped

volumes:
  mosk_pgdata:
  mosk_redisdata:

networks:
  mosk-net:
    name: mosk-net
    driver: bridge
```

- **A infra é quem *cria* a `mosk-net`** (`name: mosk-net`); os projetos
  a consomem como `external: true`. Isso força a ordem correta:
  infra antes de qualquer projeto.
- **Dados persistem** em volumes nomeados: derrubar a infra não apaga
  dados (trade-off aceito no brief — derruba todas as ferramentas juntas,
  dados ficam).

### 4.2 Detecção / criação / reuso (determinístico)

Executado por `payload-infra.sh` durante a validação de ambiente,
**idempotente**:

1. `docker network inspect mosk-net` — existe?
   - Não → copia `.mosk-infra/` para `~/projects/.mosk-infra/` (se ausente)
     e `docker compose up -d` lá (cria rede + sobe Postgres/Redis).
2. `docker compose -f ~/projects/.mosk-infra/... ps` — Postgres e Redis
   `running`?
   - Parados → `up -d` (reusa volumes existentes).
   - Rodando → **reusa**, não toca.
3. `pg_isready` + `redis-cli ping` (via `docker compose exec`) — health
   gate antes de liberar a Fase B.

Nunca pergunta nada ao leigo aqui; no máximo **avisa** ("subindo os
serviços compartilhados pela primeira vez…").

### 4.3 Provisionamento por projeto (determinístico)

Ao criar/reativar um projeto, `payload-infra.sh --provision <projeto>`:

- **Banco próprio:** `CREATE DATABASE <projeto>` no Postgres compartilhado
  (`CREATE DATABASE IF NOT EXISTS`-equivalente: checa `pg_database` antes).
  Nome derivado do slug do projeto, sanitizado (`[a-z0-9_]`). →
  **Isolamento**: uma ferramenta nunca lê/corrompe dados de outra.
- **Índice/prefixo Redis próprio:** aloca um `REDIS_DB_INDEX` livre
  (0–15) por projeto; se estourar 16, cai para prefixo de chave
  (`<projeto>:`). Registrado em `~/projects/.mosk-infra/registry.yaml`.
- **Porta livre do admin:** varre a partir de `3000` a primeira porta TCP
  não ocupada no host (bind-test), grava em `ADMIN_PORT` no `.env` do
  projeto e no `registry.yaml`.

`registry.yaml` (fonte da verdade da alocação, determinística):

```yaml
projects:
  crm-interno:  { db: crm_interno,  redis_index: 0, admin_port: 3000 }
  estoque:      { db: estoque,      redis_index: 1, admin_port: 3001 }
```

## 5. Contrato do `Workflow` da Fase B (build headless)

Ver [adr-0002](./adr/adr-0002-auto-escalation-exception.md) (exceção de
escalonamento) e [adr-0003](./adr/adr-0003-versioned-golden-starter.md).

A Fase B roda **headless**, fora da sessão do leigo (decisão 7), para
manter o barulho de build invisível. Entrada: `briefing.md` congelado +
`checklist.yaml` + testes derivados. Saída: ferramenta verde + `gate.yaml`.

### 5.1 Fases SDD encadeadas

O `Workflow` **reusa integralmente o contrato SDD do MOSK** — não inventa
pipeline paralelo:

```
specify → plan → tasks → [loop build] → qa-gate → entrega
```

- `specify` — usa `create-new-feature.sh` (numeração/branch/spec-meta
  atômicos, igual ao resto do MOSK). Projeto novo = spec 001; reativação =
  spec aditiva N (decisão 11).
- `plan` / `tasks` — derivados do briefing congelado. Determinísticos no
  scaffold (starter já resolve stack), LLM só para o recorte de
  collections/regras.

### 5.2 Loop `implement → testes → conserta` (loop-until-green)

O núcleo da Fase B. **Teto de tentativas obrigatório** para evitar loop
infinito:

```
para cada tarefa em tasks.md:
  tentativa = 0
  repita:
    dev.implement(tarefa)
    resultado = docker compose exec app pnpm test   # Local API
    se resultado == verde: break
    tentativa += 1
    se tentativa >= MAX_FIX_ATTEMPTS (default 3):
       registra falha persistente → escala (§5.4) ou marca gate CONCERNS
    dev.conserta(diff dos testes que falharam)
```

- **"Verde" = definição da decisão 8:** smoke + testes por collection +
  asserts de regra de negócio, todos via Local API no container.
- O loop é **determinístico na estrutura** (rodar teste, comparar,
  decidir continuar) e **LLM no conserto** (interpretar falha, editar
  código).
- `MAX_FIX_ATTEMPTS` é convenção (3); configurável via env do Workflow,
  nunca perguntado ao leigo.

### 5.3 `qa-gate`

Ao sair verde (ou esgotar tentativas), roda `tasks/qa-gate.md` do MOSK e
emite `gate.yaml` (`PASS` / `CONCERNS` / `FAIL`) na pasta da spec. Verde +
gate `PASS` → entrega. Gate não-`PASS` → resumo em pt-BR do que ficou
pendente (sem jargão) + lacunas registradas.

### 5.4 Agentes MOSK como subagentes com escalonamento automático

Dentro do `Workflow`, os agentes entram como **subagentes headless**:

```
po (specify/plan/tasks)  →  dev (implement/loop)  →  qa (qa-gate)
```

**Exceção escopada à Escalation Policy** (decisão 2, [adr-0002](./adr/adr-0002-auto-escalation-exception.md)):

- No MOSK global, agentes **sugerem** handoff e **esperam** o usuário.
- **Dentro deste `Workflow` e só aqui**, o escalonamento é **automático**:
  se `dev` detecta ambiguidade de arquitetura, o Workflow invoca
  `architect` como subagente, resolve por **default seguro** e **registra**
  a decisão no log da spec — não pausa para perguntar ao leigo (seria
  pedir decisão técnica, violando a regra de ouro).
- O contrato global do MOSK **permanece intocado**: a automação vive
  inteiramente no runtime da Fase B; nenhum agente shipa com
  auto-escalação fora daqui.
- **Limite duro:** o escalonamento automático resolve *técnico*. Se a
  lacuna for de **regra de negócio** ausente no briefing, o Workflow
  **não inventa** — para, registra a lacuna e devolve ao grill (Fase A)
  ou entrega com gate `CONCERNS` explicando em pt-BR o que faltou.

## 6. Fluxo de runtime end-to-end

```
1. /mosk-payload  (persona Bento assume; lê .claude/rules/*.md + payload.md)
        │
2. [det] Validar ambiente
        docker --version → docker info → docker compose version
        falta Docker? → instalação guiada, 1 confirmação obrigatória
                        (detecta SO, mostra comando oficial, Linux=sudo;
                         recusou? para com instrução amigável)
        │
3. [det] Validar/subir infra compartilhada (§4.2) + provisionar projeto (§4.3)
        │
4. [det] Projeto novo?  → copia payload-starter/ para ~/projects/<nome>,
                          git init, gera .env, gera .claude/rules/payload.md
         Projeto existe? → detecta bootstrap, PULA scaffold,
                           ciclo SDD aditivo (decisão 11)
        │
5. [LLM] Fase A — Grill (tasks/grill.md, loop humano, uma pergunta por vez)
        pergunta SÓ regra de negócio em pt-BR simples
        decide técnico por convenção; em bifurcação técnica: default + AVISA
        sai só quando checklist obrigatório 100% resolvido
        escape manual "chega" → congela com lacunas registradas
        │
6. [det] Congelar briefing → briefing.md + checklist.yaml
        │
7. [det] Derivar testes do checklist (simetria decisão 8)
        checklist = especificação dos testes
        │
8. [Workflow] Fase B — Build headless (§5)
        specify → plan → tasks → loop-until-green → qa-gate
        subagentes po→dev→qa, escalonamento técnico automático
        │
9. [LLM/det] Entrega em pt-BR
        "sua ferramenta está pronta em http://localhost:<porta>"
        resumo do que foi criado, credenciais de login, lacunas se houver
```

## 7. Determinístico vs LLM (corte explícito)

| Etapa | Natureza | Por quê |
|---|---|---|
| Validação Docker / instalação guiada | **Determinística** | Comandos fixos; confirmação é input humano, não decisão LLM. |
| Detecção/subida da infra compartilhada | **Determinística** | `docker network inspect` + `compose up -d`, idempotente. |
| Provisionamento (DB, redis index, porta) | **Determinística** | Alocação registrada em `registry.yaml`; sem criatividade. |
| Cópia do starter / scaffold | **Determinística** | Golden starter versionado; nada gerado on-the-fly. |
| Geração da rule `payload.md` | **LLM** (guiado por template) | Redação pt-BR do contexto do projeto, como `/mosk-boot`. |
| Fase A — grill | **LLM** (humano nas respostas) | Conduzir entrevista, sharpen de linguagem, decisão técnica por convenção. |
| Congelar briefing + checklist | **Determinística** | Serialização do que o grill resolveu. |
| Derivar testes do checklist | **Determinística** na estrutura, **LLM** nos asserts de regra | Casca (existe/CRUD/papéis) é template; regra de negócio vira assert redigido. |
| Fase B — loop-until-green | **Determinística** no loop, **LLM** no implement/conserta | Rodar teste e comparar é mecânico; escrever código é LLM. |
| qa-gate | **Determinística** (gate) sobre **LLM** (avaliação) | Verdict `PASS/CONCERNS/FAIL` é regra; leitura de evidência é LLM. |
| Entrega | **LLM** (redação pt-BR) | Traduzir resultado técnico em linguagem de leigo. |

Regra de leitura: **quanto mais perto do leigo, mais determinístico**
(nada de decisão técnica exposta); **quanto mais perto do código, mais
LLM** (mas headless, na Fase B).

## 8. Anatomia de arquivos no template `mosk/`

Todos shipam via degit, exceto `payload.md` (gerada por projeto).

| Peça | Caminho exato | Papel |
|---|---|---|
| Skill (gatilho) | `mosk/.claude/skills/mosk-payload/SKILL.md` | Wrapper `/mosk-payload` → agente Bento. Segue o padrão dos demais skills MOSK. |
| Task (orquestração) | `mosk/.claude/mosk/tasks/payload-mode.md` | Fluxo end-to-end (§6): valida ambiente, scaffold, chama grill, congela briefing, dispara Workflow. |
| Agente (persona) | `mosk/.claude/mosk/agents/bento.md` | Persona Bento: fala simples, conduz grill com paciência, nunca joga termo técnico no usuário. `Task mapping` → `payload-mode.md`. |
| Starter versionado | `mosk/.claude/mosk/templates/payload-starter/` | Golden starter (§3): compose do projeto, código Payload mínimo (admin pt-BR + menu completo + `Users` auth), testes Local API. |
| Infra compartilhada | `mosk/.claude/mosk/templates/payload-starter/.mosk-infra/docker-compose.yml` | Postgres+Redis+`mosk-net` (§4.1), copiado para `~/projects/.mosk-infra/`. |
| Scripts | `mosk/.claude/mosk/scripts/payload-env.sh`, `payload-infra.sh` | Validação Docker + detecção/subida/provisionamento (§4.2/§4.3). Idempotentes, `--help`, `--dry-run`, `source common.sh`. |
| Rule (gerada) | `.claude/rules/payload.md` (no projeto do usuário) | Contexto pt-BR: menu completo, collections=módulos, convenções, portas/DB alocados. Gerada como o `/mosk-boot` faz. Template-fonte: `mosk/.claude/mosk/templates/payload-rule-tmpl.md` (novo). |

**Sincronização obrigatória** (regras do repo):

- Após criar `bento.md`: `bash mosk/.claude/mosk/scripts/sync-agents-skills.sh --clean`
  (gera `.claude/agents/mosk-payload.md` e mantém as três camadas alinhadas).
- Após rosters mudarem: `bash mosk/.claude/mosk/scripts/link-codex-skills.sh`
  (paridade Codex; `AGENTS.md` é auto-gerado, nunca editar à mão).
- `bento.md` referencia `payload-mode.md` em `## Task mapping`; o skill
  aponta para o agente. Cross-refs devem permanecer válidas.

## 9. Decisões de arquitetura registradas (ADRs)

Aplicando o critério de ADR do MOSK (difícil de reverter + surpreendente
sem contexto + trade-off real), três decisões viram ADR:

- **[adr-0001](./adr/adr-0001-shared-infra-model.md)** — Infra de dados
  compartilhada por máquina (Postgres+Redis 1x, app por projeto).
- **[adr-0002](./adr/adr-0002-auto-escalation-exception.md)** —
  Escalonamento automático dos agentes escopado ao `Workflow` da Fase B.
- **[adr-0003](./adr/adr-0003-versioned-golden-starter.md)** — Starter
  Payload+Docker versionado em vez de geração on-the-fly.

As demais decisões (labels pt-BR, framework de teste, `MAX_FIX_ATTEMPTS`,
varredura de porta) são convenções — ficam neste doc, não viram ADR.

## 10. Riscos e mitigações

| Risco | Mitigação |
|---|---|
| Infra global cai → todas as ferramentas param (acoplamento aceito) | Dados em volumes nomeados; `payload-infra.sh` religa idempotente; mensagem pt-BR clara. |
| `pnpm install` no `command` deixa o primeiro start lento | Volume nomeado para `node_modules` + lockfile versionado; avisar "primeira subida demora". |
| Loop-until-green não converge | `MAX_FIX_ATTEMPTS` (teto 3) → gate `CONCERNS` + lacuna, nunca loop infinito. |
| Escalonamento automático "inventa" regra de negócio | Limite duro: auto-escala só resolve técnico; lacuna de negócio volta ao grill (§5.4). |
| Colisão de porta/DB entre projetos | `registry.yaml` como fonte da verdade; bind-test antes de alocar porta. |
| Starter desatualiza vs Payload | Versão pinada no `package.json`+lockfile; atualização é mudança versionada no `mosk/`, revista pelo time. |
