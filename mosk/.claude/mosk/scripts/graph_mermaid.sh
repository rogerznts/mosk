#!/usr/bin/env bash
# graph_mermaid.sh — render a Mermaid flowchart from pipeline-graph.yaml.
#
# Determinístico e idempotente (lê o grafo na ordem do arquivo). É a fonte do
# diagrama de fluxo embutido em docs/index.md pelo index-docs (ADR-0006: o
# desenho é DERIVADO do grafo, não uma cópia paralela).
#
# Usage: graph_mermaid.sh [--help]
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/common.sh"

for arg in "$@"; do
    case "$arg" in
        --help|-h) echo "graph_mermaid.sh — emite um flowchart Mermaid do pipeline-graph.yaml"; exit 0 ;;
        *) echo "opcao desconhecida: $arg" >&2; exit 2 ;;
    esac
done

GF="$(graph_file)"
if [[ ! -f "$GF" ]]; then
    echo "erro: pipeline-graph.yaml não encontrado em $GF" >&2
    exit 2
fi

awk '
    function sid(s) { gsub(/[^A-Za-z0-9]/, "_", s); return s }
    function field(s, name,   re, v) {
        re = name ":[[:space:]]*"
        if (match(s, re)) {
            v = substr(s, RSTART + RLENGTH)
            if (substr(v, 1, 1) == "\"") { v = substr(v, 2); sub(/".*/, "", v) }
            else { sub(/[,}].*/, "", v); gsub(/^[[:space:]]+|[[:space:]]+$/, "", v) }
            return v
        }
        return ""
    }
    BEGIN { print "flowchart TD" }
    /^[^[:space:]#]/ { be = ($0 ~ /^edges:/); bs = ($0 ~ /^escalations:/) }
    be && /^[[:space:]]*-[[:space:]]*\{/ {
        f = field($0, "from"); t = field($0, "to"); g = field($0, "guard")
        if (g != "") printf "  %s[\"%s\"] -->|%s| %s[\"%s\"]\n", sid(f), f, g, sid(t), t
        else         printf "  %s[\"%s\"] --> %s[\"%s\"]\n", sid(f), f, sid(t), t
    }
    bs && /^[[:space:]]*-[[:space:]]*\{/ {
        fl = ""
        if (match($0, /from:[[:space:]]*\[[^]]*\]/)) {
            fl = substr($0, RSTART, RLENGTH); sub(/from:[[:space:]]*\[/, "", fl); sub(/\]/, "", fl); gsub(/[[:space:]]/, "", fl)
        }
        t = field($0, "to"); sig = field($0, "signal")
        n = split(fl, a, ",")
        for (i = 1; i <= n; i++) printf "  %s[\"%s\"] -.->|%s| %s[\"%s\"]\n", sid(a[i]), a[i], sig, sid(t), t
    }
' "$GF"
