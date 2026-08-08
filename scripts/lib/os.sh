#!/usr/bin/env bash
# OS abstraction layer for ai-coding-stack installer.
# Detects Linux/macOS, provides path helpers. Windows is documented as future work.

set -euo pipefail

# detect_os: prints "linux", "macos", or "windows"
os_detect() {
    local uname_out
    uname_out="$(uname -s)"
    case "$uname_out" in
        Linux*)  echo "linux" ;;
        Darwin*) echo "macos" ;;
        MINGW*|MSYS*|CYGWIN*) echo "windows" ;;
        *)       echo "unknown" ;;
    esac
}

# os_is_linux: returns 0 if running on Linux
os_is_linux() {
    [[ "$(os_detect)" == "linux" ]]
}

# os_is_macos: returns 0 if running on macOS
os_is_macos() {
    [[ "$(os_detect)" == "macos" ]]
}

# os_is_windows: returns 0 if running on Windows (WSL/MSYS/Cygwin)
os_is_windows() {
    [[ "$(os_detect)" == "windows" ]]
}

# os_supported: returns 0 if the current OS is supported (linux or macos)
os_supported() {
    local os
    os="$(os_detect)"
    [[ "$os" == "linux" || "$os" == "macos" ]]
}

# os_path_sep: prints the path separator (always "/" on unix-like systems)
os_path_sep() {
    echo "/"
}

# os_home: prints the user home directory, respecting OS conventions
os_home() {
    echo "$HOME"
}

# os_font_dir: prints the user-level font directory for the current OS
# Linux: ~/.local/share/fonts
# macOS: ~/Library/Fonts
os_font_dir() {
    local os
    os="$(os_detect)"
    case "$os" in
        linux) echo "${HOME}/.local/share/fonts" ;;
        macos) echo "${HOME}/Library/Fonts" ;;
        *)     echo "" ;;
    esac
}

# os_require_supported: hard-fail if the OS is not Linux or macOS
os_require_supported() {
    if ! os_supported; then
        local os
        os="$(os_detect)"
        echo "ERROR: Unsupported operating system '${os}'. This installer supports Linux and macOS only." >&2
        echo "Windows support is planned for a future release. See docs for details." >&2
        exit 1
    fi
}
