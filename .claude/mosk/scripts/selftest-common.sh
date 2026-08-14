#!/usr/bin/env bash
# selftest-common.sh — exercita as duas regras do toolkit que já quebraram em
# produção e que nenhum outro verificador cobre.
#
# 1. Resolução do próprio diretório do `common.sh`, em bash E em zsh. As tasks do
#    MOSK mandam o agente rodar `source common.sh` no shell DELE, e o shell padrão
#    do macOS é zsh — onde `BASH_SOURCE` não existe. Quando isso degradava em
#    silêncio, todo caminho passava a resolver a partir do cwd (spec 009).
#
# 2. As duas regras de numeração de spec que o `create-new-feature.sh` aplica:
#    a regex ANCORADA no início do nome do branch (spec 010) e o `10#` que impede
#    `--number 010` de virar constante octal. Os dois casos exercitam as regras,
#    não o script — ele executa ao ser sourceado, então não dá para chamar suas
#    funções offline. Ainda assim pegam a regressão aqui, e não na próxima spec.
#
# Usage: selftest-common.sh [--verbose] [--help]
# Exit 0 = tudo passou; exit 1 = falhas listadas (caso :: esperado :: obtido).
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

VERBOSE=0
for arg in "$@"; do
    case "$arg" in
        --help|-h) sed -n '2,18p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        --verbose|-v) VERBOSE=1 ;;
        *) echo "opcao desconhecida: $arg" >&2; exit 2 ;;
    esac
done

set +e

PASS=0
FAILURES=""

ok()   { PASS=$((PASS + 1)); [[ "$VERBOSE" -eq 1 ]] && echo "  ok   $1"; return 0; }
fail() { FAILURES+="  $1"$'\n    esperado: '"$2"$'\n    obtido:   '"$3"$'\n'; }

check_eq() {
    local name="$1" expected="$2" got="$3"
    if [[ "$got" == "$expected" ]]; then ok "$name"; else fail "$name" "$expected" "$got"; fi
}

# ─────────── caso 1: common.sh se localiza em bash E em zsh ───────────
# A sonda é o próprio `MOSK_SCRIPTS_DIR` e um helper que depende dele. Se a
# detecção falhar, `MOSK_SCRIPTS_DIR` vira o cwd e `core_config_file` aponta para
# um arquivo que não existe — que era exatamente o modo de falha silenciosa.
echo "selftest-common: resolucao de caminho (bash vs zsh)"
for shell_bin in bash zsh; do
    if ! command -v "$shell_bin" >/dev/null 2>&1; then
        [[ "$VERBOSE" -eq 1 ]] && echo "  skip $shell_bin (ausente)"
        continue
    fi

    # Rodar de um cwd DIFERENTE do diretório dos scripts: se a resolução usar o
    # cwd por engano, o teste falha — que é o ponto.
    got="$(cd / && "$shell_bin" -c "source '$SCRIPT_DIR/common.sh' 2>/dev/null; printf '%s' \"\$MOSK_SCRIPTS_DIR\"" 2>/dev/null)"
    check_eq "1. $shell_bin: MOSK_SCRIPTS_DIR resolve para o diretorio real" "$SCRIPT_DIR" "$got"

    got="$(cd / && "$shell_bin" -c "source '$SCRIPT_DIR/common.sh' 2>/dev/null; [ -f \"\$(core_config_file)\" ] && echo TRUE || echo FALSE" 2>/dev/null)"
    check_eq "1. $shell_bin: core_config_file aponta para arquivo existente" "TRUE" "$got"

    got="$(cd / && "$shell_bin" -c "source '$SCRIPT_DIR/common.sh' 2>&1 >/dev/null" 2>&1)"
    check_eq "1. $shell_bin: source limpo, sem aviso de auto-localizacao" "" "$got"
done

# ─────────── caso 2: numeração de spec ───────────
# 2a — a âncora `^`. Sem ela, qualquer branch comum com três dígitos no meio do
# nome (`docs/adr-0012-0014-x`, `fix/issue-123-foo`) é lido como spec e desvia a
# numeração. Era o formato legado, e continua precisando da âncora.
echo "selftest-common: numeracao de spec"
BRANCHES=$'015-feature-graph-loop-orca\ndocs/adr-0012-0014-x\nfix/issue-123-foo\nchore/rfc-042-bar\nmaster'
got="$(printf '%s\n' "$BRANCHES" | grep -oE '^[0-9]{3}-' | grep -oE '[0-9]+' | sort -n | tr '\n' ',')"
check_eq "2a. so o prefixo ancorado conta como spec" "015," "$got"

# 2b — os DOIS formatos de branch (ADR-0017). `tipo/NNN-nome` é o canônico;
# `NNN-tipo-nome` continua em uso. Alargar a regex sem manter a âncora
# reintroduziria de uma vez o bug que 2a cobre.
BRANCHES2=$'011-feature-direct-agents\nfeature/012-algo\nfix/013-bug\nhotfix/014-urgente\ndocs/adr-0012-0014-x\nchore/sync-042-pmo\nfeat/komodo-deploy\nmaster'
got="$(printf '%s\n' "$BRANCHES2" | sed -nE 's|^([a-z][a-z-]*/)?([0-9]{3})-.*|\2|p' | sort -n | tr '\n' ',')"
check_eq "2b. conta os dois formatos, ignora o resto" "011,012,013,014," "$got"

# `chore/sync-042-pmo` NÃO pode contar: o 042 está no meio do nome, não logo após
# a barra. É a distinção que faz "tem número" significar "tem spec".
case "$got" in
    *042*) fail "2b. numero no meio do nome nao conta" "sem 042" "$got" ;;
    *) ok "2b. numero no meio do nome nao conta" ;;
esac

# Resolução branch -> pasta: a pasta é PLANA, o branch tem o tipo à frente.
check_eq "2b. prefixo extraido do formato novo" "012" \
    "$(printf 'feature/012-algo\n' | sed -nE 's|^([a-z][a-z-]*/)?([0-9]{3})-.*|\2|p')"
check_eq "2b. prefixo extraido do formato legado" "011" \
    "$(printf '011-feature-direct-agents\n' | sed -nE 's|^([a-z][a-z-]*/)?([0-9]{3})-.*|\2|p')"

# 2c — base 10 forçado. Sem `10#`, `--number 010` chega ao printf como constante
# octal e reserva 008.
check_eq "2c. --number 010 vale dez, nao octal oito" "010" "$(printf '%03d' "$((10#010))")"
check_eq "2c. --number 15 normaliza para 015" "015" "$(printf '%03d' "$((10#15))")"

# ─────────── caso 3: check_feature_branch aceita os DOIS formatos ───────────
# O formato CANÔNICO do branch é `tipo/NNN-nome` (ADR-0017), mas esta função
# validava com `^[0-9]{3}-`, que só casa o legado. Como `setup-plan.sh` e
# `check-prerequisites.sh` a chamam, todo branch criado no formato canônico era
# barrado na entrada de plan, tasks, implement e qa-gate.
echo "selftest-common: validacao de branch de spec"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/common.sh"

want_branch() {  # nome, branch, esperado(TRUE|FALSE)
    local got
    if check_feature_branch "$2" "true" 2>/dev/null; then got=TRUE; else got=FALSE; fi
    check_eq "$1" "$3" "$got"
}

want_branch "3a. canonico feature/012-algo aceito"      "feature/012-algo"        TRUE
want_branch "3b. canonico fix/013-bug aceito"           "fix/013-bug"             TRUE
want_branch "3c. canonico hotfix/014-urgente aceito"    "hotfix/014-urgente"      TRUE
want_branch "3d. legado 012-feature-algo aceito"        "012-feature-algo"        TRUE
want_branch "3e. master recusado"                       "master"                  FALSE
want_branch "3f. branch comum recusado"                 "chore/sync-042-pmo"      FALSE
# A âncora continua sendo o que separa "tem número" de "tem spec":
want_branch "3g. numero no meio do nome recusado"       "docs/adr-0012-0014-x"    FALSE

# ─────────── caso 4: helpers do runner autônomo ───────────
# Um processo que roda desacompanhado não pode depender de o prompt lembrar do
# teto nem do log. Estes dois são a diferença entre "convenção" e "garantia".
echo "selftest-common: helpers do runner"

check_eq "4a. max_attempts default do core-config" "3" "$(resolve_max_attempts)"

_tmpcfg="$(mktemp)"
printf 'runner:\n  max_attempts: 7\n  max_parallel: 2\n' > "$_tmpcfg"
check_eq "4a. le max_attempts do core-config" "7" "$(MOSK_CORE_CONFIG="$_tmpcfg" resolve_max_attempts)"
printf 'runner:\n  max_attempts: abacaxi\n' > "$_tmpcfg"
check_eq "4a. valor nao-numerico cai no default" "3" "$(MOSK_CORE_CONFIG="$_tmpcfg" resolve_max_attempts 2>/dev/null)"
got="$(MOSK_CORE_CONFIG="$_tmpcfg" resolve_max_attempts 2>&1 >/dev/null)"
case "$got" in
    *aviso*) ok "4a. valor invalido avisa em stderr, nao cai em silencio" ;;
    *) fail "4a. valor invalido avisa em stderr" "aviso no stderr" "$got" ;;
esac
rm -f "$_tmpcfg"

_tmpspec="$(mktemp -d)"
append_run_log "$_tmpspec" "1" "US-1" "dev-us1" "seguiu com o default X" "plan.md nao decidia"
check_eq "4b. run-log criado com cabecalho de tabela" "1" \
    "$(grep -c '^| quando | onda |' "$_tmpspec/run-log.md")"
append_run_log "$_tmpspec" "1" "US-2" "dev-us2" "outra decisao" "outro motivo"
check_eq "4b. append nao sobrescreve (2 entradas)" "2" \
    "$(grep -c '^| 20' "$_tmpspec/run-log.md")"
# Pipe no texto quebraria a tabela markdown inteira. São DUAS ocorrências numa
# linha só — conte ocorrências, não linhas.
append_run_log "$_tmpspec" "2" "US-3" "dev-us3" "usou a|b" "porque a|b"
check_eq "4b. os dois pipes do texto sao escapados" "2" \
    "$(grep -o '\\|' "$_tmpspec/run-log.md" | wc -l | tr -d ' ')"
# E a linha resultante tem exatamente 7 separadores reais (6 colunas).
check_eq "4b. a tabela nao quebra: 7 separadores na linha" "7" \
    "$(grep 'US-3' "$_tmpspec/run-log.md" | sed 's/\\|//g' | grep -o '|' | wc -l | tr -d ' ')"
if append_run_log "/caminho/que/nao/existe" 1 x y z w 2>/dev/null; then
    fail "4b. spec_dir inexistente falha" "exit != 0" "exit 0"
else
    ok "4b. spec_dir inexistente falha explicitamente"
fi
rm -rf "$_tmpspec"

# ─────────────────────────── relatório ───────────────────────────
echo
if [[ -n "$FAILURES" ]]; then
    echo "FALHOU — $PASS asserção(ões) ok, e:"
    printf '%s' "$FAILURES"
    exit 1
fi
echo "OK — $PASS asserções."
