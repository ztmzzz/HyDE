#!/usr/bin/env bash
#|---/ /+-----------------------------+---/ /|#
#|--/ /-| Script to configure my apps |--/ /-|#
#|-/ /--| Prasanth Rangan             |-/ /--|#
#|/ /---+-----------------------------+/ /---|#

scrDir=$(dirname "$(dirname "$(realpath "$0")")")
source "${scrDir}/global_fn.sh"
if [ $? -ne 0 ]; then
    echo "Error: unable to source global_fn.sh..."
    exit 1
fi

cloneDir=$(dirname "$(realpath "$cloneDir")")

#// icons

if [ -f /usr/share/applications/rofi-theme-selector.desktop ] && [ -f /usr/share/applications/rofi.desktop ]; then
    sudo rm /usr/share/applications/rofi-theme-selector.desktop
    sudo rm /usr/share/applications/rofi.desktop
fi
sudo sed -i "/^Icon=/c\Icon=adjust-colors" /usr/share/applications/nwg-look.desktop
sudo sed -i "/^Icon=/c\Icon=spectacle" /usr/share/applications/swappy.desktop
