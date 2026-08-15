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

    # Use prefix-based lookup to support multiple branches per spec
    local feature_dir=$(find_feature_dir_by_prefix "$repo_root" "$current_branch")

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
        $0 ~ "^[[:space:]]*" k "[[:space:]]*:" {
            sub("^[[:space:]]*" k "[[:space:]]*:[[:space:]]*", "", $0)
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

# A spec só pode ser concluída com PASS ou com WAIVED formalizado. Imprime a
# causa em stderr e retorna 1 quando o contrato não está satisfeito.
validate_gate_for_completion() {
    local spec_dir="$1"
    local gate_file="$spec_dir/gate.yaml"
    if [[ ! -f "$gate_file" ]]; then
        echo "gate ausente em $gate_file; rode /mosk-qa qa-gate antes do archive" >&2
        return 1
    fi

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

# Update current_phase in spec-meta.yaml. Usage: update_spec_phase <spec_dir> <phase>
# Also bumps last_phase_change to current ISO 8601 UTC.
#
# Deliberately dumb: it records where the spec IS, and validates nothing. The
# authority over which phase comes next is the human, and `spec-meta.yaml` is
# the single place that state lives.
update_spec_phase() {
    local spec_dir="$1"
    local new_phase="$2"
    local meta_file="$spec_dir/spec-meta.yaml"
    if [[ ! -f "$meta_file" ]]; then
        echo "warn: spec-meta.yaml not found at $meta_file" >&2
        return 1
    fi
    local now
    now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    local tmp
    tmp=$(mktemp)
    awk -v phase="$new_phase" -v now="$now" '
        BEGIN { phase_set=0; stamp_set=0 }
        /^[[:space:]]*current_phase[[:space:]]*:/ {
            print "current_phase: " phase
            phase_set=1
            next
        }
        /^[[:space:]]*last_phase_change[[:space:]]*:/ {
            print "last_phase_change: \"" now "\""
            stamp_set=1
            next
        }
        { print }
        END {
            if (phase_set == 0) print "current_phase: " phase
            if (stamp_set == 0) print "last_phase_change: \"" now "\""
        }
    ' "$meta_file" > "$tmp"
    mv "$tmp" "$meta_file"
}

# List all active specs (status: active). Usage: list_active_specs [<specs_root>]
# Echoes one spec_id per line.
list_active_specs() {
    local specs_root="${1:-$(get_repo_root)/docs/specs}"
    [[ -d "$specs_root" ]] || return 0
    local dir status
    for dir in "$specs_root"/*/; do
        [[ -d "$dir" ]] || continue
        [[ "$(basename "$dir")" == "archive" ]] && continue
        status=$(read_spec_meta "${dir%/}" "status")
        if [[ "$status" == "active" || -z "$status" ]]; then
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
spec_number: "$spec_number"
spec_id: "$spec_id"
type: "$spec_type"
branch: "$spec_branch"
created_at: "$now"
created_by: "$created_by"
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
