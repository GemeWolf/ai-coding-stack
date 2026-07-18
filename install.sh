#!/usr/bin/env bash
set -euo pipefail

# ai-coding-stack installer
# Instala las herramientas de coding agents y aplica configuraciones comunes.

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$REPO_ROOT/config"

echo "==> ai-coding-stack installer"
echo "    Repo root: $REPO_ROOT"

# TODO: detectar sistema operativo y gestor de paquetes
# TODO: instalar dependencias base (git, curl, node, bun, etc.)
# TODO: instalar Kimi Code CLI
# TODO: instalar OpenCode
# TODO: instalar pi-coding-agent
# TODO: enlazar/sincronizar configuraciones desde config/

echo "==> Instalación base completada. Revisa los TODOs en install.sh para continuar."
