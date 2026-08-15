# {{PROJECT_NAME}} — Regras da ferramenta (Payload / modo MOSK `/mosk-bench`)

<!--
  Template usado pela task `bench-mode.md` para gerar
  `.claude/rules/payload.md` no projeto criado pelo modo /mosk-bench.

  Preencha os {{PLACEHOLDERS}} com a alocação real do projeto (vinda do
  registry.yaml via payload-infra.sh) e com o resumo do briefing congelado.
  Escreva em pt-BR simples: este arquivo também é lido pelo Bento na ativação.

  Mantenha as seções invariantes (INV-1..6, collections=módulos, menu completo)
  intactas — elas são o contrato do produto gerado.
-->

## O que é esta ferramenta

{{ONE_PARAGRAPH_EM_PT_BR_DO_QUE_A_FERRAMENTA_FAZ}}

Criada com o modo MOSK `/mosk-bench` (persona Bento). Toda a parte técnica é
resolvida por convenção ou automaticamente — o usuário só descreve regras de negócio.

## Como acessar

- **Endereço do painel:** http://localhost:{{ADMIN_PORT}}/admin
- **Login:** criado no primeiro acesso (ou informado na entrega).
- Para ligar/desligar a ferramenta, use o modo `/mosk-bench` — nunca comandos manuais.

## Invariantes do produto (travadas por construção — não violar)

- **INV-1**: admin **sempre em pt-BR**, com **menu completo** (nada escondido ou
  agrupado que oculte entradas). Nunca usar `admin.hidden` nem `admin.group` que
  esconda módulos.
- **INV-2**: **todo módulo é uma collection** do Payload. Sem exceção.
- **INV-3**: **Postgres** como banco, **Redis** para fila (infra compartilhada `mosk-net`).
- **INV-4**: **zero build local**; só Docker. Imagens pinadas.
- **INV-5**: o usuário decide **só regra de negócio**; todo o resto é convenção.
- **INV-6**: toda saída ao usuário é **pt-BR simples**, sem jargão.

## Alocação deste projeto (fonte: registry.yaml — não editar à mão)

- **Banco (Postgres):** `{{DATABASE_NAME}}`
- **Redis:** índice `{{REDIS_INDEX}}`{{REDIS_PREFIX_NOTE}}
- **Porta do admin:** `{{ADMIN_PORT}}`

## Módulos (collections) desta ferramenta

{{COLLECTIONS_E_CAMPOS_EM_LINGUAGEM_SIMPLES}}

<!-- Ex.:
- **Clientes** (`customers`): nome, e-mail, telefone, status.
- **Pedidos** (`orders`): cliente, itens, valor, situação.
-->

## Quem pode usar (papéis)

{{PAPEIS_E_PERMISSOES_EM_LINGUAGEM_SIMPLES}}

## Regras de negócio ativas

{{REGRAS_DE_NEGOCIO_DERIVADAS_DO_BRIEFING}}

## Convenções técnicas (para os agentes, não para o usuário)

- O LLM só edita `src/collections/` e labels. **Nunca** reescreve o compose, a
  infra ou a base do `payload.config.ts` (FR-011).
- Novas collections entram em `src/collections/` e são registradas em
  `payload.config.ts` **sem** `hidden`/agrupamento (INV-1).
- Testes rodam via **Local API** do Payload, dentro do container:
  `docker compose exec app pnpm test` (Vitest) (FR-019).
- Cada mudança nasce como uma **spec aditiva** (via `create-new-feature.sh`),
  rastreável no git — nunca reescreve a spec 001 (FR-021).
- Credenciais de desenvolvimento do Postgres: `mosk:mosk` (não é produção).

## Como evoluir a ferramenta

Reative `/mosk-bench` neste projeto e descreva a mudança em pt-BR. O modo detecta
que o projeto já existe, pula a criação inicial e roda um ciclo aditivo (US2).
