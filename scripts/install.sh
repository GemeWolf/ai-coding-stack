#!/usr/bin/env bash
set -euo pipefail

# ai-coding-stack installer
# Instala gentle-ai via Homebrew, configura los agentes y aplica custom instructions.

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STATE_FILE="$HOME/.gentle-ai/state.json"
AGENTS=()

log() {
    echo "==> $*"
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --agents)
                if [[ $# -lt 2 ]]; then
                    log "Error: --agents requiere un valor"
                    exit 1
                fi
                IFS=',' read -r -a AGENTS <<< "$2"
                shift 2
                ;;
            --agents=*)
                IFS=',' read -r -a AGENTS <<< "${1#*=}"
                shift
                ;;
            *)
                log "Error: argumento desconocido: $1"
                exit 1
                ;;
        esac
    done
}

get_state_agents() {
    if [[ -f "$STATE_FILE" ]]; then
        python3 - "$STATE_FILE" <<'PY'
import json
import sys

try:
    with open(sys.argv[1], "r") as f:
        state = json.load(f)
    agents = state.get("installed_agents", [])
    if agents:
        print(",".join(str(a) for a in agents))
except Exception:
    pass
PY
    fi
}

check_dependencies() {
    if ! command -v python3 &>/dev/null; then
        log "Error: python3 no está instalado. Instálalo e intenta de nuevo."
        exit 1
    fi
    if ! command -v curl &>/dev/null; then
        log "Error: curl no está instalado. Instálalo e intenta de nuevo."
        exit 1
    fi
}

install_homebrew() {
    if command -v brew &>/dev/null; then
        log "Homebrew ya está instalado: $(brew --version | head -1)"
        return 0
    fi

    log "Homebrew no encontrado. Instalando..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

    # Asegurar que brew esté en PATH para el resto del script
    if [[ -f /home/linuxbrew/.linuxbrew/bin/brew ]]; then
        eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
    elif [[ -f /opt/homebrew/bin/brew ]]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
    elif [[ -f /usr/local/bin/brew ]]; then
        eval "$(/usr/local/bin/brew shellenv)"
    elif [[ -f "$HOME/.linuxbrew/bin/brew" ]]; then
        eval "$("$HOME/.linuxbrew/bin/brew" shellenv)"
    fi
}

install_gentle_ai() {
    if command -v gentle-ai &>/dev/null; then
        log "gentle-ai ya está instalado: $(gentle-ai --version)"
        return 0
    fi

    log "Instalando gentle-ai via Homebrew..."
    brew tap Gentleman-Programming/homebrew-tap
    brew install gentle-ai
}

configure_gentle_ai_state() {
    log "Configurando gentle-ai para los agentes: ${AGENTS[*]}"

    mkdir -p "$(dirname "$STATE_FILE")"

    local backup="$STATE_FILE.bak.$(date +%Y%m%d-%H%M%S)"
    if [[ -f "$STATE_FILE" ]]; then
        cp "$STATE_FILE" "$backup"
        log "Backup de state.json guardado en $backup"
    fi

    python3 - "$STATE_FILE" "${AGENTS[@]}" <<'PY'
import json
import os
import sys

state_file = sys.argv[1]
agents = sys.argv[2:]

state = {}
if os.path.isfile(state_file):
    with open(state_file, "r") as f:
        state = json.load(f)

state["installed_agents"] = agents
state["selection_configured"] = True
state["preset"] = state.get("preset", "full-gentleman")
state["persona"] = state.get("persona", "neutral")
state["strict_tdd"] = state.get("strict_tdd", True)

with open(state_file, "w") as f:
    json.dump(state, f, indent=2, ensure_ascii=False)
    f.write("\n")

print(f"state.json actualizado con agentes: {', '.join(agents)}")
PY
}

ensure_uv_in_path() {
    if command -v uv &>/dev/null; then
        return 0
    fi

    local uv_dir
    for uv_dir in "$HOME/.local/bin" "$HOME/.cargo/bin"; do
        if [[ -f "$uv_dir/uv" ]] && [[ -d "$uv_dir" ]]; then
            export PATH="$uv_dir:$PATH"
            return 0
        fi
    done

    return 1
}

install_uv() {
    ensure_uv_in_path
    if command -v uv &>/dev/null; then
        log "uv ya está instalado: $(uv --version)"
        return 0
    fi

    log "Instalando uv..."
    curl -LsSf https://astral.sh/uv/install.sh | sh
    ensure_uv_in_path
}

install_markitdown_mcp() {
    if command -v markitdown-mcp &>/dev/null; then
        log "markitdown-mcp ya está instalado"
        return 0
    fi

    log "Instalando markitdown-mcp via uv..."
    uv tool install markitdown-mcp
}

main() {
    log "ai-coding-stack installer"
    log "Repo root: $REPO_ROOT"

    parse_args "$@"
    check_dependencies
    install_homebrew
    install_gentle_ai

    if [[ ${#AGENTS[@]} -gt 0 ]]; then
        configure_gentle_ai_state
    elif state_agents=$(get_state_agents) && [[ -n "$state_agents" ]]; then
        IFS=',' read -r -a AGENTS <<< "$state_agents"
        log "Usando agentes existentes en state.json: ${AGENTS[*]}"
    else
        log "No hay agentes configurados. Ejecutando gentle-ai install interactivo..."
        gentle-ai install
        if state_agents=$(get_state_agents) && [[ -n "$state_agents" ]]; then
            IFS=',' read -r -a AGENTS <<< "$state_agents"
        fi
    fi

    log "Sincronizando assets de gentle-ai..."
    gentle-ai sync

    install_uv
    install_markitdown_mcp

    log "Aplicando custom instructions..."
    "$REPO_ROOT/scripts/apply-custom-instructions.sh"

    log "Instalación completada. Agentes configurados: ${AGENTS[*]:-(ninguno)}"
}

main "$@"
