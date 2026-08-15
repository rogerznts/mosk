#!/usr/bin/env bash
# classify-change.sh — classificação determinística e sem efeitos colaterais.
set -u

usage() {
    cat <<'EOF'
classify-change.sh --scope VALUE --reversibility VALUE \
  --sensitive-surface VALUE --evidence VALUE --ambiguity VALUE \
  [--requested-floor standard|elevated|critical]

Emite um ChangeProfile JSON em ordem estável. Opções ausentes, desconhecidas ou
contraditórias retornam status 2 sem emitir JSON.
EOF
}

die() {
    printf 'classify-change: %s\n' "$1" >&2
    return 2
}

scope=""
reversibility=""
sensitive_surface=""
evidence=""
ambiguity=""
requested_floor=""

set_value() {
    key="$1"
    value="$2"
    current=""
    case "$key" in
        scope) current="$scope" ;;
        reversibility) current="$reversibility" ;;
        sensitive_surface) current="$sensitive_surface" ;;
        evidence) current="$evidence" ;;
        ambiguity) current="$ambiguity" ;;
        requested_floor) current="$requested_floor" ;;
        *) return 2 ;;
    esac
    if [ -n "$current" ] && [ "$current" != "$value" ]; then
        die "opção repetida com valores contraditórios: $key"
        return 2
    fi
    case "$key" in
        scope) scope="$value" ;;
        reversibility) reversibility="$value" ;;
        sensitive_surface) sensitive_surface="$value" ;;
        evidence) evidence="$value" ;;
        ambiguity) ambiguity="$value" ;;
        requested_floor) requested_floor="$value" ;;
    esac
}

while [ "$#" -gt 0 ]; do
    option="$1"
    case "$option" in
        --help|-h)
            usage
            exit 0
            ;;
        --scope|--reversibility|--sensitive-surface|--evidence|--ambiguity|--requested-floor)
            if [ "$#" -lt 2 ]; then
                die "valor ausente para $option"
                exit 2
            fi
            value="$2"
            case "$option" in
                --scope) key=scope ;;
                --reversibility) key=reversibility ;;
                --sensitive-surface) key=sensitive_surface ;;
                --evidence) key=evidence ;;
                --ambiguity) key=ambiguity ;;
                --requested-floor) key=requested_floor ;;
            esac
            set_value "$key" "$value" || exit 2
            shift 2
            ;;
        *)
            die "opção desconhecida: $option"
            exit 2
            ;;
    esac
done

[ -n "$scope" ] || { die "--scope é obrigatório"; exit 2; }
[ -n "$reversibility" ] || { die "--reversibility é obrigatório"; exit 2; }
[ -n "$sensitive_surface" ] || { die "--sensitive-surface é obrigatório"; exit 2; }
[ -n "$evidence" ] || { die "--evidence é obrigatório"; exit 2; }
[ -n "$ambiguity" ] || { die "--ambiguity é obrigatório"; exit 2; }

case "$scope" in
    localized) scope_score=0 ;;
    multi_file) scope_score=1 ;;
    cross_domain) scope_score=2 ;;
    public_contract) scope_score=3 ;;
    *) die "scope inválido: $scope"; exit 2 ;;
esac
case "$reversibility" in
    easy) reversibility_score=0 ;;
    coordinated) reversibility_score=1 ;;
    irreversible) reversibility_score=3 ;;
    *) die "reversibility inválido: $reversibility"; exit 2 ;;
esac
case "$sensitive_surface" in
    none) sensitive_score=0 ;;
    paths_state) sensitive_score=2 ;;
    data_security) sensitive_score=3 ;;
    production_critical) sensitive_score=5 ;;
    *) die "sensitive-surface inválido: $sensitive_surface"; exit 2 ;;
esac
case "$evidence" in
    strong) evidence_score=0 ;;
    partial) evidence_score=1 ;;
    absent) evidence_score=2 ;;
    *) die "evidence inválido: $evidence"; exit 2 ;;
esac
case "$ambiguity" in
    clear) ambiguity_score=0 ;;
    bounded) ambiguity_score=1 ;;
    material) ambiguity_score=2 ;;
    *) die "ambiguity inválido: $ambiguity"; exit 2 ;;
esac
case "$requested_floor" in
    ""|standard|elevated|critical) ;;
    *) die "requested-floor inválido: $requested_floor"; exit 2 ;;
esac

score=$((scope_score + reversibility_score + sensitive_score + evidence_score + ambiguity_score))
if [ "$score" -le 2 ]; then
    profile=compact
    score_reason='score:0-2'
elif [ "$score" -le 5 ]; then
    profile=standard
    score_reason='score:3-5'
elif [ "$score" -le 9 ]; then
    profile=elevated
    score_reason='score:6-9'
else
    profile=critical
    score_reason='score:10+'
fi

rank() {
    case "$1" in
        compact) printf 0 ;;
        standard) printf 1 ;;
        elevated) printf 2 ;;
        critical) printf 3 ;;
    esac
}

floor=compact
reasons="\"$score_reason\""
raise_floor() {
    candidate="$1"
    reason="$2"
    if [ "$(rank "$candidate")" -gt "$(rank "$floor")" ]; then
        floor="$candidate"
    fi
    reasons="$reasons,\"$reason\""
}

[ "$sensitive_surface" != data_security ] || raise_floor elevated 'floor:data_security'
[ "$sensitive_surface" != production_critical ] || raise_floor critical 'floor:production_critical'
[ "$reversibility" != irreversible ] || raise_floor critical 'floor:irreversible'
if [ "$scope" = cross_domain ] && [ "$evidence" = absent ]; then
    raise_floor elevated 'floor:cross_domain_absent'
fi
if [ -n "$requested_floor" ]; then
    raise_floor "$requested_floor" "floor:requested_$requested_floor"
fi
if [ "$(rank "$floor")" -gt "$(rank "$profile")" ]; then
    profile="$floor"
fi

human_pause=false
if [ "$ambiguity" = material ]; then
    human_pause=true
    reasons="$reasons,\"pause:material_ambiguity\""
fi
if [ "$reversibility" = irreversible ] || [ "$sensitive_surface" = production_critical ]; then
    human_pause=true
fi

case "$profile" in
    compact)
        validation_floor=focused
        specialists='[]'
        ;;
    standard)
        validation_floor=domain
        specialists='[]'
        ;;
    elevated)
        validation_floor=independent
        if [ "$sensitive_surface" = data_security ] || [ "$sensitive_surface" = production_critical ]; then
            specialists='["security","qa"]'
        else
            specialists='["qa"]'
        fi
        ;;
    critical)
        validation_floor=release
        specialists='["security","qa"]'
        ;;
esac

printf '{"schema":1,"profile":"%s","score":%s,"floor":"%s","reasons":[%s],"context_budget":"%s","validation_floor":"%s","specialists":%s,"human_pause":%s}\n' \
    "$profile" "$score" "$floor" "$reasons" "$profile" "$validation_floor" "$specialists" "$human_pause"
