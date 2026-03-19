#!/usr/bin/env bash
#
# check_deps.sh — verify that all build dependencies for ValaNostr are installed.
#

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BOLD='\033[1m'
NC='\033[0m'

missing=0

check_cmd() {
    local cmd="$1"
    local label="${2:-$cmd}"
    if command -v "$cmd" &>/dev/null; then
        local ver
        ver=$("$cmd" --version 2>/dev/null | head -1) || ver="(unknown version)"
        printf "  ${GREEN}OK${NC}  %-14s %s\n" "$label" "$ver"
    else
        printf "  ${RED}MISSING${NC}  %s\n" "$label"
        missing=1
    fi
}

check_pkg() {
    local pkg="$1"
    if pkg-config --exists "$pkg" 2>/dev/null; then
        local ver
        ver=$(pkg-config --modversion "$pkg" 2>/dev/null) || ver="?"
        printf "  ${GREEN}OK${NC}  %-14s %s\n" "$pkg" "$ver"
    else
        printf "  ${RED}MISSING${NC}  %s\n" "$pkg"
        missing=1
    fi
}

check_dir() {
    local dirpath="$1"
    local label="${2:-$(basename "$dirpath")}"
    if [[ -d "$dirpath" ]] && [[ -n "$(ls -A "$dirpath" 2>/dev/null)" ]]; then
        printf "  ${GREEN}OK${NC}  %-14s %s\n" "$label" "$dirpath"
    else
        printf "  ${RED}MISSING${NC}  %s  (run: git submodule update --init)\n" "$label"
        missing=1
    fi
}

detect_distro() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        echo "${ID:-unknown}"
    else
        echo "unknown"
    fi
}

print_install_hint() {
    local distro
    distro=$(detect_distro)
    echo ""
    printf "${BOLD}Install missing system packages:${NC}\n"
    echo ""
    case "$distro" in
        ubuntu|debian|pop|linuxmint)
            echo "  sudo apt install valac meson ninja-build gcc pkg-config \\"
            echo "                   libglib2.0-dev libjson-glib-dev"
            ;;
        fedora)
            echo "  sudo dnf install vala meson ninja-build gcc pkgconf-pkg-config \\"
            echo "                   glib2-devel json-glib-devel"
            ;;
        arch|manjaro|endeavouros)
            echo "  sudo pacman -S vala meson ninja gcc pkgconf glib2 json-glib"
            ;;
        *)
            echo "  Could not detect your distro (got: $distro)."
            echo "  Install these packages with your package manager:"
            echo "    valac  meson  ninja  gcc  pkg-config"
            echo "    glib-2.0 (dev)  json-glib-1.0 (dev)"
            ;;
    esac
}

# --- Main ---

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

printf "\n${BOLD}Checking ValaNostr build dependencies...${NC}\n\n"

printf "${BOLD}Build tools:${NC}\n"
check_cmd valac "valac"
check_cmd meson "meson"
check_cmd ninja "ninja"
check_cmd gcc "gcc"
check_cmd pkg-config "pkg-config"

echo ""
printf "${BOLD}Libraries (pkg-config):${NC}\n"
check_pkg glib-2.0
check_pkg gobject-2.0
check_pkg json-glib-1.0

echo ""
printf "${BOLD}Git submodules:${NC}\n"
check_dir "deps/secp256k1/src" "libsecp256k1"

echo ""

if [[ $missing -eq 0 ]]; then
    printf "${GREEN}${BOLD}All dependencies found. Ready to build:${NC}\n"
    echo ""
    echo "  meson setup build"
    echo "  meson compile -C build"
    echo "  meson test -C build"
    echo ""
    exit 0
else
    print_install_hint
    echo ""
    printf "${YELLOW}Fix the items marked MISSING above, then re-run this script.${NC}\n\n"
    exit 1
fi
