#!/usr/bin/env bash
# Install MCPs declared in config/mcp-manifest.yaml.
# Idempotent: skips MCPs already present. Failures are non-critical (warn-and-continue).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
MANIFEST="$REPO_ROOT/config/mcp-manifest.yaml"

DRY_RUN="${DRY_RUN:-false}"

log() {
    echo "==> $*"
}

warn() {
    echo "WARNING: $*" >&2
}

# Simple YAML parser: extracts values for a given key from manifest blocks
# Reads the manifest and processes MCP entries sequentially
install_mcps() {
    if [[ ! -f "$MANIFEST" ]]; then
        log "No MCP manifest found at ${MANIFEST}; skipping MCP installation"
        return 0
    fi

    log "Installing MCPs from ${MANIFEST}..."

    # Parse manifest using Python inline (YAML parsing is non-trivial in pure bash)
    python3 - "$MANIFEST" "${DRY_RUN}" <<'PY'
import subprocess
import sys

manifest_path = sys.argv[1]
dry_run = sys.argv[2] == "true"

# Minimal YAML list-of-dicts parser (sufficient for our manifest format)
def parse_manifest(path):
    mcps = []
    current = {}
    with open(path, "r") as f:
        for line in f:
            stripped = line.rstrip()
            # New list item
            if stripped.startswith("  - name:"):
                if current:
                    mcps.append(current)
                current = {"name": stripped.split(":", 1)[1].strip()}
            elif stripped.startswith("    "):
                if ":" in stripped:
                    key, val = stripped.split(":", 1)
                    current[key.strip()] = val.strip()
            elif stripped.startswith("#") or stripped == "":
                continue
            else:
                # Top-level key (like "mcps:") — skip
                pass
    if current:
        mcps.append(current)
    return mcps

try:
    mcps = parse_manifest(manifest_path)
except Exception as e:
    print(f"WARNING: Failed to parse MCP manifest: {e}")
    sys.exit(0)

if not mcps:
    print("No MCPs declared in manifest.")
    sys.exit(0)

for mcp in mcps:
    name = mcp.get("name", "unknown")
    check_cmd = mcp.get("check_cmd", "")
    install_cmd = mcp.get("install_cmd", "")
    description = mcp.get("description", "")

    display = f"{name}" + (f" ({description})" if description else "")
    print(f"-> Checking {display}...")

    # Check if already installed
    if check_cmd:
        try:
            subprocess.run(check_cmd, shell=True, check=True,
                         stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            print(f"  [ok] {name} already installed, skipping")
            continue
        except subprocess.CalledProcessError:
            pass

    if not install_cmd:
        print(f"  [!] No install_cmd for {name}, skipping")
        continue

    if dry_run:
        print(f"  [dry-run] Would run: {install_cmd}")
        continue

    # Attempt install (non-critical: warn on failure)
    print(f"  Installing {name}: {install_cmd}")
    try:
        subprocess.run(install_cmd, shell=True, check=True)
        print(f"  [ok] {name} installed successfully")
    except subprocess.CalledProcessError as e:
        print(f"  [!] {name} install failed (non-critical): {e}")

PY

    log "MCP installation step complete."
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    install_mcps
fi
