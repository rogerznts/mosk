# advanced-elicitation

Aprofunde um conteúdo quando o usuário pedir explicitamente exploração,
crítica ou refinamento avançado. Esta task nunca é ativada por flags do template
e não faz parte do happy path de criação documental.

## Dependências

- `.claude/mosk/data/elicitation-methods.md` — catálogo de métodos; carregue
  apenas o método selecionado, nunca a lista inteira.

## Entrada

- conteúdo ou decisão a explorar;
- objetivo informado pelo usuário;
- método nomeado, quando houver.

Se o objetivo estiver claro e nenhum método tiver sido escolhido, selecione o
método mais adequado em `.claude/mosk/data/elicitation-methods.md` e diga em uma
linha qual foi usado. Se a escolha do método mudar materialmente a saída, faça
uma pergunta direta; não apresente um menu numérico obrigatório.

## Execução

1. Delimite o trecho e a decisão que serão aprofundados.
2. Carregue apenas o método escolhido e as referências diretamente necessárias.
3. Aplique o método de forma concisa, distinguindo evidência, hipótese, risco e
   alternativa.
4. Entregue insights acionáveis e uma proposta de incorporação.
5. Se o usuário pedir outra perspectiva, repita com o método solicitado. Caso
   contrário, encerre e retorne ao fluxo chamador sem nova seleção obrigatória.

`custom_elicitation` do template pode sugerir um método quando a solicitação
explícita do usuário corresponder ao tema; a presença desse campo, sozinha, não
ativa esta task.

## Limites

- Não transforme a revisão em aprovação seção a seção.
- Não invente método nem carregue o catálogo inteiro no prompt principal.
- Não substitua uma dúvida material por brainstorming: devolva uma pergunta
  objetiva ao fluxo chamador.
- Não autorize ação irreversível ou mudança de escopo; preserve a pausa humana.
