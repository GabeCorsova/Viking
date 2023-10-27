#!/bin/zsh
<<'ABOUT_THIS_SCRIPT'
-----------------------------------------------------------------------
App Maintenance script By Gabriel Marcelino from Corserva...

Working with This to make a script using Installomator and Jamf with the following:

On Installomator:

- 1Password
- Adobe Acrobat Reader
- Adobe Creative Cloud DC
- Amazon Chime
- Amazon Workspace
- Azure Data Studio
- Brave Browser
- Citrix Workspace
- Displaylink
- Google Chrome
- Microsoft Office 2019/365 applications: Excel, Powerpoint, Word
- Microsoft Outlook
- Microsoft OneNote
- Microsoft Teams
- Microsoft Edge
- Mozilla Firefox
- Postman
- RingCentral Softphone
- Royal TSX
- Slack
- Sublimetext
- Talkdesk Callbar
- Talkdesk CXcloud
- TeamViewer FUll
- TeamViewer QS
- TextExpander
- VLC
- Viscosity
- Vmware Horizon Client
- Wireshark
- Wacom Drivers
- zoom.us

On Installomator but not on this script yet:
jetbrainsrubymine
boxdrive - No App Version may not be able to 
googledrive - No App Version may not be able to 
Citrix
Adobe A Adobe Suite (using Adobe binary for update)
Palo Alto Networks GlobalProtect VPN 
Qualys Cloud Agent
-----------------------------------------------------------------------
ABOUT_THIS_SCRIPT
############################################
# Variables
############################################
JAMF_BINARY="/usr/local/bin/jamf"
AdobeRUM="/usr/local/bin/RemoteUpdateManager"
versionKey="CFBundleShortVersionString"
dialogBinary="/usr/local/bin/dialog"
dialogApp="/Library/Application Support/Dialog/Dialog.app"
dialogMessageLog=$( mktemp /var/tmp/dialogWelcomeLog.XXX )
InstallomatorApp="/usr/local/Installomator/Installomator.sh"
LOGO=$( defaults read /Library/Preferences/com.jamfsoftware.jamf.plist self_service_app_path )
json_tmp_file=$( mktemp "/var/tmp/json_tmp.XXX" )
overlayicon=$( defaults read /Library/Preferences/com.jamfsoftware.jamf.plist self_service_app_path )
WorkingDir="/usr/local/viking/WeeklyUpdates"
Log_File="/var/log/WeeklyUpdate_Defer.log"
dialog_command_file="/var/tmp/dialog.log"
loggedInUser=$( ls -l /dev/console | awk '{print $3}' )
userID=$( id -u $loggedInUser )
Deferal_Policy="WeeklyUpdateDeferal"
PLISTNAME="com.Viking.weeklyupdatedeferal.plist"
Deferal_PLIST="/Library/LaunchAgents/$PLISTNAME"
Deferals_Count_PLIST="$WorkingDir/com.viking.weeklyupdatedeferalcount.plist"
icon_most_path="/Contents/Resources"
# for future to fix the listing
appsdisplay=()
install_apps=()
app_icon=()
IFS=,
#ZoomControlappVersion="$4"
#ZoomControlappVersion="5.14.0.16775"
############################################
# Functions
############################################
sendToLog () {
	echo "$(date +"%Y-%b-%d %T") : $1" | tee -a "$Log_File"
}

dialog_command(){
    echo $1
    echo $1  >> ${dialog_command_file}
}

getJSONValue() {
	# $1: JSON string OR file path to parse (tested to work with up to 1GB string and 2GB file).
	# $2: JSON key path to look up (using dot or bracket notation).
	printf '%s' "$1" | /usr/bin/osascript -l 'JavaScript' \
		-e "let json = $.NSString.alloc.initWithDataEncoding($.NSFileHandle.fileHandleWithStandardInput.readDataToEndOfFile$(/usr/bin/uname -r | /usr/bin/awk -F '.' '($1 > 18) { print "AndReturnError(ObjC.wrap())" }'), $.NSUTF8StringEncoding)" \
		-e 'if ($.NSFileManager.defaultManager.fileExistsAtPath(json)) json = $.NSString.stringWithContentsOfFileEncodingError(json, $.NSUTF8StringEncoding, ObjC.wrap())' \
		-e "const value = JSON.parse(json.js)$([ -n "${2%%[.[]*}" ] && echo '.')$2" \
		-e 'if (typeof value === "object") { JSON.stringify(value, null, 4) } else { value }'
}

xpath() {
	# the xpath tool changes in Big Sur and now requires the `-e` option
	if [[ $(sw_vers -buildVersion) > "20A" ]]; then
		/usr/bin/xpath -e $@
		# alternative: switch to xmllint (which is not perl)
		#xmllint --xpath $@ -
	else
		/usr/bin/xpath $@
	fi
}

versionFromGit() {
    # credit: Søren Theilgaard (@theilgaard)
    # $1 git user name, $2 git repo name
    gitusername=${1?:"no git user name"}
    gitreponame=${2?:"no git repo name"}

    #appNewVersion=$(curl -L --silent --fail "https://api.github.com/repos/$gitusername/$gitreponame/releases/latest" | grep tag_name | cut -d '"' -f 4 | sed 's/[^0-9\.]//g')
    appNewVersion=$(curl -sLI "https://github.com/$gitusername/$gitreponame/releases/latest" | grep -i "^location" | tr "/" "\n" | tail -1 | sed 's/[^0-9\.]//g')
    if [ -z "$appNewVersion" ]; then
        printlog "could not retrieve version number for $gitusername/$gitreponame" WARN
        appNewVersion=""
    else
        echo "$appNewVersion"
        return 0
    fi
}

## Getting App Version ##

getAppVersion() {
    # modified by: Søren Theilgaard (@theilgaard) and Isaac Ordonez
    appPathArray=( ${(0)applist} )

        if [[ ${#appPathArray} -gt 0 ]]; then
            filteredAppPaths=( ${(M)appPathArray:#${targetDir}*} )
                if [[ ${#filteredAppPaths} -eq 1 ]]; then
            installedAppPath=$filteredAppPaths[1]
            #appversion=$(mdls -name kMDItemVersion -raw $installedAppPath )
            appversion=$(defaults read $installedAppPath/Contents/Info.plist $versionKey) #Not dependant on Spotlight indexing
            echo "Found app at $installedAppPath, version $appversion, on versionKey $versionKey"
            updateDetected="YES"
                else
                echo "could not determine location of $name"
            fi
        else
            echo "could not find $name"
        fi
}

## Checking if apps exist ##

Install_App_List() {

    ##### 1 Password #####
    name="1Password"
    applist="/Applications/$name.app"
    echo "
        *** Checking for $name ***
        App File Path: $applist"
    if [ -d "$applist" ]; then
        echo "--$name Exists--"
        echo "Checking latest Version"
        appNewVersion=$(curl -s https://app-updates.agilebits.com/product_history/OPM8 | grep -v -e "\.NIGHTLY" | grep -vE "-" | grep -Eo "([0-9]+\.){2}[0-9]+" | sort -rVu | head -n1)
        echo "$name Latest Version: $appNewVersion"
            ## Getting Current Version ##
                getAppVersion
                echo "Mac has $name version $appversion "
                if [[ $appversion != $appNewVersion ]]; then
                	if [[ "$appversion" > "$appNewVersion" ]]; then
                	  echo "$name is on a higher version then reported: $appversion"
                	  else  
            	    echo "$name Needs to be updated"   
        			appsdisplay+=("$name")
        			## Installomator variable ##
        			install_apps+=("1password8")
                    app_icon+=("$applist/$icon_most_path/icon.icns")
                    fi
        	    else
        	        echo "$name is on the latest version $appNewVersion"
        	    fi
    	else
        echo "--No $name--"
    fi

    # ##### Adobe CC #####
    # name="Creative Cloud"
    # applist="/Applications/Utilities/Adobe Creative Cloud/ACC/$name.app"
    # echo "
    #     *** Checking for $name ***
    #     App File Path: $applist"
    # if [ -d "$applist" ]; then
    #     echo "--Adobe Cloud Exists--"
    #     echo "Checking latest Version"
    #         if [[ "$(arch)" == "arm64" ]]; then
    #         downloadURL=$(curl -fs "https://helpx.adobe.com/download-install/kb/creative-cloud-desktop-app-download.html" | grep -o 'https.*macarm64.*dmg' | head -1 | cut -d '"' -f1)
    #     else
    #         downloadURL=$(curl -fs "https://helpx.adobe.com/download-install/kb/creative-cloud-desktop-app-download.html" | grep -o 'https.*osx10.*dmg' | head -1 | cut -d '"' -f1)
    #     fi        
    # 	appNewVersion=$(echo $downloadURL | grep -o '[^x]*$' | cut -d '.' -f 1 | sed 's/_/\./g')
    #     echo "$name Latest Version: $appNewVersion"
    #         ## Getting Current Version ##
    #             getAppVersion
    #             echo "Mac has $name version $appversion "
    #             if [[ $appversion != $appNewVersion ]]; then   
    #         	    echo "$name Needs to be updated"   
    #     			appsdisplay+=("$name")
    #     			## Installomator variable ##
    #     			install_apps+=("adobecreativeclouddesktop")
    #                 app_icon+=("$applist/$icon_most_path/CreativeCloudApp.icns")
    #     	    else
    #     	        echo "$name is on the latest version $appNewVersion"
    #     	    fi
    # 	else
    #     echo "--No $name--"
    # fi

    ##### Adobe Acrobat Reader #####
    name="Adobe Acrobat Reader DC"
    applist="/Applications/$name.app"
    echo "
        *** Checking for $name ***
        App File Path: $applist"
    if [ -d "$applist" ]; then
        echo "--Adobe Acrobat Reader Exists--"
        echo "Checking latest Version"
    	appNewVersion=$(curl -s https://armmf.adobe.com/arm-manifests/mac/AcrobatDC/reader/current_version.txt)
        echo "$name Latest Version: $appNewVersion"
            ## Getting Current Version ##
                getAppVersion
                echo "Mac has $name version $appversion "
                if [[ $appversion != $appNewVersion ]]; then   
            	    echo "$name Needs to be updated"   
        			appsdisplay+=("$name")
        			## Installomator variable ##
        			install_apps+=("adobereaderdc")
                    app_icon+=("$applist/$icon_most_path/ACR_App.icns")
        	    else
        	        echo "$name is on the latest version $appNewVersion"
        	    fi
    	else
        echo "--No $name--"
    fi

    ##### Adobe Acrobat Reader 2 without DC (Some have DC in the name most don't #####
    name="Adobe Acrobat Reader"
    applist="/Applications/$name.app"
    echo "
        *** Checking for $name ***
        App File Path: $applist"
    if [ -d "$applist" ]; then
        echo "--Adobe Acrobat Reader Exists--"
        echo "Checking latest Version"
    	appNewVersion=$(curl -s https://armmf.adobe.com/arm-manifests/mac/AcrobatDC/reader/current_version.txt)
        echo "$name Latest Version: $appNewVersion"
            ## Getting Current Version ##
                getAppVersion
                echo "Mac has $name version $appversion "
                if [[ $appversion != $appNewVersion ]]; then   
            	    echo "$name Needs to be updated"   
        			appsdisplay+=("$name")
        			## Installomator variable ##
        			install_apps+=("adobereaderdc-update")
                    app_icon+=("$applist/$icon_most_path/ACR_App.icns")
        	    else
        	        echo "$name is on the latest version $appNewVersion"
        	    fi
    	else
        echo "--No $name--"
    fi

    ##### Amazon Chime #####
    name="Amazon Chime"
    applist="/Applications/$name.app"
    echo "
        *** Checking for $name ***
        App File Path: $applist"
    if [ -d "$applist" ]; then
        echo "--Amazon $name Exists--"
        echo "Checking latest Version"
        downloadURL="https://clients.chime.aws/mac/latest"
        appNewVersion=$( curl -fsIL "${downloadURL}" | grep -i "^location" | awk '{print $2}' | sed -E 's/.*\/[a-zA-Z.\-]*-([0-9.]*)\..*/\1/g' )
        echo "$name Latest Version: $appNewVersion"
            ## Getting Current Version ##
                getAppVersion
                echo "Mac has $name version $appversion "
                if [[ $appversion != $appNewVersion ]]; then   
            	    echo "$name Needs to be updated"   
        			appsdisplay+=("$name")
        			## Installomator variable ##
        			install_apps+=("amazonchime")
                    app_icon+=("$applist")
        	    else
        	        echo "Amazon $name is on the latest version $appNewVersion"
        	    fi
    	else
        echo "--No $name--"
    fi

    ##### Azure Data Studio #####
    name="Azure Data Studio"
    applist="/Applications/$name.app"
    echo "
        *** Checking for $name ***
        App File Path: $applist"
    if [ -d "$applist" ]; then
        echo "--$name Exists--"
        echo "Checking latest Version"
        downloadURL=$( curl -sL https://github.com/microsoft/azuredatastudio/releases/latest | grep 'Universal' | grep -Eo "(http|https)://[a-zA-Z0-9./?=_%:-]*" | head -1 )
        appNewVersion=$(versionFromGit microsoft azuredatastudio )
        echo "$name Latest Version: $appNewVersion"
            ## Getting Current Version ##
                getAppVersion
                echo "Mac has $name version $appversion "
                if [[ $appversion != $appNewVersion ]]; then   
            	    echo "$name Needs to be updated"   
        			appsdisplay+=("$name")
        			## Installomator variable ##
        			install_apps+=("microsoftazuredatastudio")
                    app_icon+=("$applist")
        	    else
        	        echo "$name is on the latest version $appNewVersion"
        	    fi
    	else
        echo "--No $name--"
    fi

    ##### Citrix Workspace #####
    name="Citrix Workspace"
    applist="/Applications/$name.app"
    echo "
        *** Checking for $name ***
        App File Path: $applist"
    if [ -d "$applist" ]; then
        versionKey="CitrixVersionString"
        echo "--$name Exists--"
        echo "Checking latest Version"
        parseURL() {
        urlToParse='https://www.citrix.com/downloads/workspace-app/mac/workspace-app-for-mac-latest.html#ctx-dl-eula-external'
        htmlDocument=$(curl -s -L $urlToParse)
        xmllint --html --xpath "string(//a[contains(@rel, 'downloads.citrix.com')]/@rel)" 2> /dev/null <(print $htmlDocument)
    }
    downloadURL="https:$(parseURL)"
    newVersionString() {
        urlToParse='https://www.citrix.com/downloads/workspace-app/mac/workspace-app-for-mac-latest.html'
        htmlDocument=$(curl -fs $urlToParse)
        xmllint --html --xpath 'string(//p[contains(., "Version")])' 2> /dev/null <(print $htmlDocument)
    }
    appNewVersion=$(newVersionString | cut -d ' ' -f2 )
    echo "$name Latest Version: $appNewVersion"
            ## Getting Current Version ##
                getAppVersion
                echo "Mac has $name version $appversion "
                if [[ $appversion != $appNewVersion ]]; then
                	if [[ "$appversion" > "$appNewVersion" ]]; then
                	  echo "$name is on a higher version then reported: $appversion"
                	  else  
            	    echo "$name Needs to be updated"   
        			appsdisplay+=("$name")
        			## Installomator variable ##
        			install_apps+=("citrixworkspace")
                    app_icon+=("$applist/$icon_most_path/025_Receiver_Combo_Mac.icns")
                    fi
        	    else
        	        echo "$name is on the latest version $appNewVersion"
        	    fi
                versionKey="CFBundleShortVersionString"
    	else
        echo "--No $name--"
    fi

    ##### Display Link Manager #####
    name="DisplayLink Manager"
    applist="/Applications/$name.app"
    echo "
        *** Checking for $name ***
        App File Path: $applist"
    if [ -d "$applist" ]; then
        echo "--$name Exists--"
        echo "Checking latest Version"
        appNewVersion=$(curl -sfL https://www.synaptics.com/products/displaylink-graphics/downloads/macos | grep "Release:" | head -n 1 | cut -d ' ' -f2)
        echo "$name Latest Version: $appNewVersion"
            ## Getting Current Version ##
                getAppVersion
                echo "Mac has $name version $appversion "
                if [[ $appversion != $appNewVersion ]]; then
                	if [[ "$appversion" > "$appNewVersion" ]]; then
                	  echo "$name is on a higher version then reported: $appversion"
                	  else  
            	    echo "$name Needs to be updated"   
        			appsdisplay+=("$name")
        			## Installomator variable ##
        			install_apps+=("displaylinkmanager")
                    app_icon+=("$applist/$icon_most_path/Icon.icns")
                    fi
        	    else
        	        echo "$name is on the latest version $appNewVersion"
        	    fi
    	else
        echo "--No $name--"
    fi

    ##### Amazon Workspaces #####
    name="Workspaces"
    applist="/Applications/$name.app"
    echo "
        *** Checking for $name ***
        App File Path: $applist"
    if [ -d "$applist" ]; then
        echo "--Amazon $name Exists--"
        echo "Checking latest Version"
        appNewVersion=$(curl -fs https://d2td7dqidlhjx7.cloudfront.net/prod/iad/osx/WorkSpacesAppCast_macOS_20171023.xml | grep -o "Version*.*<" | head -1 | cut -d " " -f2 | cut -d "<" -f1)
        echo "$name Latest Version: $appNewVersion"
            ## Getting Current Version ##
                getAppVersion
                echo "Mac has $name version $appversion "
                if [[ $appversion != $appNewVersion ]]; then   
            	    echo "$name Needs to be updated"   
        			appsdisplay+=("Amazon $name")
        			## Installomator variable ##
        			install_apps+=("amazonworkspaces")
                    app_icon+=("$applist/$icon_most_path/AppIcon.icns")
        	    else
        	        echo "Amazon $name is on the latest version $appNewVersion"
        	    fi
    	else
        echo "--No Amazon $name--"
    fi
     ##### Brave Browser #####
    name="Brave Browser"
    applist="/Applications/$name.app"
    echo "
        *** Checking for $name ***
        App File Path: $applist"
    if [ -d "$applist" ]; then
        versionKey="CFBundleVersion"
        echo "--$name Exists--"
        echo "Checking latest Version"
        if [[ $(arch) != "i386" ]]; then
        printlog "Architecture: arm64 (not i386)"
        downloadURL=$(curl -fsIL https://laptop-updates.brave.com/latest/osxarm64/release | grep -i "^location" | sed -E 's/.*(https.*\.dmg).*/\1/g')
        appNewVersion="$(curl -fsL "https://updates.bravesoftware.com/sparkle/Brave-Browser/stable-arm64/appcast.xml" | xpath '//rss/channel/item[last()]/enclosure/@sparkle:version' 2>/dev/null  | cut -d '"' -f 2)"
    else
        printlog "Architecture: i386"
        downloadURL=$(curl -fsIL https://laptop-updates.brave.com/latest/osx/release | grep -i "^location" | sed -E 's/.*(https.*\.dmg).*/\1/g')
        appNewVersion="$(curl -fsL "https://updates.bravesoftware.com/sparkle/Brave-Browser/stable/appcast.xml" | xpath '//rss/channel/item[last()]/enclosure/@sparkle:version' 2>/dev/null  | cut -d '"' -f 2)"
    fi
        echo "$name Latest Version: $appNewVersion"
            ## Getting Current Version ##
                getAppVersion
                echo "Mac has $name version $appversion "
                if [[ $appversion != $appNewVersion ]]; then   
            	    echo "$name Needs to be updated"   
        			appsdisplay+=("$name")
        			## Installomator variable ##
        			install_apps+=("brave")
                    app_icon+=("$applist")
        	    else
        	        echo "$name is on the latest version $appNewVersion"
        	    fi
                versionKey="CFBundleShortVersionString"
    	else
        echo "--No $name--"
    fi

    ##### Google Chrome #####
    name="Google Chrome"
    applist="/Applications/$name.app"
    echo "
        *** Checking for $name ***
        App File Path: $applist"
    if [ -d "$applist" ]; then
        echo "--$name Exists--"
        echo "Checking latest Version"
        appNewVersion=$(curl -s https://omahaproxy.appspot.com/history | awk -F',' '/mac_arm64,stable/{print $3; exit}')
        echo "$name Latest Version: $appNewVersion"
            ## Getting Current Version ##
                getAppVersion
                echo "Mac has $name version $appversion "
                if [[ $appversion != $appNewVersion ]]; then   
            	    echo "$name Needs to be updated"   
        			appsdisplay+=("$name")
        			## Installomator variable ##
        			install_apps+=("googlechrome")
                    app_icon+=("$applist/$icon_most_path/app.icns")
        	    else
        	        echo "$name is on the latest version $appNewVersion"
        	    fi
    	else
        echo "--No $name--"
    fi

    ##### Sublime Text #####
    name="Sublime Text"
    applist="/Applications/$name.app"
    echo "
        *** Checking for $name ***
        App File Path: $applist"
    if [ -d "$applist" ]; then
        echo "--$name Exists--"
        echo "Checking latest Version"
        appNewVersion=$(curl -fs https://www.sublimetext.com/download | grep -i -A 4 "id.*changelog" | grep -io "Build [0-9]*")
        echo "$name Latest Version: $appNewVersion"
            ## Getting Current Version ##
                getAppVersion
                echo "Mac has $name version $appversion "
                if [[ $appversion != $appNewVersion ]]; then   
            	    echo "$name Needs to be updated"   
        			appsdisplay+=("$name")
        			## Installomator variable ##
        			install_apps+=("sublimetext")
                    app_icon+=("$applist/$icon_most_path/Sublime Text.icns")
        	    else
        	        echo "$name is on the latest version $appNewVersion"
        	    fi
    	else
        echo "--No $name--"
    fi

    ##### Viscosity #####
    name="Viscosity"
    applist="/Applications/$name.app"
    echo "
        *** Checking for $name ***
        App File Path: $applist"
    if [ -d "$applist" ]; then
        echo "--$name Exists--"
        echo "Checking latest Version"
        downloadURL="https://www.sparklabs.com/downloads/Viscosity.dmg"
        appNewVersion=$( curl -fsIL "${downloadURL}" | grep -i "^location" | awk '{print $2}' | sed -E 's/.*\/[a-zA-Z.\-]*%20([0-9.]*)\..*/\1/g' )
        echo "$name Latest Version: $appNewVersion"
            ## Getting Current Version ##
                getAppVersion
                echo "Mac has $name version $appversion "
                if [[ $appversion != $appNewVersion ]]; then   
            	    echo "$name Needs to be updated"   
        			appsdisplay+=("$name")
        			## Installomator variable ##
        			install_apps+=("viscosity")
                    app_icon+=("$applist/$icon_most_path/Viscosity.icns")
        	    else
        	        echo "$name is on the latest version $appNewVersion"
        	    fi
    	else
        echo "--No $name--"
    fi

    ##### Microsoft Auto Updater #####
    name="Microsoft AutoUpdate"
    applist="/Library/Application Support/Microsoft/MAU2.0/$name.app"
    echo "
        *** Checking for $name ***
        App File Path: $applist"
    if [ -d "$applist" ]; then
        echo "--$name Exists--"
        echo "Checking latest Version"
        downloadURL="https://go.microsoft.com/fwlink/?linkid=830196"
        appNewVersion=$(curl -fsIL "$downloadURL" | grep -i location: | grep -o "/Microsoft_.*pkg" | cut -d "_" -f 3 | cut -d "." -f 1-2)
        echo "$name Latest Version: $appNewVersion"
            ## Getting Current Version ##
                getAppVersion
                echo "Mac has $name version $appversion "
                if [[ $appversion != $appNewVersion ]]; then
                	if [[ "$appversion" > "$appNewVersion" ]]; then
                	  echo "$name is on a higher version then reported: $appversion"
                	  else
            	    	echo "$name Needs to be updated"   
        				appsdisplay+=("$name")
        				## Installomator variable ##
        				install_apps+=("microsoftautoupdate")
                        app_icon+=("$applist/$icon_most_path/AppIcon.icns")
        				fi
        	    else
        	        echo "$name is on the latest version $appNewVersion"
        	    fi
    	else
        echo "--No $name--"
    fi

    ##### Microsoft Edge #####
    name="Microsoft Edge"
    applist="/Applications/$name.app"
    echo "
        *** Checking for $name ***
        App File Path: $applist"
    if [ -d "$applist" ]; then
        echo "--$name Exists--"
        echo "Checking latest Version"
        downloadURL="https://go.microsoft.com/fwlink/?linkid=2093504"
        appNewVersion=$(curl -fsIL "$downloadURL" | grep -i location: | grep -o "/MicrosoftEdge.*pkg" | sed -E 's/.*\/[a-zA-Z]*-([0-9.]*)\..*/\1/g')
        echo "$name Latest Version: $appNewVersion"
            ## Getting Current Version ##
                getAppVersion
                echo "Mac has $name version $appversion "
                if [[ $appversion != $appNewVersion ]]; then   
            	    echo "$name Needs to be updated"   
        			appsdisplay+=("$name")
        			## Installomator variable ##
        			install_apps+=("microsoftedge")
                    app_icon+=("$applist")
        	    else
        	        echo "$name is on the latest version $appNewVersion"
        	    fi
    	else
        echo "--No $name--"
    fi

    ##### Microsoft Office Excel #####
    name="Microsoft Excel"
    applist="/Applications/$name.app"
    echo "
        *** Checking for $name ***
        App File Path: $applist"
    if [ -d "$applist" ]; then
        echo "--$name Exists--"
        echo "Checking latest Version"
        downloadURL="https://go.microsoft.com/fwlink/?linkid=525135"
        appNewVersion=$(curl -fsIL "$downloadURL" | grep -i location: | grep -o "/Microsoft_.*pkg" | cut -d "_" -f 3 | cut -d "." -f 1-2)
        echo "$name Latest Version: $appNewVersion"
            ## Getting Current Version ##
                getAppVersion
                echo "Mac has $name version $appversion "
                if [[ $appversion != $appNewVersion ]]; then
                	if [[ "$appversion" > "$appNewVersion" ]]; then
                	  echo "$name is on a higher version then reported: $appversion"
                	  else
            	    	echo "$name Needs to be updated"   
        				appsdisplay+=("$name")
        				## Installomator variable ##
        				install_apps+=("microsoftexcel")
                        app_icon+=("$applist/$icon_most_path/XCEL.icns")
        				fi
        	    else
        	        echo "$name is on the latest version $appNewVersion"
        	    fi
    	else
        echo "--No $name--"
    fi

    ##### Microsoft Office PowerPoint #####
    name="Microsoft PowerPoint"
    applist="/Applications/$name.app"
    echo "
        *** Checking for $name ***
        App File Path: $applist"
    if [ -d "$applist" ]; then
        echo "--$name Exists--"
        echo "Checking latest Version"
        downloadURL="https://go.microsoft.com/fwlink/?linkid=525136"
        appNewVersion=$(curl -fsIL "$downloadURL" | grep -i location: | grep -o "/Microsoft_.*pkg" | cut -d "_" -f 3 | cut -d "." -f 1-2)
        echo "$name Latest Version: $appNewVersion"
            ## Getting Current Version ##
                getAppVersion
                echo "Mac has $name version $appversion "
                if [[ $appversion != $appNewVersion ]]; then
                	if [[ "$appversion" > "$appNewVersion" ]]; then
                	  echo "$name is on a higher version then reported: $appversion"
                	  else
            	    	echo "$name Needs to be updated"   
        				appsdisplay+=("$name")
        				## Installomator variable ##
        				install_apps+=("microsoftpowerpoint")
                        app_icon+=("$applist/$icon_most_path/PPT3.icns")
        				fi
        	    else
        	        echo "$name is on the latest version $appNewVersion"
        	    fi
    	else
        echo "--No $name--"
    fi


    ##### Microsoft Office Word #####
   name="Microsoft Word"
    applist="/Applications/$name.app"
    echo "
        *** Checking for $name ***
        App File Path: $applist"
    if [ -d "$applist" ]; then
        echo "--$name Exists--"
        echo "Checking latest Version"
        downloadURL="https://go.microsoft.com/fwlink/?linkid=525134"
        appNewVersion=$(curl -fsIL "$downloadURL" | grep -i location: | grep -o "/Microsoft_.*pkg" | cut -d "_" -f 3 | cut -d "." -f 1-2)
        echo "$name Latest Version: $appNewVersion"
            ## Getting Current Version ##
                getAppVersion
                echo "Mac has $name version $appversion "
                if [[ $appversion != $appNewVersion ]]; then
                	if [[ "$appversion" > "$appNewVersion" ]]; then
                	  echo "$name is on a higher version then reported: $appversion"
                	  else
            	    	echo "$name Needs to be updated"   
        				appsdisplay+=("$name")
        				## Installomator variable ##
        				install_apps+=("microsoftword")
                        app_icon+=("$applist/$icon_most_path/MSWD.icns")
        				fi
        	    else
        	        echo "$name is on the latest version $appNewVersion"
        	    fi
    	else
        echo "--No $name--"
    fi

    ##### Microsoft Outlook #####
   name="Microsoft Outlook"
    applist="/Applications/$name.app"
    echo "
        *** Checking for $name ***
        App File Path: $applist"
    if [ -d "$applist" ]; then
        echo "--$name Exists--"
        echo "Checking latest Version"
        downloadURL="https://go.microsoft.com/fwlink/?linkid=525137"
        appNewVersion=$(curl -fsIL "$downloadURL" | grep -i location: | grep -o "/Microsoft_.*pkg" | cut -d "_" -f 3 | cut -d "." -f 1-2)
        echo "$name Latest Version: $appNewVersion"
            ## Getting Current Version ##
                getAppVersion
                echo "Mac has $name version $appversion "
                if [[ $appversion != $appNewVersion ]]; then
                	if [[ "$appversion" > "$appNewVersion" ]]; then
                	  echo "$name is on a higher version then reported: $appversion"
                	  else
            	    	echo "$name Needs to be updated"   
        				appsdisplay+=("$name")
        				## Installomator variable ##
        				install_apps+=("microsoftoutlook")
                        app_icon+=("$applist")
        				fi
        	    else
        	        echo "$name is on the latest version $appNewVersion"
        	    fi
    	else
        echo "--No $name--"
    fi

    ##### Microsoft Onenote #####
    name="Microsoft OneNote"
    applist="/Applications/$name.app"
    echo "
        *** Checking for $name ***
        App File Path: $applist"
    if [ -d "$applist" ]; then
        echo "--$name Exists--"
        echo "Checking latest Version"
        downloadURL="https://go.microsoft.com/fwlink/?linkid=820886"
        appNewVersion=$(curl -fsIL "$downloadURL" | grep -i location: | grep -o "/Microsoft_.*pkg" | cut -d "_" -f 3 | cut -d "." -f 1-2)
        echo "$name Latest Version: $appNewVersion"
            ## Getting Current Version ##
                getAppVersion
                echo "Mac has $name version $appversion "
                if [[ $appversion != $appNewVersion ]]; then
                	if [[ "$appversion" > "$appNewVersion" ]]; then
                	  echo "$name is on a higher version then reported: $appversion"
                	  else
            	    	echo "$name Needs to be updated"   
        				appsdisplay+=("$name")
        				## Installomator variable ##
        				install_apps+=("microsoftonenote")
                        app_icon+=("$applist/$icon_most_path/OneNote.icns")
        				fi
        	    else
        	        echo "$name is on the latest version $appNewVersion"
        	    fi
    	else
        echo "--No $name--"
    fi
    ##### Microsoft Teams #####

    name="Microsoft Teams"
    applist="/Applications/$name.app"
    echo "
        *** Checking for $name ***
        App File Path: $applist"
    if [ -d "$applist" ]; then
    versionKey="CFBundleGetInfoString"
        echo "--$name Exists--"
        echo "Checking latest Version"
        downloadURL="https://go.microsoft.com/fwlink/?linkid=869428"
        packageID="com.microsoft.teams"
        appNewVersion=$(curl -fsIL "${downloadURL}" | grep -i "^location" | tail -1 | cut -d "/" -f5)
        echo "$name Latest Version: $appNewVersion"
            ## Getting Current Version ##
            
                getAppVersion
                echo "Mac has $name version $appversion "
                if [[ $appversion != $appNewVersion ]]; then
                	if [[ "$appversion" > "$appNewVersion" ]]; then
                	  echo "$name is on a higher version then reported: $appversion"
                	  else
            	    	echo "$name Needs to be updated"   
        				appsdisplay+=("$name")
        				## Installomator variable ##
        				install_apps+=("microsoftteams")
                        app_icon+=("$applist/$icon_most_path/icon.icns")
        				fi
        	    else
        	        echo "$name is on the latest version $appNewVersion"
        	    fi
        versionKey="CFBundleShortVersionString"
    	else
        echo "--No $name--"
    fi

    ##### Microsoft VS Code #####

    name="Visual Studio Code"
    applist="/Applications/$name.app"
    echo "
        *** Checking for $name ***
        App File Path: $applist"
    if [ -d "$applist" ]; then
        echo "--$name Exists--"
        echo "Checking latest Version"
        downloadURL="https://go.microsoft.com/fwlink/?LinkID=2156837"
        appNewVersion=$(curl -fsL "https://code.visualstudio.com/Updates" | grep "/darwin" | grep -oiE ".com/([^>]+)([^<]+)/darwin" | cut -d "/" -f 2 | sed $'s/[^[:print:]	]//g' | head -1 )
        echo "$name Latest Version: $appNewVersion"
            ## Getting Current Version ##
                getAppVersion
                echo "Mac has $name version $appversion "
                if [[ $appversion != $appNewVersion ]]; then
                	if [[ "$appversion" > "$appNewVersion" ]]; then
                	  echo "$name is on a higher version then reported: $appversion"
                	  else
            	    	echo "$name Needs to be updated"   
        				appsdisplay+=("$name")
        				## Installomator variable ##
        				install_apps+=("visualstudiocode")
                        app_icon+=("$applist/$icon_most_path/Code.icns")
        				fi
        	    else
        	        echo "$name is on the latest version $appNewVersion"
        	    fi
    	else
        echo "--No $name--"
    fi

    ##### Mozilla FireFox #####
    name="Firefox"
    applist="/Applications/$name.app"
    echo "
        *** Checking for $name ***
        App File Path: $applist"
    if [ -d "$applist" ]; then
        echo "--Firefox Exists--"
        echo "Checking latest Version"
        firefoxVersions=$(curl -fs "https://product-details.mozilla.org/1.0/firefox_versions.json")
        appNewVersion=$(getJSONValue "$firefoxVersions" "LATEST_FIREFOX_VERSION")
        echo "$name Latest Version: $appNewVersion"
            ## Getting Current Version ##
                getAppVersion
                echo "Mac has $name version $appversion "
                if [[ $appversion != $appNewVersion ]]; then   
            	    echo "$name Needs to be updated"   
        			appsdisplay+=("$name")
        			## Installomator variable ##
        			install_apps+=("firefox")
                    app_icon+=("$applist/$icon_most_path/firefox.icns")
        	    else
        	        echo "$name is on the latest version $appNewVersion"
        	    fi
    	else
        echo "--No $name--"
    fi

    ##### Postman #####
    name="Postman"
    applist="/Applications/$name.app"
    echo "
        *** Checking for $name ***
        App File Path: $applist"
    if [ -d "$applist" ]; then
        echo "--$name Exists--"
        echo "Checking latest Version"
            if [[ $(arch) == "arm64" ]]; then
                downloadURL="https://dl.pstmn.io/download/latest/osx_arm64"
                appNewVersion=$(curl -fsL --head "${downloadURL}" | grep "content-disposition:" | sed 's/^.*[^0-9]\([0-9]*\.[0-9]*\.[0-9]*\).*$/\1/')
                elif [[ $(arch) == "i386" ]]; then
                    downloadURL="https://dl.pstmn.io/download/latest/osx_64"
                    appNewVersion=$(curl -fsL --head "${downloadURL}" | grep "content-disposition:" | sed 's/^.*[^0-9]\([0-9]*\.[0-9]*\.[0-9]*\).*$/\1/')
            fi
        echo "$name Latest Version: $appNewVersion"
            ## Getting Current Version ##
                getAppVersion
                echo "Mac has $name version $appversion "
                if [[ $appversion != $appNewVersion ]]; then   
            	    echo "$name Needs to be updated"   
        			appsdisplay+=("$name")
        			## Installomator variable ##
        			install_apps+=("postman")
                    app_icon+=("$applist")
        	    else
        	        echo "$name is on the latest version $appNewVersion"
        	    fi
    	else
        echo "--No $name--"
    fi

    ##### RingCentral Softphone #####
    name="RingCentral for Mac"
    applist="/Applications/$name.app"
    echo "
        *** Checking for $name ***
        App File Path: $applist"
    if [ -d "$applist" ]; then
        echo "--$name Exists--"
        echo "Checking latest Version"
        downloadURL="https://downloads.ringcentral.com/sp/RingCentralForMac"
        appNewVersion=$(curl -fsIL "$downloadURL" | grep -i location: | grep -o "/RingCentral-Phone.*dmg" | cut -d "-" -f 3 | cut -d "." -f 1-3)
        echo "$name Latest Version: $appNewVersion"
            ## Getting Current Version ##
                getAppVersion
                echo "Mac has $name version $appversion "
                if [[ $appversion != $appNewVersion ]]; then   
            	    echo "$name Needs to be updated"   
        			appsdisplay+=("$name")
        			## Installomator variable ##
        			install_apps+=("ringcentralphone")
                    app_icon+=("$applist/$icon_most_path/app.icns")
        	    else
        	        echo "$name is on the latest version $appNewVersion"
        	    fi
    	else
        echo "--No $name--"
    fi

    ##### Royal TSX #####
    name="Royal TSX"
    applist="/Applications/$name.app"
    echo "
        *** Checking for $name ***
        App File Path: $applist"
    if [ -d "$applist" ]; then
        echo "--$name Exists--"
        echo "Checking latest Version"
        appNewVersion=$(curl -fs https://royaltsx-v6.royalapps.com/updates_stable | xpath '//rss/channel/item[1]/description/@sparkle:shortVersionString'  2>/dev/null | cut -d '"' -f 2)
        echo "$name Latest Version: $appNewVersion"
            ## Getting Current Version ##
                getAppVersion
                echo "Mac has $name version $appversion "
                if [[ $appversion != $appNewVersion ]]; then   
            	    echo "$name Needs to be updated"   
        			appsdisplay+=("$name")
        			## Installomator variable ##
        			install_apps+=("royaltsx")
                    app_icon+=("$applist")
        	    else
        	        echo "$name is on the latest version $appNewVersion"
        	    fi
    	else
        echo "--No $name--"
    fi

    ##### Slack #####
    name="Slack"
    applist="/Applications/$name.app"
    echo "
        *** Checking for $name ***
        App File Path: $applist"
    if [ -d "$applist" ]; then
        echo "--$name Exists--"
        echo "Checking latest Version"
        downloadURL="https://slack.com/ssb/download-osx-universal"
    	appNewVersion=$( curl -fsIL "${downloadURL}" | grep -i "^location" | cut -d "/" -f6 )
        echo "$name Latest Version: $appNewVersion"
            ## Getting Current Version ##
                getAppVersion
                echo "Mac has $name version $appversion "
                if [[ $appversion != $appNewVersion ]]; then   
            	    echo "$name Needs to be updated"   
        			appsdisplay+=("$name")
        			## Installomator variable ##
        			install_apps+=("slack")
                    app_icon+=("$applist/$icon_most_path/electron.icns")
        	    else
        	        echo "$name is on the latest version $appNewVersion"
        	    fi
    	else
        echo "--No $name--"
    fi

    ##### Wacom Desktop Center #####
    name="Wacom Desktop Center"
    applist="/Applications/$name.app"
    echo "
        *** Checking for $name ***
        App File Path: $applist"
    if [ -d "$applist" ]; then
        echo "--$name Exists--"
        echo "Checking latest Version"
    	appNewVersion="$(curl -fs https://www.wacom.com/en-us/support/product-support/drivers | grep mac/professional/releasenotes | head -1 | tr '"' "\n" | grep -e "Driver [0-9][-0-9.]*" | sed -E 's/Driver ([-0-9.]*).*/\1/g')"
        echo "$name Latest Version: $appNewVersion"
            ## Getting Current Version ##
                getAppVersion
                echo "Mac has $name version $appversion "
                if [[ $appversion != $appNewVersion ]]; then   
            	    echo "$name Needs to be updated"   
        			appsdisplay+=("$name")
        			## Installomator variable ##
        			install_apps+=("wacomdrivers")
                    app_icon+=("$applist")
        	    else
        	        echo "$name is on the latest version $appNewVersion"
        	    fi
    	else
        echo "--No $name--"
    fi

    ##### VLC #####
    name="VLC"
    applist="/Applications/$name.app"
    echo "
        *** Checking for $name ***
        App File Path: $applist"
    if [ -d "$applist" ]; then
        echo "--$name Exists--"
        echo "Checking latest Version"
        if [[ $(arch) == "arm64" ]]; then
        downloadURL=$(curl -fs http://update.videolan.org/vlc/sparkle/vlc-arm64.xml | xpath '//rss/channel/item[last()]/enclosure/@url' 2>/dev/null | cut -d '"' -f 2 )
        #appNewVersion=$(curl -fs http://update.videolan.org/vlc/sparkle/vlc-arm64.xml | xpath '//rss/channel/item[last()]/enclosure/@sparkle:version' 2>/dev/null | cut -d '"' -f 2 )
    elif [[ $(arch) == "i386" ]]; then
        downloadURL=$(curl -fs http://update.videolan.org/vlc/sparkle/vlc-intel64.xml | xpath '//rss/channel/item[last()]/enclosure/@url' 2>/dev/null | cut -d '"' -f 2 )
        #appNewVersion=$(curl -fs http://update.videolan.org/vlc/sparkle/vlc-intel64.xml | xpath '//rss/channel/item[last()]/enclosure/@sparkle:version' 2>/dev/null | cut -d '"' -f 2 )
    fi
    	appNewVersion=$(echo ${downloadURL} | sed -E 's/.*\/vlc-([0-9.]*).*\.dmg/\1/' )
        echo "$name Latest Version: $appNewVersion"
            ## Getting Current Version ##
                getAppVersion
                echo "Mac has $name version $appversion "
                if [[ $appversion != $appNewVersion ]]; then   
            	    echo "$name Needs to be updated"   
        			appsdisplay+=("$name")
        			## Installomator variable ##
        			install_apps+=("vlc")
                    app_icon+=("$applist/$icon_most_path/VLC.icns")
        	    else
        	        echo "$name is on the latest version $appNewVersion"
        	    fi
    	else
        echo "--No $name--"
    fi

    # ##### VMWare Horizon Client #####
    # name="VMware Horizon Client"
    # applist="/Applications/$name.app"
    # echo "
    #     *** Checking for $name ***
    #     App File Path: $applist"
    # if [ -d "$applist" ]; then
    #     echo "--$name Exists--"
    #     echo "Checking latest Version"
    #     downloadGroup=$(curl -fsL "https://my.vmware.com/channel/public/api/v1.0/products/getRelatedDLGList?locale=en_US&category=desktop_end_user_computing&product=vmware_horizon_clients&version=horizon_8&dlgType=PRODUCT_BINARY" | grep -o '[^"]*_MAC_[^"]*')
    # fileName=$(curl -fsL "https://my.vmware.com/channel/public/api/v1.0/dlg/details?locale=en_US&category=desktop_end_user_computing&product=vmware_horizon_clients&dlgType=PRODUCT_BINARY&downloadGroup=${downloadGroup}" | grep -o '"fileName":"[^"]*"' | cut -d: -f2 | sed 's/"//g')
    # downloadURL="https://download3.vmware.com/software/$downloadGroup/${fileName}"
    # appNewVersion=$(curl -fsL "https://my.vmware.com/channel/public/api/v1.0/dlg/details?locale=en_US&downloadGroup=${downloadGroup}" | grep -o '[^"]*\.dmg[^"]*' | sed 's/.*-\(.*\)-.*/\1/')

    #     echo "$name Latest Version: $appNewVersion"
    #         ## Getting Current Version ##
    #             getAppVersion
    #             echo "Mac has $name version $appversion "
    #             if [[ $appversion != $appNewVersion ]]; then   
    #         	    echo "$name Needs to be updated"   
    #     			appsdisplay+=("$name")
    #     			## Installomator variable ##
    #     			install_apps+=("vmwarehorizonclient")
    #                 app_icon+=("$applist/$icon_most_path/view.icns")
    #     	    else
    #     	        echo "$name is on the latest version $appNewVersion"
    #     	    fi
    #     else
    #     echo "--No $name--"
    # fi

    ##### TextExpander #####
    name="TextExpander"
    applist="/Applications/$name.app"
    echo "
        *** Checking for $name ***
        App File Path: $applist"
    if [ -d "$applist" ]; then
        echo "--$name Exists--"
        echo "Checking latest Version"
        downloadURL="$(curl -s -L -w "%{url_effective}\n" -o /dev/null "https://rest-prod.tenet.textexpander.com/download?platform=macos")"
    	appNewVersion=$( echo "$downloadURL" | sed -n 's/.*TextExpander_\([0-9.]*\).dmg/\1/p' | grep -oE '[0-9.]+' )
        echo "$name Latest Version: $appNewVersion"
            ## Getting Current Version ##
                getAppVersion
                echo "Mac has $name version $appversion "
                if [[ $appversion != $appNewVersion ]]; then   
            	    echo "$name Needs to be updated"   
        			appsdisplay+=("$name")
        			## Installomator variable ##
        			install_apps+=("TextExpander")
                    app_icon+=("$applist/$icon_most_path/SMTEIcon.icns")
        	    else
        	        echo "$name is on the latest version $appNewVersion"
        	    fi
        else
        echo "--No $name--"
    fi

    #### talkdeskcallbar #####
    name="Callbar"
    applist="/Applications/$name.app"
    echo "
        *** Checking for $name ***
        App File Path: $applist"
    if [ -d "$applist" ]; then
        echo "--$name Exists--"
        echo "Checking latest Version"
        talkdeskcallbarVersions=$(curl -fsL "https://downloadcallbar.talkdesk.com/release_metadata.json")
        appNewVersion=$(getJSONValue "$talkdeskcallbarVersions" "version")
        downloadURL=https://downloadcallbar.talkdesk.com/Callbar-${appNewVersion}.dmg
        echo "$name Latest Version: $appNewVersion"
            ## Getting Current Version ##
                getAppVersion
                echo "Mac has $name version $appversion "
                if [[ $appversion != $appNewVersion ]]; then   
            	    echo "$name Needs to be updated"   
        			appsdisplay+=("$name")
        			## Installomator variable ##
        			install_apps+=("talkdeskcallbar")
                    app_icon+=("$applist/$icon_most_path/Callbar.icns")
        	    else
        	        echo "$name is on the latest version $appNewVersion"
        	    fi
        else
        echo "--No $name--"
    fi

    ##### TeamViewer #####
    name="TeamViewer"
    applist="/Applications/$name.app"
    echo "
        *** Checking for $name ***
        App File Path: $applist"
    if [ -d "$applist" ]; then
        echo "--$name Exists--"
        echo "Checking latest Version"
        appNewVersion=$(curl -fs "https://www.teamviewer.com/en/download/macos/" | grep "Current version" | awk -F': ' '{ print $2 }' | sed 's/<[^>]*>//g')
        echo "$name Latest Version: $appNewVersion"
            ## Getting Current Version ##
                getAppVersion
                echo "Mac has $name version $appversion "
                if [[ $appversion != $appNewVersion ]]; then   
            	    echo "$name Needs to be updated"   
        			appsdisplay+=("$name")
        			## Installomator variable ##
        			install_apps+=("teamviewer")
                    app_icon+=("$applist")
        	    else
        	        echo "$name is on the latest version $appNewVersion"
        	    fi
    	else
        echo "--No $name--"
    fi

    ##### TeamViewerQS #####
    name="TeamViewerQS"
    applist="/Applications/$name.app"
    echo "
        *** Checking for $name ***
        App File Path: $applist"
    if [ -d "$applist" ]; then
        echo "--$name Exists--"
        echo "Checking latest Version"
        appNewVersion=$(curl -fs "https://www.teamviewer.com/en/download/macos/" | grep "Current version" | awk -F': ' '{ print $2 }' | sed 's/<[^>]*>//g')
        echo "$name Latest Version: $appNewVersion"
            ## Getting Current Version ##
                getAppVersion
                echo "Mac has $name version $appversion "
                if [[ $appversion != $appNewVersion ]]; then   
            	    echo "$name Needs to be updated"   
        			appsdisplay+=("$name")
        			## Installomator variable ##
        			install_apps+=("teamviewerqs")
                    app_icon+=("$applist")
        	    else
        	        echo "$name is on the latest version $appNewVersion"
        	    fi
    	else
        echo "--No $name--"
    fi
    
    ##### talkdeskcxcloud #####
    name="Talkdesk"
    applist="/Applications/$name.app"
    echo "
        *** Checking for $name ***
        App File Path: $applist"
    if [ -d "$applist" ]; then
        echo "--$name Exists--"
        echo "Checking latest Version"
        talkdeskcxcloudVersions=$(curl -fs "https://td-infra-prd-us-east-1-s3-atlaselectron.s3.amazonaws.com/talkdesk-latest-metadata.json")
        appNewVersion=$(getJSONValue "$talkdeskcxcloudVersions" "[0].version")
        downloadURL="https://td-infra-prd-us-east-1-s3-atlaselectron.s3.amazonaws.com/talkdesk-${appNewVersion}.dmg"
        echo "$name Latest Version: $appNewVersion"
            ## Getting Current Version ##
                getAppVersion
                echo "Mac has $name version $appversion "
                if [[ $appversion != $appNewVersion ]]; then   
            	    echo "$name Needs to be updated"   
        			appsdisplay+=("$name")
        			## Installomator variable ##
        			install_apps+=("talkdeskcxcloud")
                    app_icon+=("$applist/$icon_most_path/icon.icns")
        	    else
        	        echo "$name is on the latest version $appNewVersion"
        	    fi
        else
        echo "--No $name--"
    fi

     ##### Wireshark #####
    name="Wireshark"
    applist="/Applications/$name.app"
    echo "
        *** Checking for $name ***
        App File Path: $applist"
    if [ -d "$applist" ]; then
        echo "--$name Exists--"
        echo "Checking latest Version"
        appNewVersion=$(curl -fs "https://www.wireshark.org/update/0/Wireshark/4.0.0/macOS/x86-64/en-US/stable.xml" | xmllint --xpath '//item/title/text()' - | awk '{print $2}')
        echo "$name Latest Version: $appNewVersion"
            ## Getting Current Version ##
                getAppVersion
                echo "Mac has $name version $appversion "
                if [[ $appversion != $appNewVersion ]]; then   
            	    echo "$name Needs to be updated"   
        			appsdisplay+=("$name")
        			## Installomator variable ##
        			install_apps+=("wireshark")
                    app_icon+=("$applist/$icon_most_path/Wireshark.icns")
        	    else
        	        echo "$name is on the latest version $appNewVersion"
        	    fi
        else
        echo "--No $name--"
    fi
    
    #### zoom.us #####
    name="zoom.us"
    applist="/Applications/$name.app"
    versionKey="CFBundleVersion"
    echo "
       *** Checking for $name ***
       App File Path: $applist"
    if [ -d "$applist" ]; then
        echo "--$name Exists--"
        echo "Checking latest Version"
        downloadURL="https://zoom.us/client/latest/ZoomInstallerIT.pkg"
    	appNewVersion="$(curl -fsIL ${downloadURL} | grep -i ^location | cut -d "/" -f5)"
        echo "$name Latest Version: $appNewVersion"
            ## Getting Current Version ##
                getAppVersion
                echo "Mac has $name version $appversion "
                if [[ $appversion != $appNewVersion ]]; then   
            	    echo "$name Needs to be updated"
                    # ## Adding control version for Zoom
                    # if [[ ${appNewVersion} > ${ZoomControlappVersion} ]]; then
                    # echo "$name is on the latest version we are supporting"
                    # else
        			appsdisplay+=("$name")
        			## Installomator variable ##
        			install_apps+=("zoom")
                    app_icon+=("$applist/$icon_most_path/ZPLogo.icns")
                    #fi
        	    else
        	        echo "$name is on the latest version $appNewVersion"
        	    fi
    	versionKey="CFBundleShortVersionString"
        else
        echo "--No $name--"
    fi
}

#Policy_App_List(){
        ##### Adobe DC #####
    # if [ -d '/Applications/Adobe Acrobat DC/Adobe Acrobat.app' ]; then
    #     echo "--Adobe Acrobat DC Exists--"
    #     appsdisplay+=$(echo "$appsdisplay
    #     Adobe Acrobat DC")
    #     #$AdobeRUM --action=instal --productVersions=APRO 
    #     ## Installomator variable ##
    #     CMD_Run_apps=$(echo "$CMD_Run_apps
    #     $AdobeRUM --action=instal --productVersions=APRO")
    # else
    #     echo "--No Adobe Acrobat DC--"
    # fi
    #         ##### Carbon Black #####
    # if [ -d! '/Applications/Adobe Acrobat DC/Adobe Acrobat.app' ]; then
    #     echo "--Adobe Acrobat DC Exists--"
    #     #appsdisplay+=$(echo "$appsdisplay
    #     #Adobe Acrobat DC")
    #     #$AdobeRUM --action=instal --productVersions=APRO 
    #     ## Installomator variable ##
    #     CMD_Run_apps=$(echo "$CMD_Run_apps
    #     $JAMF_BIN --action=instal --productVersions=APRO")
    # else
    #     echo "--No Adobe Acrobat DC--"
    # fi


#}

Deferal_Count_Logic() {
    if [ ! -f "$Deferals_Count_PLIST" ]; then
    # Create a new plist file with initial value
    echo "<?xml version=\"1.0\" encoding=\"UTF-8\"?>
    <!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">
    <plist version=\"1.0\">
    <dict>
        <key>deferralCount</key>
        <integer>0</integer>
    </dict>
    </plist>" > "$plist_path"
    fi
    # Read the current deferral count from the plist
    deferral_count=$(defaults read "$Deferals_Count_PLIST" deferralCount)

    # Calculate the remaining deferrals
    deferrals_left=$((3 - deferral_count))

}

PromptUser() {
    if [ "$deferral_count" -ge 3 ]; then
    echo "User used to many Deferals will run force"
    To_Update=$(
        "${dialogBinary}" \
        --quitkey x \
        --title "App Update Required" \
        --ontop \
        --moveable \
        --jsonfile "${json_tmp_file}" \
        --icon "${LOGO}" \
        --button1text "Update" \
        --timer 1800 \
        --messagefont "size=18" \
        --height 50% \
        --message "The following application(s) installed requires an update: \n\n - To update, please save all of your work and close the listed apps, then select Update. \n\n - You have **no more** deferrals left."
        )
    else
    To_Update=$( "${dialogBinary}" \
        --quitkey x \
        --title "App Update Required" \
        --ontop \
        --moveable \
        --jsonfile "${json_tmp_file}" \
        --icon "${LOGO}" \
        --timer 1800 \
        --button1text "Update" \
        --button2text "Defer" \
        --messagefont "size=18" \
        --height 50% \
        --message "The following application(s) installed requires an update: \n\n - To update, please save all of your work and close the listed apps, then select Update. \n\n - You have **$deferrals_left deferral(s)** left before you will be forced to update."
        )
    echo "$?"
    fi
}

Checking_Tools() {
    echo "
    **************************
    Checking for all the tools
    **************************
    "
        # check we are running as root
    if [[ $DEBUG -eq 0 && $(id -u) -ne 0 ]]; then
        echo "This script should be run as root"
        exit 97
    fi

    ## Check if Installomator exit
    if [ -f $InstallomatorApp ]; then
    echo "
    *************************
    Installomator found conitinue
    *************************
    "
    else 
    echo "Installomator not found will install from Jamf"
    $JAMF_BINARY policy -event Installomator
    echo "Checking if Installamator is installed correctly"
        if [ -f $InstallomatorApp ]; then
            echo "
            *************************
            Installomator found conitinue
            *************************
            "
        else 
            echo "ERROR: Installomator is not install"
            exit 1
        fi
    fi

        ## Verify Working directory exists
    if ! [ -d "${WorkingDir}" ]; then
        echo "Weekly Update directory doesn't exist yet. Creating Resources directory..."
        mkdir -p "${WorkingDir}"
    fi
    ## Verify Resources directory exists
    if ! [ -d "${WorkingDir}/resources" ]; then
        echo "JAMF Resources directory doesn't exist yet. Creating Resources directory..."
        mkdir -p "${WorkingDir}/resources"
    fi
    ## Verify Logs directory exists
    if ! [ -d "/usr/local/${WorkingDir}/logs" ]; then
        echo "JAMF Logs directory doesn't exist yet. Creating Logs directory..."
        mkdir -p "${WorkingDir}/logs"
    fi
    ## Silent Installs will be here
    ## Checking for update of installomator
    echo "
            *************************************
            Checking updates for Installomator
            *************************************
            "
    $InstallomatorApp installomator NOTIFY=silent
    ## Checking for Python
    # echo "
    #         *************************************
    #         Checking updates for Python
    #         *************************************
    #         "
    # $InstallomatorApp macadminspython NOTIFY=silent

    ## Checking for update of Swift Dialog
    echo "
            *************************************
            Checking updates for Swift Dialog
            *************************************
            "
    $InstallomatorApp dialog NOTIFY=silent

}

Deferal_Logic() {
    echo "
    ********************************
    User Defer, using deferal logic
    ********************************
    "
    ## Get User input on time ##
    timechoose=$( "${dialogBinary}" \
        --quitkey x \
        --title "Choose A Time" \
        --message "Choose when you would like to be prompted again" \
        --selecttitle "Required item",required \
        --selectvalues "30 Minutes, 1 Hour, 4 Hours, 1 day(24 Hours)" \
        --selectdefault "30 Minutes" \
        --timer 1800 \
        --button1text "Defer" \
        --icon "${LOGO}" \
        --ontop \
        --small \
        | grep "SelectedIndex" | awk -F ": " '{print $NF}'
        )
    ## Time choose will give the correct time
    if [ $timechoose = 0 ]; then
    echo "Client choose 30 Mins"
    ## convert to secs
    time="1800"
    echo "time will be $time secs"
    elif [ $timechoose = 1 ]; then
    echo "Client choose 1 hour"
    ## convert to secs
    time="3600"
    echo "time will be $time secs"
    elif [ $timechoose = 2 ]; then
    echo "Client choose 4 hour"
    ## convert to secs
    time="14400"
    echo "time will be $time secs"
    elif [ $timechoose = 3 ]; then
    echo "Client choose 1 Day"
    ## convert to secs
    ## For Testing Added 1 day to 20 Sec
    #time="20"
    time="86400"
    echo "time will be $time secs"
    else
    echo "error Client either exited or closed will put default 30 mins"
     time="1800"
    echo "time will be $time secs"
    fi
        if [ -f $Deferal_PLIST ]; then
            echo "Defer Plist exist will unload and remove it"
            /bin/launchctl bootout system $Deferal_PLIST
            /bin/rm -rf $Deferal_PLIST  
        fi
        sleep 3
    ## Creating Launch Daemon PLIST ##
    echo "<?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0">
    <dict>
        <key>Label</key>
        <string>com.viking.weeklyupdatedeferal</string>
        <key>ProgramArguments</key>
        <array>
            <string>$JAMF_BINARY</string>
            <string>policy</string>
            <string>-event</string>
            <string>$Deferal_Policy</string>
        </array>
        <key>StandardErrorPath</key>
        <string>/var/log/WeeklyUpdate_Defer_err.log</string>
        <key>StandardOutPath</key>
        <string>/var/log/WeeklyUpdate_Defer.log</string>
        <key>StartInterval</key>
        <integer>$time</integer>
    </dict>
    </plist>" > "$Deferal_PLIST"
    
    ## load plist
    /bin/launchctl bootstrap system $Deferal_PLIST
}

############################################
# Logic
############################################
## Checking if all the Tools are in place to start
Checking_Tools

echo "
    ************************************************
    Checking Installed Apps if requires updates
    ************************************************
    "
Install_App_List

    # Define the JSON variable
        json_var='{
        "listitem": [
        '

        # Loop through the install_apps array
        for ((i=1; i <= ${#install_apps[@]}; i++)); do
        # Construct each JSON item
        json_var+='    {"title": "'${appsdisplay[$i]}'", "icon": "'${app_icon[$i]}'"}'
        # Add a comma if it's not the last item
        if (( i < ${#install_apps[@]} )); then
            json_var+=','
        fi
        
        json_var+=$'\n'
        done
        # Close the JSON variable
        json_var+=("  ]")
        json_var+=("\n }")
        # Print the JSON variable
        chmod 777 $json_tmp_file
        echo "$json_var" >> "$json_tmp_file"

Notifer_DisplayApps=$(
    for displayapps in "${appsdisplay[@]}";
    do
    echo -e "**$displayapps**\n"
    done
    )

list=$(for apps in $(echo $Notifer_DisplayApps)
    do
    echo "$apps"
    done | wc -l | sed -e 's/^[ \t]*//')
    echo "this has $list updates"
        if [ ${list} = '0' ]; then
        echo "No Updates needed will exit"
        exit 0
        else 
        echo "Found $list Updates needed will continue \n ***********************************************
        "
        fi

## Prompt User ##

## if 0 update if 2 they canceled

Deferal_Count_Logic

Choice=$(PromptUser)

    if [ "$deferral_count" -ge 3 ]; then
    echo "User used to many Deferals will run force"
    Choice=0
    fi

if [ $Choice = "0" ]; then
    echo "User wants to update"
    length=${#install_apps[@]}
    progressincreament=$(( 100 / $length ))
    percentage=0
    echo "precentage: $progressincreament%"
    "${dialogBinary}" \
        --ontop \
        --moveable \
        --width 40% \
        --height 40% \
        --position "right" \
        --jsonfile "${json_tmp_file}" \
        --title "App Update" \
        --message "The following app(s) are Updating, please wait...:" \
        --icon "$LOGO" \
        --progress 100 \
        --button1text "Continue" \
        --button1disabled &

    dialog_command "progresstext: Updating..."
        for ((i=1; i<=$length; i++)); do
            icon_file=${app_icon[$i]}
            Installomator=${install_apps[$i]}
            appMessage=${appsdisplay[$i]}
            echo "
            ***Updating: $Installomator***
            "
            dialog_command "listitem: "$appMessage": progress, statustext: "Updating..."
            sleep 5
            Installomator=$(echo $Installomator | sed 's/ //g')
            
        # give everything a moment to catch up
        sleep 0.1
            dialog_command "progresstext: Updating "$appMessage"..."
            dialog_command "listitem: "$appMessage": progress, statustext: "Updating..."
            sleep 0.1
            ## Customize Installomator or other ways to install instead
            if [[ "$Installomator" == "microsoftteams" ]]; then
                    $InstallomatorApp $Installomator INSTALL="force" DIALOG_CMD_FILE=$dialog_command_file BLOCKING_PROCESS_ACTION=tell_user_then_kill PROMPT_TIMEOUT=300 LOGO="$LOGO"
            elif [[ "$Installomator" == "microsoftoutlook" ]]; then
                    $InstallomatorApp $Installomator INSTALL="force" DIALOG_CMD_FILE=$dialog_command_file BLOCKING_PROCESS_ACTION=tell_user_then_kill PROMPT_TIMEOUT=300 LOGO="$LOGO"
            elif [[ "$Installomator" == "microsoftedge" ]]; then
                    $InstallomatorApp $Installomator INSTALL="force" DIALOG_CMD_FILE=$dialog_command_file BLOCKING_PROCESS_ACTION=tell_user_then_kill PROMPT_TIMEOUT=300 LOGO="$LOGO"
            elif [[ "$Installomator" == "microsoftonenote" ]]; then
                    $InstallomatorApp $Installomator INSTALL="force" DIALOG_CMD_FILE=$dialog_command_file BLOCKING_PROCESS_ACTION=tell_user_then_kill PROMPT_TIMEOUT=300 LOGO="$LOGO"
            else
                $InstallomatorApp $Installomator DIALOG_CMD_FILE=$dialog_command_file BLOCKING_PROCESS_ACTION=tell_user_then_kill PROMPT_TIMEOUT=300 LOGO="$LOGO"
            fi
            percentage=$(($percentage + $progressincreament))
            echo "*******************
            Finished Updating $Installomator
            *******************
            "
            dialog_command "progress: increment $progressincreament"
            dialog_command "progresstext: $percentage% Completed"
            dialog_command "listitem: "$appMessage": success"

            sleep 2
        done
        dialog_command "button1text: Done"
        dialog_command "button1: enable"
        sleep 2
        dialog_command "quit:"
        killall "Dialog"
        /bin/rm -rf "$dialog_command_file"
        /bin/rm -rf "$json_tmp_file"
        ## Writing Plist to remove Defer ##
        /usr/bin/defaults write "${WorkingDir}/com.viking.deferWeeklyupdates" deferWeeklyupdates -bool false;
		sendToLog "Performing a JAMF Inventory Update and exiting..."
        ## Remove Plist if exist ##
        if [ -f $Deferal_PLIST ]; then
            echo "Defer Plist exist will unload and remove it"
            /bin/launchctl bootout system $Deferal_PLIST
            /bin/rm -rf $Deferal_PLIST
        fi
        if [ -f $Deferals_Count_PLIST ]; then
            echo "Defer Plist Counter exist will remove it"
            /bin/rm -rf $Deferals_Count_PLIST
        fi
        $JAMF_BINARY recon
elif [ $Choice = "2" ]; then
    echo "User hit cancel"
    #User either ugly closed the prompt, or choose to delay.
    Deferal_Logic
    # Increment the deferral count
    deferral_count=$((deferral_count + 1))
    # Update the plist with the new deferral count
    defaults write "$Deferals_Count_PLIST" deferralCount -int "$deferral_count"
        $JAMF_BINARY recon
		exit 0
else
    echo "ERROR: Sending log to Jamf"
    echo "User hit cancel"
    #User either ugly closed the prompt, or choose to delay.
    Deferal_Logic
    # Increment the deferral count
    deferral_count=$((deferral_count + 1))
    # Update the plist with the new deferral count
    defaults write "$Deferals_Count_PLIST" deferralCount -int "$deferral_count"
fi
exit 0