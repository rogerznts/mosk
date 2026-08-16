# deploy-mode

Orquestra o `/mosk-deploy` (voz do Bento): pega uma ferramenta **já criada pelo
`/mosk-bench`** e a **publica no ar**, na conta do próprio usuário, retornando um
**link público** — sem expor nada técnico ao leigo.

É uma skill **separada** do bench (não uma fase dele). O bench continua entregando
em `http://localhost:<porta>` (dev, intacto); o deploy é um passo **opt-in** e
**aditivo** que leva a mesma ferramenta para produção. Ver `ADR-0005`.

## User Input

```text
$ARGUMENTS
```

## Goal

Publicar a ferramenta resolvendo tudo que é técnico por **convenção determinística**
(script de deploy do adapter + overlay de produção gerado), perguntando ao usuário
**só o que é decisão dele** (conta/token e nome público), sempre em **pt-BR simples**.

```
reconhecer projeto bench → escolher driver (stack × provedor) → grill mínimo
(token + nome) → provisionar serviços gerenciados → gerar overlay de produção →
build+deploy REMOTO → migrar → entregar link público
```

---

## Adapter × Provedor (capacidade "Deploy / publicação")

Esta é a nova capacidade de deploy do adapter do bench (mesma tabela de
`bench-mode.md`). Duas dimensões plugáveis:

| Dimensão | Hoje | Concreto |
|----------|------|----------|
| Stack ativa | `payload` (Next.js) | driver `.claude/mosk/scripts/payload-deploy.sh` |
| Provedor default | `railway` | Docker-native, build remoto, Postgres/Redis num clique |

> Adicionar uma stack (ex.: `php`) = novo `<stack>-deploy.sh` + linha aqui, **sem**
> reescrever este roteiro. Adicionar um provedor (ex.: `vercel`/`fly`) = novo modo
> dentro do script do driver. Hoje só existe `payload` × `railway`.

**Invariante-chave (ver ADR-0005):** o `build` de produção roda **no provedor
(remoto)** — nada é buildado na máquina do usuário, então **INV-4 ("zero build
local") permanece válida**. O deploy nunca altera o starter dev do projeto.

---

## Fase 0 — Reconhecer o projeto e pré-requisitos (determinístico)

1. Confirme que o diretório atual é um projeto criado pelo bench (starter do adapter
   presente + `.claude/rules/payload.md`). Se não for, explique em pt-BR que o
   `/mosk-deploy` publica ferramentas feitas com o `/mosk-bench` e pare.
2. Identifique a **stack** (hoje: `payload`) → seleciona o driver de deploy.
3. Cheque a CLI do provedor (ex.: `railway --version`). Se faltar, o driver oferece
   instalação guiada com **uma confirmação** (mesmo padrão do `payload-env.sh`).

## Fase 1 — Grill mínimo (só decisão do usuário)

Pergunte **apenas** (uma de cada vez, pt-BR simples):

1. **Conta/token do provedor.** O usuário traz o próprio token (ex.: `RAILWAY_TOKEN`).
   O token entra **via variável de ambiente**, nunca em flag/linha de comando (não
   vaza no histórico). Se ele não tiver, explique em uma linha onde gerar.
2. **Nome público da ferramenta** (opcional; default derivado do nome do projeto).

Tudo o mais é decidido por convenção: banco/Redis gerenciados, variáveis de ambiente,
config de build de produção, migrations. **Bifurcação técnica ⇒ default seguro +
aviso, nunca pergunta** (INV-5). Nunca exponha porta, host, connection string, YAML
ou comando (INV-6/SC-006).

## Fase 2 — Publicar (determinístico, via driver)

Chame o **driver de deploy do adapter** (`payload-deploy.sh`), que faz, de forma
idempotente:

1. **Autenticar** no provedor pelo token (do ambiente).
2. **Provisionar serviços gerenciados**: Postgres + Redis do provedor (conta paga
   assumida — sem ginástica de free tier).
3. **Gerar o overlay de produção** no projeto **sem tocar no starter dev**:
   - `Dockerfile` de produção multi-stage (install com lockfile pinado → `pnpm build`
     → `next start`), buildado **remotamente** pelo provedor.
   - config do provedor (ex.: `railway.json`) com **release command** rodando
     `payload migrate`.
   - variáveis de produção: `NODE_ENV=production`, `PAYLOAD_SECRET` (novo, aleatório),
     `DATABASE_URI`/`REDIS_URL` (dos serviços gerenciados), storage de uploads
     persistente (volume do provedor).
4. **Disparar build+deploy remoto** e aguardar.
5. **Migrar** o banco no release.
6. Capturar a **URL pública**.

O barulho técnico (build, logs, provisionamento) fica fora da vista do leigo — mesmo
princípio de apresentação do bench.

## Entrega

- Sucesso ⇒ pt-BR, linguagem de negócio: **o link público** da ferramenta, as
  credenciais de acesso e um lembrete de que a versão local (`/mosk-bench`) continua
  funcionando separada.
- Falha ⇒ resumo pt-BR do que impediu (ex.: token inválido, conta sem plano), sem
  despejar log técnico. Nunca deixe a ferramenta "meio publicada" sem avisar.

## Rules

- Deploy é **opt-in e separado**; nunca roda dentro do fluxo do bench nem altera a
  entrega localhost dele (ADR-0005).
- O `build` é **remoto** — nada buildado/instalado na máquina além do que o bench já
  exige (INV-4 preservada).
- O overlay de produção é **gerado**, nunca substitui o starter dev do projeto.
- Token **sempre via ambiente**, nunca em flag (segue a prática da agent-skill oficial
  da Vercel).
- Só pergunte conta/token e nome. Todo o resto é convenção determinística.
- Toda menção a Payload/Railway aqui é **via adapter/driver**: trocar/adicionar stack
  ou provedor não muda este roteiro.
