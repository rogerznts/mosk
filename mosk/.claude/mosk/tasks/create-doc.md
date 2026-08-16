# create-doc

Crie um documento a partir de um template YAML sem transformar cada seção em
uma etapa de aprovação.

## Entrada

- pedido do usuário e contexto disponível;
- template informado pela task chamadora ou pelo usuário;
- destino definido pela task/template.

Se o template não estiver definido, resolva-o pela intenção. Só apresente os
templates compatíveis quando mais de um deles mudar materialmente o resultado.

## Contrato direto

1. Leia `.claude/mosk/data/adaptive-work-contract.md` e classifique a
   ambiguidade sem duplicar a política neste arquivo.
2. Inspecione o pedido, as regras do projeto e as referências diretas.
3. Reúna todas as decisões materialmente bloqueantes antes de perguntar.
   - pedido claro ou lacuna resolvível por default seguro: zero perguntas;
   - ambiguidade material: uma única rodada agrupada;
   - depois da resposta, registre defaults restantes e prossiga;
   - se ainda faltar uma decisão que altere escopo, arquitetura, dados ou efeito
     externo, pare e reporte a dúvida real em vez de iniciar outra rodada.
4. Gere o documento completo diretamente. Não peça confirmação entre seções
   reversíveis e não apresente menu numerado.
5. Grave no destino canônico. Ao sobrescrever, preserve blocos
   `<!-- custom -->...<!-- /custom -->` existentes.
6. Informe arquivo criado, decisões relevantes e próximo passo.

## Semântica do template

- `condition`: omita a seção quando a condição não se aplicar.
- `owner`, `editors`, `readonly`: respeite ownership sem inserir avisos
  operacionais no corpo do documento, salvo quando isso fizer parte do produto.
- `elicit: true`, `elicit: optional` ou `review: optional`: são sinais legados
  de que a seção pode se beneficiar de revisão; nunca são hard stop.
- `custom_elicitation`: catálogo opcional, carregado somente quando o usuário
  pedir exploração avançada.

## Elicitação avançada opt-in

Execute `.claude/mosk/tasks/advanced-elicitation.md` somente quando o usuário
pedir explicitamente exploração, crítica ou refinamento avançado. A conclusão
retorna ao documento sem menu obrigatório e sem reiniciar a rodada de
clarificação do happy path.

## Limites humanos

- Não invente informação cujo único detentor é o usuário; inclua a falta na
  rodada agrupada quando ela for material e marque assumptions quando não for.
- Pare antes de ação irreversível, mudança material de escopo ou efeito externo
  não autorizado, com contexto e uma pergunta objetiva.
- Não trate escrita reversível do artefato como motivo para confirmação
  intermediária.
