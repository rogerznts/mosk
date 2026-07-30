#!/usr/bin/env bash
# selftest-orca-driver.sh — exercita o parsing do driver Orca contra envelopes
# FIXTURE, sem app Orca de pé.
#
# Por que existe: o achado 1 da spec 009 (o `read` devolvendo string vazia porque
# `_text_from_json` desconhecia a chave `tail`) shipou justamente porque não havia
# como rodar o extrator offline. O `orca.sh` já era sourceável sem executar nada —
# faltava alguém escrever as fixtures.
#
# Cobre: precedência de chaves, lista vazia como conteúdo legítimo, envelope de
# erro, ramo de degradação sem python3, e o predicado de confirmação de entrega.
#
# Usage: selftest-orca-driver.sh [--verbose] [--help]
# Exit 0 = tudo passou; exit 1 = falhas listadas (caso :: esperado :: obtido).
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

VERBOSE=0
for arg in "$@"; do
    case "$arg" in
        --help|-h) sed -n '2,14p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        --verbose|-v) VERBOSE=1 ;;
        *) echo "opcao desconhecida: $arg" >&2; exit 2 ;;
    esac
done

# shellcheck source=/dev/null
source "$SCRIPT_DIR/orca.sh"
# orca.sh traz `set -e`; aqui queremos rodar TODOS os casos e só então reportar.
set +e

PASS=0
FAILURES=""

ok()   { PASS=$((PASS + 1)); [[ "$VERBOSE" -eq 1 ]] && echo "  ok   $1"; return 0; }
fail() { FAILURES+="  $1"$'\n    esperado: '"$2"$'\n    obtido:   '"$3"$'\n'; }

check_eq() {
    local name="$1" expected="$2" got="$3"
    if [[ "$got" == "$expected" ]]; then ok "$name"; else fail "$name" "$expected" "$got"; fi
}

# ─────────────────────────── fixtures ───────────────────────────
# Envelope real do `orca terminal read`. Note os colchetes na barra de progresso:
# é por isso que não existe extrator sed honesto para este formato.
FX_TAIL='{"id":"x","ok":true,"result":{"terminal":{"handle":"term_x","status":"running","tail":["❯","  ➜ cfo-skills git:(001-feature)…","  compact [████████░░] 85%"],"truncated":false,"returnedLineCount":3}}}'

FX_TAIL_EMPTY='{"id":"x","ok":true,"result":{"terminal":{"handle":"term_x","status":"running","tail":[],"returnedLineCount":0}}}'

FX_ERROR='{"id":"x","ok":false,"error":{"code":"terminal_handle_stale","message":"handle no longer valid"}}'

# `tail` curto competindo com um campo textual MUITO mais longo em outro ramo.
# A regra antiga (max(out, key=len)) devolvia o campo longo; a nova devolve o tail.
FX_TAIL_VS_LONG='{"id":"x","ok":true,"meta":{"content":"AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"},"result":{"terminal":{"handle":"term_x","tail":["short"]}}}'

FX_TAIL_DICTS='{"id":"x","ok":true,"result":{"terminal":{"handle":"term_x","tail":[{"text":"linha um"},{"content":"linha dois"}]}}}'

FX_LINES_ONLY='{"id":"x","ok":true,"result":{"terminal":{"handle":"term_x","lines":["via lines"]}}}'

echo "selftest-orca-driver: extrator de texto"

# ── caso 1: tail populado ──
EXPECTED_1='❯
  ➜ cfo-skills git:(001-feature)…
  compact [████████░░] 85%'
check_eq "1. tail com 3 linhas" "$EXPECTED_1" "$(_text_from_json "$FX_TAIL")"

# ── caso 2: tail vazio é conteúdo vazio LEGÍTIMO, não erro ──
got="$(_text_from_json "$FX_TAIL_EMPTY")"; rc=$?
check_eq "2a. tail vazio devolve string vazia" "" "$got"
check_eq "2b. tail vazio sai com exit 0" "0" "$rc"

# ── caso 3: envelope de erro é barrado antes do extrator, por _json_ok ──
check_eq "3a. _json_ok reprova envelope de erro" "false" "$(_json_ok "$FX_ERROR")"
check_eq "3b. _json_ok aprova envelope bom" "true" "$(_json_ok "$FX_TAIL")"
check_eq "3c. _json_error extrai a mensagem" "terminal_handle_stale; handle no longer valid" "$(_json_error "$FX_ERROR")"

# ── caso 4: precedência por SEMÂNTICA, não por comprimento ──
check_eq "4. tail curto vence campo textual longo" "short" "$(_text_from_json "$FX_TAIL_VS_LONG")"

# ── caso 5: itens dict dentro de tail ──
EXPECTED_5='linha um
linha dois'
check_eq "5. tail com itens dict" "$EXPECTED_5" "$(_text_from_json "$FX_TAIL_DICTS")"

# ── caso 5b: fallback de chave (lines) segue funcionando ──
check_eq "5b. cai para 'lines' quando não há tail" "via lines" "$(_text_from_json "$FX_LINES_ONLY")"

# ── caso 6: ramo de degradação sem python3 ──
# Regra: falhar explicitamente. NUNCA devolver fragmento do envelope — o extrator
# sed anterior devolvia `{"id":"x` aqui, que passa por qualquer checagem de
# "veio conteúdo?" e envenena quem consome (ex.: extract_tokens).
echo "selftest-orca-driver: ramo sem python3 (MOSK_ORCA_NO_PY=1)"
unset _MOSK_PY_OK
for fx_name in FX_TAIL FX_TAIL_EMPTY FX_ERROR FX_TAIL_VS_LONG; do
    got="$(MOSK_ORCA_NO_PY=1 _MOSK_PY_OK="" _text_from_json "${!fx_name}" 2>/dev/null)"
    rc=$?
    check_eq "6. $fx_name: sem python3 não emite stdout" "" "$got"
    if (( rc != 0 )); then ok "6. $fx_name: sem python3 falha explicitamente (exit $rc)"
    else fail "6. $fx_name: sem python3 deve falhar" "exit != 0" "exit 0"; fi
done
unset _MOSK_PY_OK

# ── caso 7: predicado de confirmação de entrega ──
# O 7d é a regressão que motivou o QA-009-001: mudança de tela NÃO é prova de
# entrega. A TUI do Claude muda sozinha (spinner, contador de tokens, medidor de
# compactação), então aceitar "mudou" confirmava entrega perdida.
echo "selftest-orca-driver: predicado de confirmação de entrega"

want_confirmed() {   # nome, before, after, sent
    if _delivery_confirmed "$2" "$3" "$4" 2>/dev/null; then ok "$1"
    else fail "$1" "confirmado" "não confirmado"; fi
}
want_rejected() {    # nome, before, after, sent
    if _delivery_confirmed "$2" "$3" "$4" 2>/dev/null; then fail "$1" "não confirmado" "confirmado"
    else ok "$1"; fi
}

SENT="/mosk-dev implement a fase 3 da spec 009"

want_confirmed "7a. texto enviado aparece no depois → confirmado" \
    "❯" "❯ $SENT" "$SENT"
want_rejected  "7b. nada mudou → não confirmado" \
    "❯ prompt" "❯ prompt" "$SENT"
want_rejected  "7c. vazio antes e depois → não confirmado" \
    "" "" "$SENT"

# ↓ a regressão do QA-009-001
want_rejected  "7d. MUDOU mas sem o texto → não confirmado" \
    "✻ Crunched for 2s · 100 tokens" "✻ Wrangling… · 257 tokens · compact [██░░] 20%" "$SENT"

want_confirmed "7e. reenvio do mesmo texto (2ª ocorrência) → confirmado" \
    "❯ $SENT" "❯ $SENT
❯ $SENT" "$SENT"
want_confirmed "7f. TUI quebrou a linha no meio do texto → confirmado" \
    "❯" "❯ /mosk-dev implement a fase
  3 da spec 009" "$SENT"
want_rejected  "7g. texto com metacaractere não é tratado como regex" \
    "❯" "❯ literal a.c aqui" 'a[b]c'
want_confirmed "7h. texto curto (y) → modo fraco: mudança confirma" \
    "prompt?" "prompt? y" "y"
want_rejected  "7i. texto curto (y) sem mudança → não confirmado" \
    "prompt?" "prompt?" "y"

# ── caso 7j–7m: a TUI reformata o eco (QA-009-006) ──
# Eco parcial REAL capturado pelo QA: enviamos comando + argumento, a TUI mostrou
# só o token do comando. Exigir prefixo fixo de 24 dava falso negativo no formato
# que o orq.md mais injeta.
want_confirmed "7j. TUI ecoou só o token do comando (eco real do QA) → confirmado" \
    "❯" "⏺ Unknown command: /mosk-zzz-probe-009" "/mosk-zzz-probe-009 teste de sonda"
want_confirmed "7k. slash command com argumento longo, eco só do comando → confirmado" \
    "❯" "❯ /mosk-dev" "/mosk-dev implement a fase 3 da spec 009"
# O afrouxamento não pode virar porta dos fundos: agente DIFERENTE não confirma.
want_rejected  "7l. eco de outro agente (/mosk-qa) não confirma envio de /mosk-dev" \
    "❯" "❯ /mosk-qa qa-gate" "/mosk-dev implement a fase 3 da spec 009"
want_rejected  "7m. só o prefixo comum /mosk- não basta para confirmar" \
    "❯" "❯ /mosk-" "/mosk-dev implement a fase 3 da spec 009"

# ── caso 8: dependência de caminho do common.sh, em bash E zsh ──
# O driver sourceia common.sh. Se a resolução de caminho lá quebra em zsh (onde
# BASH_SOURCE não existe), o driver herda o problema — e as tasks do MOSK mandam o
# agente sourcear common.sh no shell dele, que no macOS é zsh.
echo "selftest-orca-driver: resolução de caminho do common.sh (bash vs zsh)"
for shell_bin in bash zsh; do
    if ! command -v "$shell_bin" >/dev/null 2>&1; then
        [[ "$VERBOSE" -eq 1 ]] && echo "  skip $shell_bin (ausente)"
        continue
    fi
    got="$("$shell_bin" -c "source '$SCRIPT_DIR/common.sh' 2>/dev/null; graph_edge_exists specify plan && echo TRUE || echo FALSE" 2>/dev/null)"
    check_eq "8. $shell_bin: graph_edge_exists specify plan" "TRUE" "$got"
    got="$("$shell_bin" -c "source '$SCRIPT_DIR/common.sh' 2>/dev/null; graph_edge_exists specify implement && echo TRUE || echo FALSE" 2>/dev/null)"
    check_eq "8. $shell_bin: aresta inexistente segue reprovada" "FALSE" "$got"
done

# ─────────────────────────── relatório ───────────────────────────
echo
if [[ -n "$FAILURES" ]]; then
    echo "FALHOU — $PASS asserção(ões) ok, e:"
    printf '%s' "$FAILURES"
    exit 1
fi
echo "OK — $PASS asserções."
