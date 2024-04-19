#!/bin/zsh
# Found example https://community.jamf.com/t5/jamf-pro/uninstall-citrix/m-p/166202#M155150
# Edited for Zsh and for Corserva by Gabriel Marcelino - Senior Apple Technician
# shellcheck shell=bash
# shellcheck disable=SC2001
# this is to use sed in the case statements
# shellcheck disable=SC2034,SC2296
# these are due to the dynamic variable assignments used in the localization strings
#Debug
#set -x
<<'ABOUT_THIS_SCRIPT'
-----------------------------------------------------------------------
Unistalling Citrix Receiver from Viking computers:
Edited for Zsh and for Corserva by Gabriel Marcelino - Senior Apple Technician
-----------------------------------------------------------------------
ABOUT_THIS_SCRIPT

#Define Location of Citrix Workspace Uninstaller
workspaceApp="/Library/Application Support/Citrix Receiver/Uninstall Citrix Workspace.app"

#If Citrix Workspace is installed, uninstall it
if [ -d "$workspaceApp" ]; then
    echo "Workspace installed, uninstalling"
    /Library/Application\ Support/Citrix\ Receiver/Uninstall\ Citrix\ Workspace.app/Contents/MacOS/Uninstall\ Citrix\ Workspace --nogui
    sleep 5
    uninstallerRunning=$(ps aux | grep "Uninstall Citrix Workspace" | grep -v "grep")
    while [ -e "$uninstallerRunning" ]; do
        echo "Uninstaller running"
        sleep 5
        uninstallerRunning=$(ps aux | grep "Uninstall Citrix Workspace" | grep -v "grep")
    done
    echo "Uninstaller not running"
    sleep 2
fi

exit 0