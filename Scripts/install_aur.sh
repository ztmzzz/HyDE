#!/usr/bin/env bash
#|---/ /+-------------------------------------------+---/ /|#
#|--/ /-| Script to install aur helper, yay or paru |--/ /-|#
#|-/ /--| Prasanth Rangan                           |-/ /--|#
#|/ /---+-------------------------------------------+/ /---|#

scrDir=$(dirname "$(realpath "$0")")
# shellcheck disable=SC1091
if ! source "${scrDir}/global_fn.sh"; then
    echo "Error: unable to source global_fn.sh..."
    exit 1
fi

# shellcheck disable=SC2154
if chk_list "aurhlpr" "${aurList[@]}"; then
    print_log -sec "AUR" -stat "Detected" "${aurhlpr}"
    exit 0
fi

aurhlpr="${1:-yay-bin}"

if [[ "${aurhlpr}" == "paru" || "${aurhlpr}" == "paru-bin" ]]; then
    if ! grep -q "^[[:space:]]*\\[chaotic-aur\\]" /etc/pacman.conf 2>/dev/null; then
        print_log -r "AUR" -stat "failed" "Chaotic AUR is required before installing ${aurhlpr} via pacman."
        print_log -y "AUR" -stat "hint" "Run Scripts/install_pre.sh or enable Chaotic AUR first."
        exit 1
    fi
fi

print_log -sec "AUR" -stat "install" "Installing ${aurhlpr} via pacman..."
if ! pacman -Si "${aurhlpr}" &>/dev/null; then
    print_log -r "AUR" -stat "failed" "${aurhlpr} not found in pacman repos. Ensure Chaotic AUR is enabled."
    exit 1
fi

if sudo pacman ${use_default:+"$use_default"} -S "${aurhlpr}"; then
    print_log -sec "AUR" -stat "installed" "${aurhlpr} (pacman)"
    exit 0
else
    print_log -r "AUR" -stat "failed" "${aurhlpr} installation via pacman failed..."
    exit 1
fi
