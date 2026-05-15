# Planner Task

## Purpose

Manter um plano de projeto vivo em `docs/project/plan.md` e um log
datado de atualizações em `docs/project/update-YYYYMMDD.md`, guiado
pelo manual de acompanhamento autorado pelo time consumidor
(`docs/discovery/project-manual.md`).

A task lê o manual, a documentação viva (`docs/`), a atividade git
recente e o comentário livre passado na chamada do comando. Sempre é
disparada pelo usuário via `/mosk-pm planner "<comentário opcional>"`.
Nunca é invocada por escalation.

## When to run

- Cadência regular definida pelo manual (semanal, quinzenal, etc.).
- Antes de stakeholder sync ou checkpoint.
- Após milestone, mudança de escopo, ou criação de novo spec.
- Sob demanda para gerar artefato datado para PR de tracking.

## Inputs

- **Manual de acompanhamento**: `docs/discovery/project-manual.md`
  (autorado pelo consumidor; se faltar, é criado a partir do template
  `.claude/mosk/templates/project-manual-tmpl.md` no passo 1).
- **Documentação viva**: `docs/{discovery,prd,architecture,ui,qa}/` e
  `docs/specs/*/spec-meta.yaml` (apenas `status: active`).
- **Atividade git**: desde o mtime de `docs/project/plan.md` quando ele
  já existe; fallback `--since="7 days ago"` na primeira execução.
- **Comentário do usuário**: string livre passada como argumento da
  chamada do comando.

## Workflow

### 1. Garantir manual de acompanhamento

1. Verifique se `docs/discovery/project-manual.md` existe.
2. Se **não** existir:
   a. Copie `.claude/mosk/templates/project-manual-tmpl.md` para
      `docs/discovery/project-manual.md`.
   b. Preencha os placeholders com base no que entender lendo PRD,
      architecture e discovery (vide passo 2). Inferências razoáveis
      são preferidas a perguntas em massa.
   c. Para cada placeholder em que a confiança for baixa, faça uma
      **pergunta única e específica** ao usuário. NÃO emitir menus
      numerados 1-9. Uma pergunta direta por dúvida.
   d. Confirme com o usuário em uma frase ("Manual gerado e preenchido;
      seguindo com a geração do plano.") antes de prosseguir para o
      passo 2 no mesmo run.
3. Se o manual já existe, leia-o por inteiro e siga.

### 2. Carregar documentação viva

1. Leia `docs/index.md` se existir. Caso contrário, percorra cada
   domínio base (`discovery`, `prd`, `architecture`, `ui`, `qa`,
   `project`) e liste os arquivos `.md` existentes.
2. Para cada `docs/specs/*/spec-meta.yaml`, leia metadata (use
   `read_spec_meta` de `.claude/mosk/scripts/common.sh` quando
   conveniente). Considere apenas specs com `status: active`.
3. Extraia do manual: cadência, vocabulário de status, formato de
   marcos, regras de resumo git, escopo do update file, regras de
   tratamento do comentário do usuário.

### 3. Ler atividade git

1. Determine a janela:
   - Se `docs/project/plan.md` existe:
     ```bash
     SINCE=$(date -r docs/project/plan.md +%Y-%m-%dT%H:%M:%S)
     ```
   - Caso contrário (primeira execução real): `SINCE="7 days ago"`.
2. Execute:
   ```bash
   git log --since="$SINCE" --pretty='%h %ad %an %s' --date=short --no-merges | head -n 200
   ```
3. Agrupe a saída por autor e por prefixo de spec (`^\d{3}-` no
   subject) conforme as regras do manual.

### 4. Absorver comentário do usuário

1. O comentário é anotação autoritativa para este run.
2. Vai verbatim para o `update-YYYYMMDD.md` (campo `user_comment` no
   frontmatter e seção dedicada no corpo).
3. Reflete em `plan.md` apenas quando o manual orientar (regra
   `{{USER_COMMENT_HANDLING}}`).

### 5. Decidir se `plan.md` muda

Atualize `plan.md` somente quando ao menos uma das condições for
verdadeira:

- O manual mudou desde o último run (compare timestamp ou hash).
- Surgiu novo spec ativo desde o último run.
- Marco, risco, foco ou objetivo mudou (com base no manual + docs).
- O comentário do usuário pede ajuste explícito de planejamento.

Quando nenhuma condição se aplica: **não rescreva** o conteúdo;
apenas atualize o campo `Last updated` no topo do arquivo.

Quando rescrever:

- Carregue `.claude/mosk/templates/project-plan-tmpl.md` se o arquivo
  ainda não existir.
- Preserve o bloco `<!-- custom -->…<!-- /custom -->` na íntegra.
- Substitua somente seções demarcadas
  `<!-- section:<id> -->…<!-- /section -->` que precisem mudar.
- Nunca delete seções; se uma sumir do manual, mantenha e emita warning.

### 6. Emitir update datado

1. Caminho: `docs/project/update-YYYYMMDD.md` (data UTC do run).
2. Se o arquivo já existir para hoje, **anexe** um bloco
   `## Run HH:MM UTC` ao final — nunca sobrescreva.
3. Carregue o esqueleto de
   `.claude/mosk/templates/project-update-tmpl.md` quando criar pela
   primeira vez.
4. Preencha o frontmatter:
   - `date`: timestamp UTC ISO 8601.
   - `author`: `git config user.name` (fallback: "unknown").
   - `commits_window`: ex.: `"2026-05-08T00:00:00Z..2026-05-15T12:30:00Z"`.
   - `commits_count`: total da janela.
   - `specs_touched`: lista de `spec_id`s detectados.
   - `user_comment`: uma linha (multilinha vai pro corpo).
   - `plan_changed`: `true|false`.
   - `plan_sections_changed`: lista de section ids quando aplicável.
   - `delta`: `empty` quando `commits_count == 0` AND comentário vazio;
     `standard` caso contrário.
5. Emita **sempre**, mesmo com `delta: empty` — este artefato serve
   como registro de PR e auditoria de cadência.

### 7. Atualizar `docs/index.md`

Chame `../tasks/index-docs.md` ao final para regenerar o índice. O
índice incluirá `docs/project/` como domínio base e destacará o
`plan.md` + o update mais recente.

## Rules

- **Idempotente**: mesmo input (mesmo git, mesmo manual, mesmo
  comentário) produz o mesmo output, modulo timestamps.
- **Nunca destrutivo**: sem deleção de seções em `plan.md`, sem
  overwrite de `<!-- custom -->`, sem overwrite de update já gravado.
- **Manual ausente** → fluxo de seed inline (passo 1); nunca invente
  regras de tracking sem registrar no manual.
- **Sem elicitation 1-9**: perguntas devem ser pontuais e diretas.
- **User-triggered apenas**: não invocável por pipeline escalation.
- Respeite as invariantes MOSK (Document Organization, Promotion
  Convention, Agent Roles, Escalation Policy, Spec Numbering,
  `docs/index.md`).

## Auto-invocation points

Nenhuma. Sempre disparado pelo usuário via `/mosk-pm planner …`.

## Process Output

Ao final, reporte:

1. Janela git usada e total de commits considerados.
2. Specs ativos detectados/tocados.
3. Estado de `plan.md`: `criado`, `atualizado` (com seções afetadas),
   ou `inalterado`.
4. Caminho do `update-YYYYMMDD.md` emitido e flag `delta`.
5. Warnings: manual incompleto, seção desaparecida, link quebrado em
   `docs/`, spec sem `spec-meta.yaml`.
