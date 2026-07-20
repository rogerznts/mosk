# payload-starter (golden starter do modo `/mosk-bench`)

Starter Payload+Docker **versionado** que já **sobe e loga** antes de qualquer
customização (ADR-0003). O modo `/mosk-bench` copia esta pasta **as-is** para
`~/projects/<nome-projeto>` e só então customiza `src/collections/` e labels.

> Este README é para **quem mantém o MOSK**, não para o usuário leigo. O leigo
> nunca vê nada disto — o modo cuida de tudo.

## Invariantes travadas por construção

- **INV-1**: admin sempre em **pt-BR** (`i18n.fallbackLanguage: 'pt'`), **menu
  completo** (nenhuma collection com `admin.hidden`, nenhum `admin.group` que
  oculte entradas).
- **INV-3**: **Postgres** (via `@payloadcms/db-postgres`) + **Redis** (infra
  compartilhada).
- **INV-4**: imagem pinada (`node:22-bookworm-slim`), **zero build local**;
  código montado como volume, `node_modules` em volume nomeado.
- O LLM **só** edita `src/collections/` e labels (FR-011). Nunca reescreve
  compose, infra ou a base do `payload.config.ts`.

## O que sobe

- `docker-compose.yml` — só o serviço `app` (Payload/Next), entra na `mosk-net`.
- `.mosk-infra/docker-compose.yml` — Postgres + Redis + rede `mosk-net`
  (infra compartilhada por máquina, gerida por `payload-infra.sh`).
- `src/payload.config.ts` — config base (pt-BR, menu completo, registro de collections).
- `src/collections/Users.ts` — auth base; login funciona no primeiro `pnpm dev`.
- `src/tests/smoke.test.ts` — smoke via Local API (admin instancia, login, PG, Redis).

## Como validar localmente (checkpoint M1)

```bash
# 1. Subir a infra compartilhada (uma vez por máquina):
#    O compose da infra é dono da rede `mosk-net` (não-external) e a cria sozinho.
#    NÃO rode `docker network create mosk-net` antes — pré-criar a rede colide com
#    o compose ("network ... has incorrect label") e o Postgres não sobe.
docker compose -f .mosk-infra/docker-compose.yml up -d

# 2. Preparar o .env deste projeto (o modo faz isso automaticamente):
cp .env.example .env   # e ajustar DATABASE_URI/REDIS_URL/PAYLOAD_SECRET/ADMIN_PORT

# 3. Subir o app:
docker compose up

# 4. Rodar o smoke (em outro terminal):
docker compose exec app pnpm test
```

Esperado: admin em pt-BR em `http://localhost:<ADMIN_PORT>/admin`, login funciona,
smoke verde.

## Manutenção de versões (importante)

- As versões em `package.json` estão **pinadas exatas** (sem `^`/`~`) para subida
  reprodutível. Ao atualizar o Payload/Next, faça-o como **mudança versionada e
  revisada** aqui no `mosk/` (ADR-0003).
- **`pnpm-lock.yaml` não é versionado neste template.** Ele é gerado na primeira
  subida (`pnpm install` dentro do container) e persiste no volume do projeto
  gerado. Se o time MOSK quiser travar também as dependências transitivas,
  rode `pnpm install` uma vez neste starter e **commite o `pnpm-lock.yaml`
  resultante** — a partir daí o compose pode usar `pnpm install --frozen-lockfile`.
- Os arquivos sob `src/app/(payload)/` são **boilerplate gerado pelo Payload 3**.
  Ao subir a versão do Payload, reconcilie-os com o template oficial da versão
  pinada (`create-payload-app` blank) durante a validação M1.
