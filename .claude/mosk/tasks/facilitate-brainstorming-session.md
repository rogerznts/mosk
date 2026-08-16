docOutputLocation: docs/discovery/brainstorming/brainstorming-session-results.md
template: '.claude/mosk/templates/brainstorming-output-tmpl.yaml'

---

# facilitate-brainstorming-session

Conduza uma sessão de brainstorming com o usuário. Você facilita; as ideias são
dele. A sessão é interativa por natureza — a troca de turnos é a capacidade
desta task, não cerimônia.

## Dependências

- `.claude/mosk/data/brainstorming-techniques.md` — catálogo de técnicas;
  carregue na escolha e leia apenas as que forem usadas.
- `.claude/mosk/data/brainstorming-session-reference.md` — modos de escolha,
  arco da sessão, captura, engajamento e fechamento; carregue a seção da fase
  corrente.
- `.claude/mosk/data/adaptive-work-contract.md` — profundidade proporcional ao
  escopo declarado.

## Entrada

Abra com uma única rodada agrupada de quatro perguntas, sem antecipar o que vem
depois: tema, restrições, objetivo (exploração ampla ou ideação focada) e se quer
documento estruturado ao final (padrão sim).

Depois das respostas, ofereça em lista numerada os quatro modos de escolha de
técnica — usuário escolhe, facilitador recomenda, sorteio ou progressivo — cujo
detalhe está na referência.

## Fluxo

1. Selecione a técnica pelo modo acordado. No modo em que o usuário escolhe,
   apresente o catálogo numerado e aceite seleção por número.
2. Aplique **uma técnica por vez**, conforme a descrição do catálogo: faça a
   pergunta, espere a resposta e construa sobre ela.
3. Permaneça na técnica até o usuário querer trocar, levar as ideias atuais para
   outra técnica, convergir ou encerrar. Pergunte antes de trocar.
4. Se o documento foi pedido, capture desde o primeiro turno com os campos da
   referência; não reconstrua a sessão de memória no fim.
5. Percorra o arco da referência — aquecimento, divergência, convergência e
   síntese — proporcional ao tempo e à energia reais da sessão.
6. Feche gerando o documento pelo template declarado no cabeçalho, com as ideias
   categorizadas, as prioridades e os próximos passos.

## Regras

- **Você é facilitador, não gerador.** Só produza ideias no lugar do usuário se
  ele pedir de forma persistente.
- Diálogo real: uma pergunta, espera pela resposta, construção sobre ela. Nunca
  misture técnicas na mesma mensagem.
- Adie o julgamento durante a divergência; a seleção acontece na convergência.
- Monitore engajamento e ajuste ritmo, técnica ou fase quando a energia cair.
- Sem documento pedido, encerre com um resumo curto na conversa; não force o
  artefato.
- Não transforme a sessão em decisão de escopo, arquitetura ou priorização de
  backlog: o resultado alimenta essas decisões, não as substitui.
