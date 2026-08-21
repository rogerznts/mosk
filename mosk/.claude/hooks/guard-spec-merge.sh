#!/usr/bin/env bash
# guard-spec-merge.sh — chamador do validate.sh (ADR-0021 §5).
#
# Existe porque a spec 014 chegou ao branch padrão em `qa-gate`, sem archive,
# com o verificador instalado, correto e nunca invocado.
#
# Bloqueia (exit 2) a INVOCAÇÃO de merge/PR quando a spec do branch não está
# fechada. Cobre GitHub (`gh`) e Gitea (`tea`), com os aliases de cada um, mais
# `git merge`.
#
# --- Postura: fail-CLOSED (corrige SEC-001 e SEC-002) ------------------------
#
# As duas primeiras versões perguntavam "isto é uma invocação?" e ignoravam o
# comando quando não reconheciam a forma. Isso é uma blocklist, e blocklist erra
# por omissão: a security review encontrou SETE formas que passavam — newline
# separando comandos, prefixo de env, caminho absoluto, `command`, e três
# variantes de `<<`. Três delas acontecem sem nenhuma intenção de burlar.
#
# A pergunta foi invertida. Agora:
#
#   1. Se o comando não contém nenhum dos verbos, ignora. Busca por substring,
#      barata e sem falso negativo.
#   2. Se contém, a resposta padrão é VERIFICAR. Só ignora quando conseguir
#      PROVAR que toda ocorrência é menção — texto dentro de string ou corpo de
#      heredoc — e nunca tokens adjacentes de comando.
#   3. Qualquer coisa que impeça essa prova (sem python3, parse falhando)
#      resulta em VERIFICAR, não em ignorar.
#
# É a decisão 1 do ADR-0020 aplicada a este controle: validar contra o domínio
# do que se espera, em vez de enumerar as formas do que se recusa.
#
# O custo é falso positivo: escrever sobre `gh pr merge` numa branch de spec
# aberta dispara a verificação. Ele é barato — a mensagem diz o que falta — e é
# o lado certo para errar num controle de segurança.

set -u
INPUT="$(cat)"

# --- 1. filtro barato: o comando sequer menciona os verbos? -------------------
# Busca por substring no JSON cru. Se nem isso aparece, não há o que verificar.
#
# `|| exit 0` seria fail-open aqui: `grep` ausente devolve 127, indistinguível
# de "não encontrou" (1), e o guardrail inteiro sairia limpo. Só o 1 significa
# ausência dos verbos; qualquer outro código segue para verificação.
printf '%s' "$INPUT" | grep -qE '(gh|tea)[^"]{0,4}(pr|pull)|git[^"]{0,4}merge'
GREP_RC=$?
if [ "$GREP_RC" -eq 1 ]; then
    [ "${GUARD_DECIDE_ONLY:-0}" = "1" ] && echo "ignora"
    exit 0
fi
if [ "$GREP_RC" -ne 0 ]; then
    echo "guard-spec-merge: grep indisponivel (rc=$GREP_RC) — verificando por precaucao." >&2
fi

# --- 2. tentar provar que é apenas menção ------------------------------------
# `ignora` só é emitido quando a prova sai limpa. Todo o resto cai em `verifica`.
DECISAO="verifica"
if command -v python3 >/dev/null 2>&1; then
    DECISAO="$(printf '%s' "$INPUT" | python3 -c '
import json, re, shlex, sys

def bail(reason):
    # Na dúvida, verifica. Nunca ignora por falta de prova.
    print("verifica"); sys.exit(0)

try:
    cmd = json.load(sys.stdin).get("tool_input", {}).get("command", "")
except Exception:
    bail("json")

if not cmd:
    print("ignora"); sys.exit(0)

# Remove o CORPO de cada heredoc — ali é dado, não comando. Diferente da versão
# anterior, que cortava no primeiro `<<` em qualquer posição, inclusive dentro
# de string e no operador aritmético: aqui o delimitador é capturado e o corte
# vai do fim daquela linha até a linha que fecha.
def strip_heredocs(text):
    linhas = text.split("\n")
    saida, i = [], 0
    while i < len(linhas):
        linha = linhas[i]
        m = re.search(r"<<[-~]?\s*([\"\x27]?)([A-Za-z_][A-Za-z0-9_]*)\1\s*$", linha)
        if m:
            saida.append(linha[:m.start()])
            delim = m.group(2)
            i += 1
            while i < len(linhas) and linhas[i].strip() != delim:
                i += 1
            i += 1
            continue
        saida.append(linha)
        i += 1
    return "\n".join(saida)

cmd = strip_heredocs(cmd)

try:
    lexer = shlex.shlex(cmd, posix=True, punctuation_chars=True)
    lexer.whitespace_split = True
    tokens = list(lexer)
except Exception:
    bail("shlex")

# posix=True desempacota strings: `echo "gh pr merge"` vira UM token com
# espaços dentro, que nunca casa uma sequência de tokens adjacentes. É isso que
# separa menção de invocação, sem precisar saber onde a string começou.
def nome(tok):
    # `/usr/bin/gh` e `gh` são o mesmo comando.
    return tok.rsplit("/", 1)[-1]

# Conjuntos, nao tuplas fixas: `tea` aceita `pulls|pull|pr` para o mesmo
# comando e `create|c` / `merge|m` como acoes, o que daria doze tuplas so para
# ele. Enumerar tupla por tupla e como o guardrail perdeu `tea pr create`
# inteiro — a forma cresce e a lista nao acompanha.
FERRAMENTAS = {"gh", "tea"}
SUB_PR = {"pr", "pulls", "pull"}
ACOES = {"create", "c", "merge", "m"}

for i, tok in enumerate(tokens):
    base = nome(tok)
    # git merge
    if base == "git" and tokens[i + 1 : i + 2] == ["merge"]:
        print("verifica"); sys.exit(0)
    # gh/tea <pr> <create|merge>, com os aliases de cada um
    if base in FERRAMENTAS:
        resto = tokens[i + 1 : i + 3]
        if len(resto) == 2 and resto[0] in SUB_PR and resto[1] in ACOES:
            print("verifica"); sys.exit(0)

print("ignora")
' 2>/dev/null)"
    [ -n "$DECISAO" ] || DECISAO="verifica"
else
    # Sem python3 não há como provar que é menção. Antes isto saía com 0 e
    # deixava passar em silêncio (SEC-002); agora verifica.
    echo "guard-spec-merge: python3 indisponivel — verificando por precaucao." >&2
fi

# Modo de teste: imprime a decisao e sai, sem chamar o validate. Existe para
# que as fixtures possam cobrir o LADO QUE IMPORTA — o falso negativo — sem
# recursao (validate -> fixtures -> hook -> validate).
if [ "${GUARD_DECIDE_ONLY:-0}" = "1" ]; then
    echo "$DECISAO"
    exit 0
fi

[ "$DECISAO" = "verifica" ] || exit 0

# --- 3. verificar -------------------------------------------------------------
ROOT="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null)}"
if [ -z "$ROOT" ]; then
    echo "guard-spec-merge: raiz do repositorio nao resolvida — nao foi possivel verificar." >&2
    exit 0
fi
VALIDATE="$ROOT/mosk/.claude/mosk/scripts/validate.sh"
[ -f "$VALIDATE" ] || VALIDATE="$ROOT/.claude/mosk/scripts/validate.sh"
if [ ! -f "$VALIDATE" ]; then
    echo "guard-spec-merge: validate.sh nao encontrado — nao foi possivel verificar." >&2
    exit 0
fi

if OUT="$(bash "$VALIDATE" ship-ready 2>&1)"; then
    exit 0
fi

cat >&2 <<'CABECALHO'
Bloqueado: a spec deste branch nao esta fechada.
CABECALHO
printf '\n%s\n\n' "$OUT" >&2
cat >&2 <<'RODAPE'
Rode o archive da spec e commite antes de prosseguir.
Para conferir: bash .claude/mosk/scripts/validate.sh ship-ready
RODAPE
exit 2
