#!/usr/bin/env bash
# guard-spec-merge.sh — chamador do validate.sh (ADR-0021 §5).
#
# Existe porque a spec 014 chegou ao branch padrão em `qa-gate`, sem archive,
# com o verificador instalado, correto e nunca invocado. Uma garantia que
# depende de alguém lembrar de chamá-la tem a força de uma regra escrita em
# prompt, com o custo de manutenção de um programa.
#
# Bloqueia (exit 2) a INVOCAÇÃO de merge/PR quando a spec do branch não está
# fechada.
#
# --- Sobre distinguir invocação de menção -----------------------------------
#
# Duas versões anteriores casavam a substring do comando e bloquearam a si
# mesmas: a primeira ao editar um arquivo que citava o comando num heredoc, a
# segunda ao escrever uma mensagem de commit que o descrevia. A lição é a mesma
# do ADR-0021: casar padrão contra texto de comando é análise sintática de
# shell feita com regex, e ela erra do lado que trava o trabalho.
#
# A versão atual não procura a string em lugar nenhum. Ela quebra o comando em
# segmentos por separador de shell, DESCARTA tudo a partir de um heredoc, e
# olha apenas o PRIMEIRO TOKEN de cada segmento. `gh pr merge` só conta quando
# é o verbo sendo executado.
#
# Falha de parse => não bloqueia. Um hook que barra trabalho legítimo é
# desabilitado pelo usuário, e aí a garantia vale zero.

set -u
INPUT="$(cat)"

command -v python3 >/dev/null 2>&1 || exit 0

DECISAO="$(printf '%s' "$INPUT" | python3 -c '
import json, shlex, sys

try:
    cmd = json.load(sys.stdin).get("tool_input", {}).get("command", "")
except Exception:
    print("ignora"); raise SystemExit

if not cmd:
    print("ignora"); raise SystemExit

# Tudo a partir de um heredoc é dado, não comando.
corte = cmd.find("<<")
if corte != -1:
    cmd = cmd[:corte]

ALVOS = {("gh", "pr", "merge"), ("gh", "pr", "create"), ("git", "merge")}

try:
    lexer = shlex.shlex(cmd, posix=True, punctuation_chars=True)
    lexer.whitespace_split = True
    tokens = list(lexer)
except Exception:
    print("ignora"); raise SystemExit

SEPARADORES = {";", "&&", "||", "|", "&", "(", ")", "\n"}
segmentos, atual = [], []
for t in tokens:
    if t in SEPARADORES:
        if atual: segmentos.append(atual)
        atual = []
    else:
        atual.append(t)
if atual: segmentos.append(atual)

for seg in segmentos:
    # Só o começo do segmento importa: é ali que fica o verbo.
    cabeca = tuple(seg[:3])
    if cabeca in ALVOS or tuple(seg[:2]) in ALVOS:
        print("verifica"); raise SystemExit

print("ignora")
' 2>/dev/null)"

[ "${DECISAO:-ignora}" = "verifica" ] || exit 0

ROOT="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null)}"
[ -n "$ROOT" ] || exit 0
VALIDATE="$ROOT/mosk/.claude/mosk/scripts/validate.sh"
[ -f "$VALIDATE" ] || VALIDATE="$ROOT/.claude/mosk/scripts/validate.sh"
[ -f "$VALIDATE" ] || exit 0

if OUT="$(bash "$VALIDATE" ship-ready 2>&1)"; then
    exit 0
fi

cat >&2 <<EOF
Bloqueado: a spec deste branch nao esta fechada.

$OUT

Rode o archive da spec e commite antes de prosseguir.
Para conferir: bash .claude/mosk/scripts/validate.sh ship-ready
EOF
exit 2
