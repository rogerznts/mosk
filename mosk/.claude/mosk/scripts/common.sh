#!/usr/bin/env bash
# Common functions and variables for all scripts

# ───────────────────── localização deste arquivo (bash E zsh) ─────────────────────
# As tasks do MOSK mandam o agente rodar `source common.sh` no shell DELE — e o
# shell padrão do macOS é zsh, onde `BASH_SOURCE` não existe. Resolver caminho com
# `${BASH_SOURCE[0]}` degradava em silêncio nesse caso: `dirname ""` → `.`, e todo
# caminho passava a resolver a partir do cwd — de modo que todo helper de caminho
# (`get_repo_root`, `core_config_file`, …) apontava para fora do repo sem que nada
# reclamasse. A falha é silenciosa por natureza, então ela é coberta por teste:
# `selftest-common.sh` sourceia este arquivo de um cwd diferente, nos dois shells.
#
# Resolvido uma vez, no escopo de TOPO: em zsh, `$0` só é o arquivo sourceado aqui
# (dentro de uma função ele passa a ser o nome da função).
if [[ -z "${MOSK_SCRIPTS_DIR:-}" ]]; then
    if [[ -n "${BASH_SOURCE[0]:-}" ]]; then
        _mosk_common_self="${BASH_SOURCE[0]}"
    elif [[ -n "${ZSH_VERSION:-}" ]]; then
        # The next expansion is parsed by zsh at runtime.
        # shellcheck disable=SC2296
        _mosk_common_self="${(%):-%x}"   # equivalente zsh de BASH_SOURCE[0]
    else
        _mosk_common_self="$0"
    fi
    MOSK_SCRIPTS_DIR="$(cd "$(dirname "$_mosk_common_self")" 2>/dev/null && pwd)"
    unset _mosk_common_self
fi

# Avisa alto em vez de resolver errado em silêncio: se o diretório detectado não
# contém este arquivo, a detecção falhou, e seguir daqui é exatamente o defeito
# que esta correção remove.
if [[ ! -f "${MOSK_SCRIPTS_DIR:-}/common.sh" ]]; then
    echo "aviso: common.sh não resolveu seu próprio diretório (obtido: '${MOSK_SCRIPTS_DIR:-}')." >&2
    echo "  Exporte MOSK_SCRIPTS_DIR com o caminho de .claude/mosk/scripts/ para corrigir." >&2
fi

# Get repository root, with fallback for non-git repositories
get_repo_root() {
    if git rev-parse --show-toplevel >/dev/null 2>&1; then
        git rev-parse --show-toplevel
    else
        # Fall back to script location for non-git repos
        # Script is in .claude/mosk/scripts/, so go up 3 levels to reach repo root
        (cd "$MOSK_SCRIPTS_DIR/../../.." && pwd)
    fi
}

# Get current branch, with fallback for non-git repositories
get_current_branch() {
    # First check if SPECIFY_FEATURE environment variable is set
    if [[ -n "${SPECIFY_FEATURE:-}" ]]; then
        echo "$SPECIFY_FEATURE"
        return
    fi

    # Then check git if available
    if git rev-parse --abbrev-ref HEAD >/dev/null 2>&1; then
        git rev-parse --abbrev-ref HEAD
        return
    fi

    # For non-git repos, try to find the latest feature directory
    local repo_root=$(get_repo_root)
    local specs_dir="$repo_root/docs/specs"

    if [[ -d "$specs_dir" ]]; then
        local latest_feature=""
        local highest=0

        for dir in "$specs_dir"/*; do
            if [[ -d "$dir" ]]; then
                local dirname=$(basename "$dir")
                if [[ "$dirname" =~ ^([0-9]{3})- ]]; then
                    local number=${BASH_REMATCH[1]}
                    number=$((10#$number))
                    if [[ "$number" -gt "$highest" ]]; then
                        highest=$number
                        latest_feature=$dirname
                    fi
                fi
            fi
        done

        if [[ -n "$latest_feature" ]]; then
            echo "$latest_feature"
            return
        fi
    fi

    echo "main"  # Final fallback
}

# Check if we have git available
has_git() {
    git rev-parse --show-toplevel >/dev/null 2>&1
}

check_feature_branch() {
    local branch="$1"
    local has_git_repo="$2"

    # For non-git repos, we can't enforce branch naming but still provide output
    if [[ "$has_git_repo" != "true" ]]; then
        echo "[specify] Warning: Git repository not detected; skipped branch validation" >&2
        return 0
    fi

    # Aceita os DOIS formatos (ADR-0017), com a mesma âncora do resto do toolkit:
    #   canônico : feature/012-algo      → segmento de tipo + NNN-
    #   legado   : 012-feature-algo      → NNN- direto
    # Sem o segmento opcional, TODO branch criado no formato canônico era
    # rejeitado aqui — e como `setup-plan.sh` e `check-prerequisites.sh` chamam
    # esta função, isso bloqueava plan, tasks, implement e qa-gate.
    if [[ ! "$branch" =~ ^([a-z][a-z-]*/)?[0-9]{3}- ]]; then
        echo "ERROR: Not on a spec branch. Current branch: $branch" >&2
        echo "Spec branches look like: feature/012-checkout-coupon" >&2
        echo "  (legacy 012-feature-checkout-coupon is still accepted)" >&2
        return 1
    fi

    return 0
}

get_feature_dir() { echo "$1/docs/specs/$2"; }

# Find feature directory by numeric prefix instead of exact branch match
# This allows multiple branches to work on the same spec (e.g., 004-fix-bug, 004-add-feature)
find_feature_dir_by_prefix() {
    local repo_root="$1"
    local branch_name="$2"
    local specs_dir="$repo_root/docs/specs"

    # Extrai o prefixo numérico do branch, nos DOIS formatos (ADR-0017):
    #   legado : 004-whatever          → 004
    #   novo   : feature/012-whatever  → 012
    #
    # A âncora `^` vem antes do segmento de tipo e é o que impede que um "NNN-"
    # embutido no meio do nome seja lido como spec.
    #
    # Sem o segmento opcional, um branch no formato novo cairia no fallback de
    # match exato e procuraria `docs/specs/feature/012-whatever` — caminho que
    # nunca existe, porque a pasta é plana por decisão (ADR-0017 §4).
    if [[ ! "$branch_name" =~ ^([a-z][a-z-]*/)?([0-9]{3})- ]]; then
        # Branch sem prefixo numérico: cai para match exato.
        echo "$specs_dir/$branch_name"
        return
    fi

    local prefix="${BASH_REMATCH[2]}"

    # Search for directories in specs/ that start with this prefix
    local matches=()
    if [[ -d "$specs_dir" ]]; then
        for dir in "$specs_dir"/"$prefix"-*; do
            if [[ -d "$dir" ]]; then
                matches+=("$(basename "$dir")")
            fi
        done
    fi

    # Handle results
    if [[ ${#matches[@]} -eq 0 ]]; then
        # No match found - return the branch name path (will fail later with clear error)
        echo "$specs_dir/$branch_name"
    elif [[ ${#matches[@]} -eq 1 ]]; then
        # Exactly one match - perfect!
        echo "$specs_dir/${matches[0]}"
    else
        # Multiple matches - this shouldn't happen with proper naming convention
        echo "ERROR: Multiple spec directories found with prefix '$prefix': ${matches[*]}" >&2
        echo "Please ensure only one spec directory exists per numeric prefix." >&2
        echo "$specs_dir/$branch_name"  # Return something to avoid breaking the script
    fi
}

# Resolve a spec do branch tanto na área ativa quanto no archive. Use somente
# em verificações históricas (ship-ready, auditoria): as tasks do pipeline devem
# continuar usando find_feature_dir_by_prefix para não reabrir spec arquivada.
find_feature_dir_by_prefix_any() {
    local repo_root="$1"
    local branch_name="$2"
    local specs_dir="$repo_root/docs/specs"

    if [[ ! "$branch_name" =~ ^([a-z][a-z-]*/)?([0-9]{3})- ]]; then
        return 1
    fi

    local prefix="${BASH_REMATCH[2]}"
    local matches=()
    local dir
    for dir in "$specs_dir"/"$prefix"-* "$specs_dir/archive"/"$prefix"-*; do
        [[ -d "$dir" ]] && matches+=("$dir")
    done

    if [[ ${#matches[@]} -eq 1 ]]; then
        echo "${matches[0]}"
        return 0
    fi
    if [[ ${#matches[@]} -gt 1 ]]; then
        echo "ERROR: Multiple active/archived specs found with prefix '$prefix': ${matches[*]}" >&2
    fi
    return 1
}

get_feature_paths() {
    local repo_root=$(get_repo_root)
    local current_branch=$(get_current_branch)
    local has_git_repo="false"

    if has_git; then
        has_git_repo="true"
    fi

    # Numbered branches resolve through metadata; base/non-spec branches retain
    # the historical fallback so callers can print prospective paths.
    local feature_dir
    if [[ "$current_branch" =~ ^([a-z][a-z-]*/)?[0-9]{3}- ]]; then
        feature_dir="$(resolve_spec_dir "$repo_root" "$current_branch" active)" || return 1
    else
        feature_dir="$(find_feature_dir_by_prefix "$repo_root" "$current_branch")"
    fi

    cat <<EOF
REPO_ROOT='$repo_root'
CURRENT_BRANCH='$current_branch'
HAS_GIT='$has_git_repo'
FEATURE_DIR='$feature_dir'
FEATURE_SPEC='$feature_dir/spec.md'
IMPL_PLAN='$feature_dir/plan.md'
TASKS='$feature_dir/tasks.md'
RESEARCH='$feature_dir/research.md'
DATA_MODEL='$feature_dir/data-model.md'
QUICKSTART='$feature_dir/quickstart.md'
CONTRACTS_DIR='$feature_dir/contracts'
EOF
}

check_file() { [[ -f "$1" ]] && echo "  ✓ $2" || echo "  ✗ $2"; }
check_dir() { [[ -d "$1" && -n $(ls -A "$1" 2>/dev/null) ]] && echo "  ✓ $2" || echo "  ✗ $2"; }

# ---------- spec-meta.yaml helpers ----------
# These read/write a minimal YAML with top-level scalar keys only
# (spec_number, spec_id, type, branch, created_at, created_by, status,
# current_phase, archived_at, last_phase_change). No nested structures,
# no arrays — keep it simple and shell-friendly.

# Read one key from a spec-meta.yaml. Usage: read_spec_meta <spec_dir> <key>
# Echoes the value (without surrounding quotes) or empty if not found.
read_spec_meta() {
    local spec_dir="$1"
    local key="$2"
    local meta_file="$spec_dir/spec-meta.yaml"
    [[ -f "$meta_file" ]] || return 0
    awk -v k="$key" '
        $0 ~ "^" k "[[:space:]]*:" {
            sub("^" k "[[:space:]]*:[[:space:]]*", "", $0)
            sub("[[:space:]]*#.*$", "", $0)
            sub("^\"", "", $0); sub("\"$", "", $0)
            print
            exit
        }
    ' "$meta_file"
}

# Read a top-level scalar from a small YAML file. This intentionally supports
# only the shell-legible subset used by gate.yaml/spec-meta.yaml.
read_yaml_scalar() {
    local file="$1"
    local key="$2"
    [[ -f "$file" ]] || return 0
    awk -v k="$key" '
        $0 ~ "^" k "[[:space:]]*:" {
            sub("^" k "[[:space:]]*:[[:space:]]*", "", $0)
            sub("[[:space:]]*#.*$", "", $0)
            sub("^\"", "", $0); sub("\"$", "", $0)
            sub("^\047", "", $0); sub("\047$", "", $0)
            sub("^[[:space:]]+", "", $0)
            sub("[[:space:]]+$", "", $0)
            print
            exit
        }
    ' "$file"
}

# Reject ambiguous YAML before any security-sensitive scalar is consumed. The
# runtime intentionally supports only a small, line-oriented YAML subset, so a
# duplicate key is always a contract violation rather than merge semantics.
validate_no_duplicate_yaml_keys() {
    local file="$1" key counts plain_count alternate_count
    shift
    for key in "$@"; do
        counts="$(awk -v k="$key" '
            $0 ~ "^[[:space:]]*(\"" k "\"|\047" k "\047|" k ")[[:space:]]*:" {
                if ($0 ~ "^" k "[[:space:]]*:") plain++
                else alternate++
            }
            END { print plain + 0 ":" alternate + 0 }
        ' "$file")"
        plain_count="${counts%%:*}"
        alternate_count="${counts#*:}"
        [[ "$alternate_count" -eq 0 ]] || {
            echo "chave YAML '$key' usa representação não suportada em $file; use chave top-level sem aspas" >&2
            return 1
        }
        [[ "$plain_count" -le 1 ]] || {
            echo "chave YAML duplicada '$key' em $file" >&2
            return 1
        }
    done
}

phase_command_matches_destination() {
    case "$1:$2" in
        plan:plan|tasks:tasks|implement:implement|apply-qa-fixes:implement|qa-gate:qa-gate|archive:archived|migration:*) return 0 ;;
        *) return 1 ;;
    esac
}

# Validate the complete append-only transition chain. New schema-2 specs record
# origin=specify and therefore must start at specify -> plan. A legacy active
# spec upgraded by the transition sink records origin=migration explicitly,
# which authorizes a later first edge without pretending earlier events exist.
validate_phase_history() {
    local spec_dir="$1" current_phase="$2" expected_last_at="${3:-}"
    local history="$spec_dir/phase-history.yaml" parsed meta_schema require_origin=0
    [[ -f "$history" ]] || return 0
    meta_schema="$(read_spec_meta "$spec_dir" schema)"; meta_schema="${meta_schema:-1}"
    [[ "$meta_schema" == 2 ]] && require_origin=1

    if ! parsed="$(awk -v require_origin="$require_origin" '
        function value_after_colon(line, value) {
            value=line
            sub(/^[^:]*:[[:space:]]*/, "", value)
            sub(/[[:space:]]+$/, "", value)
            if ((substr(value, 1, 1) == "\"" && substr(value, length(value), 1) == "\"") ||
                (substr(value, 1, 1) == "\047" && substr(value, length(value), 1) == "\047")) {
                value=substr(value, 2, length(value) - 2)
            }
            return value
        }
        function invalid(message) {
            print "phase-history inválido na linha " NR ": " message > "/dev/stderr"
            bad=1
            exit 1
        }
        function flush_event() {
            if (!in_event || bad) return
            if (at_count != 1 || from_count != 1 || to_count != 1 || command_count != 1) {
                invalid("evento exige exatamente at, from, to e command")
            }
            print at "\t" from "\t" to "\t" command
            events++
        }
        /^[[:space:]]*$/ || /^[[:space:]]*#/ { next }
        /^schema[[:space:]]*:/ {
            schema_count++
            schema=value_after_colon($0)
            next
        }
        /^origin[[:space:]]*:/ {
            origin_count++
            origin=value_after_colon($0)
            next
        }
        /^transitions[[:space:]]*:[[:space:]]*$/ {
            transitions_count++
            next
        }
        /^  - at[[:space:]]*:/ {
            flush_event()
            in_event=1
            at_count=1; from_count=to_count=command_count=0
            at=value_after_colon($0)
            next
        }
        /^    at[[:space:]]*:/ { at_count++; at=value_after_colon($0); next }
        /^    from[[:space:]]*:/ { from_count++; from=value_after_colon($0); next }
        /^    to[[:space:]]*:/ { to_count++; to=value_after_colon($0); next }
        /^    command[[:space:]]*:/ { command_count++; command=value_after_colon($0); next }
        { invalid("estrutura ou chave desconhecida") }
        END {
            if (bad) exit 1
            flush_event()
            if (schema_count != 1 || schema != "1") invalid("schema deve ocorrer uma vez e ser 1")
            if (origin_count > 1 || (origin_count == 1 && origin != "specify" && origin != "migration")) {
                invalid("origin deve ocorrer no máximo uma vez e ser specify ou migration")
            }
            if (require_origin == 1 && origin_count != 1) {
                invalid("origin deve ocorrer uma vez no histórico do schema 2")
            }
            if (transitions_count != 1) invalid("transitions deve ocorrer uma vez")
            if (events < 1) invalid("histórico existente deve conter ao menos um evento")
            if (origin_count == 0) origin="migration"
            print "@origin\t" origin
        }
    ' "$history")"; then
        return 1
    fi

    local at from to command history_origin="" previous_to="" previous_at="" last_to="" last_at="" event_count=0
    while IFS=$'\t' read -r at from to command; do
        [[ -n "$at" ]] || continue
        if [[ "$at" == @origin ]]; then
            history_origin="$from"
            continue
        fi
        event_count=$((event_count + 1))
        [[ "$at" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$ ]] || {
            echo "timestamp inválido no evento $event_count de $history" >&2
            return 1
        }
        case "$from:$to" in
            specify:plan|plan:tasks|tasks:implement|implement:qa-gate|qa-gate:implement|qa-gate:archived) ;;
            *) echo "aresta inválida no evento $event_count de $history: $from -> $to" >&2; return 1 ;;
        esac
        phase_command_matches_destination "$command" "$to" || {
            echo "command inválido no evento $event_count de $history: $command -> $to" >&2
            return 1
        }
        if [[ -n "$previous_to" && "$from" != "$previous_to" ]]; then
            echo "cadeia descontínua no evento $event_count de $history" >&2
            return 1
        fi
        if [[ -n "$previous_at" && "$at" < "$previous_at" ]]; then
            echo "timestamps regressivos no evento $event_count de $history" >&2
            return 1
        fi
        previous_to="$to"
        previous_at="$at"
        last_to="$to"
        last_at="$at"
    done <<< "$parsed"

    if [[ "$history_origin" == specify && "$event_count" -gt 0 ]]; then
        local first_event
        first_event="$(printf '%s\n' "$parsed" | awk -F '\t' '$1 != "@origin" { print $2 ":" $3; exit }')"
        [[ "$first_event" == specify:plan ]] || {
            echo "phase-history truncado em $spec_dir: origin specify exige primeiro evento specify -> plan" >&2
            return 1
        }
    fi

    [[ "$event_count" -gt 0 && "$last_to" == "$current_phase" ]] || {
        echo "phase-history diverge de current_phase em $spec_dir" >&2
        return 1
    }
    if [[ -n "$expected_last_at" && "$last_at" != "$expected_last_at" ]]; then
        echo "phase-history diverge de last_phase_change em $spec_dir" >&2
        return 1
    fi
}

validate_spec_storage_root() {
    local repo_root="$1" docs_root="$1/docs" specs_root="$1/docs/specs"
    [[ -d "$docs_root" && ! -L "$docs_root" ]] || {
        echo "diretório docs ausente ou inseguro em $repo_root" >&2
        return 1
    }
    [[ -d "$specs_root" && ! -L "$specs_root" ]] || {
        echo "diretório de specs ausente ou inseguro em $repo_root" >&2
        return 1
    }
}

# Require an immediate, physical child of the selected specs root. This blocks
# both a symlink candidate and an intermediate docs/specs/archive symlink.
validate_spec_dir_containment() {
    local repo_root="$1" spec_dir="${2%/}" area="${3:-active}"
    local specs_root="$repo_root/docs/specs" archive_root="$repo_root/docs/specs/archive"
    local expected_parent actual_parent root_physical dir_physical
    validate_spec_storage_root "$repo_root" || return 1
    [[ -d "$spec_dir" && ! -L "$spec_dir" ]] || {
        echo "diretório de spec ausente ou inseguro: $spec_dir" >&2
        return 1
    }
    actual_parent="$(dirname "$spec_dir")"
    case "$area" in
        active) expected_parent="$specs_root" ;;
        archive)
            [[ -d "$archive_root" && ! -L "$archive_root" ]] || {
                echo "diretório de archive ausente ou inseguro: $archive_root" >&2
                return 1
            }
            expected_parent="$archive_root"
            ;;
        any)
            if [[ "$actual_parent" == "$specs_root" ]]; then
                expected_parent="$specs_root"
            elif [[ "$actual_parent" == "$archive_root" ]]; then
                [[ -d "$archive_root" && ! -L "$archive_root" ]] || {
                    echo "diretório de archive ausente ou inseguro: $archive_root" >&2
                    return 1
                }
                expected_parent="$archive_root"
            else
                echo "spec fora das áreas permitidas: $spec_dir" >&2
                return 1
            fi
            ;;
        *) echo "área de spec inválida '$area'" >&2; return 1 ;;
    esac
    [[ "$actual_parent" == "$expected_parent" ]] || {
        echo "spec fora da área $area: $spec_dir" >&2
        return 1
    }
    root_physical="$(cd -P "$expected_parent" 2>/dev/null && pwd)" || return 1
    dir_physical="$(cd -P "$spec_dir" 2>/dev/null && pwd)" || return 1
    [[ "$(dirname "$dir_physical")" == "$root_physical" ]] || {
        echo "spec escapa fisicamente da área $area: $spec_dir" >&2
        return 1
    }
}

infer_repo_root_from_spec_dir() {
    local spec_dir="${1%/}" parent docs_root
    parent="$(dirname "$spec_dir")"
    [[ "$(basename "$parent")" == specs ]] || return 1
    docs_root="$(dirname "$parent")"
    [[ "$(basename "$docs_root")" == docs ]] || return 1
    dirname "$docs_root"
}

# Validate the shell-legible spec metadata contract. Legacy files without a
# schema are version 1 and stay readable; new writes use schema 2.
validate_spec_metadata() {
    local spec_dir="$1"
    local meta_file="$spec_dir/spec-meta.yaml"
    [[ -f "$meta_file" ]] || { echo "spec-meta.yaml ausente em $spec_dir" >&2; return 1; }

    validate_no_duplicate_yaml_keys "$meta_file" \
        schema spec_number spec_id type branch created_at created_by status \
        current_phase last_phase_change archived_at || return 1

    local schema number spec_id spec_type branch created_at created_by spec_status phase changed archived_at
    schema="$(read_spec_meta "$spec_dir" schema)"; schema="${schema:-1}"
    case "$schema" in 1|2) ;; *) echo "schema de spec-meta não suportado: '$schema'" >&2; return 1 ;; esac
    number="$(read_spec_meta "$spec_dir" spec_number)"
    spec_id="$(read_spec_meta "$spec_dir" spec_id)"
    spec_type="$(read_spec_meta "$spec_dir" type)"
    branch="$(read_spec_meta "$spec_dir" branch)"
    created_at="$(read_spec_meta "$spec_dir" created_at)"
    created_by="$(read_spec_meta "$spec_dir" created_by)"
    spec_status="$(read_spec_meta "$spec_dir" status)"
    phase="$(read_spec_meta "$spec_dir" current_phase)"
    changed="$(read_spec_meta "$spec_dir" last_phase_change)"
    archived_at="$(read_spec_meta "$spec_dir" archived_at)"

    [[ "$spec_id" == "$(basename "$spec_dir")" ]] || { echo "spec_id diverge do diretório em $meta_file" >&2; return 1; }
    [[ -n "$branch" ]] || { echo "branch ausente em $meta_file" >&2; return 1; }
    case "$spec_status" in active|archived) ;; *) echo "status inválido em $meta_file" >&2; return 1 ;; esac
    case "$phase" in specify|plan|tasks|implement|qa-gate|archived) ;; *) echo "current_phase inválido em $meta_file" >&2; return 1 ;; esac
    if [[ "$schema" == 2 ]]; then
        [[ "$number" =~ ^[0-9]{3}$ ]] || { echo "spec_number inválido em $meta_file" >&2; return 1; }
        case "$spec_type" in feature|fix|hotfix|gmud|refactor|experimental|extension) ;; *) echo "type inválido em $meta_file" >&2; return 1 ;; esac
        local id_number id_type id_slug branch_type branch_number branch_slug
        if [[ ! "$spec_id" =~ ^[0-9]{3}-(feature|fix|hotfix|gmud|refactor|experimental|extension)-[a-z0-9][a-z0-9-]*$ ]]; then
            echo "spec_id inválido no schema 2 em $meta_file" >&2
            return 1
        fi
        id_number="${spec_id%%-*}"
        id_type="${spec_id#*-}"; id_type="${id_type%%-*}"
        id_slug="${spec_id#*-*-}"
        if [[ ! "$branch" =~ ^(feature|fix|hotfix|gmud|refactor|experimental|extension)/[0-9]{3}-[a-z0-9][a-z0-9-]*$ ]]; then
            echo "branch inválida no schema 2 em $meta_file" >&2
            return 1
        fi
        branch_type="${branch%%/*}"
        branch_number="${branch#*/}"; branch_number="${branch_number%%-*}"
        branch_slug="${branch#*/}"; branch_slug="${branch_slug#*-}"
        [[ "$number" == "$id_number" && "$spec_type" == "$id_type" && \
           "$branch_number" == "$number" && "$branch_type" == "$spec_type" && \
           "$branch_slug" == "$id_slug" ]] || {
            echo "identidade divergente entre spec_number, spec_id, type e branch em $meta_file" >&2
            return 1
        }
        [[ "$created_at" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$ ]] || { echo "created_at inválido em $meta_file" >&2; return 1; }
        [[ "$changed" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$ ]] || { echo "last_phase_change inválido em $meta_file" >&2; return 1; }
        [[ -n "$created_by" ]] || { echo "created_by obrigatório no schema 2 em $meta_file" >&2; return 1; }
    fi
    if [[ "$spec_status" == archived || "$phase" == archived ]]; then
        [[ "$spec_status" == archived && "$phase" == archived ]] || {
            echo "estado archived incoerente em $meta_file" >&2; return 1;
        }
        if [[ "$schema" == 2 && ! "$archived_at" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$ ]]; then
            echo "archived_at obrigatório no schema 2 em $meta_file" >&2; return 1
        fi
    fi

    if [[ "$schema" == 2 && "$phase" != specify && ! -f "$spec_dir/phase-history.yaml" ]]; then
        echo "phase-history obrigatório no schema 2 após specify em $spec_dir" >&2
        return 1
    fi
    validate_phase_history "$spec_dir" "$phase" "$changed"
}

# Resolve by number, spec_id or registered branch. active never enters archive;
# any inspects both and fails on ambiguity instead of preferring one.
resolve_spec_dir() {
    local repo_root="$1" locator="$2" mode="${3:-active}"
    case "$mode" in active|any) ;; *) echo "modo de resolução inválido '$mode'" >&2; return 1 ;; esac
    [[ -n "$locator" ]] || { echo "locator de spec vazio" >&2; return 1; }

    local specs_root="$repo_root/docs/specs" locator_number="" locator_kind="id" locator_spec_id="" dir base number branch spec_id matched
    validate_spec_storage_root "$repo_root" || return 1
    if [[ "$locator" =~ ^[0-9]{3}$ ]]; then
        locator_number="$locator"
        locator_kind="number"
    elif [[ "$locator" == */* ]]; then
        locator_kind="branch"
        local locator_type="${locator%%/*}" locator_tail="${locator#*/}" locator_slug
        locator_number="${locator_tail%%-*}"
        locator_slug="${locator_tail#*-}"
        if [[ "$locator_type" =~ ^(feature|fix|hotfix|gmud|refactor|experimental|extension)$ && \
              "$locator_number" =~ ^[0-9]{3}$ && "$locator_slug" =~ ^[a-z0-9][a-z0-9-]*$ ]]; then
            locator_spec_id="$locator_number-$locator_type-$locator_slug"
        fi
    fi

    local matches_count=0 match_path="" match_list=""
    for dir in "$specs_root"/*; do
        [[ -d "$dir" && ! -L "$dir" && "$(basename "$dir")" != archive ]] || continue
        base="$(basename "$dir")"
        number="$(read_spec_meta "$dir" spec_number)"
        branch="$(read_spec_meta "$dir" branch)"
        spec_id="$(read_spec_meta "$dir" spec_id)"
        matched=false
        case "$locator_kind" in
            number) [[ "$base" == "$locator_number"-* ]] && matched=true ;;
            branch) [[ "$locator" == "$branch" || ( -n "$locator_spec_id" && "$base" == "$locator_spec_id" ) ]] && matched=true ;;
            id) [[ "$locator" == "$base" ]] && matched=true ;;
        esac
        if $matched; then
            validate_spec_dir_containment "$repo_root" "$dir" active || return 1
            validate_spec_metadata "$dir" || return 1
            [[ "$(read_spec_meta "$dir" status)" == active ]] || { echo "spec em área ativa não possui status active: $dir" >&2; return 1; }
            matches_count=$((matches_count + 1))
            match_path="$dir"
            match_list="${match_list:+$match_list }$dir"
        fi
    done
    if [[ "$mode" == any && -d "$specs_root/archive" ]]; then
        for dir in "$specs_root/archive"/*; do
            [[ -d "$dir" && ! -L "$dir" ]] || continue
            base="$(basename "$dir")"
            number="$(read_spec_meta "$dir" spec_number)"
            branch="$(read_spec_meta "$dir" branch)"
            spec_id="$(read_spec_meta "$dir" spec_id)"
            matched=false
            case "$locator_kind" in
                number) [[ "$base" == "$locator_number"-* ]] && matched=true ;;
                branch) [[ "$locator" == "$branch" || ( -n "$locator_spec_id" && "$base" == "$locator_spec_id" ) ]] && matched=true ;;
                id) [[ "$locator" == "$base" ]] && matched=true ;;
            esac
            if $matched; then
                validate_spec_dir_containment "$repo_root" "$dir" archive || return 1
                validate_spec_metadata "$dir" || return 1
                [[ "$(read_spec_meta "$dir" status)" == archived ]] || { echo "spec no archive não possui status archived: $dir" >&2; return 1; }
                matches_count=$((matches_count + 1))
                match_path="$dir"
                match_list="${match_list:+$match_list }$dir"
            fi
        done
    fi
    if [[ "$matches_count" -ne 1 ]]; then
        [[ "$matches_count" -eq 0 ]] && echo "spec não encontrada para '$locator' ($mode)" >&2 || echo "spec ambígua para '$locator': $match_list" >&2
        return 1
    fi
    printf '%s\n' "$match_path"
}

validate_gate_contract() {
    local spec_dir="$1"
    local gate_file="$spec_dir/gate.yaml"
    [[ -f "$gate_file" ]] || { echo "gate ausente em $gate_file" >&2; return 1; }
    validate_no_duplicate_yaml_keys "$gate_file" \
        schema story story_title gate quality_score score_history status_reason reviewer updated \
        evidence_ref waiver_active waiver_reason waiver_approved_by waiver_approved_at || return 1

    local schema verdict evidence key value score score_history last_score updated waiver_active count
    schema="$(read_yaml_scalar "$gate_file" schema)"; schema="${schema:-1}"
    case "$schema" in 1|2) ;; *) echo "schema de gate não suportado: '$schema'" >&2; return 1 ;; esac
    if [[ "$schema" == 1 ]]; then
        local legacy_status legacy_phase legacy_parent
        legacy_status="$(read_spec_meta "$spec_dir" status)"
        legacy_phase="$(read_spec_meta "$spec_dir" current_phase)"
        legacy_parent="$(basename "$(dirname "${spec_dir%/}")")"
        [[ "$legacy_status" == archived && "$legacy_phase" == archived && "$legacy_parent" == archive ]] || {
            echo "gate schema 1 permitido somente em registro histórico arquivado" >&2
            return 1
        }
    fi
    verdict="$(read_yaml_scalar "$gate_file" gate)"
    case "$verdict" in PASS|CONCERNS|FAIL|WAIVED) ;; *) echo "gate inválido em $gate_file: veredito '$verdict'" >&2; return 1 ;; esac
    if [[ "$schema" == 2 ]]; then
        for key in schema story story_title gate quality_score score_history status_reason reviewer updated \
                   evidence_ref waiver_active waiver_reason waiver_approved_by waiver_approved_at; do
            count="$(awk -v k="$key" '$0 ~ "^" k "[[:space:]]*:" { n++ } END { print n + 0 }' "$gate_file")"
            [[ "$count" -eq 1 ]] || { echo "campo '$key' deve ocorrer uma vez no gate schema 2" >&2; return 1; }
        done
        for key in story story_title status_reason reviewer updated waiver_active; do
            value="$(read_yaml_scalar "$gate_file" "$key")"
            [[ -n "$value" ]] || { echo "campo '$key' obrigatório no gate schema 2" >&2; return 1; }
        done
        score="$(read_yaml_scalar "$gate_file" quality_score)"
        [[ "$score" =~ ^[0-9]+$ && "$score" -le 100 ]] || { echo "quality_score inválido no gate schema 2" >&2; return 1; }
        score_history="$(read_yaml_scalar "$gate_file" score_history)"
        printf '%s\n' "$score_history" | awk '
            !/^\[[[:space:]]*[0-9]+([[:space:]]*,[[:space:]]*[0-9]+)*[[:space:]]*\]$/ { exit 1 }
            {
                gsub(/^\[[[:space:]]*|[[:space:]]*\]$/, "")
                n=split($0, scores, /[[:space:]]*,[[:space:]]*/)
                for (i=1; i<=n; i++) if (scores[i] < 0 || scores[i] > 100) exit 1
            }
        ' || { echo "score_history inválido no gate schema 2" >&2; return 1; }
        last_score="$(printf '%s\n' "$score_history" | sed 's/^\[//; s/\]$//; s/.*,//; s/[[:space:]]//g')"
        [[ "$last_score" == "$score" ]] || { echo "score_history não termina em quality_score no gate schema 2" >&2; return 1; }
        updated="$(read_yaml_scalar "$gate_file" updated)"
        [[ "$updated" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$ ]] || { echo "updated inválido no gate schema 2" >&2; return 1; }
        waiver_active="$(read_yaml_scalar "$gate_file" waiver_active)"
        [[ "$waiver_active" == true || "$waiver_active" == false ]] || { echo "waiver_active inválido no gate schema 2" >&2; return 1; }
        evidence="$(read_yaml_scalar "$gate_file" evidence_ref)"
        case "$evidence" in ""|/*|*../*|../*|*/..|*//*) echo "evidence_ref inválido no gate schema 2" >&2; return 1 ;; esac
        [[ -f "$spec_dir/$evidence" ]] || { echo "evidência do gate ausente: $spec_dir/$evidence" >&2; return 1; }
    fi
}

# Validate a promote target before archive/ship-ready uses it. Success prints
# the absolute target. The lexical docs/ check blocks absolute paths and `..`;
# the physical-parent check blocks symlink escapes without requiring realpath.
validate_promotion_target() {
    local repo_root="$1"
    local target="$2"
    local mode="${3:-copy}"

    case "$mode" in
        copy|append|manual) ;;
        *) echo "promote_mode inválido '$mode' (esperado copy, append ou manual)" >&2; return 1 ;;
    esac

    case "$target" in
        docs/*) ;;
        *) echo "destino promote inválido '$target': deve ficar sob docs/" >&2; return 1 ;;
    esac
    case "$target" in
        docs/specs|docs/specs/*)
            echo "destino promote inválido '$target': deve ficar na base docs/, fora de docs/specs/" >&2
            return 1
            ;;
    esac
    case "$target" in
        */) echo "destino promote inválido '$target': informe um arquivo, não um diretório" >&2; return 1 ;;
    esac

    local remainder="${target#docs/}"
    [[ -n "$remainder" ]] || {
        echo "destino promote inválido '$target': informe um arquivo sob docs/" >&2
        return 1
    }

    # Wrap with slashes so start/end components are checked by the same
    # patterns. Avoid `read -a`: it is Bash-only and common.sh is sourced by
    # zsh on macOS too.
    case "/$remainder/" in
        *//*|*/./*|*/../*)
            echo "destino promote inválido '$target': segmentos vazios, '.' e '..' não são permitidos" >&2
            return 1
            ;;
    esac

    local docs_root="$repo_root/docs"
    [[ -d "$docs_root" ]] || {
        echo "destino promote inválido: diretório docs/ não existe em $repo_root" >&2
        return 1
    }
    [[ ! -L "$docs_root" ]] || {
        echo "destino promote inválido: docs/ não pode ser symlink" >&2
        return 1
    }

    local absolute="$repo_root/$target"
    if [[ -L "$absolute" ]]; then
        echo "destino promote inválido '$target': o arquivo final não pode ser symlink" >&2
        return 1
    fi
    if [[ "$mode" != manual && -e "$absolute" && ! -f "$absolute" ]]; then
        echo "destino promote inválido '$target': copy/append exigem arquivo regular" >&2
        return 1
    fi

    local parent
    parent="$(dirname "$absolute")"
    while [[ ! -d "$parent" ]]; do
        if [[ -e "$parent" || -L "$parent" ]]; then
            echo "destino promote inválido '$target': componente pai não é diretório seguro" >&2
            return 1
        fi
        [[ "$parent" != "$repo_root" && "$parent" != "/" ]] || {
            echo "destino promote inválido '$target': não foi possível conter o pai em docs/" >&2
            return 1
        }
        parent="$(dirname "$parent")"
    done

    local docs_physical parent_physical
    docs_physical="$(cd -P "$docs_root" 2>/dev/null && pwd)" || return 1
    parent_physical="$(cd -P "$parent" 2>/dev/null && pwd)" || return 1
    case "$parent_physical" in
        "$docs_physical"|"$docs_physical"/*) ;;
        *) echo "destino promote inválido '$target': symlink escapa de docs/" >&2; return 1 ;;
    esac

    printf '%s\n' "$absolute"
}

# Promotion declarations use front-matter only. Quoted/indented critical keys
# are rejected so the shell reader and a complete YAML parser cannot disagree.
frontmatter_yaml_key_count() {
    local file="$1" key="$2"
    awk -v k="$key" '
        NR == 1 { if ($0 != "---") exit; inside=1; next }
        inside && /^---[[:space:]]*$/ { exit }
        inside && $0 ~ "^[[:space:]]*(\"" k "\"|\047" k "\047|" k ")[[:space:]]*:" { count++ }
        END { print count + 0 }
    ' "$file"
}

read_frontmatter_scalar() {
    local file="$1" key="$2"
    awk -v k="$key" '
        NR == 1 { if ($0 != "---") exit; inside=1; next }
        inside && /^---[[:space:]]*$/ { exit }
        inside && $0 ~ "^" k "[[:space:]]*:" {
            sub("^" k "[[:space:]]*:[[:space:]]*", "", $0)
            sub("[[:space:]]*#.*$", "", $0)
            sub("^\"", "", $0); sub("\"$", "", $0)
            sub("^\047", "", $0); sub("\047$", "", $0)
            sub("^[[:space:]]+", "", $0); sub("[[:space:]]+$", "", $0)
            print
            exit
        }
    ' "$file"
}

validate_promotion_frontmatter() {
    local file="$1" key counts plain_count alternate_count
    for key in promote promote_mode; do
        counts="$(awk -v k="$key" '
            NR == 1 { if ($0 != "---") exit; inside=1; next }
            inside && /^---[[:space:]]*$/ { exit }
            inside && $0 ~ "^[[:space:]]*(\"" k "\"|\047" k "\047|" k ")[[:space:]]*:" {
                if ($0 ~ "^" k "[[:space:]]*:") plain++
                else alternate++
            }
            END { print plain + 0 ":" alternate + 0 }
        ' "$file")"
        plain_count="${counts%%:*}"
        alternate_count="${counts#*:}"
        [[ "$alternate_count" -eq 0 ]] || {
            echo "chave YAML '$key' usa representação não suportada no front-matter de $file" >&2
            return 1
        }
        [[ "$plain_count" -le 1 ]] || {
            echo "chave YAML duplicada '$key' no front-matter de $file" >&2
            return 1
        }
    done
}

extract_frontmatter_body() {
    local file="$1"
    awk '
        NR == 1 && $0 == "---" { inside=1; next }
        inside && /^---[[:space:]]*$/ { inside=0; body=1; next }
        body || !inside { print }
    ' "$file"
}

# Validate every promotion declaration before a spec can enter archived. Manual
# promotions are intentionally informational; copy/append must already have a
# materialized target. The same helper is shared by transition and ship-ready.
validate_spec_promotions_satisfied() {
    local repo_root="$1" spec_dir="$2" promotion_file target mode validated_target failures=0
    local promote_count mode_count body_tmp body_size target_size
    while IFS= read -r promotion_file; do
        [[ -n "$promotion_file" ]] || continue
        promote_count="$(frontmatter_yaml_key_count "$promotion_file" promote)"
        mode_count="$(frontmatter_yaml_key_count "$promotion_file" promote_mode)"
        [[ "$promote_count" -gt 0 || "$mode_count" -gt 0 ]] || continue
        if ! validate_promotion_frontmatter "$promotion_file"; then
            failures=$((failures + 1))
            continue
        fi
        [[ "$promote_count" -eq 1 ]] || {
            echo "promote ausente no front-matter de $(basename "$promotion_file")" >&2
            failures=$((failures + 1))
            continue
        }
        target="$(read_frontmatter_scalar "$promotion_file" promote)"
        mode="$(read_frontmatter_scalar "$promotion_file" promote_mode)"
        [[ -n "$mode" ]] || mode=copy
        if ! validated_target="$(validate_promotion_target "$repo_root" "$target" "$mode" 2>&1)"; then
            echo "promote inválido em $(basename "$promotion_file"): $validated_target" >&2
            failures=$((failures + 1))
            continue
        fi
        [[ "$mode" == manual ]] && continue
        if [[ ! -f "$validated_target" ]]; then
            echo "promote não aplicado: $(basename "$promotion_file") -> $target" >&2
            failures=$((failures + 1))
            continue
        fi
        case "$mode" in
            copy)
                if ! cmp -s "$promotion_file" "$validated_target"; then
                    echo "promote copy divergente: $(basename "$promotion_file") -> $target" >&2
                    failures=$((failures + 1))
                fi
                ;;
            append)
                body_tmp="$(mktemp "${TMPDIR:-/tmp}/mosk-promote-body.XXXXXX")" || return 1
                extract_frontmatter_body "$promotion_file" > "$body_tmp"
                body_size="$(wc -c < "$body_tmp" | tr -d ' ')"
                target_size="$(wc -c < "$validated_target" | tr -d ' ')"
                if [[ "$body_size" -eq 0 || "$target_size" -lt "$body_size" ]] || \
                   ! tail -c "$body_size" "$validated_target" | cmp -s - "$body_tmp"; then
                    echo "promote append divergente: $(basename "$promotion_file") -> $target" >&2
                    failures=$((failures + 1))
                fi
                rm -f "$body_tmp"
                body_tmp=""
                ;;
        esac
    done < <(find "$spec_dir" -type f -name '*.md' -print 2>/dev/null)
    [[ "$failures" -eq 0 ]]
}

# A spec só pode ser concluída com PASS ou com WAIVED formalizado. Imprime a
# causa em stderr e retorna 1 quando o contrato não está satisfeito.
validate_gate_for_completion() {
    local spec_dir="$1"
    local gate_file="$spec_dir/gate.yaml"
    validate_gate_contract "$spec_dir" || return 1

    local verdict
    verdict="$(read_yaml_scalar "$gate_file" gate)"
    case "$verdict" in
        PASS) return 0 ;;
        WAIVED)
            local active reason approved_by approved_at
            active="$(read_yaml_scalar "$gate_file" waiver_active)"
            reason="$(read_yaml_scalar "$gate_file" waiver_reason)"
            approved_by="$(read_yaml_scalar "$gate_file" waiver_approved_by)"
            approved_at="$(read_yaml_scalar "$gate_file" waiver_approved_at)"
            if [[ "$active" != "true" || -z "$reason" || -z "$approved_by" || \
                  ! "$approved_at" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$ ]]; then
                echo "gate WAIVED incompleto: exige waiver_active=true, reason, approved_by e approved_at ISO 8601 UTC" >&2
                return 1
            fi
            return 0
            ;;
        FAIL|CONCERNS)
            echo "gate $verdict bloqueia conclusão; corrija ou formalize um WAIVED antes do archive" >&2
            return 1
            ;;
        "")
            echo "gate inválido em $gate_file: campo top-level 'gate' ausente" >&2
            return 1
            ;;
        *)
            echo "gate inválido em $gate_file: veredito desconhecido '$verdict'" >&2
            return 1
            ;;
    esac
}

phase_transition_allowed() {
    case "$1:$2" in
        specify:plan|plan:tasks|tasks:implement|implement:qa-gate|qa-gate:implement|qa-gate:archived) return 0 ;;
        *) return 1 ;;
    esac
}

validate_phase_preconditions() {
    local spec_dir="$1" from="$2" to="$3" command="$4" repo_root="$5"
    phase_command_matches_destination "$command" "$to" || {
        echo "command '$command' não pode confirmar fase '$to'" >&2
        return 1
    }
    case "$to" in
        plan)
            [[ -s "$spec_dir/spec.md" ]] || { echo "spec.md ausente ou vazio" >&2; return 1; }
            ! grep -q '\[NEEDS CLARIFICATION' "$spec_dir/spec.md" 2>/dev/null || { echo "spec.md ainda contém esclarecimento bloqueante" >&2; return 1; }
            ;;
        tasks) [[ -s "$spec_dir/spec.md" && -s "$spec_dir/plan.md" ]] || { echo "spec.md e plan.md são obrigatórios" >&2; return 1; } ;;
        implement)
            [[ -s "$spec_dir/tasks.md" ]] || { echo "tasks.md ausente ou vazio" >&2; return 1; }
            if [[ "$from" == qa-gate ]]; then
                local verdict
                validate_gate_contract "$spec_dir" || return 1
                verdict="$(read_yaml_scalar "$spec_dir/gate.yaml" gate)"
                [[ "$verdict" == FAIL || "$verdict" == CONCERNS ]] || { echo "retorno para implement exige gate FAIL ou CONCERNS" >&2; return 1; }
            fi
            ;;
        qa-gate)
            [[ -s "$spec_dir/tasks.md" ]] || { echo "tasks.md ausente ou vazio" >&2; return 1; }
            ! grep -Eq '^- \[ \] T[0-9]{3}' "$spec_dir/tasks.md" || { echo "tasks.md possui tarefas abertas" >&2; return 1; }
            validate_gate_contract "$spec_dir" || return 1
            ;;
        archived)
            ! grep -Eq '^- \[ \] T[0-9]{3}' "$spec_dir/tasks.md" || { echo "tasks.md possui tarefas abertas" >&2; return 1; }
            validate_gate_for_completion "$spec_dir" || return 1
            validate_spec_promotions_satisfied "$repo_root" "$spec_dir" || return 1
            ;;
    esac

    local artifact
    for artifact in spec.md; do
        [[ -s "$spec_dir/$artifact" ]] || { echo "$artifact ausente ou vazio" >&2; return 1; }
        ! grep -q '\[NEEDS CLARIFICATION' "$spec_dir/$artifact" 2>/dev/null || { echo "$artifact ainda contém esclarecimento bloqueante" >&2; return 1; }
    done
    case "$to" in
        tasks|implement|qa-gate|archived)
            [[ -s "$spec_dir/plan.md" ]] || { echo "plan.md ausente ou vazio" >&2; return 1; }
            ! grep -q '\[NEEDS CLARIFICATION' "$spec_dir/plan.md" 2>/dev/null || { echo "plan.md ainda contém esclarecimento bloqueante" >&2; return 1; }
            ;;
    esac
    case "$to" in
        implement|qa-gate|archived)
            [[ -s "$spec_dir/tasks.md" ]] || { echo "tasks.md ausente ou vazio" >&2; return 1; }
            ! grep -q '\[NEEDS CLARIFICATION' "$spec_dir/tasks.md" 2>/dev/null || { echo "tasks.md ainda contém esclarecimento bloqueante" >&2; return 1; }
            ;;
    esac
}

# Atomic, validated state transition. The caller supplies the destination;
# this function never chooses pipeline route on its own.
transition_spec_phase() (
    local spec_dir="${1%/}" new_phase="$2" command="$3" repo_root="${4:-}"
    local meta_file="$spec_dir/spec-meta.yaml" history="$spec_dir/phase-history.yaml"
    local lock_dir="$spec_dir/.phase-transition.lock" meta_tmp="" history_tmp="" meta_backup="" history_backup=""
    local meta_promotion_started=false
    transition_cleanup() {
        local rc=$?
        trap - EXIT HUP INT TERM
        if [[ "$rc" -ne 0 && "$meta_promotion_started" == true && -n "$meta_backup" ]]; then
            cp "$meta_backup" "$meta_file" 2>/dev/null || true
            if [[ -n "$history_backup" ]]; then
                cp "$history_backup" "$history" 2>/dev/null || true
            else
                rm -f "$history"
            fi
        fi
        rmdir "$lock_dir" 2>/dev/null || true
        [[ -z "$meta_tmp" ]] || rm -f "$meta_tmp"
        [[ -z "$history_tmp" ]] || rm -f "$history_tmp"
        [[ -z "$meta_backup" ]] || rm -f "$meta_backup"
        [[ -z "$history_backup" ]] || rm -f "$history_backup"
        exit "$rc"
    }
    if [[ -z "$repo_root" ]]; then
        repo_root="$(infer_repo_root_from_spec_dir "$spec_dir")" || {
            echo "não foi possível inferir a raiz segura para $spec_dir" >&2
            return 1
        }
    fi
    validate_spec_dir_containment "$repo_root" "$spec_dir" active || return 1
    validate_spec_metadata "$spec_dir" || return 1
    mkdir "$lock_dir" 2>/dev/null || { echo "transição concorrente bloqueada em $spec_dir" >&2; return 1; }
    trap transition_cleanup EXIT
    trap 'exit 1' HUP INT TERM
    validate_spec_metadata "$spec_dir" || return 1

    local old_phase old_schema history_origin now
    old_phase="$(read_spec_meta "$spec_dir" current_phase)"
    old_schema="$(read_spec_meta "$spec_dir" schema)"; old_schema="${old_schema:-1}"
    if [[ "$old_schema" == 2 ]]; then history_origin=specify; else history_origin=migration; fi
    case "$new_phase" in specify|plan|tasks|implement|qa-gate|archived) ;; *) echo "fase desconhecida '$new_phase'" >&2; return 1 ;; esac
    if [[ "$old_phase" == "$new_phase" ]]; then return 0; fi
    [[ "$old_phase" != archived ]] || { echo "archived é estado terminal" >&2; return 1; }
    phase_transition_allowed "$old_phase" "$new_phase" || { echo "transição proibida: $old_phase -> $new_phase" >&2; return 1; }
    validate_phase_preconditions "$spec_dir" "$old_phase" "$new_phase" "$command" "$repo_root" || return 1
    now="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

    meta_tmp="$(mktemp "$spec_dir/.spec-meta.XXXXXX")" || return 1
    history_tmp="$(mktemp "$spec_dir/.phase-history.XXXXXX")" || return 1
    meta_backup="$(mktemp "$spec_dir/.spec-meta-backup.XXXXXX")" || return 1
    cp "$meta_file" "$meta_backup" || return 1
    if [[ -f "$history" ]]; then
        history_backup="$(mktemp "$spec_dir/.phase-history-backup.XXXXXX")" || return 1
        cp "$history" "$history_backup" || return 1
        if [[ "$old_schema" == 1 ]] && ! grep -q '^origin[[:space:]]*:' "$history"; then
            awk '
                /^schema[[:space:]]*:/ { print; print "origin: migration"; next }
                { print }
            ' "$history" > "$history_tmp" || return 1
        else
            cp "$history" "$history_tmp" || return 1
        fi
    else
        printf 'schema: 1\norigin: %s\ntransitions:\n' "$history_origin" > "$history_tmp"
    fi

    awk -v phase="$new_phase" -v now="$now" '
        BEGIN { schema_set=phase_set=stamp_set=status_set=archive_set=0 }
        /^[[:space:]]*schema[[:space:]]*:/ { print "schema: 2"; schema_set=1; next }
        /^[[:space:]]*current_phase[[:space:]]*:/ { print "current_phase: " phase; phase_set=1; next }
        /^[[:space:]]*last_phase_change[[:space:]]*:/ { print "last_phase_change: \"" now "\""; stamp_set=1; next }
        /^[[:space:]]*status[[:space:]]*:/ { if (phase == "archived") print "status: archived"; else print; status_set=1; next }
        /^[[:space:]]*archived_at[[:space:]]*:/ { if (phase == "archived") print "archived_at: \"" now "\""; else print; archive_set=1; next }
        { print }
        END {
            if (!schema_set) print "schema: 2"
            if (!phase_set) print "current_phase: " phase
            if (!stamp_set) print "last_phase_change: \"" now "\""
            if (phase == "archived" && !status_set) print "status: archived"
            if (phase == "archived" && !archive_set) print "archived_at: \"" now "\""
        }
    ' "$meta_file" > "$meta_tmp" || return 1
    printf '  - at: "%s"\n    from: %s\n    to: %s\n    command: %s\n' "$now" "$old_phase" "$new_phase" "$command" >> "$history_tmp"

    meta_promotion_started=true
    mv "$meta_tmp" "$meta_file" || return 1; meta_tmp=""
    if [[ "${MOSK_TRANSITION_FAIL_AFTER_META:-0}" == 1 ]]; then
        echo "falha injetada após metadata; estado restaurado" >&2
        return 1
    fi
    if ! mv "$history_tmp" "$history"; then
        echo "falha ao persistir histórico; metadata restaurada" >&2
        return 1
    fi
    history_tmp=""
    validate_spec_metadata "$spec_dir" || return 1
)

# Compatibility adapter for older callers. It now delegates to the strict
# transition contract instead of editing metadata directly.
update_spec_phase() {
    local spec_dir="$1" new_phase="$2" command="$2"
    if [[ "$new_phase" == implement && "$(read_spec_meta "$spec_dir" current_phase)" == qa-gate ]]; then command=apply-qa-fixes; fi
    transition_spec_phase "$spec_dir" "$new_phase" "$command"
}

# List all active specs (status: active). Usage: list_active_specs [<specs_root>]
# Echoes one spec_id per line.
list_active_specs() {
    local specs_root="${1:-$(get_repo_root)/docs/specs}"
    [[ -d "$specs_root" ]] || return 0
    local dir spec_status
    for dir in "$specs_root"/*/; do
        [[ -d "$dir" ]] || continue
        [[ "$(basename "$dir")" == "archive" ]] && continue
        spec_status=$(read_spec_meta "${dir%/}" "status")
        if [[ "$spec_status" == "active" || -z "$spec_status" ]]; then
            basename "$dir"
        fi
    done
}

# Write a new spec-meta.yaml from the template. Usage:
# write_spec_meta <spec_dir> <spec_number> <spec_id> <type> <branch>
write_spec_meta() {
    local spec_dir="$1"
    local spec_number="$2"
    local spec_id="$3"
    local spec_type="$4"
    local spec_branch="$5"
    local meta_file="$spec_dir/spec-meta.yaml"
    local now
    now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    local created_by=""
    if has_git; then
        local gu gm
        gu=$(git config user.name 2>/dev/null || echo "")
        gm=$(git config user.email 2>/dev/null || echo "")
        if [[ -n "$gu" && -n "$gm" ]]; then
            created_by="$gu <$gm>"
        elif [[ -n "$gu" ]]; then
            created_by="$gu"
        fi
    fi
cat > "$meta_file" <<EOF
schema: 2
spec_number: "$spec_number"
spec_id: "$spec_id"
type: "$spec_type"
branch: "$spec_branch"
created_at: "$now"
created_by: "${created_by:-unknown}"
status: active
current_phase: specify
last_phase_change: "$now"
EOF
}

# Resolve core-config.yaml relative to this script (template & consumer),
# overridable via MOSK_CORE_CONFIG for tests.
core_config_file() {
    if [[ -n "${MOSK_CORE_CONFIG:-}" ]]; then
        echo "$MOSK_CORE_CONFIG"
        return
    fi
    echo "$MOSK_SCRIPTS_DIR/../core-config.yaml"
}

# ---------- runner autônomo (/mosk-orq) ----------
# Estes dois helpers existem porque o precedente — o loop-until-green do bench —
# deixou as duas pontas soltas: ninguém escrevia o log de decisões (o formato só
# existia em prosa, num plan arquivado) e o teto de tentativas era convenção de
# prompt, sem constante em lugar nenhum. Um processo que roda desacompanhado não
# pode depender de o prompt lembrar.

# Resolve o teto de voltas por unidade: core-config `runner.max_attempts` → 3.
# Valor não-numérico cai no default COM aviso — nunca em silêncio, porque um teto
# lido errado é um loop que não termina. Usage: resolve_max_attempts
resolve_max_attempts() {
    local cc v
    cc="$(core_config_file)"
    if [[ -f "$cc" ]]; then
        v=$(awk '
            /^[^[:space:]#]/ { in_runner = ($0 ~ /^runner:/) }
            in_runner && /^[[:space:]]+max_attempts[[:space:]]*:/ {
                sub(/^[[:space:]]+max_attempts[[:space:]]*:[[:space:]]*/, "")
                sub(/[[:space:]]*#.*$/, "")
                gsub(/["'\'' ]/, "")
                print; exit
            }
        ' "$cc")
    fi
    if ! [[ "$v" =~ ^[0-9]+$ ]]; then
        [[ -n "$v" ]] && echo "aviso: runner.max_attempts inválido ('$v'); usando 3" >&2
        v=3
    fi
    echo "$v"
}

# Registra uma decisão tomada sem supervisão. Append-only, versionado — é o preço
# da autonomia: você não viu acontecer, então precisa poder ler depois.
# Usage: append_run_log <spec_dir> <onda> <unidade> <agente> <decisão> <porquê>
append_run_log() {
    local spec_dir="$1" wave="$2" unit="$3" agent="$4" decision="$5" why="$6"
    if [[ -z "$spec_dir" || ! -d "$spec_dir" ]]; then
        echo "erro: append_run_log precisa de um spec_dir existente (obtido: '$spec_dir')" >&2
        return 1
    fi
    local log="$spec_dir/run-log.md" now
    now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    if [[ ! -f "$log" ]]; then
        cat > "$log" <<'HDR'
# Run log — decisões tomadas sem supervisão

Registro append-only do `/mosk-orq`. Cada linha é uma decisão que a corrida tomou
sozinha, e o motivo. É o que torna a autonomia auditável depois do fato.

| quando | onda | unidade | agente | decisão | por quê |
|---|---|---|---|---|---|
HDR
    fi
    # Pipe quebraria a tabela; escapa antes de escrever.
    printf '| %s | %s | %s | %s | %s | %s |\n' \
        "$now" "${wave//|/\\|}" "${unit//|/\\|}" "${agent//|/\\|}" \
        "${decision//|/\\|}" "${why//|/\\|}" >> "$log"
}
