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

expect_fail_contains() {
    local name="$1" expected="$2"
    shift 2
    local output status
    output="$("$@" 2>&1)"
    status=$?
    if [[ "$status" -ne 0 ]] && printf '%s' "$output" | grep -Fq "$expected"; then
        ok "$name"
    else
        fail "$name (esperado falha contendo '$expected'; status=$status; saída=$output)"
    fi
}

write_gate() {
    local dir="$1" verdict="$2" active="${3:-false}" reason="${4:-}" owner="${5:-}" at="${6:-}"
    mkdir -p "$dir"
    printf 'schema: 2\nstory: "selftest"\nstory_title: "Toolkit fixture"\ngate: %s\nquality_score: 100\nscore_history: [100]\nstatus_reason: "fixture"\nreviewer: "Self Test"\nupdated: "2026-08-15T18:00:00Z"\nevidence_ref: "qa-notes.md"\nwaiver_active: %s\nwaiver_reason: "%s"\nwaiver_approved_by: "%s"\nwaiver_approved_at: "%s"\n' \
        "$verdict" "$active" "$reason" "$owner" "$at" > "$dir/gate.yaml"
    printf '# Evidence\n' > "$dir/qa-notes.md"
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

write_gate "$gate_root/waived-blank" WAIVED true "   " "   " "2026-08-15T18:00:00Z"
expect_fail "WAIVED com motivo e aprovador em branco bloqueia" validate_gate_for_completion "$gate_root/waived-blank"

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

printf 'Use `../templates/exists.md`.\n' > "$fixture/.claude/mosk/tasks/relative-valid.md"
expect_ok "referência relativa existente passa" validate_internal_refs "$fixture" "$fixture/.claude/mosk/tasks/relative-valid.md"

printf 'Use `../templates/relative-missing.md`.\n' > "$fixture/.claude/mosk/tasks/relative-invalid.md"
expect_fail "referência relativa ausente falha" validate_internal_refs "$fixture" "$fixture/.claude/mosk/tasks/relative-invalid.md"

echo "selftest-toolkit: contenção de promote"
promotion_repo="$TMP_ROOT/promotions"
mkdir -p "$promotion_repo/docs/safe" "$promotion_repo/outside"
ln -s "$promotion_repo/outside" "$promotion_repo/docs/escape"
expect_ok "destino canônico sob docs passa" validate_promotion_target "$promotion_repo" "docs/safe/output.md" copy
expect_ok "modo manual com destino canônico passa" validate_promotion_target "$promotion_repo" "docs/safe/manual.md" manual
expect_fail "destino absoluto bloqueia" validate_promotion_target "$promotion_repo" "/tmp/mosk-output.md" copy
expect_fail "segmento traversal bloqueia" validate_promotion_target "$promotion_repo" "docs/../outside.md" append
expect_fail "escape por symlink bloqueia" validate_promotion_target "$promotion_repo" "docs/escape/output.md" copy
expect_fail "destino que termina em diretório bloqueia" validate_promotion_target "$promotion_repo" "docs/safe/" copy
expect_fail "modo desconhecido bloqueia" validate_promotion_target "$promotion_repo" "docs/safe/output.md" overwrite

run_zsh_promotion() {
    zsh -c 'source "$1"; validate_promotion_target "$2" "$3" "$4"' \
        _ "$SCRIPT_DIR/common.sh" "$1" "$2" "$3"
}

expect_ok "zsh aceita destino canônico" run_zsh_promotion "$promotion_repo" "docs/safe/output.md" copy
expect_fail "zsh bloqueia separador duplo" run_zsh_promotion "$promotion_repo" "docs/safe//output.md" copy
expect_fail "zsh bloqueia segmento ponto" run_zsh_promotion "$promotion_repo" "docs/safe/./output.md" copy
expect_fail "zsh bloqueia traversal" run_zsh_promotion "$promotion_repo" "docs/safe/../output.md" append

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

run_ship_ready_branch() {
    (cd "$1" && SPECIFY_FEATURE="$2" bash .claude/mosk/scripts/check-ship-ready.sh --json)
}

echo "selftest-toolkit: ship-ready arquivado"
ship_repo="$TMP_ROOT/ship-ready"
mkdir -p "$ship_repo/.claude/mosk/scripts" \
    "$ship_repo/docs/specs/archive/014-feature-ship-ready"
cp "$SCRIPT_DIR/common.sh" "$SCRIPT_DIR/check-ship-ready.sh" \
    "$ship_repo/.claude/mosk/scripts/"
printf '%s\n' \
    'schema: 1' \
    'spec_number: "014"' \
    'spec_id: "014-feature-ship-ready"' \
    'type: feature' \
    'branch: "feature/014-ship-ready"' \
    'status: archived' \
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

expect_fail_contains "ship-ready bloqueia branch de spec sem diretório" \
    "spec não encontrada" run_ship_ready_branch "$ship_repo" "feature/015-missing-spec"

mkdir -p "$ship_repo/docs/specs/016-feature-duplicate" \
    "$ship_repo/docs/specs/archive/016-feature-duplicate"
printf '%s\n' \
    'schema: 1' 'spec_number: "016"' 'spec_id: "016-feature-duplicate"' \
    'type: feature' 'branch: "feature/016-duplicate"' 'status: active' \
    'current_phase: specify' \
    > "$ship_repo/docs/specs/016-feature-duplicate/spec-meta.yaml"
printf '%s\n' \
    'schema: 1' 'spec_number: "016"' 'spec_id: "016-feature-duplicate"' \
    'type: feature' 'branch: "feature/016-duplicate"' 'status: archived' \
    'current_phase: archived' \
    > "$ship_repo/docs/specs/archive/016-feature-duplicate/spec-meta.yaml"
expect_fail_contains "ship-ready bloqueia resolução ambígua" \
    "spec ambígua" run_ship_ready_branch "$ship_repo" "feature/016-duplicate"
rm -rf "$ship_repo/docs/specs/016-feature-duplicate" \
    "$ship_repo/docs/specs/archive/016-feature-duplicate"

mkdir -p "$ship_repo/docs/specs/017-feature-no-meta"
expect_fail_contains "ship-ready bloqueia spec sem metadata" \
    "spec-meta.yaml ausente" run_ship_ready_branch "$ship_repo" "feature/017-no-meta"
rm -rf "$ship_repo/docs/specs/017-feature-no-meta"

write_gate "$ship_repo/docs/specs/archive/014-feature-ship-ready" FAIL
git -C "$ship_repo" add .
git -C "$ship_repo" commit -qm "test: set blocking gate"
expect_fail "ship-ready bloqueia gate FAIL arquivado" run_ship_ready "$ship_repo"

write_gate "$ship_repo/docs/specs/archive/014-feature-ship-ready" PASS
printf '%s\n' \
    '---' \
    'promote: docs/../outside.md' \
    'promote_mode: append' \
    '---' \
    > "$ship_repo/docs/specs/archive/014-feature-ship-ready/unsafe-promote.md"
git -C "$ship_repo" add .
git -C "$ship_repo" commit -qm "test: add unsafe promote fixture"
expect_fail_contains "ship-ready bloqueia promote com traversal" \
    "promote inválido" run_ship_ready "$ship_repo"

echo "selftest-toolkit: superfície legada"
legacy_fixture="$TMP_ROOT/legacy-surface"
mkdir -p "$legacy_fixture/.claude/mosk/data" \
    "$legacy_fixture/.claude/mosk/tasks" \
    "$legacy_fixture/.claude/agents"
printf '# fixture\n' > "$legacy_fixture/.claude/mosk/tasks/sample.md"
printf '# consumer\n' > "$legacy_fixture/.claude/agents/mosk-sample.md"
printf 'path_pattern\tkind\treason\n' \
    > "$legacy_fixture/.claude/mosk/data/legacy-reference-allowlist.tsv"
write_legacy_catalog() {
    printf 'task\taction\tdestination\tconsumers\tevidence\treason\n' \
        > "$legacy_fixture/.claude/mosk/data/task-dispositions.tsv"
    printf '%b\n' "$1" >> "$legacy_fixture/.claude/mosk/data/task-dispositions.tsv"
}
run_legacy_audit() {
    bash "$SCRIPT_DIR/audit-legacy-surface.sh" \
        --root "$legacy_fixture" --expected-count 1
}

base_row="sample.md	keep		.claude/agents/mosk-sample.md	not_applicable	fixture válida"
write_legacy_catalog "$base_row"
expect_ok "inventário mínimo válido passa" run_legacy_audit

rm -f "$legacy_fixture/.claude/mosk/tasks/sample.md"
expect_fail_contains "task ausente falha" "task ausente sem absorção coberta" run_legacy_audit
printf '# fixture\n' > "$legacy_fixture/.claude/mosk/tasks/sample.md"

write_legacy_catalog "$base_row"
printf '%b\n' "$base_row" >> "$legacy_fixture/.claude/mosk/data/task-dispositions.tsv"
expect_fail_contains "task duplicada falha" "task ausente/duplicada" run_legacy_audit

write_legacy_catalog "sample.md	invalid		.claude/agents/mosk-sample.md	pending	ação inválida"
expect_fail_contains "ação de inventário inválida falha" "ação inválida" run_legacy_audit

write_legacy_catalog "sample.md	merge		.claude/agents/mosk-sample.md	pending	merge sem destino"
expect_fail_contains "merge sem destino falha" "merge sem destino" run_legacy_audit

write_legacy_catalog "sample.md	keep		.claude/agents/missing.md	not_applicable	consumer inválido"
expect_fail_contains "consumidor órfão falha" "consumidor órfão" run_legacy_audit

rm -f "$legacy_fixture/.claude/mosk/tasks/sample.md"
printf '# destino\n' > "$legacy_fixture/.claude/mosk/tasks/destination.md"
printf 'Use `.claude/mosk/tasks/sample.md`.\n' > "$legacy_fixture/.claude/agents/mosk-sample.md"
write_legacy_catalog "sample.md	merge	.claude/mosk/tasks/destination.md	.claude/agents/mosk-sample.md	covered	capacidade absorvida"
expect_fail_contains "referência ativa a task removida falha" "referência ativa a path removido" run_legacy_audit

rm -f "$legacy_fixture/.claude/mosk/tasks/destination.md"
printf '# fixture\n%s%s controla este fluxo.\n' 'BM' 'AD' > "$legacy_fixture/.claude/mosk/tasks/sample.md"
printf '# consumer\n' > "$legacy_fixture/.claude/agents/mosk-sample.md"
write_legacy_catalog "$base_row"
expect_fail_contains "legado operacional fora da allowlist falha" "referência legada operacional" run_legacy_audit

printf '# fixture\n<!-- Inspired by %s%s -->\n' 'BM' 'AD' > "$legacy_fixture/.claude/mosk/tasks/sample.md"
printf 'path_pattern\tkind\treason\n.claude/mosk/tasks/sample.md\tattribution\tAtribuição histórica da fixture.\n' \
    > "$legacy_fixture/.claude/mosk/data/legacy-reference-allowlist.tsv"
expect_ok "atribuição legada explicitamente permitida passa" run_legacy_audit

echo "selftest-toolkit: classificador adaptativo integrado"
expect_ok "selftest adaptativo passa" bash "$SCRIPT_DIR/selftest-adaptive-work.sh"

if [[ -n "$FAILURES" ]]; then
    echo "FALHOU" >&2
    printf '%s' "$FAILURES" >&2
    exit 1
fi

echo "OK — $PASS_COUNT asserções."
