# ADR-0003 — Starter Payload+Docker versionado (golden starter)

- Status: aceito
- Data: 2026-07-19
- Autor: Vinicius (mosk-architect)
- Contexto: modo `/mosk-payload` — ver `../mosk-payload-mode.md` §3.
- Origem: decisões 3 e 4 do brief de discovery.

## Contexto

O modo precisa de um projeto Payload que **suba e logue** antes de
qualquer customização. Há dois caminhos: (a) o LLM gera todo o scaffold
Payload+Docker on-the-fly a cada projeto, ou (b) existe um scaffold
pronto, versionado, que é copiado e só então customizado.

Geração on-the-fly é frágil: cada projeto pode nascer com um compose
levemente diferente, uma versão de imagem diferente, um `payload.config.ts`
que às vezes esconde entrada de menu ou esquece o pt-BR. Para um leigo,
"às vezes não sobe" é fatal — não há quem debugue.

## Decisão

Shipar um **starter Payload+Docker versionado** dentro do template MOSK,
em `mosk/.claude/mosk/templates/payload-starter/`, copiado **as-is** no
início de um projeto novo. O LLM **só customiza `src/collections/` e
labels** sobre uma base que já sobe e já loga (golden starter +
customização). **Nada de geração on-the-fly.**

Travas no starter (não deixadas para o LLM):

- **Imagens prontas e pinadas**, zero build local (`node:22-bookworm-slim`,
  Postgres/Redis da infra compartilhada).
- Código montado como **volume**, `pnpm dev` com hot-reload.
- `payload.config.ts` já em **pt-BR** com **menu completo** e `Users`
  (`auth: true`) funcionando no primeiro start.
- Framework de teste (Vitest) e `smoke.test.ts` via **Local API** já no
  starter.
- `pnpm-lock.yaml` versionado → subida reprodutível.

## Alternativas consideradas

1. **Geração on-the-fly pelo LLM.** Flexível, mas não-determinística e
   frágil para leigo; "não sobe" sem ninguém para debugar. Rejeitada.
2. **`create-payload-app` a cada projeto.** Depende de rede/versão no
   momento da criação e não fixa nossas invariantes (pt-BR, menu completo,
   infra compartilhada). Rejeitada em favor de um starter que já nasce
   dentro das invariantes MOSK.

## Consequências

**Positivas:** todo projeto nasce idêntico e funcional; invariantes
garantidas por construção; o scaffold é **determinístico** (afasta o LLM
da camada mais frágil); atualizar Payload é uma mudança versionada e
revisada no `mosk/`.

**Negativas:** o starter precisa de **manutenção** — versões pinadas
envelhecem; atualizar Payload é trabalho explícito do time MOSK (mitigado:
lockfile + versão pinada tornam a atualização uma mudança controlada e
revisável, não uma surpresa em produção do leigo).
