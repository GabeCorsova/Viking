#!/bin/zsh

# Define the URL for the latest version of BetterZip
download_url="https://macitbetter.com/BetterZip.zip"

# Define the destination file path
dest_file="/var/tmp/BetterZip.zip"

# Download the latest version
curl -L -o "$dest_file" "$download_url"

# Output the path to the downloaded file
echo "File downloaded to $dest_file"
chmod 777 "$dest_file"

# Unzip the archive to the Applications folder
# (assuming the ZIP file contains BetterZip.app at the root level)
unzip -q "$dest_file" -d "/Applications/"

# Optional: Remove the downloaded ZIP file
rm "$dest_file"

# Check if the application was installed successfully
if [[ -d "/Applications/BetterZip.app" ]]; then
    echo "Installation successful!"
else
    echo "Installation failed!"
fi