#!/bin/zsh 
# shellcheck shell=bash
# shellcheck disable=SC2001
# this is to use sed in the case statements
# shellcheck disable=SC2034,SC2296
# these are due to the dynamic variable assignments used in the localization strings
# Script found: https://community.jamf.com/t5/jamf-pro/allow-standard-user-to-remove-wi-fi-networks-with-prompt/td-p/273617 
export PATH=/usr/bin:/bin:/usr/sbin:/sbin

: <<DOC
==============================================================================
Corserva by Gabriel Marcelino - Senior Apple Technician
Making User Network Admin  
==============================================================================
Giving user network admin rights
DOC

#	Variables
SECURITYBIN="/usr/bin/security"
PLISTBUDDYBIN="/usr/libexec/PlistBuddy"

/usr/bin/security authorizationdb write system.preferences.network allow
/usr/bin/security authorizationdb write system.services.systemconfiguration.network allow
/usr/bin/security authorizationdb write com.apple.wifi allow
/usr/libexec/airportd prefs RequireAdminNetworkChange=NO RequireAdminIBSS=NO

$SECURITYBIN authorizationdb read system.preferences > /tmp/system.preferences.plist
$SECURITYBIN authorizationdb read system.preferences.network > /tmp/system.preferences.network.plist

#	Allow access to system wide preference panes
TARGETPLIST="/tmp/system.preferences.plist"
ARRAY=($($PLISTBUDDYBIN -c "print :rule" $TARGETPLIST | sed -e 's/^Array {//' | sed -e 's/}//' | xargs ))
#echo $ARRAY
if [[ ! $ARRAY =~ '(^allow)|(\sallow)' ]] ; then
	echo "Modifying $TARGETPLIST"
	$PLISTBUDDYBIN -c "set :class rule" $TARGETPLIST
	$PLISTBUDDYBIN -c "add :rule array" $TARGETPLIST
	$PLISTBUDDYBIN -c "add :rule: string allow" $TARGETPLIST
	$PLISTBUDDYBIN -c "set :shared true" $TARGETPLIST
	$PLISTBUDDYBIN -c "delete :authenticate-user" $TARGETPLIST
	$PLISTBUDDYBIN -c "delete :group" $TARGETPLIST
fi

#	Allow access to network preference pane
TARGETPLIST="/tmp/system.preferences.network.plist"
ARRAY=($($PLISTBUDDYBIN -c "print :rule" $TARGETPLIST | sed -e 's/^Array {//' | sed -e 's/}//' | xargs ))
#echo $ARRAY
if [[ ! $ARRAY =~ '(^allow)|(\sallow)' ]] ; then
	echo "Modifying $TARGETPLIST"
	$PLISTBUDDYBIN -c "set :class rule" $TARGETPLIST
	$PLISTBUDDYBIN -c "add :rule array" $TARGETPLIST
	$PLISTBUDDYBIN -c "add :rule: string allow" $TARGETPLIST
	$PLISTBUDDYBIN -c "set :shared true" $TARGETPLIST
	$PLISTBUDDYBIN -c "delete :authenticate-user" $TARGETPLIST
	$PLISTBUDDYBIN -c "delete :group" $TARGETPLIST
fi

$SECURITYBIN authorizationdb write system.preferences < /tmp/system.preferences.plist
$SECURITYBIN authorizationdb write system.preferences.network < /tmp/system.preferences.network.plist
exit 0