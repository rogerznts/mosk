# Brief de Discovery — Modo `/mosk-payload` (persona Bento)

> Autor: Maria (mosk-analyst) · Data: 2026-07-19 · Status: entendimento
> compartilhado, pronto para PM/Architect/PO.

## Contexto

Modo de trabalho MOSK para **usuários leigos da empresa** criarem e
testarem ferramentas internas sobre **Payload CMS**, sem tocar em
decisão técnica. Infra 100% Docker (nada instalado na máquina além do
próprio Docker), saída sempre em **pt-BR**, admin sempre com **menu
completo do Payload**, módulos = collections. Funciona igual no Claude
Code e no Codex.

## Espinha dorsal do modo

`ativar → validar ambiente → grill em loop fechado → briefing congelado →
build SDD autônomo com testes → ferramenta pronta`

Dois loops, dois mecanismos distintos:

- **Fase A — Grill (autônomo na condução, humano nas respostas):** loop
  agêntico interativo na sessão principal. Reusa `tasks/grill.md`.
- **Fase B — Build (autônomo de ponta a ponta):** tool `Workflow`
  headless, loop `implement → testes → conserta → repete até verde` +
  `qa-gate`.

## Decisões fechadas (grill)

1. **Forma estrutural.** Três peças com papéis distintos:
   - Skill `/mosk-payload` (gatilho) + task `payload-mode.md` + agente
     persona **Bento** — todos no template `mosk/` (shipam via degit).
   - Rule `.claude/rules/payload.md` **gerada por projeto** (pt-BR, menu
     completo, collections, convenções) — como o `/mosk-boot` faz hoje.

2. **Orquestração automática.** Este modo é **exceção escopada** à
   Escalation Policy do MOSK: aqui os agentes escalam automaticamente. O
   contrato global do MOSK permanece intocado. A exceção vive dentro do
   `Workflow` da Fase B.

3. **Origem do scaffold.** Template Payload+Docker **versionado**,
   shipado dentro do `mosk/`, copiado no início. LLM só customiza
   collections sobre uma base que já sobe e já loga (golden starter +
   customização). Nada de geração on-the-fly.

4. **Stack Docker.** `docker-compose.yml` com **imagens prontas e
   pinadas** — `node`, `postgres`, `redis` (fila). **Zero build local.**
   Código do projeto montado como **volume** no container Node rodando
   `pnpm dev` (hot-reload reflete no admin). Migrations/seed via
   `docker compose exec`. Ambiente de desenvolvimento, não produção.

5. **Validação de ambiente / Docker.** Ordem: `docker --version` →
   `docker info` (daemon) → `docker compose version`. Se faltar Docker,
   **instalação guiada com uma confirmação obrigatória** (detecta SO,
   mostra comando oficial, pede "sim" antes de executar; Linux usa
   `sudo`). Nunca silenciosa; se recusado, para com instrução amigável.

6. **Local dos projetos.** Cada projeto em `~/projects/nome-projeto`,
   com **git obrigatório** + docker-compose dentro. O compose do projeto
   descreve **só o serviço `app`** (ver decisão 13).

7. **Motor da Fase B.** Tool **`Workflow`**: loop-until-green + SDD +
   fan-out dos agentes MOSK (`po → dev → qa`) como subagentes. Mantém o
   barulho de build fora da sessão do leigo.

8. **Definição de "verde" (testes).** Camadas derivadas do briefing,
   rodando no container via **Local API do Payload**:
   - Base/smoke (herdados do template): admin sobe, login funciona, DB e
     Redis conectam.
   - Por collection (gerados): existe, campos definidos, CRUD, papéis.
   - Regras de negócio do briefing → asserts.
   - **Simetria:** o checklist de completude do grill É a especificação
     dos testes.

9. **Fronteira do grill.** Pergunta **só regras de negócio/domínio** em
   pt-BR simples. Decide **todo o técnico por convenção** (Postgres,
   estrutura, hooks, docker, framework de teste). Em bifurcação técnica,
   escolhe o default seguro e **avisa** (não pergunta). Regra de ouro:
   *nunca faça um leigo tomar uma decisão técnica.*

10. **Convergência do grill.** Loop fechado sai só quando **todos** os
    itens obrigatórios do checklist estão resolvidos (collections+campos,
    papéis/permissões, integrações de fábrica, labels pt-BR, regras de
    negócio, critério de "pronto"), com **escape manual** ("chega"
    congela com o que tem, registrando lacunas).

11. **Iteração pós-build.** Reativar o modo num projeto existente detecta
    o bootstrap, **pula o scaffold** e roda um **novo ciclo SDD aditivo**
    (uma spec por mudança, rastreável no git). Reusa integralmente o
    contrato SDD do MOSK e o `create-new-feature.sh`.

12. **Nomes.** Skill `/mosk-payload` · task `payload-mode.md` · persona
    **Bento** (o construtor — fala simples, conduz o grill com paciência,
    nunca joga termo técnico no usuário).

13. **Modelo de infra — compartilhada.** Os **serviços de dados**
    (Postgres + Redis) rodam **uma vez por máquina** e são **reusados**
    por todos os projetos; o **app Payload** é sempre próprio de cada
    projeto.
    - **Infra global:** `~/projects/.mosk-infra/docker-compose.yml` sobe
      Postgres + Redis + rede Docker externa `mosk-net`. Validação de
      ambiente checa se existe/roda: se não, cria e sobe; se sim, reusa.
    - **Por projeto:** compose só com o serviço `app` (Node), que entra
      na `mosk-net`, usa um **banco próprio** no Postgres (`CREATE
      DATABASE nome_projeto`), um **prefixo/DB próprio** no Redis, e uma
      **porta livre** alocada pelo modo para o admin.
    - **Isolamento:** bancos separados → uma ferramenta nunca enxerga ou
      corrompe os dados de outra.
    - **Trade-off aceito:** exceção parcial à decisão 6 — o projeto passa
      a **depender** da infra global estar de pé (acoplamento em troca de
      leveza e startup rápido). Derrubar a infra para todas as ferramentas
      juntas, mas os dados permanecem salvos.

## Invariantes do produto gerado

- Admin **sempre em pt-BR**, com **menu completo** do Payload.
- Módulos customizados = **collections**.
- Postgres como banco, Redis para fila.
- Tudo em Docker, imagens prontas, nada buildado/instalado na máquina
  além do Docker.

## Onde isso mora no MOSK (resumo)

| Peça | Caminho | Ship via degit? |
|---|---|---|
| Skill | `mosk/.claude/skills/mosk-payload/SKILL.md` | sim |
| Task | `mosk/.claude/mosk/tasks/payload-mode.md` | sim |
| Agente | `mosk/.claude/mosk/agents/bento.md` | sim |
| Template starter | `mosk/.claude/mosk/templates/payload-starter/` (novo) | sim |
| Rule (gerada) | `.claude/rules/payload.md` no projeto do usuário | gerada por projeto |

## Handoff

Esta é uma feature substancial do próprio MOSK. Próximos passos sugeridos:

1. **`/mosk-architect`** — desenhar o starter Payload+Docker versionado
   (compose, volumes, dev server, Local API de teste) e o contrato do
   `Workflow` da Fase B (fases, loop-until-green, escalonamento).
2. **`/mosk-po`** — abrir a spec via `specify` e rodar o pipeline SDD
   para construir o modo dentro de `mosk/`.
