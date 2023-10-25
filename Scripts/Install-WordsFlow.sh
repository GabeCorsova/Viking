#!/bin/zsh

##############################################################################
# Script to fetch the latest of words flow from there website then download and install on the local computer
# Script by Gabriel Marcelino
# ‪Senior Apple Technician of Corserva
# 10/02/2023
##############################################################################

# Fetch the latest release page
release_page=$(/usr/bin/curl -s "http://emsoftware.com/category/news/wordsflow/?tag=release&more=1")

# Extract the latest version number and build the download URL
version=$(echo "$release_page" | grep -oE 'WordsFlow_[0-9_]+_for_InDesign_[0-9]+_MacOS\.pkg' | head -n 1)
download_url="https://s3.amazonaws.com/ftp.emsoftware.com/installers/wordsflow/${version}"

# Download the latest package to /var/tmp
/usr/bin/curl -o "/var/tmp/$version" "$download_url"

# Output the path to the downloaded package
pkg_path="/var/tmp/$version"
echo "Package downloaded to $pkg_path"

# Install the package
# Note: The installer command requires superuser privileges, so you may need to run this script with sudo
/usr/sbin/installer -pkg "$pkg_path" -target /

# Check the installation status
if [[ $? -eq 0 ]]; then
    echo "Installation successful!"
    # Delete the downloaded package
    rm "$pkg_path"
    echo "Package deleted."
    exit 0
else
    echo "Installation failed!"
    exit 1
fi