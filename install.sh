#!/usr/bin/env bash
set -euo pipefail

# Punto de entrada principal del installer.
# La logica real vive en scripts/ para mantener el repo modular.

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$REPO_ROOT/scripts/install.sh" "$@"
