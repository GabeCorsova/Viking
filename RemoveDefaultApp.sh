#!/bin/bash

PATH=/bin:/usr/bin:/sbin:/usr/sbin:/usr/local/bin export PATH

# set -xv; exec 1>>/tmp/delete_PKNGBiMTraceLog 2>&1

#----------------------------------------------------------------------------------------------------------------------------------                                                                     
#   delete_PKNGBiM      
#   Copyright (c) 2017 Apple Inc.
#   
#   
#   This script deletes Pages, Keynote, Numbers, GarageBand and iMovie from the Applications folder
#


#-------------------------------------------------------------MAIN-------------------------------------------------------------------
# execute

# Version 1.0.0, 08-24-2017

declare -a apps_a

apps_a[0]="Pages.app"
apps_a[1]="Keynote.app"
apps_a[2]="Numbers.app"
apps_a[3]="GarageBand.app"
apps_a[4]="iMovie.app"

# loop through the apps
for i in "${apps_a[@]}"; do
    filePath="/Applications/${i}"

    # if the app exists, delete it
    if [[ -e "${filePath}" ]]; then
        rm -rf "${filePath}"
    fi
done

exit 0