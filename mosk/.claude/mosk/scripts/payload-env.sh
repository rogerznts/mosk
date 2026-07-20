#!/usr/bin/env bash
# payload-env.sh — valida o ambiente Docker para o modo /mosk-bench.
#
# Ordem de validação (FR-003): docker --version -> docker info (daemon) ->
# docker compose version. Faltando Docker, oferece instalação guiada com UMA
# confirmação explícita (FR-004, US3): detecta o SO, mostra o comando oficial,
# nunca instala silenciosamente; se o usuário recusar, para com instrução amigável.
#
# Idempotente. Suporta --help e --dry-run. Usa common.sh.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

DRY_RUN=false

for arg in "$@"; do
    case "$arg" in
        --dry-run)
            DRY_RUN=true
            ;;
        --help|-h)
            cat <<'EOF'
Usage: payload-env.sh [--dry-run] [--help]

Valida o ambiente Docker exigido pelo modo /mosk-bench.

Checa, nesta ordem:
  1. docker --version        (binário instalado)
  2. docker info             (daemon rodando)
  3. docker compose version  (plugin compose v2)

Se o Docker não estiver instalado, propõe a instalação oficial do SO
detectado e pede UMA confirmação explícita antes de executar (Linux usa
sudo). Nunca instala nada silenciosamente; recusa => para de forma amigável.

Códigos de saída:
  0  ambiente pronto (ou instalado com sucesso após confirmação)
  1  ambiente não pronto (Docker ausente/recusado, daemon parado, etc.)

OPTIONS:
  --dry-run   Mostra o que faria; não instala nem altera nada.
  --help, -h  Mostra esta ajuda.

O script é idempotente: rodar de novo num ambiente já pronto é um no-op.
EOF
            exit 0
            ;;
        *)
            echo "ERRO: opção desconhecida '$arg'. Use --help." >&2
            exit 1
            ;;
    esac
done

# ---------- detecção de SO ----------

detect_os() {
    case "$(uname -s)" in
        Linux)  echo "linux" ;;
        Darwin) echo "macos" ;;
        *)      echo "other" ;;
    esac
}

# Comando oficial de instalação por SO. Linux: script de conveniência oficial
# do Docker. macOS: Docker Desktop (via Homebrew se houver, senão download).
install_command() {
    local os="$1"
    case "$os" in
        linux)
            echo "curl -fsSL https://get.docker.com | sudo sh"
            ;;
        macos)
            if command -v brew >/dev/null 2>&1; then
                echo "brew install --cask docker"
            else
                echo "Baixe o Docker Desktop em https://www.docker.com/products/docker-desktop/ e instale."
            fi
            ;;
        *)
            echo ""
            ;;
    esac
}

# ---------- checagens ----------

has_docker_bin()      { command -v docker >/dev/null 2>&1 && docker --version >/dev/null 2>&1; }
has_docker_daemon()   { docker info >/dev/null 2>&1; }
has_docker_compose()  { docker compose version >/dev/null 2>&1; }

guided_install() {
    local os cmd
    os="$(detect_os)"
    cmd="$(install_command "$os")"

    echo
    echo "O Docker não está instalado nesta máquina."

    if [[ "$os" == "other" || -z "$cmd" ]]; then
        echo "Não consegui detectar um instalador automático para o seu sistema."
        echo "Instale o Docker manualmente: https://docs.docker.com/get-docker/"
        return 1
    fi

    echo "Sistema detectado: $os"
    echo "Comando oficial de instalação:"
    echo
    echo "    $cmd"
    echo

    if $DRY_RUN; then
        echo "would  executar o comando acima (após confirmação) — dry-run, nada foi feito."
        return 0
    fi

    # Instalação por comando (só Linux tem comando executável direto).
    if [[ "$os" != "linux" ]]; then
        echo "No macOS a instalação é manual (ou via Homebrew). Rode o comando acima e depois execute este passo de novo."
        return 1
    fi

    printf 'Posso instalar o Docker agora com esse comando oficial? (digite "sim" para continuar): '
    read -r answer
    case "$answer" in
        sim|Sim|SIM|s|S|yes|y)
            echo "Instalando o Docker (isso pode pedir sua senha do sistema)..."
            curl -fsSL https://get.docker.com | sudo sh
            echo "Instalação concluída. Pode ser necessário reabrir o terminal ou fazer logout/login para usar o Docker sem sudo."
            ;;
        *)
            echo "Tudo bem — nada foi instalado. Quando quiser, instale o Docker com o comando acima e rode o modo de novo."
            return 1
            ;;
    esac
}

# ---------- fluxo principal ----------

echo "Verificando o ambiente Docker..."

# 1. binário
if ! has_docker_bin; then
    if $DRY_RUN; then
        echo "would  propor instalação guiada do Docker (binário ausente)."
        exit 0
    fi
    guided_install || exit 1
    # Revalida após instalar.
    if ! has_docker_bin; then
        echo "Docker ainda não disponível nesta sessão. Reabra o terminal e rode de novo." >&2
        exit 1
    fi
fi
echo "  ok  docker instalado: $(docker --version 2>/dev/null)"

# 2. daemon
if ! has_docker_daemon; then
    echo "  x   o Docker está instalado, mas o serviço (daemon) não está rodando." >&2
    if [[ "$(detect_os)" == "macos" ]]; then
        echo "      Abra o Docker Desktop e aguarde ele iniciar; depois rode de novo." >&2
    else
        echo "      Inicie o serviço (ex.: sudo systemctl start docker) e rode de novo." >&2
    fi
    exit 1
fi
echo "  ok  daemon do Docker está rodando."

# 3. compose v2
if ! has_docker_compose; then
    echo "  x   o plugin 'docker compose' (v2) não está disponível." >&2
    echo "      Atualize o Docker para uma versão com Compose v2 embutido." >&2
    exit 1
fi
echo "  ok  docker compose disponível: $(docker compose version --short 2>/dev/null || docker compose version 2>/dev/null | head -n1)"

echo "Ambiente pronto."
exit 0
