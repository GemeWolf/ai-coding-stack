#!/usr/bin/env bash
# Install workspace tools: gentle-ai (via Homebrew tap) and engram (GitHub release, checksum-verified).
# Idempotent: skips tools already installed.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# shellcheck source=lib/os.sh
source "$SCRIPT_DIR/lib/os.sh"

DRY_RUN="${DRY_RUN:-false}"

log() {
    echo "==> $*"
}

install_homebrew() {
    if command -v brew &>/dev/null; then
        log "Homebrew already installed: $(brew --version | head -1)"
        return 0
    fi

    if [[ "$DRY_RUN" == "true" ]]; then
        log "[dry-run] Would install Homebrew"
        return 0
    fi

    log "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

    # Ensure brew is on PATH for the rest of the script
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
        log "gentle-ai already installed: $(gentle-ai --version 2>/dev/null || echo '(version unknown)')"
        return 0
    fi

    if [[ "$DRY_RUN" == "true" ]]; then
        log "[dry-run] Would install gentle-ai via Homebrew tap"
        return 0
    fi

    log "Installing gentle-ai via Homebrew tap..."
    brew tap Gentleman-Programming/homebrew-tap
    brew install gentle-ai
}

install_engram() {
    if command -v engram &>/dev/null; then
        log "engram already installed: $(engram --version 2>/dev/null || echo '(version unknown)')"
        return 0
    fi

    if [[ "$DRY_RUN" == "true" ]]; then
        log "[dry-run] Would download engram GitHub release and verify checksum"
        return 0
    fi

    local os arch asset_url download_dir checksum_url
    os="$(os_detect)"
    arch="$(uname -m)"

    # Map architecture to release naming
    case "$arch" in
        x86_64)  arch="x86_64" ;;
        arm64|aarch64) arch="aarch64" ;;
        *)
            log "ERROR: Unsupported architecture '${arch}' for engram download"
            return 1
            ;;
    esac

    # Gentle AI engram releases: https://github.com/gentle-ai/engram/releases
    local repo="gentle-ai/engram"
    local latest_url="https://api.github.com/repos/${repo}/releases/latest"

    log "Fetching latest engram release info..."
    local tag
    tag="$(curl -fsSL "$latest_url" | python3 -c "
import json, sys
data = json.load(sys.stdin)
print(data.get('tag_name', ''))
")"

    if [[ -z "$tag" ]]; then
        log "ERROR: Could not determine latest engram release tag"
        return 1
    fi

    log "Latest engram release: ${tag}"

    local filename="engram-${os}-${arch}.tar.gz"
    asset_url="https://github.com/${repo}/releases/download/${tag}/${filename}"
    checksum_url="https://github.com/${repo}/releases/download/${tag}/checksums.txt"

    download_dir="$(mktemp -d)"
    trap 'rm -rf "$download_dir"' RETURN

    log "Downloading ${filename}..."
    if ! curl -fsSL -o "${download_dir}/${filename}" "$asset_url"; then
        log "ERROR: Failed to download engram release from ${asset_url}"
        return 1
    fi

    # Verify checksum if available
    log "Verifying checksum..."
    if curl -fsSL -o "${download_dir}/checksums.txt" "$checksum_url" 2>/dev/null; then
        (cd "$download_dir" && sha256sum -c --ignore-missing checksums.txt)
        if [[ $? -ne 0 ]]; then
            log "ERROR: engram checksum verification failed"
            return 1
        fi
        log "Checksum verified."
    else
        log "WARNING: No checksum file available; skipping verification"
    fi

    # Extract and install to ~/.local/bin
    local install_dir="${HOME}/.local/bin"
    mkdir -p "$install_dir"

    log "Extracting engram to ${install_dir}..."
    tar -xzf "${download_dir}/${filename}" -C "$install_dir"

    # Ensure install dir is on PATH
    export PATH="${install_dir}:${PATH}"

    log "engram installed to ${install_dir}/engram"
}

install_tools() {
    os_require_supported

    install_homebrew
    install_gentle_ai
    install_engram
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    install_tools
fi
