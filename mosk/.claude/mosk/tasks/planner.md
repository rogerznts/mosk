# Planner Task

## Purpose

Manter planos de acompanhamento vivos e logs datados de atualização,
guiados pelo manual autorado pelo time consumidor
(`docs/discovery/project-manual.md`).

O planner opera em **dois escopos**, decididos pela branch atual:

- **Projeto inteiro** — quando na branch principal
  (`main`/`master`/`develop`/`dev`): escreve `docs/project/plan.md` e
  `docs/project/update-YYYYMMDD.md`.
- **Spec atual** — quando em qualquer branch não-principal que casa com
  uma spec: escreve `docs/specs/{id}/project/plan.md` e
  `docs/specs/{id}/project/update-YYYYMMDD.md` **e** dá um refresh no
  `docs/project/plan.md` do projeto com o progresso dessa spec.

> **Audiência (regra de ouro).** Estes arquivos são para **PO,
> stakeholders, gestores de projeto e usuários envolvidos que não são
> técnicos**. São documentos de **acompanhamento de negócio**, não
> documentação técnica. Escreva em linguagem de progresso, escopo e
> valor — não de implementação. É permitido **mencionar** um arquivo
> técnico ou trazer um detalhe técnico pontual quando isso ajuda o
> leitor, mas isso **nunca é a prioridade**: não despeje specs, APIs,
> schemas, nomes de função, caminhos de código ou trechos técnicos. O
> detalhe técnico mora na spec / em `docs/architecture/`; aqui mora o
> "onde estamos, o que entregamos e para onde vamos".

A task lê o manual, a documentação viva (`docs/`), a atividade git
recente e o comentário livre passado na chamada do comando. Sempre é
disparada pelo usuário via `/mosk-pm planner "<comentário opcional>"`.
Nunca é invocada por escalation.

## When to run

- Cadência regular definida pelo manual (semanal, quinzenal, etc.).
- Antes de stakeholder sync ou checkpoint.
- Após milestone, mudança de escopo, ou criação de novo spec.
- Durante o desenvolvimento de uma spec, para registrar progresso na
  branch da feature (escopo SPEC).
- Sob demanda para gerar artefato datado para PR de tracking.

## Inputs

- **Manual de acompanhamento**: `docs/discovery/project-manual.md`
  (autorado pelo consumidor; se faltar, é criado a partir do template
  `.claude/mosk/templates/project-manual-tmpl.md` no passo 2). Um único
  manual governa os dois escopos.
- **Documentação viva (projeto)**: `docs/{discovery,prd,architecture,ui,qa,project}/`
  e `docs/specs/*/spec-meta.yaml` (apenas `status: active`).
- **Documentação da spec (escopo SPEC)**: `docs/specs/{id}/` — `spec.md`,
  `spec-meta.yaml` e o que houver em `discovery/`, `architecture/`,
  `ui/`, `stories/` — lido como **insumo de tradução**, nunca copiado
  como conteúdo técnico.
- **Atividade git**: desde o mtime do `plan.md` do escopo corrente
  quando ele já existe; fallback `--since="7 days ago"` na primeira
  execução.
- **Comentário do usuário**: string livre passada como argumento da
  chamada do comando.

## Workflow

### 1. Detectar escopo (branch)

1. Resolva a branch atual:
   ```bash
   BRANCH=$(bash -c 'source .claude/mosk/scripts/common.sh; get_current_branch')
   ```
2. Branches principais (escopo PROJETO): `main master develop dev`.
3. **Branch principal → escopo PROJETO.** Alvos:
   - `PLAN = docs/project/plan.md`
   - `UPDATE_DIR = docs/project/`
4. **Branch não-principal → escopo SPEC.** Valide na ordem
   "**primeiro o projeto, depois a spec**":
   a. Confirme que existe `docs/project/` com `plan.md`. Se não existir,
      ele será semeado adiante — o refresh do projeto (passo 6b) depende
      dele.
   b. Resolva a spec da branch pelo prefixo numérico:
      ```bash
      SPEC_DIR=$(bash -c 'source .claude/mosk/scripts/common.sh; find_feature_dir_by_prefix "$(get_repo_root)" "'"$BRANCH"'"')
      ```
   c. Se `SPEC_DIR` existe como pasta → **escopo SPEC**. Alvos:
      - `PLAN = $SPEC_DIR/project/plan.md`
      - `UPDATE_DIR = $SPEC_DIR/project/`
      - **+ refresh** de `docs/project/plan.md` (passo 6b).
      Crie a subpasta `project/` dentro da spec se ainda não existir.
   d. Se a branch **não** casa com nenhuma spec (sem prefixo `^\d{3}-`
      ou pasta inexistente): faça **uma pergunta única e direta** ao
      usuário — tratar como escopo de projeto, ou apontar o id da spec a
      usar? **Sem menu 1-9.** Prossiga conforme a resposta.

Registre o escopo escolhido (`project` ou `spec`, e o `spec_id` quando
SPEC) para usar no frontmatter do update e no report final.

### 2. Garantir manual de acompanhamento

1. Verifique se `docs/discovery/project-manual.md` existe (o manual é
   **único e project-wide**; vale para os dois escopos).
2. Se **não** existir:
   a. Copie `.claude/mosk/templates/project-manual-tmpl.md` para
      `docs/discovery/project-manual.md`.
   b. Preencha os placeholders com base no que entender lendo PRD,
      architecture e discovery (vide passo 3). Inferências razoáveis
      são preferidas a perguntas em massa.
   c. Para cada placeholder em que a confiança for baixa, faça uma
      **pergunta única e específica** ao usuário. NÃO emitir menus
      numerados 1-9. Uma pergunta direta por dúvida.
   d. Confirme com o usuário em uma frase ("Manual gerado e preenchido;
      seguindo com a geração do plano.") antes de prosseguir.
3. Se o manual já existe, leia-o por inteiro e siga.

### 3. Carregar documentação viva — projeto primeiro, depois a spec

1. **Projeto primeiro.** Leia `docs/index.md` se existir. Caso
   contrário, percorra cada domínio base (`discovery`, `prd`,
   `architecture`, `ui`, `qa`, `project`) e liste os arquivos `.md`
   existentes.
2. Para cada `docs/specs/*/spec-meta.yaml`, leia metadata (use
   `read_spec_meta` de `.claude/mosk/scripts/common.sh` quando
   conveniente). Considere apenas specs com `status: active`.
3. **Depois a spec atual (somente escopo SPEC).** Leia `SPEC_DIR/spec.md`,
   `SPEC_DIR/spec-meta.yaml` (status, `current_phase`) e o que houver em
   `SPEC_DIR/{discovery,architecture,ui,stories}/`. Trate tudo como
   insumo a ser **traduzido para linguagem de acompanhamento** — não
   copie conteúdo técnico para o plano.
4. Extraia do manual: cadência, vocabulário de status, formato de
   marcos, regras de resumo git, escopo do update file, regras de
   tratamento do comentário do usuário.

### 4. Ler atividade git

1. Determine a janela a partir do `plan.md` do **escopo corrente**:
   - Se `$PLAN` existe:
     ```bash
     SINCE=$(date -r "$PLAN" +%Y-%m-%dT%H:%M:%S)
     ```
   - Caso contrário (primeira execução): escopo SPEC usa o `created_at`
     da spec (de `spec-meta.yaml`) quando disponível; senão, e no escopo
     PROJETO, `SINCE="7 days ago"`.
2. Execute:
   ```bash
   git log --since="$SINCE" --pretty='%h %ad %an %s' --date=short --no-merges | head -n 200
   ```
3. Escopo SPEC: filtre/priorize commits cujo subject é prefixado pelo
   número da spec (`^{NNN}-`) ou que tocaram `SPEC_DIR`. Escopo PROJETO:
   agrupe por autor e por prefixo de spec conforme as regras do manual.
4. **Traduza commits → progresso de negócio.** Os hashes e termos
   técnicos podem aparecer apenas na seção de auditoria do update file;
   no corpo do plano, descreva o que avançou em termos de
   valor/entrega, não de implementação.

### 5. Gerar o comentário da AI

O update file tem uma seção `## Comentário` (variável
`{{AI_COMMENT_FULL_OR_NONE}}`) **escrita pela própria AI**, não copiada
do usuário. Regras:

1. Compor o comentário a partir do que foi observado neste run: commits
   da janela git, spec ativo/atual tocado, mudanças detectadas no
   planejamento e estado atual do `plan.md` do escopo.
2. Se o usuário passou um comentário na chamada do comando, **usar
   esse texto como guia**: incorporar verbatim ou parafrasear,
   destacar o que ele pediu para registrar, e responder pontos
   levantados.
3. Se o usuário não passou nada (string vazia): **modo YOLO** — a AI
   sintetiza livremente o que viu, sem ficar travada esperando direção.
4. O comentário deve ser objetivo (3–8 linhas), em primeira pessoa do
   plural ("Avançamos…", "Bloqueamos em…"), **em tom de acompanhamento
   e sem jargão técnico** (vide audiência na seção Purpose), pronto para
   colar em PR.
5. Independente do modo, o frontmatter do update guarda o input
   original do usuário em `user_comment` (one-line; vazio quando YOLO)
   para auditoria.

### 6. Decidir se o(s) plan.md muda(m)

#### 6a. Plano do escopo corrente (`$PLAN`)

Atualize `$PLAN` somente quando ao menos uma das condições for
verdadeira:

- O manual mudou desde o último run (compare timestamp ou hash).
- Surgiu novo spec ativo / a fase da spec atual mudou desde o último run.
- Marco, risco, foco ou objetivo mudou (com base no manual + docs).
- O comentário do usuário pede ajuste explícito de planejamento.

Quando nenhuma condição se aplica: **não rescreva** o conteúdo; apenas
atualize o campo `Last updated` no topo do arquivo.

Quando rescrever:

- Carregue `.claude/mosk/templates/project-plan-tmpl.md` se o arquivo
  ainda não existir (vale para projeto e para spec; no escopo SPEC,
  `{{PROJECT_NAME}}` = título/id da spec). Ordem padrão das seções:
  `objectives` (Resumo), `milestones` (Planejamento), `deliverables`
  (Entregáveis), `current-focus` (Foco Atual), `status-snapshot`
  (Status Snapshot), `risks` (Riscos), `open-questions` (Perguntas
  Abertas).
- A seção `objectives` consome `{{SUMMARY_AND_OBJECTIVES}}`: um
  parágrafo de resumo do estado seguido pelos objetivos declarados.
- **Conteúdo em linguagem não-técnica** (vide audiência). No escopo
  SPEC, descreva o valor e o progresso da feature, não seu desenho
  técnico.
- Preserve o bloco `<!-- custom -->…<!-- /custom -->` na íntegra.
- Substitua somente seções demarcadas
  `<!-- section:<id> -->…<!-- /section -->` que precisem mudar.
- Nunca delete seções; se uma sumir do manual, mantenha e emita warning.

#### 6b. Refresh do projeto (apenas escopo SPEC)

Além do plano da spec, atualize `docs/project/plan.md` para refletir o
progresso **desta spec** no contexto do todo:

- Atualize a linha do marco/épico correspondente (quando houver), o
  `Status Snapshot` e o `Foco Atual` apenas no que o avanço da spec
  mudar.
- Se `docs/project/plan.md` não existir, crie-o do template antes do
  refresh.
- Mesmas regras não-destrutivas do 6a: nunca delete seções, preserve
  `<!-- custom -->`, mexa só nas seções afetadas.
- Mantenha o foco do projeto: a spec é **uma linha do todo**, não o
  todo. Não inche o plano do projeto com detalhe de uma única feature.

### 7. Emitir update datado

1. Caminho: `$UPDATE_DIR/update-YYYYMMDD.md` (data UTC do run) — ou seja,
   `docs/project/` no escopo PROJETO e `docs/specs/{id}/project/` no
   escopo SPEC.
2. Se o arquivo já existir para hoje, **anexe** um bloco
   `## Run HH:MM UTC` ao final — nunca sobrescreva.
3. Carregue o esqueleto de
   `.claude/mosk/templates/project-update-tmpl.md` quando criar pela
   primeira vez.
4. Preencha o frontmatter:
   - `date`: timestamp UTC ISO 8601.
   - `author`: `git config user.name` (fallback: "unknown").
   - `scope`: `project` ou `spec`.
   - `spec_id`: o id da spec quando escopo SPEC; vazio no escopo PROJETO.
   - `commits_window`: ex.: `"2026-05-08T00:00:00Z..2026-05-15T12:30:00Z"`.
   - `commits_count`: total da janela.
   - `specs_touched`: lista de `spec_id`s detectados (no escopo SPEC,
     normalmente só a spec atual).
   - `user_comment`: o texto bruto que o usuário passou no comando, em
     uma linha (vazio quando YOLO).
   - `plan_changed`: `true|false` (refere-se ao `$PLAN` do escopo).
   - `plan_sections_changed`: lista de section ids quando aplicável.
   - `delta`: `empty` quando `commits_count == 0` AND `user_comment`
     vazio AND `plan_changed: false`; `standard` caso contrário.
5. Emita **sempre**, mesmo com `delta: empty` — este artefato serve
   como registro de PR e auditoria de cadência. A seção `## Comentário`
   traz o texto escrito pela AI no passo 5, nunca fica em branco.

### 8. Atualizar `docs/index.md`

Chame `../tasks/index-docs.md` ao final para regenerar o índice. O
índice incluirá `docs/project/` como domínio base e destacará o
`plan.md` + o update mais recente. No escopo SPEC, os arquivos sob
`docs/specs/{id}/project/` aparecem listados dentro da spec.

## Rules

- **Audiência não-técnica**: todo conteúdo de `plan.md` e dos updates é
  para PO, stakeholders, gestores e usuários não-técnicos. Linguagem de
  acompanhamento, não de implementação. Detalhe técnico é citável, nunca
  prioritário.
- **Escopo por branch**: branch principal → projeto inteiro; branch de
  spec → plano da spec **+ refresh do projeto**. Valide sempre primeiro
  o projeto (`docs/project/`), depois a spec da branch.
- **Idempotente**: mesmo input (mesmo git, mesmo manual, mesmo
  comentário) produz o mesmo output, modulo timestamps.
- **Nunca destrutivo**: sem deleção de seções em `plan.md`, sem
  overwrite de `<!-- custom -->`, sem overwrite de update já gravado.
- **Manual ausente** → fluxo de seed inline (passo 2); nunca invente
  regras de tracking sem registrar no manual.
- **Sem elicitation 1-9**: perguntas devem ser pontuais e diretas
  (inclui a desambiguação de escopo no passo 1).
- **User-triggered apenas**: não invocável por pipeline escalation.
- Respeite as invariantes MOSK (Document Organization, Promotion
  Convention, Agent Roles, Escalation Policy, Spec Numbering,
  `docs/index.md`).

## Auto-invocation points

Nenhuma. Sempre disparado pelo usuário via `/mosk-pm planner …`.

## Process Output

Ao final, reporte:

1. Escopo detectado (`project` ou `spec`) e a branch que o determinou;
   no escopo SPEC, o `spec_id` resolvido.
2. Janela git usada e total de commits considerados.
3. Specs ativos detectados/tocados.
4. Estado do `plan.md` do escopo: `criado`, `atualizado` (com seções
   afetadas), ou `inalterado`. No escopo SPEC, também o estado do
   refresh em `docs/project/plan.md`.
5. Caminho do `update-YYYYMMDD.md` emitido e flag `delta`.
6. Warnings: manual incompleto, seção desaparecida, link quebrado em
   `docs/`, spec sem `spec-meta.yaml`, branch não-principal sem spec
   correspondente.
