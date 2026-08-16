# planner

Mantenha um plano vivo e um update datado para acompanhamento de negócio. A
fonte das regras do time é `docs/discovery/project-manual.md`; a saída é para
PO, stakeholders, gestores e usuários não técnicos.

## Dependências

- `.claude/mosk/data/planner-reference.md` — paths, frontmatter e mecânica rara;
  carregue apenas as seções acionadas pelo run.
- `.claude/mosk/data/adaptive-work-contract.md` — orçamento de contexto.
- `.claude/mosk/templates/project-{manual,plan,update}-tmpl.md`.
- `.claude/mosk/scripts/common.sh` e `.claude/mosk/tasks/index-docs.md`.

## Entrada e escopo

Use o comentário livre de `$ARGUMENTS`. Resolva a branch com `get_current_branch`:

- `main|master|develop|dev` → projeto: `docs/project/`;
- outra branch com uma spec inequívoca → spec:
  `docs/specs/{id}/project/`, mais refresh proporcional de
  `docs/project/plan.md`;
- sem spec ou com ambiguidade → uma pergunta direta; não escreva antes da
  resposta.

## Perfil de trabalho

Classifique a mudança pelo contrato adaptativo. Comece pelo manual, índice,
metadata ativa e plano do escopo. Expanda para docs da spec/domínio, histórico
git e referências somente quando o perfil ou a evidência exigir. Material
técnico é insumo de tradução, nunca conteúdo predominante do plano.

## Fluxo

1. Se o manual faltar, gere-o do template, preencha o que as docs sustentarem e
   faça uma única rodada agrupada apenas para lacunas que mudem o tracking.
2. Leia o manual inteiro. Depois carregue `docs/index.md` (ou os domínios base),
   specs ativas e, no escopo spec, seus artefatos relevantes.
3. Defina a janela git desde o mtime do plano; no primeiro run use `created_at`
   da spec ou sete dias. Limite a 200 commits, priorize a spec corrente e traduza
   atividade em progresso de negócio.
4. Gere comentário objetivo de 3–8 linhas. Use o comentário do usuário como guia;
   sem ele, sintetize a evidência disponível sem pedir direção.
5. Atualize o plano somente por mudança material de manual, fase/spec ativa,
   marco, risco, foco, objetivo ou pedido explícito. Sem mudança, altere apenas
   `Last updated`. Preserve blocos `<!-- custom -->` e edite somente seções
   demarcadas.
6. No escopo spec, reflita no plano do projeto apenas o impacto daquela spec,
   sem transformar o todo em relato da feature.
7. Sempre emita `update-YYYYMMDD.md`; no segundo run do dia, anexe
   `## Run HH:MM UTC`. Nunca sobrescreva execução anterior.
8. Rode `index-docs.md` e reporte escopo, janela, specs tocadas, estado dos
   planos, update emitido, `delta` e warnings.

## Regras

- Acompanhamento em linguagem de valor; hashes ficam apenas na auditoria do
  update e detalhes técnicos pertencem à spec/arquitetura.
- Mesmo input produz o mesmo conteúdo, salvo timestamps.
- Nunca delete seções, conteúdo customizado ou update existente.
- O manual único governa projeto e specs; ausência dele não autoriza inventar
  convenções sem registrá-las.
- Planner é acionado somente pelo usuário e não participa de mudança de fase.
