#!/bin/zsh 
# shellcheck shell=bash
# shellcheck disable=SC2001
# this is to use sed in the case statements
# shellcheck disable=SC2034,SC2296
# these are due to the dynamic variable assignments used in the localization strings
export PATH=/usr/bin:/bin:/usr/sbin:/sbin

: <<DOC
==============================================================================
Display Update Warning  
==============================================================================
Display users that have not updated to Sonoma to update using self service
DOC

############################################
# Variables
############################################
JAMF_BINARY="/usr/local/bin/jamf"
dialogBinary="/usr/local/bin/dialog"
dialogApp="/Library/Application Support/Dialog/Dialog.app"
LOGO=$( defaults read /Library/Preferences/com.jamfsoftware.jamf.plist self_service_app_path )
userID=$( id -u $loggedInUser )
InstallomatorApp="/usr/local/Installomator/Installomator.sh"

# check we are running as root
if [[ $DEBUG -eq 0 && $(id -u) -ne 0 ]]; then
    echo "This script should be run as root"
    exit 97
fi
## Checking for latest Swift Dialog

$InstallomatorApp dialog NOTIFY=silent

"${dialogBinary}" \
        --blurscreen \
        --quitkey p \
        --title "Your macOS is Not in Compliant" \
        --message "The macOS version needs to upgrade to macOS Sonoma to be in compliant with security standards.\n\n Please click '"'Continue'"' to open **Self Service** and run the **Upgrade to Sonoma** procedure" \
        --icon "$LOGO" \
        --timer 1800 \
        --button1text "Continue"

open "jamfselfservice://content?entity=policy&id=97&action=view"

exit 0