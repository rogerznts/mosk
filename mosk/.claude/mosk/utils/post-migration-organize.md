# post-migration-organize

O objetivo é reorganizar os resíduos, fora do padrão na raiz de `docs/`, pastas órfãs, 
ou stories/épicos sem destino definido, dentro da nova estrutura de domínios
(`discovery/`, `prd/`, `architecture/`, `ui/`, `qa/`, `specs/`) **sem**
contaminar a base com conteúdo que na verdade pertence a uma spec em andamento.

## Context required

Antes de começar, leia (nesta ordem):

1. `.claude/README.md` — estrutura oficial do template e fluxo único com preâmbulo.
2. `.claude/rules/project.md` — regras do projeto, incluindo as seções
   **Document Organization**, **Promotion Convention** e a decisão
   **base × spec**.
3. `.claude/mosk/core-config.yaml` — paths canônicos: `discovery.root`,
   `prd.root`, `architecture.root`, `ui.root`, `qa.gatesDir`, `specs.root`.

Se qualquer um desses arquivos estiver ausente, pare e avise o usuário
antes de mover qualquer coisa.

## Guardrails

- **Nunca sobrescreva** um arquivo existente na base sem confirmação do
  usuário. Se houver colisão, proponha um nome alternativo ou pule.
- **Nunca mova** um arquivo que você não conseguiu classificar com
  confiança — pergunte o destino ao usuário.
- **Não aplique `promote:` automaticamente** em artefatos que foram para
  uma spec específica; apenas sugira ao usuário adicionar o front-matter
  quando fizer sentido.
- **Não delete nada** que não tenha sido movido com sucesso. Em caso de
  dúvida, deixe para o usuário revisar.

## Steps

### 1. Scan — mapear os resíduos

Percorra `docs/` de forma rasa e profunda o suficiente para identificar:

- **Arquivos `.md` soltos na raiz de `docs/`** (fora de `discovery/`, `prd/`,
  `architecture/`, `ui/`, `qa/`, `specs/`, `index.md`).
- **Pastas não-canônicas na raiz de `docs/`** — por exemplo, `docs/epics/`,
  `docs/brainstorming/`, `docs/research/`, `docs/stories/` residual, etc.
- **Stories órfãs** em `docs/specs/_orphan-stories/`.
- **Subpastas dentro de `docs/specs/*/`** que não seguem o padrão
  (`stories/`, `tests/`, `discovery/`, `architecture/`, `ui/`) — raro, mas
  pode acontecer.

Monte uma tabela inicial e apresente ao usuário:

| # | Caminho | Tipo inferido | Sugestão de destino | Motivo |
|---|---|---|---|---|
| 1 | docs/project-brief.md | brief | docs/discovery/brief.md | H1 + conteúdo indicam product brief |
| 2 | docs/api-spec.md | API contract | docs/architecture/api-spec.md | mencionado no `devLoadAlwaysFiles` padrão |
| 3 | docs/epics/epic-3-billing.md | epic | specs/003-feature-billing/ (a criar) | numeração 3 casa com pattern |
| 4 | docs/specs/_orphan-stories/random.md | standalone story | escolher spec | sem prefixo epic reconhecível |

### 2. Classificar por domínio

Para cada arquivo solto, use heurísticas combinadas (nome + conteúdo):

| Heurística | Destino provável |
|---|---|
| Nome contém `brief`, `research`, `competitor`, `market`, `brainstorm` | `docs/discovery/` |
| Primeiro `#` do arquivo menciona "Product Requirements", "PRD", "Goals", "Personas" | `docs/prd/` |
| Nome ou H1 indica arquitetura, data model, API, tech stack, ADR | `docs/architecture/` (ADRs entram em `docs/architecture/adr/`) |
| Nome contém `design`, `ui`, `ux`, `flow`, `wireframe`, `style` | `docs/ui/` (flows em `docs/ui/flows/`) |
| Nome contém `qa`, `gate`, `test-plan`, `nfr`, `risk` | `docs/qa/` ou `docs/qa/gates/` |
| Nome começa com `epic-N`, `N.M.story`, ou conteúdo referencia ACs | **spec** (não base) |

Quando o arquivo tiver múltiplas pistas ou ambiguidade, **pergunte ao
usuário** apresentando 2–3 opções mais prováveis.

### 3. Epics e stories órfãs — alocar em spec

Para cada epic/story solto (`docs/epics/epic-N-*.md`,
`docs/specs/_orphan-stories/*.md`, stories dentro de pastas não-padrão):

1. **Tentar casar com spec existente.** Extraia a numeração do arquivo
   (`epic-3-*` → prefixo `003`, `1.2.story.md` → epic `001`). Verifique se
   existe `docs/specs/003-*` (ou qualquer outra pasta com esse prefixo).
   Se sim, proponha mover para `docs/specs/{match}/stories/`.

2. **Se não houver match**, ofereça três opções ao usuário:
   - **(a)** alocar em uma spec ativa existente (liste as ativas lendo
     `spec-meta.yaml` de cada `docs/specs/*/`);
   - **(b)** criar uma nova spec agora via
     `bash .claude/mosk/scripts/create-new-feature.sh --type feature --short-name '<slug>' '<descrição>'`
     e mover o(s) arquivo(s) para a nova `stories/`;
   - **(c)** deixar em `_orphan-stories/` com nota de revisão pendente.

3. Para epics consolidados (`docs/epics/epic-N-foo.md`), considere o
   arquivo do epic como **um resumo**; os arquivos de story correspondentes
   devem entrar em `stories/` da mesma spec. O epic em si pode virar
   `docs/specs/{id}/epic.md` ou ser absorvido na `spec.md` da spec —
   pergunte ao usuário qual caminho prefere.

### 4. Resíduos dentro de `docs/specs/*/`

Se uma spec carrega subpastas não-canônicas (por exemplo, um `notes/`
legado ou `attachments/`), liste-as e pergunte ao usuário:

- mover para a subpasta canônica correspondente (`discovery/`,
  `architecture/`, `ui/`, `tests/`);
- manter como extensão da spec (aceitável, mas não canônica);
- descartar.

### 5. Confirmar em bloco e aplicar

Depois de classificar tudo, apresente a tabela final com todas as
movimentações propostas e peça confirmação em bloco (`aplicar tudo`,
`revisar item a item`, ou `cancelar`).

Para cada movimentação confirmada:

- Use `git mv` quando a árvore está versionada, caso contrário `mv`.
- Se o destino já existe, pare e pergunte: sobrescrever, renomear, ou
  pular.
- Para arquivos que foram para dentro de uma spec, sugira ao usuário
  adicionar `promote:` front-matter se o artefato deve ser promovido
  para a base no `archive` (opcional, nunca automático).

### 6. Limpar estruturas vazias

Após as movimentações, remova pastas na raiz de `docs/` que ficaram
vazias (por exemplo, `docs/epics/`, `docs/specs/_orphan-stories/`). Nunca
remova nada com arquivos ainda dentro.

### 7. Regenerar `docs/index.md`

Execute a task `.claude/mosk/tasks/index-docs.md` com `docs/` como
target. Isso atualiza a tabela de Active Specs (caso uma nova spec
tenha sido criada no passo 3) e recalcula a seção Domain Contents.

### 8. Atualizar `spec-meta.yaml` quando aplicável

Se alguma story/epic foi promovido para dentro de uma spec existente ou
nova, verifique se `docs/specs/{id}/spec-meta.yaml` está consistente:

- `status: active`
- `current_phase` reflete a fase real (se a spec tem apenas stories e
  nenhum `plan.md`/`tasks.md`, use `specify`).
- Se a spec acabou de ser criada pelo `create-new-feature.sh`, ela já
  tem `spec-meta.yaml` preenchido — não edite desnecessariamente.

### 9. Relatório final

Emita um resumo com:

- Total de arquivos movidos por domínio (discovery, prd, architecture,
  ui, qa).
- Total de stories/epics alocados em specs existentes vs. nova spec vs.
  mantidos órfãos.
- Pastas removidas por estarem vazias.
- **Itens pendentes** que exigem ação humana: colisões não resolvidas,
  arquivos cuja classificação você não teve confiança, stories órfãs
  mantidas com nota de revisão.
- Próximos passos recomendados ao usuário:
  - rodar `shard-doc` em `docs/prd/raw.md` / `docs/architecture/raw.md`
    se ainda estiverem como monolito;
  - rodar `/mosk-boot` novamente se `.claude/rules/` precisa ser
    regenerado após a nova estrutura;
  - abrir as specs ativas e verificar se `spec-meta.yaml` precisa de
    atenção manual (campo `created_by` vazio, por exemplo).

## Reference

- `.claude/README.md` — estrutura oficial e fluxo.
- `.claude/rules/project.md` — regra canônica; seção **Document
  Organization** define onde cada tipo de artefato mora.
- `.claude/mosk/tasks/archive.md` — como a promoção (`promote:`) funciona
  quando a spec é arquivada.
- `.claude/mosk/tasks/index-docs.md` — regeneração do `docs/index.md`.
- `.claude/mosk/scripts/create-new-feature.sh` — criação de spec nova
  quando órfãos precisam de um destino estrutural.

## Exemplo de sessão (resumido)

```
Usuário: rodei migrate-docs-structure.sh e sobrou coisa solta.
         Organize o resto.

Agente:  Escaneei docs/. Encontrei:
         - 3 arquivos soltos na raiz (brief.md, api-contract.md, ui-notes.md)
         - 1 pasta não-canônica: docs/epics/ (2 arquivos)
         - 4 stories em docs/specs/_orphan-stories/

         Proposta:
         | # | Caminho               | Destino                                 |
         |---|-----------------------|-----------------------------------------|
         | 1 | docs/brief.md         | docs/discovery/brief.md                 |
         | 2 | docs/api-contract.md  | docs/architecture/api-contract.md       |
         | 3 | docs/ui-notes.md      | docs/ui/ui-notes.md  (confirmar?)       |
         | 4 | docs/epics/epic-3-*.md| docs/specs/003-feature-billing/epic.md  |
         | 5 | _orphan/story-1.1.md  | docs/specs/001-feature-auth/stories/    |
         | 6 | _orphan/random.md     | (não casou) escolha: (a) spec ativa,
         |   |                       |   (b) nova spec, (c) manter órfão       |

         Confirma o bloco (aplicar tudo/revisar/cancelar)?
```
