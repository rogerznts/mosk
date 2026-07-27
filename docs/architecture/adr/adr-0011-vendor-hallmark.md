---
promote: docs/architecture/adr/adr-0011-vendor-hallmark.md
promote_mode: copy
---

# ADR-0011 — Hallmark vendorizado como corpo de referência do `mosk-ui-expert`

- Status: aceito
- Data: 2026-07-26
- Autor: spec `008-feature-ui-expert-hallmark`
- Contexto: dar ao Tiago variedade **estrutural**, não só acabamento visual, sem criar dependência de rede em tempo de execução.

## Contexto

O `mosk-ui-expert` carrega seis tasks `webdesign-*.md` derivadas do sistema
[taste](https://github.com/Leonxlnx/taste-skill). Elas cobrem bem o *acabamento*:
tipografia, paleta, estados, guardrails de performance, lista de "AI tells". O que
elas não cobrem é o **ritmo da página**. Três estilos fixos e uma auditoria não
impedem que dois briefs distintos produzam a mesma sequência hero → 3 features →
CTA → footer. O tell mais forte de UI gerada por LLM não é a fonte errada: é a
repetição da forma.

O [Hallmark](https://github.com/Nutlope/hallmark) (Nutlope / Together AI, MIT,
v1.1.0) ataca exatamente esse eixo: 21 macroestruturas nomeadas, 50 arquétipos de
componente (14 navs, 9 heroes, 8 footers), 20 temas com tokens OKLCH, 4 gêneros, 58
gates de slop-test, e uma regra de diversificação com memória por projeto
(`.hallmark/log.json`) que proíbe repetir macroestrutura, nav ou footer entre
execuções. São 106 arquivos / 675 KB de material de referência.

Três decisões precisavam ser tomadas juntas.

## Decisão

**1. Vendorizar, não referenciar.** O corpo do Hallmark entra em
`mosk/.claude/mosk/data/hallmark/` e viaja no `npx degit` junto com o resto do
template.

**2. Ancorar em `data/`, não numa pasta nova.** `.claude/mosk/data/` já é, no
contrato do MOSK, o lugar de material de referência estático lido por tasks
(`elicitation-methods.md`, `test-levels-framework.md`, …). O Hallmark é a mesma
categoria de coisa, em outra escala. Não se cria `references/`.

**3. Expor por uma task roteadora, não por skill própria.** `tasks/hallmark.md`
implementa os quatro verbos e entra com uma linha no `## Task mapping` do
`ui-expert.md`. O gatilho de linguagem natural (`hallmark audit x.tsx` escrito cru)
vem da `description` da skill, que o `sync-agents-skills.sh` deriva da primeira linha
da `## Mission` do agente.

**4. Coexistir com as tasks `webdesign-*`.** Nada é removido. Verbo com prefixo
(`hallmark redesign X`) roda Hallmark; verbo nu (`redesign X`) dispara uma pergunta
de desambiguação de uma linha.

**5. Precedência declarada.** Enquanto a task está carregada, as regras do Hallmark
vencem a `## Core design philosophy` do Tiago. O conflito é real e não acidental: o
Tiago bane serifas e `Inter`; o Hallmark constrói seis dos vinte temas sobre serifas
de display e usa Inter Tight no gênero `modern-minimal`. A intenção anti-slop é a
mesma; a codificação é diferente.

## Consequências

**Custo aceito.** O template vai de 175 para 285 arquivos e de 1,5 MB para ~2,2 MB —
cerca de +45 % no `degit`, pago por todo consumidor, inclusive quem nunca usa o
Tiago. A alternativa (baixar sob demanda) foi descartada: criaria dependência de rede
em tempo de execução num toolkit que hoje funciona offline, e tornaria o
comportamento do agente dependente da disponibilidade do GitHub.

**O fork precisa de manutenção mecânica.** Vendorizar cria um fork: além da cópia,
há cinco adequações (rename do `SKILL.md`, `tokens.css` trazido de fora da skill,
links externos virando permalinks, bloco `## MOSK integration`, e edições in-place
onde o upstream hardcoda um `design.md` na raiz). Uma cópia manual do upstream apaga
tudo isso silenciosamente — o modo de falha clássico do vendoring.

A mitigação é `scripts/sync-hallmark.sh`, que **não** carrega uma lista de patches
escrita à mão. Ele baixa o upstream no ref pinado, tira um `git diff --no-index`
contra o vendor atual — esse diff *é* o conjunto de adequações, por construção
sempre atualizado — baixa o ref novo e replica. Conflito vira `.rej` numa área de
trabalho preservada e o vendor não é tocado. Adequação nova não exige tocar no
script.

**Um bug latente veio junto, e foi consertado aqui.** Precisar de uma description
com gatilhos expôs que `sync-agents-skills.sh` a derivava da primeira linha da
`## Mission` (`head -1`). Como as 11 descriptions do template são curadas em pt-BR e
as Missions são prosa em inglês, **qualquer** execução do sync num projeto
consumidor as trocava por prosa truncada — silenciosamente, sem erro. Pior: o
gerador reescrevia o `SKILL.md` inteiro a partir do boilerplate, apagando o
`argument-hint:` e o corpo autoral do `mosk-orq`.

A causa é conceitual: `description` e `Mission` são coisas diferentes. A primeira é
string de **roteamento** (quando me carregar), a segunda é **prosa da persona** (o
que eu faço depois de carregado). Derivar uma da outra é o erro.

A correção separa as duas. Cada agente declara a sua na primeira linha:

```md
<!-- skill-description: UI: interfaces premium, redesign, Hallmark (audit · redesign · study). -->
```

Ordem de resolução: `skill-description` → wrapper existente → CC agent → Mission →
genérico. E o sync passou a **editar em vez de regenerar**: num wrapper ou CC agent
que já existe, só a linha `description:` é reescrita; front-matter extra e corpo
autoral sobrevivem. Isso também liberou a Mission do `ui-expert` para voltar ao wrap
normal. De quebra, `link-codex-skills.sh` tinha um `\(.*\)` guloso que deixava uma
aspa sobrando em quase toda entrada do `AGENTS.md` — corrigido.

Verificado num consumidor recém-instalado: antes, um `sync` degradava 10
descriptions; agora, zero, e o `argument-hint` do Mauro sobrevive.

**Licença.** MIT. `LICENSE` preservado verbatim, atribuição no cabeçalho do
`hallmark.md` e procedência completa no `VENDOR.md`.

**Estado de máquina fica na raiz.** `.hallmark/log.json` e `.hallmark/preflight.json`
não migram para `docs/` — são cache e log, análogos a `.claude/`, e a memória de
diversificação depende deles.

## Alternativas descartadas

- **Skill standalone `/mosk-hallmark`** — resolveria o gatilho de forma mais limpa,
  mas quebra o padrão "skill = wrapper fino de agente" e exige entrada na allowlist
  `standalone_skills` do `sync-agents-skills.sh`, sob pena de `rm -rf` no `--clean`.
- **Criar `mosk/.claude/agents/mosk-ui-expert.md`** para controlar a description via
  CC agent (o script prioriza essa fonte) — introduziria no template uma pasta que
  hoje só existe no espelho local.
- **Substituir as tasks `webdesign-*`** pelo Hallmark — é quebra para instalações
  existentes, e o taste cobre acabamento em ângulos que o Hallmark não cobre.
- **Traduzir os references para pt-BR** — 675 KB, inviabiliza o re-sync e introduz
  erro de tradução em regras normativas. A saída ao usuário já sai em pt-BR pela
  seção `## Idioma` do agente.
