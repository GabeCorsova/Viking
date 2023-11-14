#!/bin/bash

##############################################################################
# Script to find the latest Anaconda and install and extract the Python coponites using anaconda's script
# Script by Gabriel Marcelino
# Senior Apple Technician of Corserva
# 11/06/2023
##############################################################################

loggedInUser=$( ls -l /dev/console | awk '{print $3}' )
LoggedinHomeFolder="/Users/$loggedInUser"
Scriptlocation="$LoggedinHomeFolder"/anaconda3.sh

#Downloading the latest Anaconda3 installer for macOS. Your architecture may vary.
echo "
Downloading latest script for Anaconda
"
/usr/bin/curl https://repo.anaconda.com/archive/Anaconda3-2023.09-0-MacOSX-x86_64.sh -o "$Scriptlocation"

echo "
Running Script for Anaconda
"

/bin/bash "$LoggedinHomeFolder"/anaconda3.sh -b -p "$LoggedinHomeFolder"/anaconda3

#Clean up
echo "
Removing $Scriptlocation
"
/bin/rm -rf "$Scriptlocation"

exit 0