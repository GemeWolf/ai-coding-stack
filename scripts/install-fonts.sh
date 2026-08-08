#!/usr/bin/env bash
# Copy font files from the repo source to assets/fonts/.
# This script only COPIES — it does NOT run any system-level font install command.
# Idempotent: skips copy if file exists and matches (by size).
# After copy, prints manual installation instructions for the user.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

DRY_RUN="${DRY_RUN:-false}"

log() {
    echo "==> $*"
}

install_fonts() {
    local asset_dir="$REPO_ROOT/assets/fonts"
    local font_sources=()

    # Discover font files in the repo (assets/fonts/ or a fonts/ source directory)
    # Priority 1: assets/fonts/ (already copied)
    if [[ -d "$asset_dir" ]]; then
        while IFS= read -r -d '' font; do
            # Skip .gitkeep
            [[ "$(basename "$font")" == ".gitkeep" ]] && continue
            font_sources+=("$font")
        done < <(find "$asset_dir" -type f \( -name "*.ttf" -o -name "*.otf" -o -name "*.woff" -o -name "*.woff2" \) -print0 2>/dev/null || true)
    fi

    # Priority 2: fonts/ directory at repo root (source fonts)
    local source_font_dir="$REPO_ROOT/fonts"
    if [[ ${#font_sources[@]} -eq 0 && -d "$source_font_dir" ]]; then
        while IFS= read -r -d '' font; do
            font_sources+=("$font")
        done < <(find "$source_font_dir" -type f \( -name "*.ttf" -o -name "*.otf" -o -name "*.woff" -o -name "*.woff2" \) -print0 2>/dev/null || true)
    fi

    if [[ ${#font_sources[@]} -eq 0 ]]; then
        log "No font files found to copy. Place .ttf/.otf files in ${source_font_dir}/ or ${asset_dir}/"
        return 0
    fi

    # Ensure target assets/fonts/ directory exists
    mkdir -p "$asset_dir"

    local copied=0
    local skipped=0

    for font in "${font_sources[@]}"; do
        local filename target
        filename="$(basename "$font")"
        target="${asset_dir}/${filename}"

        # Idempotency check: skip if file exists and size matches
        if [[ -f "$target" ]]; then
            local src_size tgt_size
            src_size="$(stat -f%z "$font" 2>/dev/null || stat --printf="%s" "$font" 2>/dev/null || echo "0")"
            tgt_size="$(stat -f%z "$target" 2>/dev/null || stat --printf="%s" "$target" 2>/dev/null || echo "0")"
            if [[ "$src_size" == "$tgt_size" && "$src_size" != "0" ]]; then
                log "  [skip] ${filename} already present and up-to-date"
                ((skipped++)) || true
                continue
            fi
        fi

        if [[ "$DRY_RUN" == "true" ]]; then
            log "  [dry-run] Would copy ${filename} -> ${target}"
            ((copied++)) || true
            continue
        fi

        cp "$font" "$target"
        log "  [ok] Copied ${filename} -> ${target}"
        ((copied++)) || true
    done

    # Print manual install instructions
    echo ""
    echo "==> Font files are available in: ${asset_dir}/"
    echo ""
    echo "To install the fonts on your system:"
    echo ""
    if [[ "$(uname -s)" == "Darwin" ]]; then
        echo "  macOS:"
        echo "    - Double-click the font file(s) in Finder → 'Install Font'"
        echo "    - Or copy to ~/Library/Fonts/ manually"
    else
        echo "  Linux:"
        echo "    - Copy font(s) to ~/.local/share/fonts/ then run: fc-cache -fv"
        echo "    - Or use your distro's font manager"
    fi
    echo ""
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    install_fonts
fi
