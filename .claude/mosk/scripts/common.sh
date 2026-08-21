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

has_git() {
    git rev-parse --show-toplevel >/dev/null 2>&1
}

core_config_file() {
    if [[ -n "${MOSK_CORE_CONFIG:-}" ]]; then
        echo "$MOSK_CORE_CONFIG"
        return
    fi
    echo "$MOSK_SCRIPTS_DIR/../core-config.yaml"
}

infer_repo_root_from_spec_dir() {
    local spec_dir="${1%/}" parent docs_root
    parent="$(dirname "$spec_dir")"
    [[ "$(basename "$parent")" == specs ]] || return 1
    docs_root="$(dirname "$parent")"
    [[ "$(basename "$docs_root")" == docs ]] || return 1
    dirname "$docs_root"
}

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

write_spec_meta() {
    local spec_dir="$1"
    local spec_number="$2"
    local spec_id="$3"
    local spec_type="$4"
    local spec_branch="$5"
    local spec_extends="${6:-}"
    local meta_file="$spec_dir/spec-meta.yaml"
    local now tmp
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
    # Defesa em profundidade (SEC-003): o chamador valida, e o emissor recusa
    # de novo. Um valor fora do dominio aqui significa que alguem contornou a
    # validacao de entrada, e escrever seria injetar chave arbitraria no YAML.
    if [[ -n "$spec_extends" ]] && \
       [[ ! "$spec_extends" =~ ^[0-9]{3}-[a-z]+-[a-z0-9][a-z0-9-]*$ ]]; then
        echo "write_spec_meta: extends fora do dominio: '$spec_extends'" >&2
        return 1
    fi
    tmp="$(mktemp "$spec_dir/.spec-meta.XXXXXX")" || return 1
    {
        cat <<EOF
schema: 2
spec_number: "$spec_number"
spec_id: "$spec_id"
type: "${spec_type:-feature}"
branch: "$spec_branch"
created_at: "$now"
created_by: "${created_by:-unknown}"
status: active
current_phase: specify
last_phase_change: "$now"
EOF
        [[ -z "$spec_extends" ]] || echo "extends: \"$spec_extends\""
    } > "$tmp" || { rm -f "$tmp"; return 1; }
    mv "$tmp" "$meta_file" || { rm -f "$tmp"; return 1; }
}

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
