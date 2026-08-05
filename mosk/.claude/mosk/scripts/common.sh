#!/usr/bin/env bash
# Common functions and variables for all scripts

# ───────────────────── localização deste arquivo (bash E zsh) ─────────────────────
# As tasks do MOSK mandam o agente rodar `source common.sh` no shell DELE — e o
# shell padrão do macOS é zsh, onde `BASH_SOURCE` não existe. Resolver caminho com
# `${BASH_SOURCE[0]}` degradava em silêncio nesse caso: `dirname ""` → `.`, e todo
# caminho passava a resolver a partir do cwd. Efeito observado (spec 009):
# `graph_file` apontando para fora do repo, `graph_edge_exists` sempre falso, e
# TODA transição legal de fase gravada como `off-graph` no phase-history.log — o
# mesmo log de onde `attempt_count` deriva o contador do delivery-loop (ADR-0008).
#
# Resolvido uma vez, no escopo de TOPO: em zsh, `$0` só é o arquivo sourceado aqui
# (dentro de uma função ele passa a ser o nome da função).
if [[ -z "${MOSK_SCRIPTS_DIR:-}" ]]; then
    if [[ -n "${BASH_SOURCE[0]:-}" ]]; then
        _mosk_common_self="${BASH_SOURCE[0]}"
    elif [[ -n "${ZSH_VERSION:-}" ]]; then
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

    if [[ ! "$branch" =~ ^[0-9]{3}- ]]; then
        echo "ERROR: Not on a feature branch. Current branch: $branch" >&2
        echo "Feature branches should be named like: 001-feature-name" >&2
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

    # Extract numeric prefix from branch (e.g., "004" from "004-whatever")
    if [[ ! "$branch_name" =~ ^([0-9]{3})- ]]; then
        # If branch doesn't have numeric prefix, fall back to exact match
        echo "$specs_dir/$branch_name"
        return
    fi

    local prefix="${BASH_REMATCH[1]}"

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

# Update current_phase in spec-meta.yaml. Usage: update_spec_phase <spec_dir> <phase>
# Also bumps last_phase_change to current ISO 8601 UTC.
#
# Reducer (ADR-0006 #7): validates the transition against pipeline-graph.yaml
# and appends an audit entry to <spec_dir>/phase-history.log. An off-graph
# transition is WARNED but NEVER blocked — the human is the authority, the
# graph is only an advisor.
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

    # --- graph validation + audit trail (advisory, never blocking) ---
    # Três rótulos, não dois: `off-graph` só quando o grafo foi LIDO e a aresta
    # realmente não existe. Grafo ilegível vira `unverified` — conflacionar os dois
    # foi o que transformou um bug de resolução de caminho em log corrompido, já que
    # `attempt_count` lê este arquivo para contar tentativas do delivery-loop.
    local old_phase legality="legal" gf
    old_phase="$(read_spec_meta "$spec_dir" "current_phase")"
    gf="$(graph_file)"
    if [[ -n "$old_phase" && "$old_phase" != "$new_phase" ]]; then
        if [[ ! -f "$gf" ]]; then
            legality="unverified"
            echo "warn: grafo ilegível em '$gf'; transição ${old_phase} → ${new_phase} não verificada (prosseguindo)." >&2
        elif ! graph_edge_exists "$old_phase" "$new_phase" 2>/dev/null; then
            legality="off-graph"
            echo "warn: transição fora do grafo: ${old_phase} → ${new_phase} (prosseguindo; ver pipeline-graph.yaml)" >&2
        fi
    fi
    printf '%s\t%s\t%s -> %s\n' "$now" "$legality" "${old_phase:-<none>}" "$new_phase" \
        >> "$spec_dir/phase-history.log"

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

# ---------- pipeline-graph.yaml helpers (ADR-0007) ----------
# The graph uses a "shell-legible" schema: one record per line in YAML flow
# style. These projections read it with awk/grep only (zero external dep).
# The shell never needs to deserialize arbitrary YAML — only cheap, fixed
# projections. Rich consumers (agents) read the YAML natively.

# Resolve the graph path relative to this script (works in template & consumer),
# with an env override for tests: MOSK_GRAPH_FILE.
graph_file() {
    if [[ -n "${MOSK_GRAPH_FILE:-}" ]]; then
        echo "$MOSK_GRAPH_FILE"
        return
    fi
    echo "$MOSK_SCRIPTS_DIR/../pipeline-graph.yaml"
}

# List edges whose `from` matches <phase>. Usage: graph_edges_from <phase>
# Emits one TAB-separated record per edge: <to>\t<guard>\t<default>
# (guard/default empty when absent). Degrades to empty output if the graph
# file is missing/unreadable (caller decides how to warn).
graph_edges_from() {
    local phase="$1"
    local gf
    gf="$(graph_file)"
    [[ -f "$gf" ]] || { echo "warn: pipeline-graph.yaml not found at $gf" >&2; return 0; }
    awk -v want="$phase" '
        function field(s, name,   re, v) {
            re = name ":[[:space:]]*"
            if (match(s, re)) {
                v = substr(s, RSTART + RLENGTH)
                if (substr(v, 1, 1) == "\"") {        # quoted value (may contain commas)
                    v = substr(v, 2); sub(/".*/, "", v)
                } else {                               # bareword: cut at , or }
                    sub(/[,}].*/, "", v)
                    gsub(/^[[:space:]]+|[[:space:]]+$/, "", v)
                }
                return v
            }
            return ""
        }
        /^[^[:space:]#]/ { in_edges = ($0 ~ /^edges:/) }
        in_edges && /^[[:space:]]*-[[:space:]]*\{/ {
            if (field($0, "from") != want) next
            # separador "|" (nao-whitespace) para preservar campos vazios no read
            printf "%s|%s|%s\n", field($0, "to"), field($0, "guard"), field($0, "default")
        }
    ' "$gf"
}

# Legality test: does an edge <from> -> <to> exist? Usage: graph_edge_exists <from> <to>
# Returns 0 if legal, 1 otherwise. Used by update_spec_phase (warn-and-proceed).
graph_edge_exists() {
    local from="$1" to="$2"
    graph_edges_from "$from" | awk -v t="$to" -F'|' '$1 == t { found = 1 } END { exit found ? 0 : 1 }'
}

# Read a field from a guard entry. Internal. Usage: _graph_guard_field <name> <field>
_graph_guard_field() {
    local name="$1" fld="$2" gf
    gf="$(graph_file)"
    [[ -f "$gf" ]] || return 0
    awk -v want="$name" -v fld="$fld" '
        function field(s, name,   re, v) {
            re = name ":[[:space:]]*"
            if (match(s, re)) {
                v = substr(s, RSTART + RLENGTH)
                if (substr(v, 1, 1) == "\"") {        # quoted value (may contain commas)
                    v = substr(v, 2); sub(/".*/, "", v)
                } else {                               # bareword: cut at , or }
                    sub(/[,}].*/, "", v)
                    gsub(/^[[:space:]]+|[[:space:]]+$/, "", v)
                }
                return v
            }
            return ""
        }
        /^[^[:space:]#]/ { in_guards = ($0 ~ /^guards:/) }
        in_guards && $0 ~ ("^[[:space:]]+" want "[[:space:]]*:[[:space:]]*\\{") {
            print field($0, fld)
            exit
        }
    ' "$gf"
}

# Guard kind: fact | judgment (empty if unknown). Usage: guard_kind <name>
guard_kind() { _graph_guard_field "$1" "kind"; }

# Guard human-readable question. Usage: guard_question <name>
guard_question() { _graph_guard_field "$1" "question"; }

# ---------- delivery-loop helpers (ADR-0008) ----------
# The delivery-loop counts gate cycles per-spec, derived from phase-history.log
# (no new persisted state). The retry cap is a policy: per-spec override in
# spec-meta.yaml, else global default in core-config.yaml, else 3.

# Resolve core-config.yaml relative to this script (template & consumer),
# overridable via MOSK_CORE_CONFIG for tests.
core_config_file() {
    if [[ -n "${MOSK_CORE_CONFIG:-}" ]]; then
        echo "$MOSK_CORE_CONFIG"
        return
    fi
    echo "$MOSK_SCRIPTS_DIR/../core-config.yaml"
}

# Count delivery-loop attempts for a spec = number of `qa-gate -> implement`
# loopbacks recorded in phase-history.log. Usage: attempt_count <spec_dir>
# Echoes an integer (0 when the log is absent).
attempt_count() {
    local spec_dir="$1"
    local log="$spec_dir/phase-history.log"
    if [[ ! -f "$log" ]]; then
        echo "warn: phase-history.log ausente em $spec_dir (contagem = 0)" >&2
        echo 0
        return 0
    fi
    local n
    n=$(grep -cE 'qa-gate[[:space:]]*->[[:space:]]*implement' "$log" 2>/dev/null || true)
    echo "${n:-0}"
}

# Read orchestration.max_retries from core-config.yaml (nested 2-level key).
_core_config_max_retries() {
    local cc
    cc="$(core_config_file)"
    [[ -f "$cc" ]] || return 0
    awk '
        /^[^[:space:]#]/ { in_orch = ($0 ~ /^orchestration:/) }
        in_orch && /^[[:space:]]+max_retries[[:space:]]*:/ {
            sub(/^[[:space:]]+max_retries[[:space:]]*:[[:space:]]*/, "")
            gsub(/["'\'' ]/, "")
            print; exit
        }
    ' "$cc"
}

# Resolve max_retries for a spec: spec-meta override -> core-config default -> 3.
# Non-numeric values fall back to 3 with a warning. Usage: resolve_max_retries <spec_dir>
resolve_max_retries() {
    local spec_dir="$1"
    local v
    v="$(read_spec_meta "$spec_dir" "max_retries")"
    [[ -z "$v" ]] && v="$(_core_config_max_retries)"
    if ! [[ "$v" =~ ^[0-9]+$ ]]; then
        [[ -n "$v" ]] && echo "warn: max_retries inválido ('$v'); usando default 3" >&2
        v=3
    fi
    echo "$v"
}

# ---------- atuador de panes: helpers compartilhados (ADR-0010/0014) ----------
# O driver de orquestração (orca.sh) implementa o contrato de subcomandos sobre a
# CLI do Orca — o único backend suportado (ADR-0014). Estas peças moram aqui, e
# não no driver, porque a fachada (panes.sh) também as consome.

MOSK_DEFAULT_TOKEN_CEILING=800000

# Teto de tokens para o gatilho de handoff por contexto.
# Precedência: env MOSK_CONTEXT_TOKEN_CEILING > core-config > default.
# Lê a chave comum (orchestration.context_token_ceiling). O grep é por nome de
# chave, não por caminho, então uma chave legada aninhada de instalação antiga
# continua sendo encontrada — não quebra quem ainda não migrou o core-config.
context_token_ceiling() {
    if [[ -n "${MOSK_CONTEXT_TOKEN_CEILING:-}" ]]; then
        echo "$MOSK_CONTEXT_TOKEN_CEILING"
        return 0
    fi
    local cfg val
    cfg="$(core_config_file 2>/dev/null || true)"
    if [[ -n "$cfg" && -f "$cfg" ]]; then
        val="$(grep -E '^[[:space:]]*context_token_ceiling:' "$cfg" 2>/dev/null | head -1 | sed -E 's/.*:[[:space:]]*//; s/[^0-9].*//')"
        [[ -n "$val" ]] && { echo "$val"; return 0; }
    fi
    echo "$MOSK_DEFAULT_TOKEN_CEILING"
}

# Extrai a contagem de tokens do texto de um pane (lê stdin).
# Regra: ignora linhas de dica ("save"/"/clear"/"ctx left") e pega a ÚLTIMA
# ocorrência de "<n>[k] tokens" — o contador de contexto nativo do Claude Code.
# Se nada casar, não imprime nada (o chamador trata como desconhecido).
extract_tokens() {
    awk '
        function tonum(s,   k){
            k=0
            if (s ~ /[kK]/) { k=1; sub(/[kK]/,"",s) }
            sub(/,/,".",s)
            if (k) return int((s+0)*1000)
            return int(s+0)
        }
        {
            l=$0; low=tolower(l)
            if (low ~ /save|clear|ctx left|context left/) next
            while (match(l, /[0-9][0-9.,]*[ ]*[kK]?[ ]*tokens/)) {
                m=substr(l,RSTART,RLENGTH)
                num=m; sub(/[ ]*tokens.*/,"",num); gsub(/ /,"",num)
                found=tonum(num)
                l=substr(l,RSTART+RLENGTH)
            }
        }
        END { if (found != "") print found }
    '
}

