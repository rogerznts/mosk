# create-deep-research-prompt

Transforme um objetivo de investigação em um prompt executável, com perguntas,
métodos, evidência esperada e formato de entrega.

## Entrada

Use brief, brainstorming, pesquisa anterior ou pergunta do usuário como fonte.
Infira o foco quando estiver claro. Se recorte, decisão ou restrição puderem
mudar materialmente a investigação, concentre tudo em uma única rodada
agrupada; não apresente catálogo numerado de tipos de pesquisa.

## Processo

1. Resuma objetivo, decisão que a pesquisa informará e limites conhecidos.
2. Separe perguntas primárias obrigatórias das secundárias.
3. Defina fontes, recência, critérios de credibilidade e método de análise.
4. Declare entregáveis, incertezas, critérios de sucesso e restrições.
5. Entregue o prompt completo diretamente e incorpore feedback objetivo sem
   reiniciar uma entrevista.

Use `.claude/mosk/tasks/advanced-elicitation.md` somente se o usuário pedir
explicitamente exploração de alternativas ou crítica avançada.

## Formato de saída

```markdown
## Objetivo
## Contexto e limites
## Perguntas primárias
## Perguntas secundárias
## Fontes e método
## Entregáveis esperados
## Critérios de sucesso
## Assumptions e incertezas
```

O prompt deve ser específico o suficiente para execução por pesquisador humano
ou assistente com ferramentas, sem inventar acesso a fontes, prazo ou dados.
