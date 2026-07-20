#!/usr/bin/env bash
# payload-deploy.sh — driver de deploy do adapter Payload (provedor: Railway).
#
# Publica uma ferramenta criada pelo /mosk-bench num servidor Railway, usando a
# conta do próprio usuário. O BUILD roda REMOTO no Railway (INV-4 "zero build
# local" preservada, ADR-0005). Gera um overlay de produção no projeto SEM tocar
# no starter dev (docker-compose.yml/`pnpm dev` continuam intactos).
#
# Fluxo (idempotente):
#   1. checa a CLI do Railway (instalação guiada com UMA confirmação se faltar)
#   2. autentica via RAILWAY_TOKEN (do ambiente — nunca em flag)
#   3. gera overlay de produção: Dockerfile.production + railway.json + env prod
#   4. provisiona Postgres + Redis gerenciados
#   5. railway up (build+deploy remoto) + migrate no pre-deploy
#   6. gera/retorna a URL pública
#
# Suporta --help e --dry-run. Usa common.sh. Assume conta paga (sem free-tier).
#
# NOTA DE MANUTENÇÃO: as flags exatas da CLI do Railway evoluem; validar contra a
# versão instalada (`railway --help`) ao ajustar. O caminho --dry-run é seguro e
# não executa nenhuma ação remota.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

DRY_RUN=false
APP_NAME=""

usage() {
    cat <<'EOF'
Usage: payload-deploy.sh [--name <nome-publico>] [--dry-run] [--help]

Publica no Railway a ferramenta Payload do diretório atual (projeto /mosk-bench).

Pré-requisitos:
  - Rodar dentro de um projeto criado pelo /mosk-bench (starter Payload presente).
  - RAILWAY_TOKEN exportado no ambiente (token da conta do usuário).
    Gere em: https://railway.com/account/tokens

OPTIONS:
  --name <nome>  Nome público da ferramenta (default: nome do diretório do projeto).
  --dry-run      Mostra o plano de deploy; não instala, provisiona nem publica nada.
  --help, -h     Mostra esta ajuda.

O build de produção roda REMOTO no Railway — nada é buildado na sua máquina.
O overlay de produção (Dockerfile.production, railway.json) é gerado no projeto e
não altera o ambiente de desenvolvimento (docker-compose.yml / pnpm dev).
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run) DRY_RUN=true ;;
        --name) shift; APP_NAME="${1:-}"; [[ -z "$APP_NAME" ]] && { echo "ERRO: --name exige um valor." >&2; exit 1; } ;;
        --help|-h) usage; exit 0 ;;
        *) echo "ERRO: opção desconhecida '$1'. Use --help." >&2; exit 1 ;;
    esac
    shift
done

PROJECT_DIR="$(pwd)"
[[ -z "$APP_NAME" ]] && APP_NAME="$(basename "$PROJECT_DIR")"

run() {  # executa (ou só descreve em dry-run)
    if $DRY_RUN; then echo "would  $*"; else echo "  ->  $*"; eval "$@"; fi
}

# ---------- 0. reconhecer projeto bench ----------
recognize_project() {
    if [[ ! -f "$PROJECT_DIR/src/payload.config.ts" || ! -f "$PROJECT_DIR/package.json" ]]; then
        echo "ERRO: este diretório não parece uma ferramenta criada pelo /mosk-bench" >&2
        echo "      (esperado src/payload.config.ts + package.json). Rode dentro do projeto." >&2
        exit 1
    fi
    echo "  ok  projeto bench reconhecido: $APP_NAME"
}

# ---------- 1. CLI do Railway (instalação guiada) ----------
has_railway() { command -v railway >/dev/null 2>&1; }

ensure_railway_cli() {
    if has_railway; then echo "  ok  Railway CLI: $(railway --version 2>/dev/null)"; return 0; fi
    echo
    echo "A CLI do Railway não está instalada."
    echo "Comando oficial de instalação:"
    echo "    npm i -g @railway/cli"
    echo
    if $DRY_RUN; then echo "would  instalar a CLI (após confirmação) — dry-run, nada feito."; return 0; fi
    printf 'Posso instalar a CLI do Railway agora? (digite "sim" para continuar): '
    read -r ans
    case "$ans" in
        sim|Sim|SIM|s|S|yes|y) npm i -g @railway/cli ;;
        *) echo "Tudo bem — nada instalado. Instale com o comando acima e rode de novo."; exit 1 ;;
    esac
    has_railway || { echo "CLI ainda indisponível nesta sessão. Reabra o terminal e rode de novo." >&2; exit 1; }
}

# ---------- 2. autenticação por token ----------
check_token() {
    if [[ -z "${RAILWAY_TOKEN:-}" ]]; then
        echo "ERRO: RAILWAY_TOKEN não está no ambiente." >&2
        echo "      Exporte o token da sua conta (nunca passe em flag):" >&2
        echo "        export RAILWAY_TOKEN=<seu-token>   # https://railway.com/account/tokens" >&2
        exit 1
    fi
    echo "  ok  RAILWAY_TOKEN presente no ambiente."
    $DRY_RUN || railway whoami >/dev/null 2>&1 || { echo "ERRO: token inválido ou sem acesso." >&2; exit 1; }
}

# ---------- 3. overlay de produção (não toca o starter dev) ----------
PAYLOAD_SECRET_PROD=""
generate_overlay() {
    local df="$PROJECT_DIR/Dockerfile.production"
    local rj="$PROJECT_DIR/railway.json"

    if $DRY_RUN; then
        echo "would  gerar $df (multi-stage: install --frozen-lockfile -> pnpm build -> pnpm start)"
        echo "would  gerar $rj (builder DOCKERFILE + preDeployCommand: payload migrate)"
        echo "would  gerar PAYLOAD_SECRET de produção (aleatório) e variáveis NODE_ENV=production"
        return 0
    fi

    cat > "$df" <<'DOCKER'
# Dockerfile.production — gerado por payload-deploy.sh. Buildado REMOTAMENTE no
# Railway (nada roda na máquina do usuário). Não usado pelo ambiente de dev.
FROM node:22-bookworm-slim
RUN corepack enable
WORKDIR /app
COPY package.json pnpm-lock.yaml ./
RUN pnpm install --frozen-lockfile
COPY . .
ENV NODE_ENV=production
RUN pnpm build
EXPOSE 3000
CMD ["pnpm", "start"]
DOCKER

    cat > "$rj" <<'RJSON'
{
  "$schema": "https://railway.app/railway.schema.json",
  "build": { "builder": "DOCKERFILE", "dockerfilePath": "Dockerfile.production" },
  "deploy": {
    "preDeployCommand": "pnpm payload migrate",
    "startCommand": "pnpm start",
    "restartPolicyType": "ON_FAILURE"
  }
}
RJSON

    # segredo de produção próprio (independente do dev)
    PAYLOAD_SECRET_PROD="$(openssl rand -hex 24 2>/dev/null || head -c 48 /dev/urandom | od -An -tx1 | tr -d ' \n')"
    echo "  ok  overlay de produção gerado (Dockerfile.production, railway.json)"
}

# ---------- 4-6. provisionar, deployar, migrar, expor ----------
deploy() {
    # cria/vincula o projeto no Railway
    run "railway init -n '$APP_NAME' || railway link"
    # serviços gerenciados (Postgres + Redis). Flags conforme CLI atual do Railway.
    run "railway add --database postgres"
    run "railway add --database redis"
    # variáveis de produção (DATABASE_URL/REDIS_URL são injetadas pelos plugins do Railway;
    # o payload.config lê DATABASE_URI/REDIS_URL — mapeamos via referência de variável).
    run "railway variables --set 'NODE_ENV=production'"
    run "railway variables --set 'PAYLOAD_SECRET=${PAYLOAD_SECRET_PROD:-<gerado>}'"
    run "railway variables --set 'DATABASE_URI=\${{Postgres.DATABASE_URL}}'"
    run "railway variables --set 'REDIS_URL=\${{Redis.REDIS_URL}}'"
    # build + deploy REMOTO (o Railway builda o Dockerfile.production)
    run "railway up --detach"
    # domínio público
    run "railway domain"
}

# ---------- fluxo principal ----------
echo "Publicando a ferramenta '$APP_NAME'$($DRY_RUN && echo ' (dry-run)')..."
recognize_project
ensure_railway_cli
check_token
generate_overlay
deploy
echo
if $DRY_RUN; then
    echo "Dry-run concluído — nenhuma ação remota foi executada."
else
    echo "Deploy disparado. A URL pública aparece acima (railway domain)."
    echo "O ambiente local (/mosk-bench) continua funcionando separado, sem alteração."
fi
