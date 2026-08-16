#!/usr/bin/env bash
# selftest-adaptive-work.sh — contrato portátil do classificador adaptativo.
set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CLASSIFIER="$SCRIPT_DIR/classify-change.sh"
FIXTURES="$SCRIPT_DIR/../data/adaptive-work-fixtures.tsv"
SCHEMA="$SCRIPT_DIR/../schemas/change-profile.schema.json"
VERBOSE=0
case "${1:-}" in
    --verbose) VERBOSE=1 ;;
    --help|-h) echo "selftest-adaptive-work.sh [--verbose]"; exit 0 ;;
    "") ;;
    *) echo "opção desconhecida: $1" >&2; exit 2 ;;
esac

TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT HUP INT TERM
PASS_COUNT=0
FAILURES=""

ok() { PASS_COUNT=$((PASS_COUNT + 1)); [ "$VERBOSE" -eq 0 ] || echo "  ok   $1"; }
fail() { FAILURES="${FAILURES}  $1\n"; }

extract_string() {
    printf '%s' "$1" | sed -n "s/.*\"$2\":\"\([^\"]*\)\".*/\1/p"
}
extract_number() {
    printf '%s' "$1" | sed -n "s/.*\"$2\":\([0-9][0-9]*\).*/\1/p"
}
extract_bool() {
    printf '%s' "$1" | sed -n "s/.*\"$2\":\([a-z][a-z]*\).*/\1/p"
}
extract_specialists() {
    value="$(printf '%s' "$1" | sed -n 's/.*"specialists":\[\([^]]*\)\].*/\1/p' | tr -d '"')"
    [ -n "$value" ] && printf '%s' "$value" || printf '-'
}

[ -x "$CLASSIFIER" ] || fail "classify-change.sh não é executável"
[ -f "$FIXTURES" ] || fail "fixtures ausentes"
[ -f "$SCHEMA" ] || fail "schema ausente"

if [ -f "$FIXTURES" ]; then
    sed '1d' "$FIXTURES" > "$TMP_ROOT/fixture-data"
    while IFS="$(printf '\t')" read -r name expect_status scope reversibility surface evidence ambiguity requested expect_profile expect_score expect_floor expect_validation expect_specialists expect_pause; do
        set -- --scope "$scope" --reversibility "$reversibility" --sensitive-surface "$surface" --evidence "$evidence" --ambiguity "$ambiguity"
        [ "$requested" = - ] || set -- "$@" --requested-floor "$requested"
        [ "$name" != contradictory-duplicate ] || set -- "$@" --scope multi_file

        bash_out="$(bash "$CLASSIFIER" "$@" 2>"$TMP_ROOT/$name.bash.err")"
        bash_status=$?
        zsh_out="$(/bin/zsh "$CLASSIFIER" "$@" 2>"$TMP_ROOT/$name.zsh.err")"
        zsh_status=$?
        if [ "$expect_status" -ne 0 ]; then
            if [ "$bash_status" -ne 0 ] && [ "$zsh_status" -ne 0 ] && [ -z "$bash_out" ] && [ -z "$zsh_out" ]; then
                ok "$name falha fechado"
            else
                fail "$name deveria falhar sem output (bash=$bash_status zsh=$zsh_status)"
            fi
            continue
        fi
        if [ "$bash_status" -ne 0 ] || [ "$zsh_status" -ne 0 ]; then
            fail "$name falhou (bash=$bash_status zsh=$zsh_status)"
            continue
        fi
        [ "$bash_out" = "$zsh_out" ] || fail "$name divergiu entre Bash e zsh"
        [ "$(extract_string "$bash_out" profile)" = "$expect_profile" ] || fail "$name profile divergente"
        [ "$(extract_number "$bash_out" score)" = "$expect_score" ] || fail "$name score divergente"
        [ "$(extract_string "$bash_out" floor)" = "$expect_floor" ] || fail "$name floor divergente"
        [ "$(extract_string "$bash_out" validation_floor)" = "$expect_validation" ] || fail "$name validation divergente"
        [ "$(extract_specialists "$bash_out")" = "$expect_specialists" ] || fail "$name specialists divergentes"
        [ "$(extract_bool "$bash_out" human_pause)" = "$expect_pause" ] || fail "$name pausa divergente"
        if command -v jq >/dev/null 2>&1; then
            printf '%s\n' "$bash_out" | jq -e . >/dev/null 2>&1 || fail "$name JSON inválido"
        fi
        if command -v check-jsonschema >/dev/null 2>&1; then
            printf '%s\n' "$bash_out" > "$TMP_ROOT/$name.json"
            check-jsonschema --schemafile "$SCHEMA" "$TMP_ROOT/$name.json" >/dev/null 2>&1 || \
                fail "$name não satisfaz o schema"
        fi
        ok "$name"
    done < "$TMP_ROOT/fixture-data"
fi

run_must_fail_clean() {
    name="$1"
    shift
    output="$(bash "$CLASSIFIER" "$@" 2>/dev/null)"
    command_status=$?
    if [ "$command_status" -ne 0 ] && [ -z "$output" ]; then ok "$name"; else fail "$name"; fi
}

marker="$TMP_ROOT/command-substitution"
run_must_fail_clean "command substitution não é avaliada" \
    --scope "\$(touch $marker)" --reversibility easy --sensitive-surface none --evidence strong --ambiguity clear
[ ! -e "$marker" ] || fail "command substitution criou arquivo"
run_must_fail_clean "metacaracteres falham" \
    --scope 'localized;echo injected' --reversibility easy --sensitive-surface none --evidence strong --ambiguity clear
run_must_fail_clean "duplicidade contraditória falha" \
    --scope localized --scope multi_file --reversibility easy --sensitive-surface none --evidence strong --ambiguity clear
run_must_fail_clean "rebaixamento compact não existe" \
    --scope localized --reversibility easy --sensitive-surface data_security --evidence strong --ambiguity clear --requested-floor compact
run_must_fail_clean "Unicode inesperado falha" \
    --scope 'localizéd' --reversibility easy --sensitive-surface none --evidence strong --ambiguity clear
run_must_fail_clean "path não é interpretado" \
    --scope /tmp --reversibility easy --sensitive-surface none --evidence strong --ambiguity clear

if command -v jq >/dev/null 2>&1; then
    jq -e . "$SCHEMA" >/dev/null 2>&1 && ok "schema é JSON válido" || fail "schema JSON inválido"
fi

# Integration contract: every operational consumer points to the same policy
# and the same deterministic classifier. The prompts select evidence; none may
# carry a private copy of score/floor rules.
cat > "$TMP_ROOT/consumers" <<EOF
implement	$SCRIPT_DIR/../tasks/implement.md
security-review	$SCRIPT_DIR/../tasks/security-review.md
qa-gate	$SCRIPT_DIR/../tasks/qa-gate.md
orq-run	$SCRIPT_DIR/../tasks/orq-run.md
EOF

while IFS="$(printf '\t')" read -r consumer consumer_file; do
    if [ ! -f "$consumer_file" ]; then
        fail "$consumer sem task consumidora"
        continue
    fi
    grep -F 'adaptive-work-contract.md' "$consumer_file" >/dev/null 2>&1 || \
        fail "$consumer não referencia o contrato adaptativo"
    grep -F 'classify-change.sh' "$consumer_file" >/dev/null 2>&1 || \
        fail "$consumer não referencia o classificador"
    grep -F 'context_budget' "$consumer_file" >/dev/null 2>&1 || \
        fail "$consumer não consome context_budget"
    grep -F 'validation_floor' "$consumer_file" >/dev/null 2>&1 || \
        fail "$consumer não consome validation_floor"
    grep -i 'reclassif' "$consumer_file" >/dev/null 2>&1 || \
        fail "$consumer não prevê reclassificação"
    ok "$consumer consome a fonte canônica"

    # Run every fixture through the exact classifier referenced by this
    # consumer. This matrix makes divergence visible if a consumer later forks
    # the executable contract.
    while IFS="$(printf '\t')" read -r name expect_status scope reversibility surface evidence ambiguity requested expect_profile expect_score expect_floor expect_validation expect_specialists expect_pause; do
        set -- --scope "$scope" --reversibility "$reversibility" --sensitive-surface "$surface" --evidence "$evidence" --ambiguity "$ambiguity"
        [ "$requested" = - ] || set -- "$@" --requested-floor "$requested"
        [ "$name" != contradictory-duplicate ] || set -- "$@" --scope multi_file
        consumer_bash_out="$(bash "$CLASSIFIER" "$@" 2>/dev/null)"
        consumer_bash_status=$?
        consumer_zsh_out="$(/bin/zsh "$CLASSIFIER" "$@" 2>/dev/null)"
        consumer_zsh_status=$?
        if [ "$expect_status" -ne 0 ]; then
            if [ "$consumer_bash_status" -ne 0 ] && [ "$consumer_zsh_status" -ne 0 ] && \
               [ -z "$consumer_bash_out" ] && [ -z "$consumer_zsh_out" ]; then
                ok "$consumer/$name falha fechado"
            else
                fail "$consumer/$name deveria falhar fechado"
            fi
            continue
        fi
        if [ "$consumer_bash_status" -ne 0 ] || [ "$consumer_zsh_status" -ne 0 ] || \
           [ "$consumer_bash_out" != "$consumer_zsh_out" ] || \
           [ "$(extract_string "$consumer_bash_out" profile)" != "$expect_profile" ] || \
           [ "$(extract_string "$consumer_bash_out" context_budget)" != "$expect_profile" ] || \
           [ "$(extract_string "$consumer_bash_out" validation_floor)" != "$expect_validation" ]; then
            fail "$consumer/$name divergiu da fixture canônica"
        else
            ok "$consumer/$name concorda"
        fi
    done < "$TMP_ROOT/fixture-data"
done < "$TMP_ROOT/consumers"

initial_profile="$(bash "$CLASSIFIER" --scope localized --reversibility easy --sensitive-surface none --evidence strong --ambiguity clear)"
grown_profile="$(bash "$CLASSIFIER" --scope public_contract --reversibility coordinated --sensitive-surface data_security --evidence partial --ambiguity bounded)"
critical_profile="$(bash "$CLASSIFIER" --scope public_contract --reversibility irreversible --sensitive-surface data_security --evidence partial --ambiguity bounded)"
[ "$(extract_string "$initial_profile" profile)" = compact ] || fail "perfil inicial deveria ser compact"
[ "$(extract_string "$grown_profile" profile)" = elevated ] || fail "crescimento de escopo deveria reclassificar para elevated"
[ "$(extract_string "$critical_profile" profile)" = critical ] || fail "irreversibilidade deveria reclassificar para critical"
case "$initial_profile|$grown_profile|$critical_profile" in
    *'"profile":"compact"'*'"profile":"elevated"'*'"profile":"critical"'*)
        ok "reclassificação por crescimento nunca reduz rigor" ;;
    *) fail "sequência de reclassificação inválida" ;;
esac

if [ -n "$FAILURES" ]; then
    echo "FALHOU" >&2
    printf '%b' "$FAILURES" >&2
    exit 1
fi
echo "OK — $PASS_COUNT asserções."
