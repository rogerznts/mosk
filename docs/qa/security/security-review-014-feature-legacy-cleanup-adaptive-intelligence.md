# Security review — 014-feature-legacy-cleanup-adaptive-intelligence

**SECURITY: PASS** — 4 achados: 0 altos, 0 médios, 4 baixos.
**`SEC-1`, `SEC-2` e `SEC-3` estão os três fechados** e revalidados de forma
independente. `SEC-4` é o resíduo final, registrado e **aceito sem correção
nesta entrega**: a prova de literalidade passou a ser a existência do arquivo,
e reabrir o bypass exige commitar um arquivo literalmente chamado `*` — dois
artefatos deliberados e berrantes num diff. Não alcança a barra de exploração
da task. Nenhum dos quatro é caminho de execução, escrita ou escalonamento a
partir de entrada externa; os quatro são perda silenciosa de alcance de um
check bloqueante.

- Revisor: Heitor (`/mosk-security`), revisão independente (T059)
- Diff: `94e97e674a78e3a13b98a455672195632b12cd60...HEAD`
- Data: 2026-08-15 — revisão inicial e revalidações de `SEC-1`, `SEC-2` e `SEC-3`
- Perfil adaptativo desta revisão: `elevated` · score 5 · piso `elevated`
  (`floor:requested_elevated`) · contexto `elevated` · validação `independent`
  · especialistas `["qa"]` · `human_pause: false`

  Sinais observados: `scope=public_contract` (a spec publica uma CLI nova,
  `classify-change.sh`, mais um JSON schema que vira contrato de saída),
  `reversibility=easy` (só edição de arquivo, nada implantado),
  `sensitive_surface=paths_state` (scripts resolvem caminhos, criam `mktemp -d`
  e mantêm uma allowlist que porta um check bloqueante — não há credencial,
  PII nem cripto no diff), `evidence=strong` (li os scripts e rodei fixtures
  adversariais próprias), `ambiguity=clear`. O piso foi elevado por a revisão
  ter sido pedida explicitamente. Não houve gatilho de reclassificação: o
  rastreamento de fluxo de dados não revelou superfície mais sensível que a
  declarada.

---

## Achados

### SEC-1 · baixa · Um asterisco a menos na allowlist desliga a auditoria de legado inteira

**Status: fechado em 2026-08-15**, revalidado de forma independente. O registro
do defeito original fica abaixo; a evidência do fechamento está em
"Revalidação da correção de SEC-1".

`audit-legacy-surface.sh` tenta recusar padrões de allowlist abrangentes, mas o
guard compara **duas strings literais** em vez de avaliar a abrangência do glob.
Um `pattern` igual a `.claude/*` passa nas duas validações — começa com
`.claude/`, e não é nenhuma das duas literais rejeitadas — e, no `case` do
shell, `*` casa também com `/`. O efeito é que uma única linha na allowlist
allowlista **todo arquivo sob `.claude/`** e a varredura de referências legadas
para de reportar qualquer coisa, em silêncio e com `rc=0`.

Reproduzido sobre uma cópia da árvore real (`--root` em `mktemp -d`), com uma
referência legada plantada em `.claude/agents/leak-note.md`:

| `path_pattern` na allowlist | Resultado |
|---|---|
| allowlist real do template | `falha  .claude/agents/leak-note.md:2 :: referência legada operacional fora da allowlist` |
| `.claude/**` | `falha  pattern inseguro na allowlist: .claude/**` — guard funciona |
| `.claude/*` | **nenhuma violação reportada, nenhum aviso de pattern amplo** |
| `.claude/mosk/**` | violação ainda reportada (escopo estreito o bastante) |

O impacto é de integridade de gate, não de exploração remota: o auditor roda
como verificação **bloqueante** dentro do `doctor.sh`
(`run_check "superfície-legada"`), e é o `doctor.sh` que sustenta a afirmação de
"toolkit íntegro" antes de publicar uma versão. Um check que passa a retornar
sempre íntegro é pior que um check ausente, porque continua sendo citado como
evidência. Não há atacante externo neste modelo de ameaça — o risco é a perda
silenciosa de um controle por uma linha de dado plausível, escrita de boa-fé por
quem quis liberar um diretório específico.

- Onde: `mosk/.claude/mosk/scripts/audit-legacy-surface.sh:431-438` — o bloco
  que valida cada `path_pattern` da allowlist; as linhas 436-438 são a
  comparação literal com `.claude/**` e `docs/**`
- Também: `mosk/.claude/mosk/scripts/audit-legacy-surface.sh:413-422`
  (`allow_path`), onde o `case "$candidate" in $pattern)` aplica o glob — é lá
  que `*` atravessa `/`. A expansão é segura (o valor de `$pattern` não é
  re-escaneado para substituição de comando); o problema é só de abrangência
- Onde: `mosk/.claude/mosk/scripts/doctor.sh:192` — o ponto que torna o auditor
  bloqueante
- Correção: recusar qualquer pattern cuja parte literal antes do primeiro `*`
  seja mais rasa que um diretório concreto — por exemplo, exigir ao menos três
  segmentos literais (`.claude/mosk/data/...`) antes do primeiro curinga, em vez
  de comparar com uma lista de duas strings
- Custo: código — cinco a dez linhas no bloco de validação, mais uma fixture em
  `selftest-toolkit.sh` que prove que `.claude/*` falha
- Confiança: 0.95 no comportamento (reproduzido); o achado é `baixa` porque
  exige commit no repo e não abre nenhuma capacidade nova a quem não a tenha

### SEC-2 · baixa · A lista de superfície operacional esquece `data/`, o maior diretório do produto

**Status: fechado em 2026-08-15**, revalidado de forma independente. O registro
do defeito fica abaixo; a evidência do fechamento está em "Revalidação da
correção de SEC-2".

A segunda regra da correção de `SEC-1` — recusar curinga cujo prefixo literal
caia sob superfície operacional ativa — é uma **enumeração de sete diretórios**,
e enumeração tem o defeito de toda enumeração: o que ficou de fora passa. Sob
`.claude/mosk/` existem sete diretórios; a lista cita cinco (`tasks/`,
`scripts/`, `templates/`, `checklists/`, `utils/`) e omite `data/` e `schemas/`.

`data/` não é resíduo: são **126 arquivos**, o maior diretório sob `.claude/` —
mais que `templates/` (53) e `tasks/` (47) somados —, e é onde moram os três
contratos canônicos que a própria spec 014 criou ou consolidou
(`output-contract.md`, `adaptive-work-contract.md`, `qa-evidence-contract.md`),
além do catálogo `task-dispositions.tsv` e da própria allowlist. As regras do
projeto descrevem `data/` como "static reference material read by tasks" — é
superfície distribuível lida em runtime, exatamente o que a regra quer proteger.

Como o prefixo `.claude/mosk/data/` tem profundidade 3, ele passa na primeira
regra; como não está na lista da segunda, passa nela também. Reproduzido sobre
uma cópia da árvore real com uma referência legada plantada em cinco
diretórios distintos:

| `path_pattern` | Recusa de pattern | Legados ainda reportados |
|---|---|---|
| `.claude/*` | sim (`pattern amplo`) | — |
| `.claude/mosk/tasks/*` | sim (`superfície operacional ativa`) | 5 de 5 |
| `.claude/mosk/checklists/*` | sim | 4 de 5 (só a própria plantada some) |
| **`.claude/mosk/data/*`** | **não** | **4 de 5 — a de `data/` some calada** |
| **`.claude/mosk/schemas/*`** | **não** | **4 de 5** |
| `.claude/mosk/data/hallmark/upstream/**` | não (correto) | 5 de 5 |

O impacto é menor que o de `SEC-1`: a varredura não é desligada por inteiro, só
perde um diretório. Mas é o diretório com mais arquivos e com os contratos
normativos, e a supressão continua sendo silenciosa — `rc=0`, sem aviso.

- Onde: `mosk/.claude/mosk/scripts/audit-legacy-surface.sh:451-457` — a lista
  `tasks/|scripts/|templates/|checklists/|utils/|agents/|skills/`
- Também: `mosk/.claude/mosk/scripts/audit-legacy-surface.sh:443-446` — a regra
  de profundidade, que sozinha aprova qualquer prefixo com três barras e por
  isso depende inteiramente da lista para separar produto de arquivo histórico
- Correção: inverter a lista. Em vez de enumerar o que é operacional, enumerar
  o que é **permitido** ter curinga — hoje só `.claude/mosk/data/hallmark/` e
  `docs/specs/archive/` — e recusar o resto. Uma allowlist que existe para
  licença e material arquivado tem um conjunto legítimo pequeno e conhecido;
  descrevê-lo diretamente elimina a classe de omissão em vez de tapar mais um
  caso. Nota lateral: com a inversão, `.claude/agents/*` e `.claude/skills/*`
  saem da lista — hoje são redundantes, já recusados pela profundidade 2
- Custo: código — a lista já existe, muda de polaridade; mais duas fixtures em
  `selftest-toolkit.sh` (`.claude/mosk/data/*` e `.claude/mosk/schemas/*`)
- Confiança: 0.95 no comportamento (reproduzido); `baixa` pelo mesmo motivo de
  `SEC-1` — exige commit no repo e não concede capacidade nova a ninguém

### SEC-3 · baixa · O conjunto fechado de curingas depende de uma lista aberta de três caracteres

**Status: fechado em 2026-08-15**, revalidado de forma independente. O registro
do defeito fica abaixo; a evidência do fechamento está em "Revalidação da
correção de SEC-3".

A inversão de polaridade fecha o conjunto de **prefixos** permitidos, mas o
gatilho que decide *se um pattern é curinga* continua sendo uma enumeração de
caracteres: `case "$pattern" in *'*'*|*'?'*|*'['*)`. Um pattern que o shell
expande como glob sem conter nenhum dos três nunca entra no bloco, e por isso
nunca é confrontado com o conjunto fechado. É a mesma forma que a inversão
eliminou um nível acima — enumerar o que é perigoso em vez do que é permitido —
sobrevivendo na camada de detecção.

O caso concreto é o glob estendido do bash: `@(…)` e `!(…)` são compostos só de
`@`/`!`, parênteses e `|`. Com uma allowlist contendo `.claude/!(zzz)`, sobre
uma cópia da árvore real com duas referências legadas plantadas em arquivos que
já constam do catálogo:

| Ambiente | `--json` | Legados reportados |
|---|---|---|
| padrão (extglob off) | `{"ok":false,…,"failures":2}` · `rc=1` | 2 de 2 |
| `BASHOPTS=extglob` | `{"ok":true,…,"failures":0}` · **`rc=0`** | **0 de 2** |
| `zsh -o KSH_GLOB` executando o script | `{"ok":false,…,"failures":2}` · `rc=1` | 2 de 2 |

Sob `BASHOPTS=extglob` o resultado é exatamente a forma de `SEC-1`: `ok:true`,
`rc=0`, varredura inteira suprimida, sem uma linha de aviso — e o pattern não é
recusado, porque o detector nunca disparou. `BASHOPTS` é lido pelo bash na
inicialização, então basta a variável estar exportada no ambiente de quem roda o
`doctor.sh`.

**Este achado não alcança a barra de exploração da task, e digo isso
explicitamente:** exige uma variável de ambiente que nada no MOSK configura
**mais** uma linha de allowlist com sintaxe que ninguém escreve por acidente —
`.claude/!(zzz)` não é o vizinho plausível de `.claude/*`. Registro porque a
invariante declarada pela correção é "curinga é declarado por inclusão", e sob
uma configuração suportada do bash ela não se sustenta; a decisão de fechar ou
aceitar formalmente é sua.

- Onde: `mosk/.claude/mosk/scripts/audit-legacy-surface.sh:459-460` — o
  `case "$pattern" in *'*'*|*'?'*|*'['*)` que porteia o bloco inteiro
- Correção: tirar o gatilho da equação em vez de somar caracteres à lista.
  Exigir que **todo** pattern seja ou um caminho exato existente sob `$ROOT`, ou
  um pattern cujo prefixo literal caia nos dois roots permitidos. `.claude/!(zzz)`
  não é arquivo existente e não está sob os roots, então cai pelas duas pontas,
  com ou sem extglob — e a regra deixa de depender de prever a sintaxe de glob
  de cada shell
- Custo: código — troca o `case` de gatilho por um `[ -e "$ROOT/$pattern" ]` na
  primeira perna; mais uma fixture com `BASHOPTS=extglob` no `selftest-toolkit.sh`
- Confiança: 0.95 no comportamento (reproduzido nos três ambientes); `baixa`
  pela dupla precondição descrita acima

### SEC-4 · baixa · Existir no disco virou prova de que o pattern é literal — e um arquivo chamado `*` desfaz isso

> **Aceito sem correção nesta entrega**, por decisão registrada do time lead.
> Não alcança a barra de exploração da task: severidade `baixa` e exige commit
> no repositório. Fica documentado para a próxima vez que este arquivo for
> tocado.

A correção de `SEC-3` troca a pergunta "isto parece um curinga?" por "isto é um
caminho exato existente?" — e essa troca é o que fecha a classe do extglob, de
forma correta. O efeito colateral é que **`[ -e "$ROOT/$pattern" ]` prova
existência, não literalidade**, e as duas coisas só coincidem enquanto nenhum
nome de arquivo contiver metacaractere de glob. Um arquivo literalmente chamado
`*` faz o pattern `.claude/*` passar pela primeira perna, nunca chegar ao
confronto com os dois roots, e voltar a casar a árvore inteira em `allow_path`.

Reproduzido sobre uma cópia da árvore real com três referências legadas
plantadas em arquivos já catalogados:

| Cenário | `--json` | Legados reportados |
|---|---|---|
| allowlist real (linha de base) | `{"ok":false,…,"failures":3}` · `rc=1` | 3 de 3 |
| `.claude/*` sozinho | `{"ok":false,…,"failures":1}` · `rc=1` | recusado, alto e claro |
| `.claude/*` **+ arquivo `.claude/*`** | `{"ok":true,…,"failures":0}` · **`rc=0`** | **0 de 3, "íntegro"** |

A terceira linha é a forma de `SEC-1` de volta por inteiro: `ok:true`, `rc=0`,
varredura desligada, sem uma linha de aviso.

O que segura o achado em `baixa` é o custo da precondição. Não é uma linha de
dado plausível como em `SEC-1` e `SEC-2`: é preciso **commitar um arquivo cujo
nome é um único asterisco**, que aparece no `git status`, no diff e em qualquer
`ls`, junto com a linha de allowlist que o explora. Nenhum dos dois é escrito
por acidente, e quem consegue commitar os dois já tem a chave da casa.

Vale registrar que a variante inofensiva **existe hoje no template**: o
`payload-starter` traz diretórios de rota do Next.js com colchetes no nome —
`templates/payload-starter/src/app/(payload)/api/[...slug]` e
`.../admin/[[...segments]]`. Um pattern apontando para eles passa por `-e` e é
aceito, e no `case` o `[...slug]` vira classe de caracteres que casa **um**
caractere a mais. Sobre-casamento de um caractere, sem alcance. Nenhum arquivo
do template tem `*` ou `?` no nome — conferido com
`find .claude -name '*[][*?]*'`.

- Onde: `mosk/.claude/mosk/scripts/audit-legacy-surface.sh:456-458` — o
  `if [ -e "$ROOT/$pattern" ]; then :` que aceita a primeira perna sem mais nada
- Correção quando este arquivo for tocado de novo: exigir as **duas** condições
  na perna do caminho exato, em vez de escolher uma — o pattern precisa existir
  **e** não conter metacaractere. A lista de metacaracteres volta, mas agora
  numa posição onde esquecer um é inofensivo: o pattern ainda teria de nomear um
  arquivo existente, então a classe do extglob (`!(zzz)`, que não existe) segue
  fechada. É a diferença entre a lista ser a única defesa e ser a segunda
- Custo: código — uma condição a mais no `if`; mais uma fixture criando um
  arquivo chamado `*` no `selftest-toolkit.sh`
- Confiança: 0.95 no comportamento (reproduzido); `baixa` pela precondição de
  commitar um artefato que não passa despercebido

---

## Revalidação da correção de SEC-3

Verificação independente sobre cópias da árvore real em `mktemp -d`, com
referências legadas plantadas dentro de arquivos já catalogados — assim o único
`problem` possível é a própria referência, e o `rc` fica livre de ruído.

**`SEC-3` está fechado.** `.claude/!(zzz)` é recusado nos dois ambientes, e é
essa simetria que importa: sob `BASHOPTS=extglob` o pattern ainda suprime a
varredura, mas agora vem com `rc=1` e a linha `pattern não permitido` — a
supressão deixou de ser silenciosa, que era o defeito.

| `path_pattern` | Ambiente | Recusado | Legados reportados |
|---|---|---|---|
| `.claude/!(zzz)` | padrão | sim | 2 de 2 |
| `.claude/!(zzz)` | `BASHOPTS=extglob` | **sim** | 0 de 2, mas com `rc=1` |
| `.claude/@(agents\|mosk)` | `BASHOPTS=extglob` | sim | 2 de 2 |

A regra nova é imune ao shell porque nenhuma das duas pernas expande nada:
`[ -e "$ROOT/$pattern" ]` compara um caminho literal (o `[` não faz expansão de
nome de arquivo sobre o valor de uma variável), e o `case` dos dois roots casa
prefixo literal. Por isso `!(zzz)` cai igual com extglob ligado ou desligado.

**Sem regressão de `SEC-1` e `SEC-2`.** Os oito vetores das duas rodadas
anteriores continuam recusados: `.claude/*`, `.claude/**`, `.claude/mosk/**`,
`.claude/mosk/tasks/*`, `.claude/mosk/data/*`, `.claude/mosk/schemas/*`,
`.claude/mosk/data/?*` e `docs/specs/*`.

**Nenhum uso legítimo quebrou.** Os quatro patterns da allowlist real passam:
`hallmark/VENDOR.md` e `hallmark/LICENSE` pela perna do caminho exato,
`hallmark/upstream/**` e `docs/specs/archive/**` pela perna dos roots. O
auditor sobre o template sai `{"ok":true,…,"failures":0}` **com e sem**
`BASHOPTS=extglob`. Confirmei também que allowlistar um arquivo específico
qualquer sob `.claude/` continua funcionando: `.claude/mosk/tasks/archive.md`
é aceito e suprime exatamente aquele arquivo.

**Ganho colateral que vale registrar:** entrada de allowlist apontando para
arquivo que não existe mais passou a ser **recusada**
(`.claude/mosk/tasks/inexistente.md` → `pattern não permitido`). Allowlist morta
agora aparece em vez de apodrecer em silêncio, e a falha é fechada.

**Paridade e suite.** `zsh -n` aceita o bloco. `doctor.sh --json` no template →
`{"ok":true,"checks":8,"failures":0}`. `selftest-common` 29 ·
`selftest-toolkit` 113 · `selftest-pipeline-state` 201 ·
`selftest-adaptive-work` 92, todos `rc=0`. Os números que você reportou
conferem.

**Observação não-bloqueante, fora de segurança — segunda vez que aponto.** O
bloco de comentários acumulou três parágrafos, e **dois descrevem regras que já
não existem**: `audit-legacy-surface.sh:436-440` ainda afirma "Exigimos três
segmentos literais antes do primeiro curinga" (regra removida na segunda volta)
e o parágrafo seguinte descreve a inversão pela ótica do gatilho de curinga
(removido nesta). Só o terceiro, a partir da linha 450, descreve o código. Três
comentários empilhados sobre o mesmo `if`, dois deles errados, é exatamente como
esta classe de defeito volta: o próximo a mexer aqui lê a regra que não existe
mais e "restaura" o buraco.

---

## Revalidação da correção de SEC-2

Verificação independente da inversão de polaridade, sobre cópias da árvore real
em `mktemp -d`. Duas formas de fixture: uma com sete referências legadas
plantadas em `agents/`, `data/`, `schemas/`, `checklists/`, `utils/`, `tasks/` e
`data/hallmark/upstream/`, e outra "limpa" que planta o legado **dentro de
arquivos já catalogados**, para que a única falha possível seja a referência
legada e o `rc` fique livre de ruído.

**`SEC-2` está fechado.** Os seis vetores que levantei são recusados agora,
inclusive os que a regra de profundidade aprovava:

| `path_pattern` | Recusado |
|---|---|
| `.claude/mosk/data/*` | sim |
| `.claude/mosk/schemas/*` | sim |
| `.claude/mosk/data/**` | sim |
| `.claude/mosk/data/?*` | sim |
| `.claude/mosk/data/[a-z]*` | sim |
| `docs/specs/*` | sim (duas vezes: escopo e curinga) |

**O conjunto de dois prefixos atende os usos legítimos existentes.** Os quatro
patterns da allowlist real passam: as duas linhas literais
(`hallmark/VENDOR.md`, `hallmark/LICENSE`) nem entram no bloco por não terem
curinga, e `.claude/mosk/data/hallmark/upstream/**` e `docs/specs/archive/**`
casam os roots permitidos. `audit-legacy-surface.sh --json` no template →
`{"ok":true,…,"failures":0}`. Verifiquei também que `.claude/mosk/data/hallmark/*`
é aceito e suprime exatamente o vendor, e que a supressão por **linha literal**
continua funcionando em qualquer lugar sob `.claude/` — a correção restringe
curinga, não a allowlist, então allowlistar um arquivo específico segue
possível. O único custo futuro é que vendorizar um segundo fork exigirá tocar a
lista; para uma decisão que já deveria passar por revisão, é o tradeoff certo.

**Bracket malformada não produz prefixo que escape.** O `sed 's/[][*?].*//'`
só **trunca** — a classe `[][*?]` cobre `]`, `[`, `*` e `?`, e o corte é sempre
no primeiro deles —, então o prefixo nunca pode crescer para dentro dos roots
permitidos. Os três casos que você citou, mais dois meus:

| `path_pattern` | Prefixo literal | Resultado |
|---|---|---|
| `.claude/[` | `.claude/` | recusado, varredura 7 de 7 |
| `.claude/]*` | `.claude/` | recusado, varredura 7 de 7 |
| `.claude/[a-` | `.claude/` | recusado, varredura 7 de 7 |
| `.claude/mosk/data/hallmark[` | `.claude/mosk/data/hallmark` | recusado (falta a `/` final) |
| `.claude/mosk/data/hallmark[/]upstream/*` | `.claude/mosk/data/hallmark` | recusado, e a supressão que ele causa vem acompanhada de `rc=1` |

As duas últimas mostram a propriedade que importa: quando um pattern com
bracket consegue casar algo, ele já foi recusado, então a supressão nunca é
silenciosa. E `.claude/mosk/data/hallmark*` (sem a barra) também é recusado —
estrito demais em teoria, na direção segura na prática.

**Supressão sem curinga é explícita e cara.** Um pattern sem `*`, `?` ou `[` é
caminho exato e casa um arquivo só: para desligar a varredura seriam precisas N
linhas, cada uma com `kind`, `reason` e visibilidade no diff. Confirmei com sete
linhas literais que suprimem exatamente os sete arquivos plantados. Também
testei formas que o `case` **poderia** interpretar de modo inesperado —
`{agents,mosk}` (brace expansion não se aplica a pattern de `case`),
`@(agents|mosk)` e `!(zzz)` (extglob desligado) e barra invertida final: as
quatro casam **zero** arquivos no ambiente padrão, varredura intacta em 7 de 7.
A exceção é o `!(…)` com extglob ligado, registrada como `SEC-3`.

**Nenhuma ordem deixa a recusa registrada com `rc` 0.** `problem()` só faz
append em `$ERRORS`; a única truncagem (`: > "$ERRORS"`) acontece uma vez, antes
de tudo. A última linha do script é `[ "$failure_count" -eq 0 ]`, avaliada
depois do bloco `--json`, então nem o modo JSON escapa: com um pattern recusado,
`--json` sai `{"ok":false,…,"failures":2}` com `rc=1`, e `--quiet` sai `rc=1`
sem imprimir nada. Allowlist ausente ou diretório já falha antes, no
`problem "allowlist ausente"`. Linha vazia falha no check de escopo. Última
linha **sem newline final** é ignorada pelos dois laços — o de validação e o
`allow_path` — de forma simétrica: não é validada, mas também não allowlista
nada, então não abre janela.

**Paridade e suite.** `zsh -n` aceita o bloco; o auditor sob `zsh` produz a
mesma contagem que sob `bash`. `doctor.sh --json` no template →
`{"ok":true,"checks":8,"failures":0}`. `selftest-common` 29 · `selftest-toolkit`
111 · `selftest-pipeline-state` 201 · `selftest-adaptive-work` 92, todos `rc=0`.
Os números que você reportou conferem.

**Observação não-bloqueante, fora de segurança.** O comentário do bloco antigo
sobreviveu à edição: `audit-legacy-surface.sh:436-440` ainda afirma "Exigimos
três segmentos literais antes do primeiro curinga", regra que a inversão
removeu, e logo abaixo vem o comentário novo que descreve a regra real. Dois
comentários contraditórios sobre o mesmo `case` é como esta classe de defeito
volta — o próximo a mexer aqui lê a regra que não existe mais.

---

## Revalidação da correção de SEC-1

Verificação independente da correção, sobre cópias da árvore real em `mktemp -d`
com referências legadas plantadas em `.claude/agents/`, `.claude/mosk/data/`,
`.claude/mosk/schemas/`, `.claude/mosk/checklists/` e `.claude/mosk/utils/`.

**O achado original está fechado.** `.claude/*` e `.claude/**` agora são
recusados com `pattern amplo na allowlist`, e o auditor sai `rc=1` em vez de
`rc=0` silencioso. Cobertos por fixture em
`selftest-toolkit.sh:369-374`, que exercita os quatro patterns amplos mais o
caso positivo.

**As duas regras novas fazem o que dizem, dentro do alcance que têm.** Todos os
sete diretórios da lista operacional são recusados de fato — inclusive
`checklists/` e `utils/`, que ficam na linha de continuação `|\` do `case` e
poderiam não ter sido tokenizados; verifiquei que são. `.claude/agents/*` e
`.claude/skills/*` são recusados **duas vezes** (profundidade 2 e lista), o que
é redundância inofensiva, não defeito.

**Os vetores exóticos que você pediu não abrem nada.** Testei cada um contra a
árvore real:

- **`sed 's/[][*?].*//'` com bracket malformada** — não há injeção possível: o
  `pattern` entra por **stdin**, nunca como parte do script `sed`, então uma
  bracket aberta no dado não pode alterar a expressão. E o efeito da bracket é
  sempre **encurtar** o prefixo literal (o `sed` corta no primeiro `[`), o que
  empurra na direção segura: `.claude/mosk/[t]asks/*` vira prefixo
  `.claude/mosk/` → profundidade 2 → recusado. `.claude/mosk/data/[abc`, com o
  `[` sem fechar, vira glob literal no `case` do shell e casa só com o caminho
  literal `[abc` — nada real. Confirmado: a varredura segue reportando 5 de 5.
- **`?` como curinga** — entra no mesmo ramo `*'?'*` e recebe a mesma medição de
  profundidade; `.claude/?` é recusado.
- **`//` e `/./` no prefixo** — inflam o contador de barras e passam nas duas
  regras (`.claude//mosk/*` e `.claude/./mosk/*` não são recusados), mas os
  candidatos vêm de `rel="${file#"$ROOT/"}"` sobre caminhos reais, que nunca
  contêm `//` nem `/./`. Confirmado empiricamente: os dois casam com zero
  arquivos e a varredura segue reportando 5 de 5. Passar no guard sem casar com
  nada não reduz cobertura.
- **Pattern sem curinga** — pula o bloco novo inteiro, mas é caminho exato e
  casa com no máximo um arquivo. `.claude/` sozinho passa o check de escopo
  (`*` casa vazio) e não casa com nenhum candidato.
- **Traversal** — `/../` continua recusado antes, e caminho real nunca contém
  `..`, então nem chegaria a casar.

**Nenhuma regressão de uso legítimo.** A allowlist real do template continua
válida: `audit-legacy-surface.sh --json` → `{"ok":true,…,"failures":0}`.
`.claude/mosk/data/hallmark/upstream/**` (profundidade 5) e
`docs/specs/archive/**` (profundidade 3) passam, e com eles a varredura segue
reportando 5 de 5 legados plantados. Paridade Bash/zsh confirmada: `zsh -n`
aceita o `case` com continuação `|\`, e o auditor sob `zsh` produz a mesma
contagem que sob `bash`.

**Suite completa, executada por mim:** `doctor.sh --json` no template →
`{"ok":true,"checks":8,"failures":0}`. `selftest-common` 29 · `selftest-toolkit`
103 · `selftest-pipeline-state` 201 · `selftest-adaptive-work` 92 — todos
`rc=0`. Os números que você reportou conferem.

---

## O que foi verificado e está limpo

**`classify-change.sh` — parsing e pisos.** A allowlist de opções é real, não
aparente: o `case` do laço de parse enumera as sete opções aceitas e manda todo
o resto para `die` + `exit 2`, e cada valor passa por um `case` de enum antes de
virar score. Confirmei por execução, além dos 7 inputs já checados pelo lead:

- `--scope=localized` (forma com `=`) → `rc=2`, sem JSON
- `--` como separador → `rc=2`, sem JSON
- opção consumindo outra opção como valor (`--scope --evidence localized …`) →
  `rc=2`, sem JSON
- `--sensitive-surface data_security … --sensitive-surface none` (tentativa de
  rebaixar por repetição) → `rc=2`, sem JSON
- paridade Bash/zsh no mesmo input → byte a byte idêntica

**Nenhum caminho rebaixa o perfil.** `raise_floor` só substitui o piso quando o
`rank` do candidato é **maior**, e a aplicação final é
`if rank(floor) > rank(profile) then profile=floor` — as duas comparações são
monotônicas para cima. Verifiquei as quatro rotas que a spec pediu:

- argumento: `--requested-floor standard` sobre uma mudança `data_security`
  mantém `elevated` (o piso calculado vence); `--requested-floor compact` não
  existe no enum e falha fechado
- ordem de flags: os `raise_floor` são avaliados em ordem fixa no script,
  depois do parse inteiro — passar `--requested-floor` primeiro ou por último
  produz o mesmo JSON
- variável de ambiente: o script não lê nenhuma; `set -u` e zero `${VAR:-}` de
  configuração
- arquivo de dados: o classificador não lê arquivo algum

**Nenhum especialista obrigatório é removível.** Toda combinação com
`sensitive_surface=data_security` cai em `elevated` ou `critical`, e os dois
ramos emitem `["security","qa"]`. `production_critical` e `irreversible` forçam
`critical`, que emite `["security","qa"]` incondicionalmente.

**Sem command injection.** Não há `eval`, backtick, `$( )` sobre input, nem
`printf` com formato controlado por dado em nada que a spec introduziu — grepei
as linhas adicionadas do diff inteiro sob `mosk/` por `eval`, `curl`, `wget`,
`sudo`, `chmod`, `base64 -d`, `/dev/tcp` e `git push`: zero ocorrências. O JSON
de saída é montado com formato literal e argumentos que só podem ser constantes
internas ou inteiros de aritmética do shell, o que torna a injeção no campo
`reasons` impossível por construção.

**`audit-legacy-surface.sh` — o `awk` com `getline` é leitura, não execução.**
O detector de cópia de contrato itera sobre `find "$ROOT/.claude" -type f` e usa
`getline row < candidate`, que é redirecionamento de **arquivo**; a forma que
executaria comando é `cmd | getline`, ausente. `find` sem `-L` não desce em
symlink e `-type f` é falso para symlink, então o detector não sai da árvore. Os
arquivos lidos nunca têm conteúdo impresso — só o caminho e a contagem de
linhas casadas —, então também não há divulgação de conteúdo de
`.claude/settings.local.json` ou similares.

**Containment de path nos dados do catálogo.** `safe_product_path` exige prefixo
`.claude/` e recusa absoluto, `../`, `/../`, `/..`, `/./` e `//`; como o prefixo
já é obrigatório, as formas de traversal restantes são as internas, todas
cobertas. Nomes de task passam por `case ... *[!A-Za-z0-9._-]*` antes de virar
argumento de `grep -F -e` e nome de arquivo temporário. `--expected-count` é
validado como inteiro. `--root` é resolvido com `pwd -P` antes de qualquer uso.

**Integridade dos gates preservada.** `transition-spec-phase.sh`,
`check-ship-ready.sh` e `common.sh` **não** foram tocados neste range — a
máquina de estados, o `validate_promotion_target` e o guardrail de merge chegam
inalterados. No lado da instrução, `qa-gate.md:51` mantém "Missing evidence
required by the adaptive validation or specialist floor cannot produce `PASS`" e
`qa-gate.md:79` repete a regra; `orq-run.md` acrescenta que ausência de
evidência exigida pelo `validation_floor` "volta como falha; nunca é convertida
em confiança implícita pelo runner". Nada converte bloqueante em não-bloqueante.
`selftest-pipeline-state.sh:307-355` adiciona fixtures que provam exatamente
isso: perfil `critical` não autoriza salto de fase, não enfraquece gate sem
evidência e não permite archive fail-open.

**Dispensas de confirmação humana não abrem nada.** `specify.md`, `tasks.md`,
`plan.md` e `full-spec.md` passaram a dispensar confirmação para transição de
fase reversível e refresh de índice — mas a transição continua passando pelo
`transition-spec-phase.sh`, que valida aresta e artefatos, e `specify.md:88`
preserva explicitamente a aprovação para criação de branch. `full-spec.md:57`
preserva "every existing human limit for irreversible actions".

**Sem segredos.** Scan das linhas adicionadas por `api_key`, `secret`, `token`,
`password`, chave privada PEM, `xox*-`, `ghp_` e `AKIA…`: zero ocorrências.

**Execução de verificação.** `audit-legacy-surface.sh` → `rc=0`
(50 decisões, 47 tasks ativas, corpus 2641→618 linhas com teto 1848).
`selftest-adaptive-work.sh` → `rc=0`, 92 asserções.

## Fora de escopo por política

Descartados por serem teóricos, exigirem escrita prévia no repo ou caírem nos
filtros de falso-positivo da task:

- Escape por symlink em rota do catálogo/fixture: `safe_product_path` não checa
  symlink, e `[ -f "$ROOT/$rel" ]` seguiria um. Mas a operação é `grep -Fq`
  (booleano, sem eco de conteúdo) e exige um symlink commitado no repo. Sem
  divulgação e sem escrita.
- `mktemp -d` falhando faz `ERRORS` virar `/errors`. Em macOS a escrita é
  recusada e o script termina com status ≠ 0 (falha fechado). É esgotamento de
  recurso — filtro 1/4 da task.
- Templates que perderam o comentário `<!-- Inspired by … -->`: mudança de
  atribuição/documentação, sem efeito de segurança (filtro 17).
- Scripts `selftest-*`: usados só em teste (filtro 11); os `rm -rf` que
  introduzem operam apenas sobre caminhos derivados de `mktemp -d` com aspas.

---

## Resumo

- Arquivos revisados com atenção: 6 scripts Bash (`classify-change.sh`,
  `audit-legacy-surface.sh`, `selftest-adaptive-work.sh`,
  `selftest-toolkit.sh`, `selftest-pipeline-state.sh`, `doctor.sh`), 1 schema
  JSON (`change-profile.schema.json`), 4 arquivos de dados TSV e as tasks de
  pipeline que mudaram contrato de gate (`qa-gate.md`, `implement.md`,
  `orq-run.md`, `specify.md`, `plan.md`, `tasks.md`, `full-spec.md`)
- Achados: 0 HIGH · 0 MEDIUM · 4 LOW — `SEC-1`, `SEC-2` e `SEC-3` **fechados e
  revalidados**; `SEC-4` **aceito sem correção nesta entrega**, abaixo da barra
  de exploração da task
- Revisão concluída: sim, incluindo as revalidações das correções de `SEC-1`,
  `SEC-2` e `SEC-3`
- Nota sobre a trajetória: três voltas de correção, cada uma fechando a
  anterior sem reabrir nenhuma. `SEC-1` era uma linha de allowlist plausível
  que desligava tudo; `SEC-4` exige commitar um arquivo chamado `*`. A
  precondição do bypass encareceu a cada volta e o veredito nunca deixou de ser
  `PASS` — fechar o ciclo aqui é a leitura certa da evidência
- Aviso de escopo: esta revisão não é endurecida contra prompt injection. O diff
  é de autoria do próprio dono do repositório, então o pré-requisito de código
  confiável está satisfeito.

SECURITY: PASS
