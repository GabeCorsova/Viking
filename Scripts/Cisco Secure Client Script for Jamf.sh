#!/bin/zsh 
# shellcheck shell=bash
# shellcheck disable=SC2001
# this is to use sed in the case statements
# shellcheck disable=SC2034,SC2296
# these are due to the dynamic variable assignments used in the localization strings
export PATH=/usr/bin:/bin:/usr/sbin:/sbin

: <<DOC
==============================================================================
Cisco Secure Client Script to install this should auto clean up the 
Cisco Umbrella clients once it install
By Gabriel Marcelino Corserva Senior Apple Technician
==============================================================================
DOC

############################################
# Variables
############################################
JAMF_BINARY="/usr/local/bin/jamf"
WorkingDir="/private/var/tmp/CiscoSecure"
# JSON files need to begin with Name of company -Orginfo.json
# Bluelake-OrgInfo.json 
# Corserva-Orginfo.json 
# Enertiv-Orginfo.json
# SmartOs-Orginfo.json
JSONFile="$WorkingDir/$4-Orginfo.json"

############################################
# Functions
############################################



# Running the Pkg
echo "
==============================
Starting installation
==============================
"

sudo installer -pkg "$WorkingDir"/Cisco\ Secure\ Client.pkg -applyChoiceChangesXML "$WorkingDir"/install_choices.xml -target /

wait

# Look for the file and rename it and move it to the proper folder
if [ -f "$JSONFile" ]; then
echo "
==============================================================================
File was found will move "$JSONFile" to Working Directory
==============================================================================
"
mv "$JSONFile" "$WorkingDir"/Profiles/Orginfo.json
/bin/cp -f "$WorkingDir"/Profiles/Orginfo.json /opt/cisco/secureclient/umbrella/
else
echo "
+++++++++++++++++++++++++++++++++++++++
ERROR JSON File could not be found
+++++++++++++++++++++++++++++++++++++++
"
exit 1
fi 

# Clean up
echo "
==============================
Cleanup mess
==============================
"
rm -rf "$WorkingDir"
exit 0