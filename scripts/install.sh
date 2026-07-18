#!/usr/bin/env bash
set -euo pipefail

# ai-coding-stack installer
# Instala gentle-ai via Homebrew, configura los agentes y aplica custom instructions.

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STATE_FILE="$HOME/.gentle-ai/state.json"
AGENTS=("kimi" "opencode" "pi")

log() {
    echo "==> $*"
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

main() {
    log "ai-coding-stack installer"
    log "Repo root: $REPO_ROOT"

    check_dependencies
    install_homebrew
    install_gentle_ai
    configure_gentle_ai_state

    log "Sincronizando assets de gentle-ai..."
    gentle-ai sync

    configure_gentle_ai_state

    log "Aplicando custom instructions..."
    "$REPO_ROOT/scripts/apply-custom-instructions.sh"

    log "Instalación completada. Agentes configurados: ${AGENTS[*]}"
}

main "$@"
