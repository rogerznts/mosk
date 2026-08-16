# Referência operacional do Planner

Leia as seções acionadas por `planner.md`; o fluxo principal e as decisões de
conteúdo permanecem na task.

## Fontes e resolução

- Manual: `docs/discovery/project-manual.md`.
- Projeto: `docs/{discovery,prd,architecture,ui,qa,project}/` e metadata de
  `docs/specs/*/spec-meta.yaml` com `status: active`.
- Spec: `spec.md`, metadata e arquivos existentes em
  `{discovery,architecture,ui,stories}/`.

Em branch de spec use o resolvedor canônico de `common.sh`; não presuma igualdade
entre nome de branch e pasta. Resolva primeiro o projeto e depois a spec.

## Manual ausente

Copie `project-manual-tmpl.md`, derive placeholders apenas de evidência nas docs
e agrupe dúvidas materiais em uma rodada. Confirme em uma frase que o manual foi
gerado antes de seguir. Um manual existente é sempre lido por inteiro.

Extraia cadência, vocabulário de status, formato de marcos, regras de resumo git,
escopo do update e tratamento de comentários.

## Janela git

Use o mtime do `plan.md` atual. Sem plano, use `created_at` da spec; no projeto,
sete dias. Comando base:

```bash
git log --since="$SINCE" --pretty='%h %ad %an %s' --date=short --no-merges |
  head -n 200
```

Na spec, priorize commits cujo assunto começa pelo número ou que tocaram seu
diretório. No projeto, agrupe conforme o manual. Corpo do plano não recebe
hashes nem despejo técnico.

## Atualização dos planos

Crie planos ausentes com `project-plan-tmpl.md`. A ordem padrão é `objectives`,
`milestones`, `deliverables`, `current-focus`, `status-snapshot`, `risks` e
`open-questions`. Preserve `<!-- custom -->…<!-- /custom -->`; altere somente
blocos `<!-- section:<id> -->`. Se uma seção exigida desaparecer do manual,
mantenha-a e avise.

No escopo spec, `{{PROJECT_NAME}}` recebe título/id da spec. O refresh do projeto
altera apenas marco correspondente, status e foco afetados pela spec. Se o plano
do projeto não existir, crie-o antes.

## Update datado

Caminho: `$UPDATE_DIR/update-YYYYMMDD.md`, em UTC. Crie do
`project-update-tmpl.md`; se existir, anexe um bloco de run. Frontmatter:

- `date`, `author`, `scope`, `spec_id`;
- `commits_window`, `commits_count`, `specs_touched`;
- `user_comment`, `plan_changed`, `plan_sections_changed`;
- `delta: empty` somente quando não há commit, comentário ou mudança de plano;
  nos demais casos, `standard`.

O comentário é produzido pelo agente, em primeira pessoa do plural, pronto para
PR. O input bruto do usuário fica em `user_comment`. O update é emitido mesmo
com `delta: empty` e nunca fica sem comentário.

## Relatório final

Informe escopo/branch/spec, janela e contagem git, specs ativas/tocadas, plano
criado/atualizado/inalterado, refresh do projeto quando aplicável, update + delta
e warnings de manual, seção, link, metadata ou resolução.
