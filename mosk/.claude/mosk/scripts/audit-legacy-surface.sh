#!/usr/bin/env bash
# audit-legacy-surface.sh — inventário, rotas, referências, redução do corpus,
# cópias de contrato e legado operacional.
set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DEFAULT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
ROOT="$DEFAULT_ROOT"
EXPECTED_COUNT=50
QUIET=0
JSON=0

usage() {
    cat <<'EOF'
audit-legacy-surface.sh [--root PATH] [--expected-count N] [--quiet] [--json]

Valida o catálogo de tasks, destinos/consumidores, referências a tasks já
absorvidas e ocorrências do legado fora da allowlist legal/histórica.

Mede também o corpus-alvo (tasks `rewrite` do catálogo) com a fórmula da
baseline, exige redução mínima de 30% sobre `legacy-baseline-metrics.tsv` e
falha quando outro arquivo do produto copia o bloco normativo de um contrato
canônico em vez de referenciá-lo.
EOF
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --root)
            [ "$#" -ge 2 ] || { echo "valor ausente para --root" >&2; exit 2; }
            ROOT="$2"
            shift 2
            ;;
        --expected-count)
            [ "$#" -ge 2 ] || { echo "valor ausente para --expected-count" >&2; exit 2; }
            EXPECTED_COUNT="$2"
            shift 2
            ;;
        --quiet) QUIET=1; shift ;;
        --json) JSON=1; shift ;;
        --help|-h) usage; exit 0 ;;
        *) echo "opção desconhecida: $1" >&2; exit 2 ;;
    esac
done

case "$EXPECTED_COUNT" in
    ''|*[!0-9]*) echo "--expected-count deve ser inteiro não negativo" >&2; exit 2 ;;
esac
[ -d "$ROOT" ] || { echo "raiz inexistente: $ROOT" >&2; exit 2; }
ROOT="$(cd "$ROOT" && pwd -P)"

DATA_DIR="$ROOT/.claude/mosk/data"
TASK_DIR="$ROOT/.claude/mosk/tasks"
CATALOG="$DATA_DIR/task-dispositions.tsv"
ALLOWLIST="$DATA_DIR/legacy-reference-allowlist.tsv"
MERGED_FIXTURES="$DATA_DIR/merged-task-fixtures.md"
BASELINE_METRICS="$DATA_DIR/legacy-baseline-metrics.tsv"
# Contratos canônicos; a lista vira arquivo porque zsh não faz word splitting
# de variável não citada e a iteração precisa ser idêntica nos dois shells.
CONTRACT_ADAPTIVE=".claude/mosk/data/adaptive-work-contract.md"
CONTRACT_OUTPUT=".claude/mosk/data/output-contract.md"
# Redução mínima exigida sobre a baseline, em pontos percentuais mantidos.
REDUCTION_KEEP_PERCENT=70
# Uma linha só vira sentinela do contrato a partir deste tamanho normalizado;
# abaixo disso ela é estrutura de markdown, não redação normativa.
SENTINEL_MIN_LENGTH=30
# Abaixo deste número de sentinelas o bloco normativo é indetectável.
CONTRACT_MIN_SENTINELS=3
# Três linhas normativas verbatim já são cópia, não menção.
CONTRACT_MIN_MATCHES=3
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT HUP INT TERM
ERRORS="$TMP_DIR/errors"
: > "$ERRORS"

problem() {
    printf '%s\n' "$1" >> "$ERRORS"
}

safe_product_path() {
    case "$1" in
        .claude/*) ;;
        *) return 1 ;;
    esac
    case "$1" in
        /*|*'/../'*|../*|*/..|*'/./'*|./*|*'//'*) return 1 ;;
    esac
    return 0
}

[ -f "$CATALOG" ] || problem "catálogo ausente: .claude/mosk/data/task-dispositions.tsv"
[ -f "$ALLOWLIST" ] || problem "allowlist ausente: .claude/mosk/data/legacy-reference-allowlist.tsv"
[ -d "$TASK_DIR" ] || problem "diretório de tasks ausente: .claude/mosk/tasks"

catalog_count=0
task_count=0
legacy_count=0
baseline_total=0
current_total=0
reduction_ceiling=0
contract_duplications=0

# Fórmula da baseline (docs/specs/.../legacy-baseline.md): linhas não vazias,
# sem frontmatter YAML inicial e sem comentário HTML de atribuição.
measure_operational_lines() {
    awk '
      BEGIN { front = 0 }
      /^---[[:space:]]*$/ {
        if (NR == 1 || front == 1) { front = !front; next }
      }
      front { next }
      /^[[:space:]]*$/ { next }
      /^<!--[[:space:]]*(Inspired|Adapted|Based)[^>]*-->[[:space:]]*$/ { next }
      { count++ }
      END { print count + 0 }
    ' "$1"
}

catalog_field() {
    awk -F '\t' -v task="$1" -v field="$2" 'NR > 1 && $1 == task { print $field; exit }' "$CATALOG"
}

extract_merged_fixtures() {
    [ -f "$MERGED_FIXTURES" ] || return 1
    awk '
        /<!-- merged-task-fixtures:start -->/ { inside = 1; next }
        /<!-- merged-task-fixtures:end -->/ { inside = 0 }
        inside { print }
    ' "$MERGED_FIXTURES"
}

if [ -f "$MERGED_FIXTURES" ]; then
    extract_merged_fixtures > "$TMP_DIR/merged-fixtures"
    fixture_header="$(sed -n '1p' "$TMP_DIR/merged-fixtures")"
    [ "$fixture_header" = "legacy_task	capability	entrypoints	destinations	expected_result	evidence" ] || \
        problem "header inválido em merged-task-fixtures.md"
else
    : > "$TMP_DIR/merged-fixtures"
fi

if [ -f "$CATALOG" ]; then
    header="$(sed -n '1p' "$CATALOG")"
    [ "$header" = "task	action	destination	consumers	evidence	reason" ] || \
        problem "header inválido em task-dispositions.tsv"
    catalog_count="$(awk 'END { print (NR > 0 ? NR - 1 : 0) }' "$CATALOG")"
    [ "$catalog_count" -eq "$EXPECTED_COUNT" ] || \
        problem "catálogo contém $catalog_count decisões; esperado $EXPECTED_COUNT"

    awk -F '\t' 'NR > 1 { count[$1]++ } END { for (task in count) if (count[task] != 1) print task }' \
        "$CATALOG" > "$TMP_DIR/duplicates"
    while IFS= read -r duplicate; do
        [ -z "$duplicate" ] || problem "task ausente/duplicada no catálogo: $duplicate"
    done < "$TMP_DIR/duplicates"

    tail -n +2 "$CATALOG" > "$TMP_DIR/catalog-data"
    while IFS= read -r line || [ -n "$line" ]; do
        fields="$(printf '%s\n' "$line" | awk -F '\t' '{ print NF }')"
        if [ "$fields" -ne 6 ]; then
            problem "linha do catálogo deve possuir 6 campos TSV: $line"
            continue
        fi
        task="$(printf '%s\n' "$line" | awk -F '\t' '{ print $1 }')"
        action="$(printf '%s\n' "$line" | awk -F '\t' '{ print $2 }')"
        destination="$(printf '%s\n' "$line" | awk -F '\t' '{ print $3 }')"
        consumers="$(printf '%s\n' "$line" | awk -F '\t' '{ print $4 }')"
        evidence="$(printf '%s\n' "$line" | awk -F '\t' '{ print $5 }')"
        reason="$(printf '%s\n' "$line" | awk -F '\t' '{ print $6 }')"

        case "$task" in
            ''|*[!A-Za-z0-9._-]*|*.md.md) problem "nome de task inválido: $task"; continue ;;
            *.md) ;;
            *) problem "nome de task inválido: $task"; continue ;;
        esac
        case "$action" in keep|rewrite|merge|remove) ;; *) problem "ação inválida para $task: $action" ;; esac
        case "$evidence" in pending|covered|not_applicable) ;; *) problem "evidência inválida para $task: $evidence" ;; esac
        [ -n "$reason" ] || problem "justificativa ausente para $task"
        if [ "$action" = merge ] && [ -z "$destination" ]; then
            problem "merge sem destino: $task"
        fi

        if [ "$action" = merge ] && [ "$evidence" = covered ]; then
            fixture_rows="$(awk -F '\t' -v task="$task" 'NR > 1 && $1 == task { count++ } END { print count + 0 }' "$TMP_DIR/merged-fixtures")"
            if [ "$fixture_rows" -ne 1 ]; then
                problem "fixture de capacidade ausente/duplicada para merge coberto: $task"
            else
                fixture_line="$(awk -F '\t' -v task="$task" 'NR > 1 && $1 == task { print; exit }' "$TMP_DIR/merged-fixtures")"
                fixture_fields="$(printf '%s\n' "$fixture_line" | awk -F '\t' '{ print NF }')"
                if [ "$fixture_fields" -ne 6 ]; then
                    problem "fixture de capacidade deve possuir 6 campos TSV: $task"
                else
                    capability="$(printf '%s\n' "$fixture_line" | awk -F '\t' '{ print $2 }')"
                    entrypoints="$(printf '%s\n' "$fixture_line" | awk -F '\t' '{ print $3 }')"
                    fixture_destinations="$(printf '%s\n' "$fixture_line" | awk -F '\t' '{ print $4 }')"
                    expected_result="$(printf '%s\n' "$fixture_line" | awk -F '\t' '{ print $5 }')"
                    fixture_evidence="$(printf '%s\n' "$fixture_line" | awk -F '\t' '{ print $6 }')"
                    case "$capability" in ''|*[!a-z0-9-]*) problem "capability inválida para $task: $capability" ;; esac
                    [ -n "$expected_result" ] || problem "resultado esperado ausente na fixture: $task"
                    [ "$fixture_evidence" = covered ] || problem "fixture sem cobertura para merge: $task"

                    printf '%s\n%s\n' "$entrypoints" "$fixture_destinations" | tr '|' '\n' > "$TMP_DIR/fixture-routes"
                    while IFS= read -r rel; do
                        [ -n "$rel" ] || { problem "rota vazia na fixture: $task"; continue; }
                        if ! safe_product_path "$rel"; then
                            problem "rota inválida na fixture para $task: $rel"
                        elif [ ! -f "$ROOT/$rel" ]; then
                            problem "rota ausente na fixture para $task: $rel"
                        elif ! grep -Fq "Capability: $capability" "$ROOT/$rel"; then
                            problem "rota sem marcador de capability para $task: $rel"
                        fi
                    done < "$TMP_DIR/fixture-routes"

                    printf '%s\n' "$destination" | tr '|' '\n' > "$TMP_DIR/catalog-destinations"
                    while IFS= read -r rel; do
                        [ -z "$rel" ] && continue
                        case "|$fixture_destinations|" in
                            *"|$rel|"*) ;;
                            *) problem "destino do catálogo não coberto pela fixture para $task: $rel" ;;
                        esac
                    done < "$TMP_DIR/catalog-destinations"
                fi
            fi
        fi

        printf '%s\n' "$destination" | tr '|' '\n' > "$TMP_DIR/destinations"
        while IFS= read -r rel; do
            [ -n "$rel" ] || continue
            if ! safe_product_path "$rel"; then
                problem "destino inválido para $task: $rel"
            elif [ ! -e "$ROOT/$rel" ]; then
                problem "destino ausente para $task: $rel"
            fi
        done < "$TMP_DIR/destinations"
        if [ "$consumers" = none ]; then
            case "$action" in merge|remove) ;; *) problem "consumidor ausente para task ativa: $task" ;; esac
        else
            printf '%s\n' "$consumers" | tr '|' '\n' > "$TMP_DIR/consumers"
            while IFS= read -r rel; do
                if ! safe_product_path "$rel"; then
                    problem "consumidor inválido para $task: $rel"
                elif [ ! -e "$ROOT/$rel" ]; then
                    problem "consumidor órfão para $task: $rel"
                fi
            done < "$TMP_DIR/consumers"
        fi

        source_path="$TASK_DIR/$task"
        if [ -f "$source_path" ]; then
            :
        elif { [ "$action" = merge ] || [ "$action" = remove ]; } && [ "$evidence" = covered ]; then
            refs="$TMP_DIR/refs-$task"
            grep -RFn --exclude=task-dispositions.tsv --exclude=legacy-reference-allowlist.tsv \
                --exclude=merged-task-fixtures.md \
                -e ".claude/mosk/tasks/$task" -e "../tasks/$task" "$ROOT/.claude" > "$refs" 2>/dev/null || true
            if [ -s "$refs" ]; then
                problem "referência ativa a path removido: $task"
            fi
        else
            problem "task ausente sem absorção coberta: $task"
        fi
    done < "$TMP_DIR/catalog-data"
fi

if [ -d "$TASK_DIR" ]; then
    task_count="$(find "$TASK_DIR" -maxdepth 1 -type f -name '*.md' | wc -l | tr -d ' ')"
    find "$TASK_DIR" -maxdepth 1 -type f -name '*.md' -exec basename {} \; | sort > "$TMP_DIR/tasks-on-disk"
    if [ -f "$CATALOG" ]; then
        awk -F '\t' 'NR > 1 { print $1 }' "$CATALOG" | sort -u > "$TMP_DIR/tasks-catalog"
        comm -23 "$TMP_DIR/tasks-on-disk" "$TMP_DIR/tasks-catalog" > "$TMP_DIR/untracked"
        while IFS= read -r task; do
            [ -z "$task" ] || problem "task sem decisão no catálogo: $task"
        done < "$TMP_DIR/untracked"
    fi
fi

if [ -s "$TMP_DIR/merged-fixtures" ] && [ -f "$CATALOG" ]; then
    tail -n +2 "$TMP_DIR/merged-fixtures" > "$TMP_DIR/merged-fixture-data"
    while IFS="$(printf '\t')" read -r legacy_task capability entrypoints destinations expected_result fixture_evidence; do
        [ -n "$legacy_task" ] || continue
        catalog_rows="$(awk -F '\t' -v task="$legacy_task" 'NR > 1 && $1 == task && $2 == "merge" && $5 == "covered" { count++ } END { print count + 0 }' "$CATALOG")"
        [ "$catalog_rows" -eq 1 ] || problem "fixture sem merge covered correspondente no catálogo: $legacy_task"
    done < "$TMP_DIR/merged-fixture-data"
fi

if [ ! -f "$BASELINE_METRICS" ]; then
    problem "baseline de medição ausente: .claude/mosk/data/legacy-baseline-metrics.tsv"
elif [ -f "$CATALOG" ]; then
    baseline_header="$(sed -n '1p' "$BASELINE_METRICS")"
    if [ "$baseline_header" != "task	baseline_lines" ]; then
        problem "header inválido em legacy-baseline-metrics.tsv"
    else
        tail -n +2 "$BASELINE_METRICS" > "$TMP_DIR/baseline-data"

        awk -F '\t' '{ count[$1]++ } END { for (task in count) if (count[task] != 1) print task }' \
            "$TMP_DIR/baseline-data" | sort > "$TMP_DIR/baseline-duplicates"
        while IFS= read -r duplicate; do
            [ -z "$duplicate" ] || problem "task duplicada na baseline de medição: $duplicate"
        done < "$TMP_DIR/baseline-duplicates"

        awk -F '\t' 'NR > 1 && $2 == "rewrite" { print $1 }' "$CATALOG" | sort -u > "$TMP_DIR/corpus-catalog"
        awk -F '\t' '{ print $1 }' "$TMP_DIR/baseline-data" | sort -u > "$TMP_DIR/corpus-baseline"
        comm -23 "$TMP_DIR/corpus-catalog" "$TMP_DIR/corpus-baseline" > "$TMP_DIR/corpus-unmeasured"
        while IFS= read -r task; do
            [ -z "$task" ] || problem "task rewrite sem baseline de medição: $task"
        done < "$TMP_DIR/corpus-unmeasured"

        while IFS= read -r line || [ -n "$line" ]; do
            [ -n "$line" ] || continue
            fields="$(printf '%s\n' "$line" | awk -F '\t' '{ print NF }')"
            if [ "$fields" -ne 2 ]; then
                problem "linha da baseline deve possuir 2 campos TSV: $line"
                continue
            fi
            task="$(printf '%s\n' "$line" | awk -F '\t' '{ print $1 }')"
            baseline_lines="$(printf '%s\n' "$line" | awk -F '\t' '{ print $2 }')"
            case "$baseline_lines" in
                ''|*[!0-9]*) problem "baseline não numérica para $task: $baseline_lines"; continue ;;
            esac
            action="$(catalog_field "$task" 2)"
            evidence="$(catalog_field "$task" 5)"
            case "$action" in
                rewrite) ;;
                merge|remove)
                    [ "$evidence" = covered ] || \
                        problem "task da baseline fora do corpus rewrite: $task"
                    ;;
                *) problem "task da baseline fora do corpus rewrite: $task"; continue ;;
            esac

            baseline_total=$((baseline_total + baseline_lines))
            source_path="$TASK_DIR/$task"
            if [ -f "$source_path" ]; then
                measured="$(measure_operational_lines "$source_path")"
                current_total=$((current_total + measured))
            elif { [ "$action" = merge ] || [ "$action" = remove ]; } && [ "$evidence" = covered ]; then
                :
            else
                problem "task do corpus ausente sem absorção coberta: $task"
            fi
        done < "$TMP_DIR/baseline-data"

        reduction_ceiling=$((baseline_total * REDUCTION_KEEP_PERCENT / 100))
        if [ "$current_total" -gt "$reduction_ceiling" ]; then
            problem "redução insuficiente no corpus: $current_total linhas medidas > teto $reduction_ceiling (baseline $baseline_total)"
        fi
    fi
fi

if [ -d "$ROOT/.claude" ]; then
    find "$ROOT/.claude" -type f ! -name '.DS_Store' -print | sort > "$TMP_DIR/contract-candidates"
    printf '%s\n%s\n' "$CONTRACT_ADAPTIVE" "$CONTRACT_OUTPUT" > "$TMP_DIR/contract-list"
    while IFS= read -r contract_rel; do
        [ -n "$contract_rel" ] || continue
        contract_abs="$ROOT/$contract_rel"
        if [ ! -f "$contract_abs" ]; then
            problem "contrato canônico ausente: $contract_rel"
            continue
        fi
        marker_starts="$(grep -Fc '<!-- contract-normative:start -->' "$contract_abs" || true)"
        marker_ends="$(grep -Fc '<!-- contract-normative:end -->' "$contract_abs" || true)"
        if [ "$marker_starts" -ne 1 ] || [ "$marker_ends" -ne 1 ]; then
            problem "marcadores do bloco normativo ausentes/duplicados: $contract_rel"
            continue
        fi
        awk -v min="$SENTINEL_MIN_LENGTH" '
            /<!-- contract-normative:start -->/ { inside = 1; next }
            /<!-- contract-normative:end -->/ { inside = 0; next }
            inside {
                gsub(/^[[:space:]]+|[[:space:]]+$/, "")
                gsub(/[[:space:]]+/, " ")
                if (length($0) >= min) print
            }
        ' "$contract_abs" | sort -u > "$TMP_DIR/contract-sentinels"
        sentinel_count="$(wc -l < "$TMP_DIR/contract-sentinels" | tr -d ' ')"
        if [ "$sentinel_count" -lt "$CONTRACT_MIN_SENTINELS" ]; then
            problem "bloco normativo curto demais para auditar cópias: $contract_rel"
            continue
        fi
        LC_ALL=C awk -v sentinels="$TMP_DIR/contract-sentinels" \
            -v list="$TMP_DIR/contract-candidates" \
            -v skip="$contract_abs" \
            -v min="$SENTINEL_MIN_LENGTH" \
            -v threshold="$CONTRACT_MIN_MATCHES" '
            BEGIN {
                while ((getline sentinel < sentinels) > 0) known[sentinel] = 1
                while ((getline candidate < list) > 0) {
                    if (candidate == skip || candidate == "") continue
                    split("", seen)
                    hits = 0
                    while ((getline row < candidate) > 0) {
                        norm = row
                        gsub(/^[[:space:]]+|[[:space:]]+$/, "", norm)
                        gsub(/[[:space:]]+/, " ", norm)
                        if (length(norm) < min) continue
                        if ((norm in known) && !(norm in seen)) {
                            seen[norm] = 1
                            hits++
                        }
                    }
                    close(candidate)
                    if (hits >= threshold) printf "%s\t%d\n", candidate, hits
                }
            }
        ' > "$TMP_DIR/contract-copies"
        while IFS="$(printf '\t')" read -r copy hits; do
            [ -n "$copy" ] || continue
            rel="${copy#"$ROOT/"}"
            contract_duplications=$((contract_duplications + 1))
            problem "$rel :: cópia divergente do contrato $contract_rel ($hits linhas normativas verbatim)"
        done < "$TMP_DIR/contract-copies"
    done < "$TMP_DIR/contract-list"
fi

allow_path() {
    candidate="$1"
    [ -f "$ALLOWLIST" ] || return 1
    sed '1d' "$ALLOWLIST" > "$TMP_DIR/allow-data"
    while IFS="$(printf '\t')" read -r pattern kind reason; do
        [ -n "$pattern" ] || continue
        case "$candidate" in $pattern) return 0 ;; esac
    done < "$TMP_DIR/allow-data"
    return 1
}

if [ -f "$ALLOWLIST" ]; then
    allow_header="$(sed -n '1p' "$ALLOWLIST")"
    [ "$allow_header" = "path_pattern	kind	reason" ] || problem "header inválido em legacy-reference-allowlist.tsv"
    sed '1d' "$ALLOWLIST" > "$TMP_DIR/allow-data"
    while IFS="$(printf '\t')" read -r pattern kind reason; do
        case "$kind" in license|attribution|archive) ;; *) problem "kind inválido na allowlist: $kind" ;; esac
        [ -n "$reason" ] || problem "justificativa ausente na allowlist: $pattern"
        case "$pattern" in
            .claude/*|docs/specs/archive/*) ;;
            *) problem "pattern amplo ou fora do escopo na allowlist: $pattern" ;;
        esac
        case "$pattern" in /*|*'/../'*|../*|*'//') problem "pattern inseguro na allowlist: $pattern" ;; esac
        if [ "$pattern" = '.claude/**' ] || [ "$pattern" = 'docs/**' ]; then
            problem "pattern inseguro na allowlist: $pattern"
        fi
    done < "$TMP_DIR/allow-data"
fi

if [ -d "$ROOT/.claude" ]; then
    legacy_regex='(^|[^[:alnum:]_])[Bb][Mm][Aa][Dd]([^[:alnum:]_]|$)'
    grep -RniE --exclude=task-dispositions.tsv --exclude=legacy-reference-allowlist.tsv \
        "$legacy_regex" "$ROOT/.claude" > "$TMP_DIR/legacy" 2>/dev/null || true
    while IFS=: read -r file line rest; do
        [ -n "$file" ] || continue
        rel="${file#"$ROOT/"}"
        if ! allow_path "$rel"; then
            legacy_count=$((legacy_count + 1))
            problem "$rel:$line :: referência legada operacional fora da allowlist"
        fi
    done < "$TMP_DIR/legacy"
fi

failure_count="$(wc -l < "$ERRORS" | tr -d ' ')"
if [ "$JSON" -eq 1 ]; then
    printf '{"ok":%s,"catalog":%s,"tasks_on_disk":%s,"legacy_violations":%s,"failures":%s,"corpus_baseline_lines":%s,"corpus_current_lines":%s,"corpus_ceiling_lines":%s,"contract_duplications":%s}\n' \
        "$([ "$failure_count" -eq 0 ] && printf true || printf false)" \
        "$catalog_count" "$task_count" "$legacy_count" "$failure_count" \
        "$baseline_total" "$current_total" "$reduction_ceiling" "$contract_duplications"
elif [ "$failure_count" -gt 0 ]; then
    [ "$QUIET" -eq 1 ] || sed 's/^/falha  /' "$ERRORS" >&2
else
    [ "$QUIET" -eq 1 ] || printf 'audit-legacy-surface: íntegro (%s decisões, %s tasks ativas, corpus %s→%s linhas com teto %s)\n' \
        "$catalog_count" "$task_count" "$baseline_total" "$current_total" "$reduction_ceiling"
fi

[ "$failure_count" -eq 0 ]
