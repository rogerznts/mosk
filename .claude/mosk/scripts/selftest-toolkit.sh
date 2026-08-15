#!/usr/bin/env bash
# selftest-toolkit.sh — fixtures dos contratos de gate, resolução e referências.
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VERBOSE=0
case "${1:-}" in
    --verbose) VERBOSE=1 ;;
    --help|-h)
        echo "selftest-toolkit.sh [--verbose] [--help]"
        exit 0
        ;;
    "") ;;
    *) echo "opção desconhecida: $1" >&2; exit 2 ;;
esac

# shellcheck source=/dev/null
source "$SCRIPT_DIR/common.sh"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/doctor.sh"

TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT
PASS_COUNT=0
FAILURES=""

ok() {
    PASS_COUNT=$((PASS_COUNT + 1))
    [[ "$VERBOSE" -eq 1 ]] && echo "  ok   $1"
}

fail() {
    FAILURES+="  $1"$'\n'
}

expect_ok() {
    local name="$1"
    shift
    if "$@" >/dev/null 2>&1; then ok "$name"; else fail "$name (esperado sucesso)"; fi
}

expect_fail() {
    local name="$1"
    shift
    if "$@" >/dev/null 2>&1; then fail "$name (esperado falha)"; else ok "$name"; fi
}

write_gate() {
    local dir="$1" verdict="$2" active="${3:-false}" reason="${4:-}" owner="${5:-}" at="${6:-}"
    mkdir -p "$dir"
    printf 'gate: %s\nwaiver_active: %s\nwaiver_reason: "%s"\nwaiver_approved_by: "%s"\nwaiver_approved_at: "%s"\n' \
        "$verdict" "$active" "$reason" "$owner" "$at" > "$dir/gate.yaml"
}

echo "selftest-toolkit: gate de conclusão"
gate_root="$TMP_ROOT/gates"
mkdir -p "$gate_root/missing"
expect_fail "gate ausente bloqueia" validate_gate_for_completion "$gate_root/missing"

write_gate "$gate_root/pass" PASS
expect_ok "PASS permite conclusão" validate_gate_for_completion "$gate_root/pass"

write_gate "$gate_root/fail" FAIL
expect_fail "FAIL bloqueia" validate_gate_for_completion "$gate_root/fail"

write_gate "$gate_root/concerns" CONCERNS
expect_fail "CONCERNS bloqueia" validate_gate_for_completion "$gate_root/concerns"

write_gate "$gate_root/unknown" MAYBE
expect_fail "veredito desconhecido bloqueia" validate_gate_for_completion "$gate_root/unknown"

write_gate "$gate_root/waived-incomplete" WAIVED true "risco aceito"
expect_fail "WAIVED incompleto bloqueia" validate_gate_for_completion "$gate_root/waived-incomplete"

write_gate "$gate_root/waived-bad-date" WAIVED true "risco aceito" "PO" "2026-08-15"
expect_fail "WAIVED com data inválida bloqueia" validate_gate_for_completion "$gate_root/waived-bad-date"

write_gate "$gate_root/waived" WAIVED true "risco aceito" "PO" "2026-08-15T18:00:00Z"
expect_ok "WAIVED completo permite conclusão" validate_gate_for_completion "$gate_root/waived"

echo "selftest-toolkit: resolução ativa e arquivada"
repo="$TMP_ROOT/repo"
mkdir -p "$repo/docs/specs/012-feature-active"
resolved="$(find_feature_dir_by_prefix_any "$repo" "feature/012-active")"
if [[ "$resolved" == "$repo/docs/specs/012-feature-active" ]]; then ok "resolve spec ativa"; else fail "resolve spec ativa"; fi

mkdir -p "$repo/docs/specs/archive/013-fix-archived"
resolved="$(find_feature_dir_by_prefix_any "$repo" "fix/013-archived")"
if [[ "$resolved" == "$repo/docs/specs/archive/013-fix-archived" ]]; then ok "resolve spec arquivada"; else fail "resolve spec arquivada"; fi

mkdir -p "$repo/docs/specs/013-fix-duplicate"
expect_fail "prefixo duplicado falha" find_feature_dir_by_prefix_any "$repo" "fix/013-archived"
expect_fail "branch base não vira spec" find_feature_dir_by_prefix_any "$repo" master

echo "selftest-toolkit: referências internas"
fixture="$TMP_ROOT/refs"
mkdir -p "$fixture/.claude/mosk/tasks" "$fixture/.claude/mosk/templates"
printf '# ok\n' > "$fixture/.claude/mosk/templates/exists.md"
printf 'Use `.claude/mosk/templates/exists.md`.\n' > "$fixture/.claude/mosk/tasks/valid.md"
expect_ok "referência existente passa" validate_internal_refs "$fixture" "$fixture/.claude/mosk/tasks/valid.md"

printf 'Use `.claude/mosk/templates/missing.md`.\n' > "$fixture/.claude/mosk/tasks/invalid.md"
expect_fail "referência ausente falha" validate_internal_refs "$fixture" "$fixture/.claude/mosk/tasks/invalid.md"

printf 'Use `.claude/mosk/templates/<name>.md`.\n' > "$fixture/.claude/mosk/tasks/placeholder.md"
expect_ok "placeholder genérico é ignorado" validate_internal_refs "$fixture" "$fixture/.claude/mosk/tasks/placeholder.md"

echo "selftest-toolkit: auditor autocontido"
expect_ok "audit-docs-paths roda sem PyYAML" bash "$SCRIPT_DIR/audit-docs-paths.sh" --quiet

audit_fixture="$TMP_ROOT/audit"
mkdir -p "$audit_fixture"
cp -R "$INSTALL_ROOT/.claude" "$audit_fixture/"
printf '**Save to:** `docs/legacy/output.md`\n' > "$audit_fixture/.claude/mosk/tasks/selftest-invalid-path.md"
expect_fail "path fora do domínio canônico falha" \
    bash "$audit_fixture/.claude/mosk/scripts/audit-docs-paths.sh" --quiet
rm -f "$audit_fixture/.claude/mosk/tasks/selftest-invalid-path.md"

printf 'Leia `prd.chaveInexistente`.\n' > "$audit_fixture/.claude/mosk/tasks/selftest-invalid-config.md"
expect_fail "chave de config inexistente falha" \
    bash "$audit_fixture/.claude/mosk/scripts/audit-docs-paths.sh" --quiet
rm -f "$audit_fixture/.claude/mosk/tasks/selftest-invalid-config.md"

printf 'Use `.claude/mosk/templates/missing-tmpl.md`.\n' > "$audit_fixture/.claude/mosk/tasks/selftest-invalid-template.md"
expect_fail "template referenciado inexistente falha" \
    bash "$audit_fixture/.claude/mosk/scripts/audit-docs-paths.sh" --quiet

run_ship_ready() {
    (cd "$1" && bash .claude/mosk/scripts/check-ship-ready.sh --json)
}

echo "selftest-toolkit: ship-ready arquivado"
ship_repo="$TMP_ROOT/ship-ready"
mkdir -p "$ship_repo/.claude/mosk/scripts" \
    "$ship_repo/docs/specs/archive/014-feature-ship-ready"
cp "$SCRIPT_DIR/common.sh" "$SCRIPT_DIR/check-ship-ready.sh" \
    "$ship_repo/.claude/mosk/scripts/"
printf '%s\n' \
    'spec_id: "014-feature-ship-ready"' \
    'current_phase: archived' \
    > "$ship_repo/docs/specs/archive/014-feature-ship-ready/spec-meta.yaml"
write_gate "$ship_repo/docs/specs/archive/014-feature-ship-ready" PASS
git -C "$ship_repo" init -q
git -C "$ship_repo" config user.name "MOSK Selftest"
git -C "$ship_repo" config user.email "selftest@invalid.local"
git -C "$ship_repo" checkout -q -b feature/014-ship-ready
git -C "$ship_repo" add .
git -C "$ship_repo" commit -qm "test: create archived fixture"
expect_ok "ship-ready encontra spec arquivada com PASS" run_ship_ready "$ship_repo"

write_gate "$ship_repo/docs/specs/archive/014-feature-ship-ready" FAIL
git -C "$ship_repo" add .
git -C "$ship_repo" commit -qm "test: set blocking gate"
expect_fail "ship-ready bloqueia gate FAIL arquivado" run_ship_ready "$ship_repo"

if [[ -n "$FAILURES" ]]; then
    echo "FALHOU" >&2
    printf '%s' "$FAILURES" >&2
    exit 1
fi

echo "OK — $PASS_COUNT asserções."
