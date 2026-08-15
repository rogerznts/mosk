#!/usr/bin/env bash
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

SPEC=""
TO=""
COMMAND=""
JSON=false

usage() {
    cat <<'EOF'
Usage: transition-spec-phase.sh --spec <number|spec_id|branch> --to <phase> --command <task> [--json]

Executes one validated MOSK phase transition. Exit 0 = success, 1 = contract
violation, 2 = usage error. The command never chooses the destination phase.
EOF
}

json_escape() {
    local value="$1"
    value="${value//\\/\\\\}"
    value="${value//\"/\\\"}"
    value="${value//$'\n'/\\n}"
    printf '%s' "$value"
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --spec) [[ $# -ge 2 ]] || { usage >&2; exit 2; }; SPEC="$2"; shift 2 ;;
        --to) [[ $# -ge 2 ]] || { usage >&2; exit 2; }; TO="$2"; shift 2 ;;
        --command) [[ $# -ge 2 ]] || { usage >&2; exit 2; }; COMMAND="$2"; shift 2 ;;
        --json) JSON=true; shift ;;
        --help|-h) usage; exit 0 ;;
        *) echo "ERROR: opção desconhecida '$1'" >&2; usage >&2; exit 2 ;;
    esac
done
[[ -n "$SPEC" && -n "$TO" && -n "$COMMAND" ]] || { usage >&2; exit 2; }

REPO_ROOT="$(get_repo_root)"
if ! SPEC_DIR="$(resolve_spec_dir "$REPO_ROOT" "$SPEC" active 2>&1)"; then
    if $JSON; then printf '{"ok":false,"failures":["%s"]}\n' "$(json_escape "$SPEC_DIR")"; else echo "$SPEC_DIR" >&2; fi
    exit 1
fi
FROM="$(read_spec_meta "$SPEC_DIR" current_phase)"
if failure="$(transition_spec_phase "$SPEC_DIR" "$TO" "$COMMAND" "$REPO_ROOT" 2>&1)"; then
    CHANGED=true; [[ "$FROM" == "$TO" ]] && CHANGED=false
    if $JSON; then
        printf '{"ok":true,"spec":"%s","from":"%s","to":"%s","changed":%s}\n' "$(basename "$SPEC_DIR")" "$FROM" "$TO" "$CHANGED"
    else
        echo "$(basename "$SPEC_DIR"): $FROM -> $TO ($COMMAND)"
    fi
else
    if $JSON; then printf '{"ok":false,"spec":"%s","from":"%s","to":"%s","failures":["%s"]}\n' "$(basename "$SPEC_DIR")" "$FROM" "$TO" "$(json_escape "$failure")"; else echo "$failure" >&2; fi
    exit 1
fi
