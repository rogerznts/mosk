#!/usr/bin/env bash
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

VERBOSE=false
case "${1:-}" in
    --verbose) VERBOSE=true ;;
    --help|-h) echo "Usage: selftest-pipeline-state.sh [--verbose]"; exit 0 ;;
    "") ;;
    *) echo "ERROR: opção desconhecida '$1'" >&2; exit 2 ;;
esac

PASS=0
FAIL=0
TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/mosk-state-test.XXXXXX")"
trap 'rm -rf "$TMP_ROOT"' EXIT

ok() { PASS=$((PASS + 1)); $VERBOSE && echo "ok $PASS - $1"; return 0; }
bad() { FAIL=$((FAIL + 1)); echo "not ok - $1 :: $2" >&2; }
expect_ok() {
    local name="$1" output; shift
    if output="$("$@" 2>&1)"; then ok "$name"; else bad "$name" "esperado sucesso: $output"; fi
}
expect_fail() {
    local name="$1"; shift
    if "$@" >/dev/null 2>&1; then bad "$name" "esperado falha"; else ok "$name"; fi
}
expect_eq() {
    local name="$1" expected="$2" actual="$3"
    [[ "$expected" == "$actual" ]] && ok "$name" || bad "$name" "esperado '$expected', obtido '$actual'"
}

make_spec() {
    local repo="$1" number="$2" phase="$3" schema="${4:-2}"
    local dir="$repo/docs/specs/${number}-feature-demo-${number}"
    mkdir -p "$dir"
    cat > "$dir/spec-meta.yaml" <<EOF
schema: $schema
spec_number: "$number"
spec_id: "${number}-feature-demo-${number}"
type: "feature"
branch: "feature/${number}-demo-${number}"
created_at: "2026-08-15T00:00:00Z"
created_by: "Self Test"
status: active
current_phase: $phase
last_phase_change: "2026-08-15T00:00:00Z"
EOF
    printf '# Spec\n' > "$dir/spec.md"
    printf '# Plan\n' > "$dir/plan.md"
    printf -- '- [x] done\n' > "$dir/tasks.md"
    echo "$dir"
}

append_event() {
    local history="$1" at="$2" from="$3" to="$4" command="$5"
    printf '  - at: "%s"\n    from: %s\n    to: %s\n    command: %s\n' \
        "$at" "$from" "$to" "$command" >> "$history"
}

# Build a schema-2 fixture whose metadata and complete history agree at any
# canonical phase. This lets the exhaustive matrix exercise the real sink,
# rather than only the phase_transition_allowed case statement.
make_state_spec() {
    local repo="$1" number="$2" phase="$3" dir history last_at="2026-08-15T00:00:00Z"
    dir="$(make_spec "$repo" "$number" "$phase")"
    history="$dir/phase-history.yaml"
    if [[ "$phase" != specify ]]; then
        printf 'schema: 1\norigin: specify\ntransitions:\n' > "$history"
        append_event "$history" "2026-08-15T00:00:01Z" specify plan plan
        last_at="2026-08-15T00:00:01Z"
    fi
    case "$phase" in
        tasks|implement|qa-gate|archived)
            append_event "$history" "2026-08-15T00:00:02Z" plan tasks tasks
            last_at="2026-08-15T00:00:02Z"
            ;;
    esac
    case "$phase" in
        implement|qa-gate|archived)
            append_event "$history" "2026-08-15T00:00:03Z" tasks implement implement
            last_at="2026-08-15T00:00:03Z"
            ;;
    esac
    case "$phase" in
        qa-gate|archived)
            append_event "$history" "2026-08-15T00:00:04Z" implement qa-gate qa-gate
            last_at="2026-08-15T00:00:04Z"
            ;;
    esac
    if [[ "$phase" == archived ]]; then
        append_event "$history" "2026-08-15T00:00:05Z" qa-gate archived archive
        last_at="2026-08-15T00:00:05Z"
        sed -i.bak 's/^status: active$/status: archived/' "$dir/spec-meta.yaml" && rm -f "$dir/spec-meta.yaml.bak"
        printf 'archived_at: "%s"\n' "$last_at" >> "$dir/spec-meta.yaml"
    fi
    sed -i.bak "s/^last_phase_change:.*/last_phase_change: \"$last_at\"/" "$dir/spec-meta.yaml" && rm -f "$dir/spec-meta.yaml.bak"
    echo "$dir"
}

make_archive_ready_spec() {
    local repo="$1" number="$2" dir
    dir="$(make_state_spec "$repo" "$number" qa-gate)"
    printf '# Evidence\n' > "$dir/qa-notes.md"
    cat > "$dir/gate.yaml" <<'EOF'
schema: 2
story: "fixture"
story_title: "Archive front-matter"
gate: PASS
quality_score: 100
score_history: [100]
status_reason: "ready"
reviewer: "Self Test"
updated: "2026-08-15T00:00:04Z"
evidence_ref: "qa-notes.md"
waiver_active: false
waiver_reason: ""
waiver_approved_by: ""
waiver_approved_at: ""
EOF
    echo "$dir"
}

state_digest() {
    local dir="$1"
    cksum "$dir/spec-meta.yaml"
    if [[ -f "$dir/phase-history.yaml" ]]; then cksum "$dir/phase-history.yaml"; else echo "history:absent"; fi
}

repo="$TMP_ROOT/repo"
mkdir -p "$repo/docs/specs/archive"
spec="$(make_spec "$repo" 013 specify)"

echo "selftest-pipeline-state: resolução"
expect_eq "resolve por número" "$spec" "$(resolve_spec_dir "$repo" 013 active 2>/dev/null || true)"
expect_eq "resolve por spec_id" "$spec" "$(resolve_spec_dir "$repo" 013-feature-demo-013 active 2>/dev/null || true)"
expect_eq "resolve por branch" "$spec" "$(resolve_spec_dir "$repo" feature/013-demo-013 active 2>/dev/null || true)"
expect_eq "zsh resolve por branch" "$spec" "$(zsh -c 'source "$1"; resolve_spec_dir "$2" feature/013-demo-013 active' _ "$SCRIPT_DIR/common.sh" "$repo" 2>/dev/null || true)"
expect_fail "branch diferente com mesmo número falha" resolve_spec_dir "$repo" feature/013-outra active
expect_fail "zsh bloqueia branch diferente com mesmo número" zsh -c 'source "$1"; resolve_spec_dir "$2" feature/013-outra active' _ "$SCRIPT_DIR/common.sh" "$repo"
expect_fail "ausência falha" resolve_spec_dir "$repo" 099 active
archived="$repo/docs/specs/archive/014-feature-demo-014"
mkdir -p "$archived"
cat > "$archived/spec-meta.yaml" <<'EOF'
schema: 1
spec_id: "014-feature-demo-014"
branch: "feature/014-demo-014"
status: archived
current_phase: archived
EOF
expect_eq "resolve archive somente em any" "$archived" "$(resolve_spec_dir "$repo" feature/014-demo-014 any 2>/dev/null || true)"
expect_fail "archive não reabre em active" resolve_spec_dir "$repo" 014 active
mkdir -p "$repo/docs/specs/013-feature-duplicate"
cp "$spec/spec-meta.yaml" "$repo/docs/specs/013-feature-duplicate/spec-meta.yaml"
expect_fail "duplicidade falha" resolve_spec_dir "$repo" 013 active
rm -rf "$repo/docs/specs/013-feature-duplicate"
outside_repo="$TMP_ROOT/outside-repo"
outside_spec="$(make_spec "$outside_repo" 015 tasks)"
ln -s "$outside_spec" "$repo/docs/specs/015-feature-demo-015"
outside_before="$(cksum "$outside_spec/spec-meta.yaml")"
expect_fail "resolvedor bloqueia diretório de spec symlink" resolve_spec_dir "$repo" 015 active
expect_fail "sink bloqueia diretório de spec symlink" transition_spec_phase "$repo/docs/specs/015-feature-demo-015" implement implement "$repo"
expect_eq "symlink bloqueado não altera alvo externo" "$outside_before" "$(cksum "$outside_spec/spec-meta.yaml")"
rm "$repo/docs/specs/015-feature-demo-015"
unsafe_repo="$TMP_ROOT/unsafe-repo"
mkdir -p "$unsafe_repo/docs"
ln -s "$outside_repo/docs/specs" "$unsafe_repo/docs/specs"
expect_fail "resolvedor bloqueia raiz specs symlink" resolve_spec_dir "$unsafe_repo" 015 active
cp "$spec/spec-meta.yaml" "$spec/spec-meta.identity"
sed -i.bak 's/spec_number: "013"/spec_number: "999"/' "$spec/spec-meta.yaml" && rm -f "$spec/spec-meta.yaml.bak"
expect_fail "metadata com número divergente falha" validate_spec_metadata "$spec"
expect_fail "resolvedor bloqueia metadata com número divergente" resolve_spec_dir "$repo" 013-feature-demo-013 active
mv "$spec/spec-meta.identity" "$spec/spec-meta.yaml"
cp "$spec/spec-meta.yaml" "$spec/spec-meta.identity"
sed -i.bak 's/type: "feature"/type: "hotfix"/; s#branch: "feature/013-demo-013"#branch: "hotfix/999-outra"#' "$spec/spec-meta.yaml" && rm -f "$spec/spec-meta.yaml.bak"
expect_fail "metadata com tipo e branch divergentes falha" validate_spec_metadata "$spec"
mv "$spec/spec-meta.identity" "$spec/spec-meta.yaml"

echo "selftest-pipeline-state: schemas"
expect_ok "metadata schema vigente" validate_spec_metadata "$spec"
expect_ok "zsh valida metadata vigente" zsh -c 'source "$1"; validate_spec_metadata "$2"' _ "$SCRIPT_DIR/common.sh" "$spec"
cp "$spec/spec-meta.yaml" "$spec/spec-meta.clean"
printf 'status: archived\n' >> "$spec/spec-meta.yaml"
expect_fail "metadata com chave crítica duplicada falha" validate_spec_metadata "$spec"
mv "$spec/spec-meta.clean" "$spec/spec-meta.yaml"
cp "$spec/spec-meta.yaml" "$spec/spec-meta.clean"
printf '"status": archived\n' >> "$spec/spec-meta.yaml"
expect_fail "metadata com chave crítica citada falha" validate_spec_metadata "$spec"
expect_fail "zsh bloqueia chave crítica citada em metadata" zsh -c 'source "$1"; validate_spec_metadata "$2"' _ "$SCRIPT_DIR/common.sh" "$spec"
mv "$spec/spec-meta.clean" "$spec/spec-meta.yaml"
cp "$spec/spec-meta.yaml" "$spec/spec-meta.clean"
printf '"sta\\u0074us": archived\n' >> "$spec/spec-meta.yaml"
expect_fail "metadata bloqueia chave com escape Unicode" validate_spec_metadata "$spec"
expect_fail "zsh bloqueia chave com escape Unicode em metadata" zsh -c 'source "$1"; validate_spec_metadata "$2"' _ "$SCRIPT_DIR/common.sh" "$spec"
mv "$spec/spec-meta.clean" "$spec/spec-meta.yaml"
sed -i.bak 's/schema: 2/schema: 99/' "$spec/spec-meta.yaml" && rm -f "$spec/spec-meta.yaml.bak"
expect_fail "schema futuro falha" validate_spec_metadata "$spec"
sed -i.bak 's/schema: 99/schema: 2/' "$spec/spec-meta.yaml" && rm -f "$spec/spec-meta.yaml.bak"
malformed_spec="$(make_spec "$repo" 016 implement)"
cat > "$malformed_spec/phase-history.yaml" <<'EOF'
schema: 1
origin: specify
transitions:
  - at: "not-a-date"
    from: archived
    to: implement
    command: archive
EOF
expect_fail "histórico com evento impossível falha" validate_spec_metadata "$malformed_spec"
cat > "$malformed_spec/phase-history.yaml" <<'EOF'
schema: 1
origin: specify
transitions:
  - at: "2026-08-15T00:00:00Z"
    from: tasks
    to: implement
    command: implement
  - at: "2026-08-15T00:00:01Z"
    from: plan
    to: tasks
    command: tasks
EOF
expect_fail "histórico com cadeia descontínua falha" validate_spec_metadata "$malformed_spec"
cat > "$malformed_spec/phase-history.yaml" <<'EOF'
schema: 1
origin: specify
transitions:
  - at: "2026-08-15T00:00:00Z"
    from: qa-gate
    to: implement
    command: apply-qa-fixes
EOF
expect_fail "histórico schema 2 truncado falha" validate_spec_metadata "$malformed_spec"
expect_fail "zsh bloqueia histórico schema 2 truncado" zsh -c 'source "$1"; validate_spec_metadata "$2"' _ "$SCRIPT_DIR/common.sh" "$malformed_spec"
sed -i.bak 's/origin: specify/origin: migration/' "$malformed_spec/phase-history.yaml" && rm -f "$malformed_spec/phase-history.yaml.bak"
expect_fail "schema 2 novo não pode alegar origin migration" validate_spec_metadata "$malformed_spec"
expect_fail "zsh bloqueia origin migration sem evidência legada" zsh -c 'source "$1"; validate_spec_metadata "$2"' _ "$SCRIPT_DIR/common.sh" "$malformed_spec"
rm "$malformed_spec/phase-history.yaml"
expect_fail "schema 2 após specify sem histórico falha" validate_spec_metadata "$malformed_spec"
rm -rf "$malformed_spec"
legacy_migration_spec="$(make_spec "$repo" 018 tasks 1)"
expect_ok "spec legada registra origem de migração" transition_spec_phase "$legacy_migration_spec" implement implement "$repo"
expect_eq "histórico migrado declara origin migration" migration "$(read_yaml_scalar "$legacy_migration_spec/phase-history.yaml" origin)"
expect_eq "metadata migrada persiste schema de origem" 1 "$(read_spec_meta "$legacy_migration_spec" history_origin_schema)"
expect_ok "estado migrado continua válido" validate_spec_metadata "$legacy_migration_spec"
legacy_migration_zsh="$(make_spec "$repo" 019 tasks 1)"
expect_ok "zsh registra origem de migração legada" zsh -c 'source "$1"; transition_spec_phase "$2" implement implement "$3"' _ "$SCRIPT_DIR/common.sh" "$legacy_migration_zsh" "$repo"
expect_eq "histórico migrado por zsh declara origin migration" migration "$(read_yaml_scalar "$legacy_migration_zsh/phase-history.yaml" origin)"
expect_eq "metadata migrada por zsh persiste schema de origem" 1 "$(read_spec_meta "$legacy_migration_zsh" history_origin_schema)"
timestamp_spec="$(make_state_spec "$repo" 017 implement)"
sed -i.bak 's/last_phase_change:.*/last_phase_change: "2099-01-01T00:00:00Z"/' "$timestamp_spec/spec-meta.yaml" && rm -f "$timestamp_spec/spec-meta.yaml.bak"
expect_fail "metadata e histórico com instantes divergentes falham" validate_spec_metadata "$timestamp_spec"
expect_fail "zsh bloqueia instantes divergentes" zsh -c 'source "$1"; validate_spec_metadata "$2"' _ "$SCRIPT_DIR/common.sh" "$timestamp_spec"
rm -rf "$timestamp_spec"

echo "selftest-pipeline-state: matriz exaustiva"
phases=(specify plan tasks implement qa-gate archived)
matrix_number=100
for from in "${phases[@]}"; do
    for to in "${phases[@]}"; do
        expected=fail
        [[ "$from" == "$to" ]] && expected=noop
        phase_transition_allowed "$from" "$to" && expected=allowed
        if [[ "$expected" == allowed ]]; then
            ok "matriz permite $from -> $to"
            continue
        fi
        matrix_id="$(printf '%03d' "$matrix_number")"; matrix_number=$((matrix_number + 1))
        matrix_spec="$(make_state_spec "$repo" "$matrix_id" "$from")"
        matrix_before="$(state_digest "$matrix_spec")"
        if [[ "$expected" == noop ]]; then
            expect_ok "matriz no-op $from -> $to" transition_spec_phase "$matrix_spec" "$to" migration "$repo"
        else
            expect_fail "matriz proíbe $from -> $to" transition_spec_phase "$matrix_spec" "$to" migration "$repo"
        fi
        expect_eq "matriz preserva estado $from -> $to" "$matrix_before" "$(state_digest "$matrix_spec")"
    done
done

echo "selftest-pipeline-state: sinais e marcadores"
zsh_mv_dir="$TMP_ROOT/zsh-mv-wrapper"
mkdir -p "$zsh_mv_dir"
printf '#!/bin/sh\nreal_mv="%s"\n"$real_mv" "$@" || exit $?\ncase "${2:-}" in */spec-meta.yaml) kill -"${MOSK_TEST_SIGNAL:-TERM}" "$PPID" ;; esac\n' "$(command -v mv)" > "$zsh_mv_dir/mv"
chmod +x "$zsh_mv_dir/mv"
signal_number=180
for test_signal in HUP INT TERM; do
    signal_id="$(printf '%03d' "$signal_number")"; signal_number=$((signal_number + 1))
    signal_bash="$(make_state_spec "$repo" "$signal_id" plan)"
    signal_before="$(state_digest "$signal_bash")"
    expect_fail "$test_signal em Bash bloqueia transição" env MOSK_TEST_SIGNAL="$test_signal" bash -c 'source "$1"; mv() { command mv "$@" || return; case "${2:-}" in */spec-meta.yaml) kill -"$MOSK_TEST_SIGNAL" "$BASHPID" ;; esac; }; transition_spec_phase "$2" tasks tasks "$3"' _ "$SCRIPT_DIR/common.sh" "$signal_bash" "$repo"
    expect_eq "$test_signal em Bash restaura metadata e histórico" "$signal_before" "$(state_digest "$signal_bash")"
    expect_ok "estado após $test_signal em Bash continua válido" validate_spec_metadata "$signal_bash"

    signal_id="$(printf '%03d' "$signal_number")"; signal_number=$((signal_number + 1))
    signal_zsh="$(make_state_spec "$repo" "$signal_id" plan)"
    signal_before="$(state_digest "$signal_zsh")"
    expect_fail "$test_signal em zsh bloqueia transição" env MOSK_TEST_SIGNAL="$test_signal" PATH="$zsh_mv_dir:$PATH" zsh -c 'source "$1"; transition_spec_phase "$2" tasks tasks "$3"' _ "$SCRIPT_DIR/common.sh" "$signal_zsh" "$repo"
    expect_eq "$test_signal em zsh restaura metadata e histórico" "$signal_before" "$(state_digest "$signal_zsh")"
    expect_ok "estado após $test_signal em zsh continua válido" validate_spec_metadata "$signal_zsh"
done
marker_spec="$(make_state_spec "$repo" 186 plan)"
printf '[NEEDS CLARIFICATION: decisão pendente]\n' >> "$marker_spec/plan.md"
marker_before="$(state_digest "$marker_spec")"
expect_fail "marcador bloqueante em plan.md impede tasks" transition_spec_phase "$marker_spec" tasks tasks "$repo"
expect_eq "falha por marcador preserva estado" "$marker_before" "$(state_digest "$marker_spec")"

echo "selftest-pipeline-state: transições"
expect_ok "specify para plan" transition_spec_phase "$spec" plan plan
expect_eq "fase plan persistida" plan "$(read_spec_meta "$spec" current_phase)"
history_before="$(cksum "$spec/phase-history.yaml")"
expect_ok "mesma fase é idempotente" transition_spec_phase "$spec" plan plan
expect_eq "no-op não duplica histórico" "$history_before" "$(cksum "$spec/phase-history.yaml")"
meta_before="$(cksum "$spec/spec-meta.yaml")"
history_before="$(cksum "$spec/phase-history.yaml")"
expect_fail "salto plan para implement falha" transition_spec_phase "$spec" implement implement
expect_eq "falha preserva metadata" "$meta_before" "$(cksum "$spec/spec-meta.yaml")"
expect_eq "falha preserva histórico" "$history_before" "$(cksum "$spec/phase-history.yaml")"
expect_fail "falha entre metadata e histórico é revertida" env MOSK_TRANSITION_FAIL_AFTER_META=1 bash -c 'source "$1"; transition_spec_phase "$2" tasks tasks' _ "$SCRIPT_DIR/common.sh" "$spec"
expect_eq "rollback restaura metadata" "$meta_before" "$(cksum "$spec/spec-meta.yaml")"
expect_eq "rollback preserva histórico" "$history_before" "$(cksum "$spec/phase-history.yaml")"
expect_ok "plan para tasks" transition_spec_phase "$spec" tasks tasks
expect_ok "tasks para implement" transition_spec_phase "$spec" implement implement
cat > "$spec/qa-notes.md" <<'EOF'
# Evidence
EOF
cat > "$spec/gate.yaml" <<'EOF'
schema: 2
story: "013"
story_title: "Demo"
gate: FAIL
quality_score: 80
score_history: [80]
status_reason: "finding aberto"
reviewer: "QA"
updated: "2026-08-15T00:00:00Z"
evidence_ref: "qa-notes.md"
waiver_active: false
waiver_reason: ""
waiver_approved_by: ""
waiver_approved_at: ""
EOF
expect_ok "implement para qa-gate" transition_spec_phase "$spec" qa-gate qa-gate
expect_ok "qa-gate retorna para implement" transition_spec_phase "$spec" implement apply-qa-fixes
expect_fail "archive fora de qa-gate falha" transition_spec_phase "$spec" archived archive

echo "selftest-pipeline-state: gate"
sed -i.bak 's/gate: FAIL/gate: PASS/' "$spec/gate.yaml" && rm -f "$spec/gate.yaml.bak"
expect_ok "gate vigente com evidência" validate_gate_for_completion "$spec"
cp "$spec/gate.yaml" "$spec/gate.clean"
sed -i.bak '/score_history:/d' "$spec/gate.yaml" && rm -f "$spec/gate.yaml.bak"
expect_fail "gate vigente sem score_history" validate_gate_for_completion "$spec"
mv "$spec/gate.clean" "$spec/gate.yaml"
sed -i.bak '/evidence_ref:/d' "$spec/gate.yaml" && rm -f "$spec/gate.yaml.bak"
expect_fail "gate vigente sem evidência" validate_gate_for_completion "$spec"
sed -i.bak 's/schema: 2/schema: 99/' "$spec/gate.yaml" && rm -f "$spec/gate.yaml.bak"
expect_fail "gate com schema futuro falha" validate_gate_for_completion "$spec"
sed -i.bak 's/schema: 99/schema: 2/' "$spec/gate.yaml" && rm -f "$spec/gate.yaml.bak"
printf 'evidence_ref: "qa-notes.md"\n' >> "$spec/gate.yaml"
sed -i.bak 's/gate: PASS/gate: WAIVED/' "$spec/gate.yaml" && rm -f "$spec/gate.yaml.bak"
expect_fail "waiver incompleto falha" validate_gate_for_completion "$spec"
sed -i.bak 's/gate: WAIVED/gate: PASS/' "$spec/gate.yaml" && rm -f "$spec/gate.yaml.bak"
printf 'gate: FAIL\n' >> "$spec/gate.yaml"
expect_fail "gate com chave crítica duplicada falha" validate_gate_for_completion "$spec"
sed -i.bak '$d' "$spec/gate.yaml" && rm -f "$spec/gate.yaml.bak"
printf '"gate": FAIL\n' >> "$spec/gate.yaml"
expect_fail "gate com chave crítica citada falha" validate_gate_for_completion "$spec"
expect_fail "zsh bloqueia chave crítica citada em gate" zsh -c 'source "$1"; validate_gate_for_completion "$2"' _ "$SCRIPT_DIR/common.sh" "$spec"
sed -i.bak '$d' "$spec/gate.yaml" && rm -f "$spec/gate.yaml.bak"
printf '"ga\\u0074e": FAIL\n' >> "$spec/gate.yaml"
expect_fail "gate bloqueia chave com escape Unicode" validate_gate_for_completion "$spec"
expect_fail "zsh bloqueia chave com escape Unicode em gate" zsh -c 'source "$1"; validate_gate_for_completion "$2"' _ "$SCRIPT_DIR/common.sh" "$spec"
sed -i.bak '$d' "$spec/gate.yaml" && rm -f "$spec/gate.yaml.bak"
sed -i.bak 's/schema: 2/schema: 1/' "$spec/gate.yaml" && rm -f "$spec/gate.yaml.bak"
expect_fail "gate schema 1 em spec ativa falha" validate_gate_for_completion "$spec"
sed -i.bak 's/schema: 1/schema: 2/' "$spec/gate.yaml" && rm -f "$spec/gate.yaml.bak"
expect_ok "implement retorna a qa-gate" transition_spec_phase "$spec" qa-gate qa-gate

echo "selftest-pipeline-state: front-matter raiz indentada"
indented_unicode="$(make_archive_ready_spec "$repo" 190)"
cat > "$indented_unicode/promotion.md" <<'EOF'
---
  "promo\u0074e": docs/canonical/missing-unicode.md
  promote_mode: copy
---
# Hidden Unicode promotion
EOF
indented_before="$(state_digest "$indented_unicode")"
expect_fail "archive bloqueia promote Unicode em mapping raiz indentada" transition_spec_phase "$indented_unicode" archived archive "$repo"
expect_eq "Unicode indentado preserva estado em Bash" "$indented_before" "$(state_digest "$indented_unicode")"
expect_fail "zsh bloqueia promote Unicode em mapping raiz indentada" zsh -c 'source "$1"; transition_spec_phase "$2" archived archive "$3"' _ "$SCRIPT_DIR/common.sh" "$indented_unicode" "$repo"
expect_eq "Unicode indentado preserva estado em zsh" "$indented_before" "$(state_digest "$indented_unicode")"
expect_ok "Unicode indentado não materializa destino" test ! -e "$repo/docs/canonical/missing-unicode.md"

indented_explicit="$(make_archive_ready_spec "$repo" 191)"
cat > "$indented_explicit/promotion.md" <<'EOF'
---
  ? promote
  : docs/canonical/missing-explicit.md
  promote_mode: copy
---
# Hidden explicit-key promotion
EOF
indented_before="$(state_digest "$indented_explicit")"
expect_fail "archive bloqueia chave promote explícita indentada" transition_spec_phase "$indented_explicit" archived archive "$repo"
expect_eq "chave explícita preserva estado em Bash" "$indented_before" "$(state_digest "$indented_explicit")"
expect_fail "zsh bloqueia chave promote explícita indentada" zsh -c 'source "$1"; transition_spec_phase "$2" archived archive "$3"' _ "$SCRIPT_DIR/common.sh" "$indented_explicit" "$repo"
expect_eq "chave explícita preserva estado em zsh" "$indented_before" "$(state_digest "$indented_explicit")"
expect_ok "chave explícita não materializa destino" test ! -e "$repo/docs/canonical/missing-explicit.md"

indented_tag="$(make_archive_ready_spec "$repo" 192)"
cat > "$indented_tag/promotion.md" <<'EOF'
---
  !!str promote: docs/canonical/missing-tag.md
  promote_mode: copy
---
# Hidden tagged promotion
EOF
indented_before="$(state_digest "$indented_tag")"
expect_fail "archive bloqueia chave promote com tag indentada" transition_spec_phase "$indented_tag" archived archive "$repo"
expect_eq "tag indentada preserva estado em Bash" "$indented_before" "$(state_digest "$indented_tag")"
expect_fail "zsh bloqueia chave promote com tag indentada" zsh -c 'source "$1"; transition_spec_phase "$2" archived archive "$3"' _ "$SCRIPT_DIR/common.sh" "$indented_tag" "$repo"
expect_eq "tag indentada preserva estado em zsh" "$indented_before" "$(state_digest "$indented_tag")"
expect_ok "tag indentada não materializa destino" test ! -e "$repo/docs/canonical/missing-tag.md"

cat > "$spec/promotion-copy.md" <<'EOF'
---
promote: docs/canonical/applied.md
promote_mode: copy
---
# Copy fixture
EOF
cat > "$spec/promotion-manual.md" <<'EOF'
---
promote: docs/canonical/manual.md
promote_mode: manual
---
# Manual fixture
EOF
cat > "$spec/promotion-append.md" <<'EOF'
---
promote: docs/canonical/append.md
promote_mode: append
---
# Append fixture
EOF
cat > "$spec/promotion-quoted.md" <<'EOF'
---
"promote": docs/canonical/quoted.md
promote_mode: copy
---
# Quoted fixture
EOF
archive_before="$(state_digest "$spec")"
expect_fail "archive bloqueia promoção copy pendente" transition_spec_phase "$spec" archived archive "$repo"
expect_eq "promoção pendente preserva estado" "$archive_before" "$(state_digest "$spec")"
mkdir -p "$repo/docs/canonical"
expect_fail "promoção não pode usar o próprio artefato na área de specs" validate_promotion_target "$repo" "docs/specs/013-feature-demo-013/promotion-copy.md" copy
expect_fail "zsh bloqueia destino de promoção dentro de docs/specs" zsh -c 'source "$1"; validate_promotion_target "$2" "$3" copy' _ "$SCRIPT_DIR/common.sh" "$repo" "docs/specs/013-feature-demo-013/promotion-copy.md"
expect_fail "front-matter bloqueia chave promote citada" validate_spec_promotions_satisfied "$repo" "$spec"
expect_fail "zsh bloqueia chave promote citada" zsh -c 'source "$1"; validate_spec_promotions_satisfied "$2" "$3"' _ "$SCRIPT_DIR/common.sh" "$repo" "$spec"
rm "$spec/promotion-quoted.md"
cat > "$spec/promotion-unicode.md" <<'EOF'
---
"promo\u0074e": docs/canonical/missing.md
promote_mode: copy
---
# Unicode fixture
EOF
expect_fail "front-matter bloqueia promote com escape Unicode" validate_spec_promotions_satisfied "$repo" "$spec"
expect_fail "zsh bloqueia promote com escape Unicode" zsh -c 'source "$1"; validate_spec_promotions_satisfied "$2" "$3"' _ "$SCRIPT_DIR/common.sh" "$repo" "$spec"
rm "$spec/promotion-unicode.md"
cat > "$spec/promotion-duplicate.md" <<'EOF'
---
promote: docs/canonical/one.md
promote: docs/canonical/two.md
promote_mode: copy
---
# Duplicate fixture
EOF
expect_fail "front-matter bloqueia chave promote duplicada" validate_spec_promotions_satisfied "$repo" "$spec"
expect_fail "zsh bloqueia chave promote duplicada" zsh -c 'source "$1"; validate_spec_promotions_satisfied "$2" "$3"' _ "$SCRIPT_DIR/common.sh" "$repo" "$spec"
rm "$spec/promotion-duplicate.md"
mkdir "$repo/docs/canonical/directory-target"
expect_fail "helper bloqueia diretório como alvo de append" validate_promotion_target "$repo" docs/canonical/directory-target append
expect_fail "zsh bloqueia diretório como alvo de append" zsh -c 'source "$1"; validate_promotion_target "$2" docs/canonical/directory-target append' _ "$SCRIPT_DIR/common.sh" "$repo"
sed -i.bak 's#docs/canonical/applied.md#docs/canonical/directory-target#' "$spec/promotion-copy.md" && rm -f "$spec/promotion-copy.md.bak"
expect_fail "promoção copy bloqueia diretório como alvo" validate_spec_promotions_satisfied "$repo" "$spec"
expect_fail "zsh bloqueia diretório como alvo de copy" zsh -c 'source "$1"; validate_spec_promotions_satisfied "$2" "$3"' _ "$SCRIPT_DIR/common.sh" "$repo" "$spec"
sed -i.bak 's#docs/canonical/directory-target#docs/canonical/applied.md#' "$spec/promotion-copy.md" && rm -f "$spec/promotion-copy.md.bak"
printf '# Divergent\n' > "$repo/docs/canonical/applied.md"
printf '# Existing without payload\n' > "$repo/docs/canonical/append.md"
expect_fail "promoções bloqueiam conteúdo copy/append divergente" validate_spec_promotions_satisfied "$repo" "$spec"
expect_fail "zsh bloqueia conteúdo copy/append divergente" zsh -c 'source "$1"; validate_spec_promotions_satisfied "$2" "$3"' _ "$SCRIPT_DIR/common.sh" "$repo" "$spec"
cp "$spec/promotion-copy.md" "$repo/docs/canonical/applied.md"
extract_frontmatter_body "$spec/promotion-append.md" >> "$repo/docs/canonical/append.md"
expect_ok "promoções copy/append materialmente equivalentes passam" validate_spec_promotions_satisfied "$repo" "$spec"
expect_ok "zsh aceita promoções materialmente equivalentes" zsh -c 'source "$1"; validate_spec_promotions_satisfied "$2" "$3"' _ "$SCRIPT_DIR/common.sh" "$repo" "$spec"
expect_ok "qa-gate com PASS arquiva" transition_spec_phase "$spec" archived archive
expect_eq "archived é estado final persistido" archived "$(read_spec_meta "$spec" current_phase)"
expect_fail "archived não reabre" transition_spec_phase "$spec" implement implement
cat > "$archived/gate.yaml" <<'EOF'
schema: 1
gate: PASS
EOF
expect_ok "gate histórico schema 1 no archive" validate_gate_for_completion "$archived"

echo "selftest-pipeline-state: lock"
mkdir "$spec/.phase-transition.lock"
expect_fail "lock concorrente bloqueia" transition_spec_phase "$spec" qa-gate qa-gate
rmdir "$spec/.phase-transition.lock"

if [[ "$FAIL" -gt 0 ]]; then
    echo "FAIL — $FAIL falha(s), $PASS sucesso(s)." >&2
    exit 1
fi
echo "OK — $PASS asserções."
