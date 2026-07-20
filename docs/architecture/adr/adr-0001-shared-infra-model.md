# ADR-0001 — Infra de dados compartilhada por máquina

- Status: aceito
- Data: 2026-07-19
- Autor: Vinicius (mosk-architect)
- Contexto: modo `/mosk-payload` — ver `../mosk-payload-mode.md` §4.
- Origem: decisão 13 do brief de discovery.

## Contexto

Cada ferramenta interna criada pelo modo `/mosk-payload` precisa de
Postgres (banco) e Redis (fila). A decisão 6 do brief coloca cada projeto
em `~/projects/nome-projeto` com docker-compose próprio. Se cada projeto
subisse seu próprio Postgres+Redis, teríamos N pares de containers de
dados por máquina: consumo de RAM/porta multiplicado, startup lento, e um
leigo rodando 3–4 ferramentas afundaria a máquina.

## Decisão

Os **serviços de dados rodam uma vez por máquina** e são **reusados** por
todos os projetos:

- **Infra global:** `~/projects/.mosk-infra/docker-compose.yml` sobe
  Postgres + Redis + a rede Docker externa `mosk-net`. A infra é quem
  **cria** a rede (`name: mosk-net`).
- **Por projeto:** o compose descreve **só o serviço `app`** (Node), que
  entra na `mosk-net` (`external: true`), usa um **banco próprio**
  (`CREATE DATABASE <projeto>`), um **índice/prefixo Redis próprio** e uma
  **porta livre** alocada para o admin.
- **Isolamento por banco:** bancos separados garantem que uma ferramenta
  nunca lê ou corrompe dados de outra.
- **Alocação determinística:** `registry.yaml` em `~/projects/.mosk-infra/`
  é a fonte da verdade de db/redis-index/porta por projeto.

## Alternativas consideradas

1. **Postgres+Redis por projeto** (seguir decisão 6 à risca). Isolamento
   máximo, zero acoplamento — mas peso e startup inviáveis para um leigo
   com várias ferramentas. Rejeitada.
2. **Um único banco compartilhado com schemas por projeto.** Mais leve que
   (1), mas isolamento mais frágil (um DROP errado vaza entre schemas) e
   mais lógica de roteamento. Rejeitada em favor de banco-por-projeto no
   mesmo servidor: mesmo peso de servidor, isolamento forte.

## Consequências

**Positivas:** startup rápido, RAM/porta controladas, isolamento forte por
banco, dados persistem em volumes nomeados mesmo derrubando a infra.

**Negativas (trade-off aceito):** exceção parcial à decisão 6 — o projeto
passa a **depender** da infra global estar de pé (acoplamento em troca de
leveza). Derrubar a infra para uma ferramenta derruba todas juntas; os
dados, porém, permanecem salvos. `payload-infra.sh` religa a infra de
forma idempotente e o modo comunica isso ao leigo em pt-BR.
