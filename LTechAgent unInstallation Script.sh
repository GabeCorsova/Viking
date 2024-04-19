#!/bin/sh

## Uninstall Script for LTSAgents
## By Gabriel Marcelino - Senior Apple Technician

## Uninstall LTS
sh /usr/local/ltechagent/uninstaller.sh

#Remote Connect wise if exist
rm -rf /Applications/connectwisecontrol*
rm -rf /Library/LaunchDaemons/connectwisecontrol*
rm -rf /Library/LaunchAgents/connectwisecontrol*
rm -rf /opt/screenconnect*
rm -rf /Library/LaunchDaemons/screenconnect*
rm -rf /Library/LaunchAgents/screenconnect*


#Clean it up old installer
rm -rf "/private/var/tmp/LTSAgent"

exit 0		## Success
