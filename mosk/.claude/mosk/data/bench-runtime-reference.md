# Referência de runtime do Bench

Carregue somente a seção necessária à fase corrente de `bench-mode.md`. Esta é
a fonte dos detalhes técnicos que Bento não expõe ao usuário.

## Adapter Payload (ativo)

| Capacidade | Implementação |
|---|---|
| Starter | `.claude/mosk/templates/payload-starter/` |
| Ambiente | `.claude/mosk/scripts/payload-env.sh` |
| Infra e alocação | `.claude/mosk/scripts/payload-infra.sh` |
| Template da rule | `.claude/mosk/templates/payload-rule-tmpl.md` |
| Rule gerada | `.claude/rules/payload.md` |
| Testes | `docker compose exec app pnpm test` |
| Publicação opt-in | `.claude/mosk/scripts/payload-deploy.sh` |

Adicionar stack significa fornecer starter, scripts, template de rule, comando
de teste e este mapeamento; o fluxo do Bench não muda.

### Invariantes

- Admin e labels em pt-BR; módulo equivale a collection.
- Postgres + Redis; zero build local fora de Docker.
- Usuário decide regras de negócio, nunca tecnologia.
- Saída visível sempre em pt-BR simples.

## Preparação e scaffold

1. Rode `payload-env.sh`; não avance com status diferente de zero.
2. Rode `payload-infra.sh` e depois
   `payload-infra.sh --provision "<nome-do-projeto>"`. Reuse `ALLOC_*` em nova
   execução; não reprovisione.
3. Em projeto novo, copie o starter sem regenerá-lo para
   `~/projects/<nome>`, inicialize git e materialize `.env` com `DATABASE_URI`,
   `REDIS_URL`, `ADMIN_PORT` e segredo aleatório.
4. Gere `.claude/rules/payload.md` do template e depois acrescente o resumo do
   briefing. O LLM só altera `src/collections/` e labels.

## Briefing e testes

O checklist obrigatório resolve módulos/campos, papéis, integrações, labels,
regras e critério de pronto. Grave o acordo em `briefing.md` e
`checklist.yaml`; registre lacunas quando houver escape `chega`.

Os testes são simétricos ao checklist:

- smoke herdado do starter;
- existência, campos, CRUD e papéis por módulo;
- asserts de negócio derivados do briefing.

## Execução headless

O disco é a fronteira de estado: diretório da spec, `spec-meta.yaml`, artefatos
e `decisions-log.md`. Passos de agente passam por
`invoke_phase_agent(role, phase, spec_dir)`:

- isolamento nativo é preferido; entrada contém apenas fase + `spec_dir`, saída
  é status curto e o resultado fica no disco;
- sem isolamento nativo, execute a mesma task na sessão e redirecione detalhes
  para `build-log.md`;
- processo filho headless é otimização opcional, nunca requisito.

Sequência:

1. `specify`: `create-new-feature.sh`; projeto novo inicia na primeira spec
   disponível, incremento usa novo número reservado.
2. `plan` e `tasks`: agente PO nas tasks canônicas.
3. `build-loop`: agente Dev, testes do adapter e até três correções por tarefa.
4. `qa-gate`: agente QA grava `gate.yaml`.
5. `deliver`: apenas apresentação; não é fase canônica.

`PASS` exige smoke, testes acumulados de módulo e asserts de negócio verdes.
Teto esgotado produz `CONCERNS`. Decisão técnica interna usa default seguro e é
registrada; lacuna de negócio não é inventada. Scripts de transição continuam
sendo a única forma de alterar fases canônicas.

## Iteração aditiva

Carregue rule e módulos existentes, faça grill apenas do delta, resolva colisões
antes de congelar e preserve tudo que não foi explicitamente substituído. Testes
antigos e novos rodam juntos. A entrega resume somente o que mudou e mantém o
mesmo endereço.
