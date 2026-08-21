# Security review — spec 016 (toolkit prompt-first)

**Revisor:** Heitor (mosk-security)
**Data:** 2026-08-20
**Escopo:** `git diff master...HEAD` — 45 arquivos, 2.225 inserções, 12.326 remoções
**Perfil adaptativo:** `elevated` · score 6 · contexto `elevated` · validação `independent` · especialistas `qa`
*(escopo `public_contract` — o toolkit é distribuído por degit; superfície `paths_state` — guardrail de merge e contenção de caminho; evidência `strong`; ambiguidade `clear`)*

---

## SECURITY: CONCERNS

Duas superfícies das três revisadas estão sólidas. A terceira — **o guardrail de merge**, que é a peça central da spec — é contornável por sete caminhos, e a maioria deles é acidental, não adversária.

Nenhum achado é execução remota, exposição de dado ou escalonamento de privilégio. Todos são **falha de controle**: o mecanismo que a spec criou para impedir uma repetição da spec 014 não se aplica em casos comuns de uso.

---

## SEC-001 — Guardrail de merge contornável por sete caminhos

**Severity:** HIGH · **Confidence:** 0.95 · **Category:** security control bypass
**Arquivo:** `.claude/hooks/guard-spec-merge.sh:34-70`

O hook decide se verifica ou ignora um comando quebrando-o em segmentos e olhando o primeiro token de cada um. Sete formas de invocar merge/PR **não são reconhecidas** e passam sem verificação alguma.

Verificado empiricamente contra a spec 016 (não arquivada, portanto todo comando deveria bloquear):

| tentativa | comando | resultado |
|---|---|---|
| baseline | `gh pr merge 21` | bloqueou ✅ |
| **newline separando** | `echo oi⏎gh pr merge 21` | **passou** ❌ |
| **prefixo de env** | `FOO=bar gh pr merge 21` | **passou** ❌ |
| **caminho absoluto** | `/usr/bin/gh pr merge 21` | **passou** ❌ |
| **`command` builtin** | `command gh pr merge 21` | **passou** ❌ |
| **`<<` em string** | `echo "a << b"; gh pr merge 21` | **passou** ❌ |
| **`<<` aritmético** | `echo $((1 << 2)); gh pr merge 21` | **passou** ❌ |
| **aspas não fechadas** | `echo 'aberta ; gh pr merge 21` | **passou** ❌ |

**Três causas distintas:**

1. **`cmd.find("<<")` corta cedo demais** (linha 44). Ele descarta tudo a partir do primeiro `<<` em qualquer posição — inclusive dentro de string literal ou num operador aritmético. Não distingue heredoc real de ocorrência do par de caracteres.
2. **Apenas o primeiro token do segmento é comparado** (linha 68). Qualquer coisa antes do verbo — atribuição de env, `command`, `env`, `sudo`, caminho absoluto — desloca o verbo para fora da janela examinada.
3. **Newline não é separador de segmento.** `SEPARADORES` inclui `"\n"`, mas `shlex` com `whitespace_split=True` consome a quebra de linha como espaço; ela nunca chega como token. Um comando de duas linhas vira um segmento só, cujo primeiro token é o da primeira linha.

**Por que isto importa mais do que o número sugere.** A spec 016 existe porque a spec 014 chegou ao branch padrão em `qa-gate` com o verificador instalado e nunca invocado. O ADR-0021 §5 codificou a lição: *garantia sem chamador não é garantia*. Este hook é o chamador. Os casos 1, 2 e 3 da tabela — newline, prefixo de env, caminho absoluto — não exigem intenção de burlar: acontecem sozinhos. O controle falha **em silêncio**, sem registrar que pulou.

**Falha de teste anterior:** as 13 fixtures do hook cobrem menção vs. invocação, que era o defeito conhecido. Nenhuma cobre invocação **não reconhecida** — testaram o falso positivo e não o falso negativo, que é o lado que importa num controle de segurança.

**Correção sugerida:** inverter o default. Em vez de tentar reconhecer as formas de invocação (blocklist, que erra por omissão), verificar sempre que o comando **contiver** os verbos e só ignorar quando puder provar que é menção. Fail-closed, como o `validate.sh` já faz para leitura de campo — é a mesma lição do ADR-0020, decisão 1, aplicada ao outro controle.

---

## SEC-002 — Guardrail falha aberto quando `python3` não existe

**Severity:** MEDIUM · **Confidence:** 0.9 · **Category:** insecure default
**Arquivo:** `.claude/hooks/guard-spec-merge.sh:28`

```bash
command -v python3 >/dev/null 2>&1 || exit 0
```

Sem `python3` no ambiente, o hook sai com 0 — **todo merge passa, sem aviso**. O mesmo vale para JSON malformado e para exceção do `shlex`: os três caminhos convergem em `ignora`.

O fail-open é uma escolha declarada no cabeçalho do arquivo ("um hook que barra trabalho legítimo é desabilitado pelo usuário"), e o raciocínio tem mérito. O problema não é a escolha: é ela ser **silenciosa**. Um projeto consumidor sem `python3` recebe o guardrail, o registra no `settings.json`, e nunca descobre que ele não está protegendo nada.

Isto contradiz diretamente o FR-007 do resto da spec, que exigiu que o `validate.sh` funcionasse sem PyYAML/npm/pip — e o `validate.sh` cumpre. O hook introduziu a dependência de volta pela porta dos fundos, num arquivo que ninguém pensou em avaliar sob esse critério.

**Correção sugerida:** manter o fail-open, mas **ruidoso** — escrever em stderr que o guardrail não pôde avaliar o comando. Ou implementar o caminho de fallback sem `python3`, aceitando cobertura menor.

---

## SEC-003 — `--extends` chega cru ao `spec-meta.yaml`

**Severity:** LOW · **Confidence:** 0.85 · **Category:** input validation
**Arquivos:** `mosk/.claude/mosk/scripts/create-new-feature.sh:74-86` · `common.sh:324`

`--extends` é o único argumento que vai da linha de comando ao arquivo YAML sem validação de domínio. `--type` é validado contra uma lista fechada; `--number` contra `^[0-9]+$`; `--short-name` é sanitizado com `sed 's/[^a-z0-9]/-/g'`. `--extends` não passa por nada:

```bash
EXTENDS="$next_arg"                          # create-new-feature.sh:85
...
echo "extends: \"$spec_extends\""            # common.sh:324
```

Um valor contendo aspas e quebra de linha injeta chaves arbitrárias no `spec-meta.yaml`.

**Por que LOW e não mais:** quem passa a flag já tem acesso de escrita ao repositório — não há travessia de fronteira de confiança. E o `ler_campo` do `validate.sh` é fail-closed: chave duplicada faz `grep -c` retornar ≠ 1 e o valor vira vazio, o que reprova em vez de aceitar. O impacto prático é metadata corrompida, não decisão de gate forjada.

**Observação de procedência:** a branch da spec 015 **já havia corrigido isto**, com a justificativa registrada no próprio diff — *"`extends` é o ÚNICO campo do spec-meta que chega cru da linha de comando, e ele é um vínculo entre specs, não decoração"*. A correção não foi colhida na T029 porque a colheita mirou o runner. Não é regressão introduzida pela 016; é correção conhecida deixada para trás.

---

## O que foi verificado e está sólido

Registro o que passou, porque num relatório curto o silêncio é ambíguo.

**Contenção de caminho — 7/7 vetores recusados.** `validate_promotion_target` rejeitou traversal simples, caminho absoluto, destino fora de `docs/`, barra dupla, segmento `.`, til e o prefixo enganoso `docsevil/`. Só o destino legítimo passou. Esta é a superfície com maior potencial de dano da spec (escrita de arquivo por caminho vindo de front-matter) e ela está correta.

**Leitor do `validate.sh` — fail-closed confirmado.** `ler_campo` devolveu string vazia para anchor YAML (`&a`), aspas simples, valor com comentário sufixado e chave malformada; leu corretamente apenas as formas canônicas, incluindo tab e CRLF. A troca de blocklist por allowlist de caracteres, feita durante a Phase 4, sustenta: nenhum dos vetores que custaram treze voltas à spec 015 produz leitura falsa aqui.

**Interpolação em `sed`/`awk` — sem injeção.** `ler_campo` interpola `$chave` num regex, mas a chave é validada contra `CAMPOS_LIDOS` antes; a regra R4 do `docs-paths` interpola em `awk -v`, com valores que vêm de um `grep` com allowlist. Ambos fechados.

**Remoção de 12.326 linhas — sem perda de controle de segurança.** Os validadores removidos de `common.sh` eram defesa de parser (gramática, duplicidade, contagem), não regra de domínio. A contenção física permaneceu, que é a única parte que exigia consultar o disco.

---

## Veredito

**SECURITY: CONCERNS.**

Nada aqui impede a spec de seguir para o gate de QA, e nenhum achado é explorável por um terceiro. Mas o SEC-001 tem uma qualidade incômoda que a decisão de gate deveria pesar: **é a mesma classe de falha que a spec 016 foi escrita para corrigir.** A 014 passou porque o verificador não tinha chamador; agora o chamador existe, e não reconhece as formas comuns de invocar aquilo que deveria interceptar.

Corrigir o SEC-001 e o SEC-002 é trabalho de horas, não de dias, e mantém a coerência entre o que a spec afirma e o que ela entrega.
