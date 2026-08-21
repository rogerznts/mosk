# Contrato de saída — como um agente MOSK escreve para um humano

<!-- contract-normative:start -->

Fonte única do **formato de comunicação** dos agentes MOSK. Vale para toda saída
que um humano vai ler: achados de gate, relatórios de segurança, avaliações de
risco e NFR, rastreabilidade, análises de consistência.

## O problema que este contrato resolve

Um agente escreveu isto:

> | QA-001-1 | high | SC-004 e SR-001 não satisfeitos — 10 de 12 arquivos sem estreitar por collection |

Para agir, o leitor precisa abrir `spec.md`, achar SC-004, achar SR-001, e só
então descobrir se aquilo importa. E `SR-001` sequer existia no projeto — o
agente inventou o prefixo naquela sessão.

Um identificador é um **ponteiro**. Ponteiro sem o valor ao lado transfere
trabalho de quem escreve para quem lê, e quem escreve é justamente quem acabou
de olhar o artefato. O custo é assimétrico: uma linha a mais na escrita poupa
uma busca na leitura, toda vez.

---

## 1. Vocabulário canônico de identificadores

**Não invente prefixos.** Se algo não couber na tabela, use `QA-` e diga no
título o que é.

### Nascem no planejamento — o que foi combinado

| Prefixo | Significa | Nasce em |
|---|---|---|
| `FR-###` | requisito funcional | `spec.md` → Functional Requirements |
| `NFR-###` | requisito não-funcional | `spec.md` → Non-Functional Requirements |
| `SC-###` | critério de sucesso mensurável | `spec.md` → Measurable Outcomes |
| `US-#` | user story | épico / PRD |
| `AC-#` | critério de aceite | arquivo da story |
| `T###` | tarefa de implementação | `tasks.md` |
| `ADR-####` | decisão de arquitetura | `docs/architecture/adr/` |

### Nascem na avaliação — o que se descobriu

| Prefixo | Significa | Nasce em |
|---|---|---|
| `QA-#` | achado do quality gate | `gate.yaml` (task `qa-gate`) |
| `SEC-#` | achado de segurança | relatório de `security-review` |
| `RISK-<CAT>-#` | risco identificado | task `assess-risk`; `CAT` ∈ `SEC` `PERF` `DATA` `BUS` `OPS` `TECH` |

> **`SEC-` era ambíguo e deixou de ser.** Ele significava *achado de segurança*
> no gate e *risco de categoria segurança* no `assess-risk` — duas coisas com
> ciclos de vida diferentes sob o mesmo nome. Risco agora é sempre
> `RISK-SEC-001`; achado é sempre `SEC-001`.

**Ids de achado são estáveis dentro da spec.** `QA-1` na segunda volta do gate é
o mesmo defeito que `QA-1` na primeira. Renumerar a cada rodada destrói a única
coisa que torna a série comparável. Achado resolvido não é reciclado: o número
morre com ele.

---

## 2. As quatro regras de citação

### R1 — Primeira menção carrega o significado

Todo id ganha a sua glossa na primeira vez que aparece na resposta:

```
SC-004 — "toda busca deve estreitar por collection"
```

Aspas = citação literal do artefato. Sem aspas = paráfrase de até ~12 palavras.
Menções seguintes no mesmo bloco podem ser secas.

**Vale para todo id, não só para os de spec.** `ADR-0021`, `T014`, `QA-2`,
`SEC-001`, `Q7`, `R1`, `D3` — a regra é a mesma. O teste é simples: se a pessoa
precisa abrir outro arquivo para entender a frase, a glossa faltou.

> ~~"o `SEC-001` foi corrigido e o `FR-009` continua atendido"~~
> **"o SEC-001 — guardrail contornável por sete caminhos — foi corrigido, e o
> FR-009 — nenhuma regra sai antes do equivalente declarativo — continua
> atendido"**

Isto é a regra mais violada do contrato, e o motivo é sempre o mesmo: quem
escreve acabou de ler o artefato e o id lhe parece autoexplicativo. Para quem
lê, não é.

### R2 — Id nunca é sujeito de uma afirmação

O leitor tem de entender a frase sem sair dela.

- ❌ `SC-004 e SR-001 não satisfeitos`
- ✅ `A busca não estreita por coleção — contraria SC-004`

### R3 — Caminho diz o que há lá

- ❌ `spec.md:174–181`
- ✅ `spec.md:174–181 (seção "Medidas de sucesso")`

### R4 — Título se sustenta sozinho

Quem lê só os títulos tem de sair sabendo o que está errado. Se o título só faz
sentido depois de ler o corpo, ele ainda não é um título.

- ❌ `QA-2 · Problema no SC-002`
- ✅ `QA-2 · Critério nunca verificado`

---

## 3. Formato do achado

Um achado é um **bloco com título**, nunca uma linha de tabela — uma célula não
comporta a afirmação e a glossa ao mesmo tempo, e foi exatamente essa compressão
que produziu o exemplo do topo.

```markdown
### QA-1 · alta · Busca não estreita por coleção

10 de 12 arquivos ignoram o filtro de collection.

- Contraria: SC-004 — "toda busca deve estreitar por collection" (spec.md:112)
- Também: SR-001, a mesma exigência do lado do requisito — corrigir um sem o
  outro deixa a contradição pela metade
- Custo: reescrita de texto, não de código
```

**Cabeçalho:** `### <id> · <severidade> · <título em linguagem simples>`

**Corpo:** um parágrafo com a evidência observada. Prefira o número concreto
("10 de 12 arquivos", "zero chamadas `fetch(`") à qualificação vaga
("cobertura insuficiente").

**Marcadores, quando houver o que dizer — nesta ordem, todos opcionais:**

| Marcador | Para quê |
|---|---|
| `Contraria:` | o critério ou requisito violado, com a glossa |
| `Também:` | ids irmãos e **por que** estão ligados |
| `Onde:` | `arquivo:linha` com o que há naquele ponto |
| `Correção:` | o conserto proposto, em uma linha |
| `Custo:` | a natureza do conserto — texto, código ou arquitetura |

Um marcador vazio é ruído: omita em vez de escrever "n/a". Esta é a lista
inteira: task que precise de outro rótulo o declara na própria task, em vez de
publicar um vocabulário paralelo.

### Severidade

O **valor no YAML** é sempre `low` \| `medium` \| `high` — schema não se
traduz. O **texto para o humano** vai no idioma de comunicação do projeto
(`baixa` \| `média` \| `alta` em pt-BR).

---

## 4. Quando a tabela ainda serve

Para **inventário**, não para achado: matriz de risco, cobertura de
rastreabilidade, lista de arquivos. O critério é se cada linha precisa de
argumento. Precisa → bloco. Não precisa → tabela.

Mesmo em tabela, R1 continua valendo: a coluna de id não dispensa a glossa em
algum lugar visível da mesma tela.

---

## 5. Resumo antes do detalhe

Toda saída com mais de três achados abre com uma linha de veredito e uma
contagem, antes dos blocos:

```markdown
**Gate: FAIL · score 20** — 6 achados: 2 altos, 4 médios.
Cinco dos seis são reescrita de texto; nenhum pede decisão de arquitetura.
```

Isso existe para que quem só lê a primeira linha saia com a informação certa.

<!-- contract-normative:end -->

---

## 6. Fonte única

Tudo acima, entre os comentários `contract-normative:start` e
`contract-normative:end`, é a redação normativa deste contrato. Task, agente ou
skill que precise dela **referencia este arquivo pelo caminho**; copiar o texto
cria uma segunda fonte que passa a divergir em silêncio.

`validate.sh single-source` falha quando três ou mais linhas normativas — as de 30
caracteres ou mais, comparadas com espaçamento normalizado — reaparecem
literalmente em outro arquivo do produto. Mencionar, linkar ou citar uma linha
isolada continua correto e não dispara nada.
