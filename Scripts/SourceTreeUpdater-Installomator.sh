#!/bin/zsh

export PATH=/usr/bin:/bin:/usr/sbin:/sbin

<<'ABOUT_THIS_SCRIPT'

-----------------------------------------------------------------------
Using Swift Dialog and Installomator to install for Self Service Apps
Exit codes:
98 = Not supported OS
97 = Not being run as Root
96 = Installomator couldn't be installed or found
95 = Swift Dialog couldn't be installed or found
0 = All went well
-----------------------------------------------------------------------

ABOUT_THIS_SCRIPT

############################################
# Variables
############################################
JAMF_BINARY="/usr/local/bin/jamf"
dialog_command_file="/var/tmp/dialog.log"
# Parameter 4: message displayed over the progress bar
message="Updating Sourcetree..."
# Parameter 5: path or URL to an icon
icon="https://usw2.ics.services.jamfcloud.com/icon/hash_176409e6a4b5ca1bc4cf2b0b98e03a87701adf56a1cf64121284786e30e4721f"
app="sourcetree"
dialogApp="/Library/Application Support/Dialog/Dialog.app"
InstallomatorApp="/usr/local/Installomator/Installomator.sh"
overlayicon=$( defaults read /Library/Preferences/com.jamfsoftware.jamf.plist self_service_app_path )

dialogUpdate() {
    # $1: dialog command
    local dcommand="$1"

    if [[ -n $dialog_command_file ]]; then
        echo "$dcommand" >> "$dialog_command_file"
        echo "Dialog: $dcommand"
    fi
}

############################################
# Checking for Tools
############################################
    # check minimal macOS requirement
    if [[ $(sw_vers -buildVersion ) < "20A" ]]; then
        echo "This script requires at least macOS 11 Big Sur."
        exit 98
    fi

    # check we are running as root
    if [[ $DEBUG -eq 0 && $(id -u) -ne 0 ]]; then
        echo "This script should be run as root"
        exit 97
    fi

    # Clean up old Log if there
     if [ -f $dialog_command_file ]; then
        /bin/rm -rf "$dialog_command_file"
    else 
    echo  "
    ******************************
    * No Log file continue
    ******************************
    "
    fi

    # Check if Installomator exit
    if [ -f $InstallomatorApp ]; then
    echo "
    ******************************
    * Installomator found conitinue
    ******************************
    "
    else 
    echo "Installomator not found will install from Jamf"
    $JAMF_BINARY policy -event Installomator
    echo "Checking if Installamator is installed correctly"
        if [ -f $InstallomatorApp ]; then
            echo "
            ******************************
            * Installomator found conitinue
            ******************************
            "
        else 
            echo "
                ############################################
                # ERROR: Could not find Instomator
                ############################################
                "
            exit 96
        fi
    fi
    # swiftDialog installation
    if [ -d $dialogApp ]; then
    echo "
    *****************************
    * Swift Dialog found conitinue
    *****************************
    "
    else
    echo "Swift Dialog not found will install from Jamf"
    echo "
        ############################################
        # Installing Swift Dialog with Installomator
        ############################################
        "
    $InstallomatorApp swiftdialog NOTIFY=silent INSTALL="force"
    echo "Checking if Swift Dialog is installed correctly"
        if [  -d $dialogApp ]; then
            echo "
            *************************
            * Swift Dialog found conitinue
            *****************************
            "
        else 
            echo "
                ############################################
                # ERROR: Could not find Swift Dialog
                ############################################
                "
            exit 95
        fi
    fi
############################################
# Logic
############################################

echo "
********************************************
* Installing $app
********************************************
"

# display first screen
open -a "$dialogApp" --args \
        --title none \
        --icon "$icon" \
        --overlayicon "$overlayicon" \
        --message "$message" \
        --mini \
        --progress 100 \
        --position bottomright \
        --movable \
        --commandfile "$dialog_command_file"

# give everything a moment to catch up
sleep 0.1

echo "
********************************************
* Installomator
********************************************
"
# Installomator installing app
    $InstallomatorApp $app DIALOG_CMD_FILE=$dialog_command_file NOTIFY=silent

echo "
********************************************
* Cleaning up
********************************************
"
# close and quit dialog
dialogUpdate "progress: complete"
dialogUpdate "progresstext: Done"

# pause a moment
sleep 0.5

dialogUpdate "quit:"

# let everything catch up
sleep 0.5

# just to be safe
killall "Dialog"

# Clean up
/bin/rm -rf "$dialog_command_file"

# the killall command above will return error when Dialog is already quit
# but we don't want that to register as a failure in Jamf,  so always exit 0
echo "
********************************************
* Done! Closing Up!
********************************************
"
exit 0