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

file_contains() {
    grep -Fq "$2" "$1"
}

file_not_contains_pattern() {
    ! grep -Eq "$2" "$1"
}

file_contains_pattern() {
    grep -Eiq "$2" "$1"
}

exact_occurrences() {
    local file="$1" needle="$2" expected="$3" actual
    actual="$(grep -Fc "$needle" "$file" || true)"
    [[ "$actual" -eq "$expected" ]]
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
# -L dereferencia symlinks: o espelho local aponta `data/hallmark` para o
# vendor do template, e o degit entrega arquivo real. A fixture precisa ser a
# instalação, não o atalho de quem desenvolve.
cp -RL "$INSTALL_ROOT/.claude" "$audit_fixture/"
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
# A auditoria falha fechada sem baseline de medição e sem os contratos
# canônicos; a fixture mínima precisa dos dois para exercitar o resto.
printf 'task\tbaseline_lines\n' \
    > "$legacy_fixture/.claude/mosk/data/legacy-baseline-metrics.tsv"
cp "$INSTALL_ROOT/.claude/mosk/data/adaptive-work-contract.md" \
    "$INSTALL_ROOT/.claude/mosk/data/output-contract.md" \
    "$legacy_fixture/.claude/mosk/data/"
write_legacy_catalog() {
    printf 'task\taction\tdestination\tconsumers\tevidence\treason\n' \
        > "$legacy_fixture/.claude/mosk/data/task-dispositions.tsv"
    printf '%b\n' "$1" >> "$legacy_fixture/.claude/mosk/data/task-dispositions.tsv"
}
run_legacy_audit() {
    bash "$SCRIPT_DIR/audit-legacy-surface.sh" \
        --root "$legacy_fixture" --expected-count 1
}
write_merged_fixture() {
    local evidence="${1:-covered}"
    {
        printf '%s\n' '<!-- merged-task-fixtures:start -->'
        printf 'legacy_task\tcapability\tentrypoints\tdestinations\texpected_result\tevidence\n'
        printf 'sample.md\tsample-capability\t.claude/agents/mosk-sample.md\t.claude/mosk/data/destination.md\tcapacidade preservada\t%s\n' "$evidence"
        printf '%s\n' '<!-- merged-task-fixtures:end -->'
    } > "$legacy_fixture/.claude/mosk/data/merged-task-fixtures.md"
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
printf '# destino\n' > "$legacy_fixture/.claude/mosk/data/destination.md"
printf 'Use `.claude/mosk/tasks/sample.md`.\n' > "$legacy_fixture/.claude/agents/mosk-sample.md"
write_legacy_catalog "sample.md	merge	.claude/mosk/data/destination.md	.claude/agents/mosk-sample.md	covered	capacidade absorvida"
expect_fail_contains "merge coberto sem fixture falha" "fixture de capacidade ausente/duplicada" run_legacy_audit

write_merged_fixture pending
expect_fail_contains "fixture sem cobertura falha" "fixture sem cobertura" run_legacy_audit

write_merged_fixture covered
expect_fail_contains "rota sem marcador de capability falha" "rota sem marcador de capability" run_legacy_audit

printf '# destino\n<!-- Capability: sample-capability -->\n' > "$legacy_fixture/.claude/mosk/data/destination.md"
printf '<!-- Capability: sample-capability -->\nUse `.claude/mosk/tasks/sample.md`.\n' > "$legacy_fixture/.claude/agents/mosk-sample.md"
expect_fail_contains "referência ativa a task removida falha" "referência ativa a path removido" run_legacy_audit

printf '<!-- Capability: sample-capability -->\n# consumer\n' > "$legacy_fixture/.claude/agents/mosk-sample.md"
expect_ok "merge removido com destino, rota e cobertura passa" run_legacy_audit

rm -f "$legacy_fixture/.claude/mosk/data/destination.md"
expect_fail_contains "destino removido depois da fusão falha" "destino ausente" run_legacy_audit

rm -f "$legacy_fixture/.claude/mosk/data/merged-task-fixtures.md"
printf '# fixture\n%s%s controla este fluxo.\n' 'BM' 'AD' > "$legacy_fixture/.claude/mosk/tasks/sample.md"
printf '# consumer\n' > "$legacy_fixture/.claude/agents/mosk-sample.md"
write_legacy_catalog "$base_row"
expect_fail_contains "legado operacional fora da allowlist falha" "referência legada operacional" run_legacy_audit

printf '# fixture\n<!-- Inspired by %s%s -->\n' 'BM' 'AD' > "$legacy_fixture/.claude/mosk/tasks/sample.md"
printf 'path_pattern\tkind\treason\n.claude/mosk/tasks/sample.md\tattribution\tAtribuição histórica da fixture.\n' \
    > "$legacy_fixture/.claude/mosk/data/legacy-reference-allowlist.tsv"
expect_ok "atribuição legada explicitamente permitida passa" run_legacy_audit

# `.claude/rules/` é contexto do projeto consumidor, não superfície do toolkit:
# um projeto que usa a ferramenta legada pode dizer isso na própria rule sem que
# a auditoria do MOSK o repreenda. Sem este caso, a exclusão seria comportamento
# sem prova e a primeira refatoração a reintroduziria.
mkdir -p "$legacy_fixture/.claude/rules"
printf '# regra local\nO time ainda descreve o fluxo antigo do %s%s aqui.\n' 'BM' 'AD' \
    > "$legacy_fixture/.claude/rules/project.md"
expect_ok "termo legado em rules do projeto não é cobrado" run_legacy_audit
rm -rf "$legacy_fixture/.claude/rules"

echo "selftest-toolkit: capacidades fundidas"
merged_fixtures="$INSTALL_ROOT/.claude/mosk/data/merged-task-fixtures.md"
expect_ok "fixtures de fusão existem" test -f "$merged_fixtures"
expect_ok "project mapping possui uma fixture" exact_occurrences "$merged_fixtures" $'map-project.md\tproject-mapping\t' 1
expect_ok "story review possui uma fixture" exact_occurrences "$merged_fixtures" $'review-story.md\tpost-implementation-story-review\t' 1
expect_ok "entrega UI completa possui uma fixture" exact_occurrences "$merged_fixtures" $'webdesign-output.md\tcomplete-ui-delivery\t' 1
expect_ok "boot expõe project mapping" file_contains "$INSTALL_ROOT/.claude/mosk/tasks/boot.md" 'Capability: project-mapping'
expect_ok "Architect expõe project mapping" file_contains "$INSTALL_ROOT/.claude/agents/mosk-architect.md" 'Capability: project-mapping'
expect_ok "qa-gate expõe revisão pós-implementação" file_contains "$INSTALL_ROOT/.claude/mosk/tasks/qa-gate.md" 'Capability: post-implementation-story-review'
expect_ok "QA expõe revisão pós-implementação" file_contains "$INSTALL_ROOT/.claude/agents/mosk-qa.md" 'Capability: post-implementation-story-review'
expect_ok "Hallmark expõe entrega completa" file_contains "$INSTALL_ROOT/.claude/mosk/tasks/hallmark.md" 'Capability: complete-ui-delivery'
expect_ok "UI Expert expõe entrega completa" file_contains "$INSTALL_ROOT/.claude/agents/mosk-ui-expert.md" 'Capability: complete-ui-delivery'
removed_task_dir="$INSTALL_ROOT/.claude/mosk/tasks"
expect_fail "task antiga de project mapping foi removida" test -e "$removed_task_dir/map-project.md"
expect_fail "task antiga de story review foi removida" test -e "$removed_task_dir/review-story.md"
expect_fail "task antiga de output visual foi removida" test -e "$removed_task_dir/webdesign-output.md"
expect_ok "auditoria aceita as três fusões" bash "$SCRIPT_DIR/audit-legacy-surface.sh" --root "$INSTALL_ROOT" --expected-count 50 --quiet

echo "selftest-toolkit: fluxo documental direto"
direct_fixture="$INSTALL_ROOT/.claude/mosk/data/direct-flow-fixtures.md"
create_doc="$INSTALL_ROOT/.claude/mosk/tasks/create-doc.md"
advanced_elicitation="$INSTALL_ROOT/.claude/mosk/tasks/advanced-elicitation.md"

expect_ok "fixtures do fluxo direto existem" test -f "$direct_fixture"
expect_ok "pedido claro usa zero rodadas" \
    exact_occurrences "$direct_fixture" '## clear-request' 1
expect_ok "ambiguidade material usa uma rodada" \
    exact_occurrences "$direct_fixture" '`clarification_rounds: 1`' 1
expect_ok "demais fixtures não abrem entrevista" \
    exact_occurrences "$direct_fixture" '`clarification_rounds: 0`' 3
expect_ok "fixture avançada exige ativação explícita" \
    file_contains "$direct_fixture" '`activation: explicit_only`'
expect_ok "fixture irreversível preserva pausa humana" \
    exact_occurrences "$direct_fixture" '`human_pause: true`' 1

expect_ok "create-doc consome contrato adaptativo" \
    file_contains "$create_doc" '.claude/mosk/data/adaptive-work-contract.md'
expect_ok "create-doc concentra uma rodada agrupada" \
    file_contains "$create_doc" 'uma única rodada agrupada'
expect_ok "create-doc não contém menu obrigatório" \
    file_not_contains_pattern "$create_doc" 'Select 1-9|Choose a number|MANDATORY.*ELICITATION|ELICITATION IS REQUIRED|1-9 options'
expect_ok "advanced-elicitation declara opt-in" \
    file_contains "$advanced_elicitation" 'pedir explicitamente'
expect_ok "advanced-elicitation não contém menu obrigatório" \
    file_not_contains_pattern "$advanced_elicitation" 'Choose a number|0-9 selection|re-offer'

direct_tasks="
$INSTALL_ROOT/.claude/mosk/tasks/create-brief.md
$INSTALL_ROOT/.claude/mosk/tasks/create-market-research.md
$INSTALL_ROOT/.claude/mosk/tasks/create-competitor-analysis.md
$INSTALL_ROOT/.claude/mosk/tasks/create-deep-research-prompt.md
"
direct_templates="
$INSTALL_ROOT/.claude/mosk/templates/project-brief-tmpl.yaml
$INSTALL_ROOT/.claude/mosk/templates/market-research-tmpl.yaml
$INSTALL_ROOT/.claude/mosk/templates/competitor-analysis-tmpl.yaml
$INSTALL_ROOT/.claude/mosk/templates/prd-tmpl.yaml
$INSTALL_ROOT/.claude/mosk/templates/architecture-tmpl.yaml
$INSTALL_ROOT/.claude/mosk/templates/existing-project-architecture-tmpl.yaml
$INSTALL_ROOT/.claude/mosk/templates/front-end-architecture-tmpl.yaml
$INSTALL_ROOT/.claude/mosk/templates/fullstack-architecture-tmpl.yaml
"
pipeline_tasks="
$INSTALL_ROOT/.claude/mosk/tasks/full-spec.md
$INSTALL_ROOT/.claude/mosk/tasks/specify.md
$INSTALL_ROOT/.claude/mosk/tasks/plan.md
$INSTALL_ROOT/.claude/mosk/tasks/tasks.md
"
direct_agents="
$INSTALL_ROOT/.claude/agents/mosk-analyst.md
$INSTALL_ROOT/.claude/agents/mosk-po.md
$INSTALL_ROOT/.claude/agents/mosk-pm.md
$INSTALL_ROOT/.claude/agents/mosk-architect.md
"

direct_contract_ok() {
    local file
    printf '%s\n' "$direct_tasks" | while IFS= read -r file; do
        [[ -z "$file" ]] && continue
        file_not_contains_pattern "$file" 'Select 1-9|1-9 options|Choose a number|HARD STOP' || exit 1
        file_contains "$file" 'uma única rodada' || exit 1
    done
}

template_contract_ok() {
    local file
    printf '%s\n' "$direct_templates" | while IFS= read -r file; do
        [[ -z "$file" ]] && continue
        file_contains "$file" 'mode: direct' || exit 1
        file_contains "$file" 'clarification: grouped-once' || exit 1
        file_contains "$file" 'elicitation: opt-in' || exit 1
        file_not_contains_pattern "$file" 'elicit:[[:space:]]*true|elicitation:[[:space:]]*advanced-elicitation' || exit 1
    done
}

pipeline_contract_ok() {
    local file
    printf '%s\n' "$pipeline_tasks" | while IFS= read -r file; do
        [[ -z "$file" ]] && continue
        file_contains_pattern "$file" 'uma.*rodada|one.*round|one grouped' || exit 1
        file_not_contains_pattern "$file" 'Select 1-9|1-9 options|Choose a number|HARD STOP' || exit 1
    done
}

agent_contract_ok() {
    local file
    printf '%s\n' "$direct_agents" | while IFS= read -r file; do
        [[ -z "$file" ]] && continue
        file_contains_pattern "$file" 'uma.*rodada|one.*round' || exit 1
        file_contains_pattern "$file" 'advanced elicitation.*explicit|elicitação avançada.*explícit' || exit 1
    done
}

expect_ok "wrappers documentais usam contrato direto" direct_contract_ok
expect_ok "templates alvo não impõem hard stop" template_contract_ok
expect_ok "pipeline limita clarificação a uma rodada" pipeline_contract_ok
expect_ok "agentes consumidores expõem opt-in explícito" agent_contract_ok

echo "selftest-toolkit: instalação isolada"
# Materialização distribuível: apenas o conteúdo que o degit entrega a partir
# de mosk/. Toda verificação desta seção roda contra ela, nunca contra o
# repositório de desenvolvimento — é a única forma de provar que a instrução
# se sustenta sozinha depois de instalada.
iso_root="$TMP_ROOT/isolated"
mkdir -p "$iso_root"
cp -RL "$INSTALL_ROOT/.claude" "$iso_root/.claude"

# Superfície de instrução: o que o agente lê para agir. Scripts ficam de fora
# de propósito — são código, e suas referências internas já são cobertas pelo
# bloco anterior e pelo doctor.
iso_surface=(
    "$iso_root/.claude/agents"
    "$iso_root/.claude/skills"
    "$iso_root/.claude/mosk/tasks"
    "$iso_root/.claude/mosk/templates"
    "$iso_root/.claude/mosk/checklists"
    "$iso_root/.claude/mosk/utils"
    "$iso_root/.claude/README.md"
)
# data/ entra arquivo a arquivo: data/hallmark/ é fork vendorizado com 100+
# arquivos upstream e não segue as regras de referência do MOSK.
for iso_data in "$iso_root"/.claude/mosk/data/*; do
    [[ -f "$iso_data" ]] && iso_surface+=("$iso_data")
done

# Raiz que contém docs/specs — o repositório de desenvolvimento quando o
# toolkit é editado a partir de mosk/. Numa materialização pura ela não
# existe, e a comparação vira no-op de propósito.
resolve_dev_specs_root() {
    local candidate
    for candidate in "$INSTALL_ROOT" "$(cd "$INSTALL_ROOT/.." && pwd)"; do
        if [[ -d "$candidate/docs/specs" ]]; then
            printf '%s' "$candidate"
            return 0
        fi
    done
    return 1
}

# Falha quando uma instrução depende de caminho disponível apenas no
# repositório de desenvolvimento: o prefixo `mosk/`, que o degit não entrega,
# ou uma spec concreta de docs/specs/ que só existe lá.
validate_isolated_refs() {
    local iso="$1" dev_specs="$2"
    shift 2
    local failed=0 scan file line ref
    for scan in "$@"; do
        [[ -e "$scan" ]] || continue
        while IFS=: read -r file line ref; do
            [[ -n "$ref" ]] || continue
            case "$ref" in
                */|*'<'*|*'{'*|*'*'*|*NAME*) continue ;;
            esac
            case "$ref" in
                mosk/.claude/*)
                    echo "${file#$iso/}:$line :: ISOLADA :: '$ref' usa o prefixo 'mosk/', ausente na instalação"
                    failed=1
                    ;;
                docs/specs/*)
                    [[ -n "$dev_specs" ]] || continue
                    [[ -e "$dev_specs/$ref" ]] || continue
                    echo "${file#$iso/}:$line :: ISOLADA :: '$ref' só existe no repositório de desenvolvimento"
                    failed=1
                    ;;
            esac
        done < <(grep -rnEo '(mosk/\.claude|docs/specs/[0-9]{3})[A-Za-z0-9._/-]*' "$scan" 2>/dev/null || true)
    done
    return "$failed"
}

iso_dev_specs="$(resolve_dev_specs_root || true)"
expect_ok "instalação isolada não depende do repositório de desenvolvimento" \
    validate_isolated_refs "$iso_root" "$iso_dev_specs" "${iso_surface[@]}"
expect_ok "referências internas resolvem na materialização" \
    validate_internal_refs "$iso_root" "${iso_surface[@]}"

printf 'Rode `%s/.claude/mosk/scripts/sync-agents-skills.sh`.\n' 'mosk' \
    > "$iso_root/.claude/mosk/tasks/selftest-dev-prefix.md"
expect_fail_contains "prefixo do repositório de desenvolvimento falha" \
    "ausente na instalação" \
    validate_isolated_refs "$iso_root" "$iso_dev_specs" "$iso_root/.claude/mosk/tasks/selftest-dev-prefix.md"
rm -f "$iso_root/.claude/mosk/tasks/selftest-dev-prefix.md"

iso_fake_dev="$TMP_ROOT/fake-dev"
mkdir -p "$iso_fake_dev/docs/specs/099-feature-selftest"
printf 'Leia `docs/specs/099-feature-selftest`.\n' \
    > "$iso_root/.claude/mosk/tasks/selftest-dev-spec.md"
expect_fail_contains "spec concreta do repositório de desenvolvimento falha" \
    "só existe no repositório de desenvolvimento" \
    validate_isolated_refs "$iso_root" "$iso_fake_dev" "$iso_root/.claude/mosk/tasks/selftest-dev-spec.md"
expect_ok "exemplo de spec inexistente não é cobrado" \
    validate_isolated_refs "$iso_root" "$TMP_ROOT/sem-docs" "$iso_root/.claude/mosk/tasks/selftest-dev-spec.md"
rm -f "$iso_root/.claude/mosk/tasks/selftest-dev-spec.md"

printf 'Use `.claude/mosk/data/selftest-inexistente.md`.\n' \
    > "$iso_root/.claude/mosk/tasks/selftest-broken-ref.md"
expect_fail "referência quebrada na materialização falha" \
    validate_internal_refs "$iso_root" "$iso_root/.claude/mosk/tasks/selftest-broken-ref.md"
rm -f "$iso_root/.claude/mosk/tasks/selftest-broken-ref.md"

echo "selftest-toolkit: carregamento sob demanda"
# Material movido para referência só é carregado se a task o declarar e o
# arquivo existir. As duas pontas são verificadas: declaração sem arquivo, e
# arquivo sem nenhum consumidor que o declare.

dependency_dir_for_key() {
    case "$1" in
        data) printf '.claude/mosk/data' ;;
        scripts) printf '.claude/mosk/scripts' ;;
        templates) printf '.claude/mosk/templates' ;;
        schemas) printf '.claude/mosk/schemas' ;;
        checklists) printf '.claude/mosk/checklists' ;;
        tasks) printf '.claude/mosk/tasks' ;;
        utils) printf '.claude/mosk/utils' ;;
        *) return 1 ;;
    esac
}

trim_ws() {
    local value="$1"
    value="${value#"${value%%[![:space:]]*}"}"
    value="${value%"${value##*[![:space:]]}"}"
    printf '%s' "$value"
}

# Aceita as duas formas de declaração em uso: bloco YAML com basenames por
# domínio (`data:`, `scripts:`, …) e bullets em prosa com o path completo.
validate_declared_dependencies() {
    local root="$1" failed=0 file rel
    local in_section in_block dir line item key rest lineno
    for file in "$root"/.claude/mosk/tasks/*.md; do
        [[ -f "$file" ]] || continue
        rel="${file#$root/}"
        in_section=0
        in_block=0
        dir=""
        lineno=0
        while IFS= read -r line || [[ -n "$line" ]]; do
            lineno=$((lineno + 1))
            case "$line" in
                '## Depend'*) in_section=1; in_block=0; dir=""; continue ;;
                '## '*) in_section=0 ;;
            esac
            [[ "$in_section" -eq 1 ]] || continue
            case "$line" in
                '```'*) in_block=$((1 - in_block)); dir=""; continue ;;
            esac
            if [[ "$in_block" -eq 1 ]]; then
                case "$line" in
                    [a-z]*:)
                        key="${line%:}"
                        dir="$(dependency_dir_for_key "$key" || true)"
                        continue
                        ;;
                    *-\ *) ;;
                    *) continue ;;
                esac
                [[ -n "$dir" ]] || continue
                item="${line#*- }"
                item="${item%%#*}"
                item="$(trim_ws "$item")"
                [[ -n "$item" ]] || continue
                case "$item" in
                    */|*'<'*|*'{'*|*'*'*) continue ;;
                esac
                if [[ ! -e "$root/$dir/$item" ]]; then
                    echo "$rel:$lineno :: DEP :: '$dir/$item' declarado e ausente"
                    failed=1
                fi
            else
                rest="$line"
                while [[ "$rest" == *'`'*'`'* ]]; do
                    rest="${rest#*\`}"
                    item="${rest%%\`*}"
                    rest="${rest#*\`}"
                    case "$item" in
                        .claude/mosk/*) ;;
                        *) continue ;;
                    esac
                    case "$item" in
                        */|*'<'*|*'{'*|*'*'*) continue ;;
                    esac
                    if [[ ! -e "$root/$item" ]]; then
                        echo "$rel:$lineno :: DEP :: '$item' declarado e ausente"
                        failed=1
                    fi
                done
            fi
        done < "$file"
    done
    return "$failed"
}

# Referência que ninguém declara é material que nunca é carregado. O match é
# pelo radical do nome: um consumidor declara o arquivo ao nomeá-lo, com ou
# sem extensão. data/hallmark/ está fora — fork vendorizado, não é referência
# MOSK.
validate_no_orphan_references() {
    local root="$1" failed=0 file base stem
    for file in "$root"/.claude/mosk/data/*; do
        [[ -f "$file" ]] || continue
        base="$(basename "$file")"
        stem="${base%.*}"
        if ! grep -rlF --exclude-dir=data "$stem" "$root/.claude" >/dev/null 2>&1; then
            echo ".claude/mosk/data/$base :: ÓRFÃ :: nenhum consumidor declara esta referência"
            failed=1
        fi
    done
    return "$failed"
}

expect_ok "dependências declaradas existem na materialização" \
    validate_declared_dependencies "$iso_root"
expect_ok "referências de data têm ao menos um consumidor" \
    validate_no_orphan_references "$iso_root"

expect_ok "par sob demanda do bench declara a referência" \
    file_contains "$iso_root/.claude/mosk/tasks/bench-mode.md" \
    '.claude/mosk/data/bench-runtime-reference.md'
expect_ok "par sob demanda do planner declara a referência" \
    file_contains "$iso_root/.claude/mosk/tasks/planner.md" \
    '.claude/mosk/data/planner-reference.md'

printf '# t\n\n## Dependencies\n\n```yaml\ndata:\n  - selftest-ausente.md\n```\n' \
    > "$iso_root/.claude/mosk/tasks/selftest-dep-yaml.md"
expect_fail_contains "dependência declarada em bloco e ausente falha" \
    "declarado e ausente" validate_declared_dependencies "$iso_root"
rm -f "$iso_root/.claude/mosk/tasks/selftest-dep-yaml.md"

printf '# t\n\n## Dependências\n\n- `%s` — referência sob demanda.\n' \
    '.claude/mosk/data/selftest-ausente.md' \
    > "$iso_root/.claude/mosk/tasks/selftest-dep-prose.md"
expect_fail_contains "dependência declarada em prosa e ausente falha" \
    "declarado e ausente" validate_declared_dependencies "$iso_root"
rm -f "$iso_root/.claude/mosk/tasks/selftest-dep-prose.md"

# O radical é montado em partes: este script vive dentro da materialização, e
# o nome escrito por extenso aqui tornaria a própria fixture seu consumidor.
iso_orphan_stem="selftest-$(printf '%s%s' 'orph' 'an')-probe"
printf '# ninguém carrega isto\n' \
    > "$iso_root/.claude/mosk/data/$iso_orphan_stem.md"
expect_fail_contains "referência sem consumidor falha" \
    "nenhum consumidor declara" validate_no_orphan_references "$iso_root"
rm -f "$iso_root/.claude/mosk/data/$iso_orphan_stem.md"

printf '# vendor upstream\n' \
    > "$iso_root/.claude/mosk/data/hallmark/selftest-orphan-vendor.md"
expect_ok "arquivo do fork vendorizado não é cobrado como referência" \
    validate_no_orphan_references "$iso_root"
rm -f "$iso_root/.claude/mosk/data/hallmark/selftest-orphan-vendor.md"

echo "selftest-toolkit: classificador adaptativo integrado"
expect_ok "selftest adaptativo passa" bash "$SCRIPT_DIR/selftest-adaptive-work.sh"

if [[ -n "$FAILURES" ]]; then
    echo "FALHOU" >&2
    printf '%s' "$FAILURES" >&2
    exit 1
fi

echo "OK — $PASS_COUNT asserções."
