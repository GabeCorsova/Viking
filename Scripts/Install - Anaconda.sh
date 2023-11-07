#!/bin/bash

##############################################################################
# Script to find the latest Anaconda and install and extract the Python coponites using anaconda's script
# Script by Gabriel Marcelino
# Senior Apple Technician of Corserva
# 11/06/2023
##############################################################################

loggedInUser=$( ls -l /dev/console | awk '{print $3}' )
LoggedinHomeFolder="/Users/$loggedInUser"

#Downloading the latest Anaconda3 installer for macOS. Your architecture may vary.
curl https://repo.anaconda.com/archive/Anaconda3-2023.09-0-MacOSX-x86_64.sh -o "$LoggedinHomeFolder"/anaconda3.sh
bash "$LoggedinHomeFolder"/anaconda3.sh -b -p $HOME/anaconda3

####
# Prep Installation script
#####

# COMMON UTILS
# If you update this block, please propagate changes to the other scripts using it
set -euo pipefail

notify() {
# shellcheck disable=SC2050
if [ "False" = "True" ]; then
osascript <<EOF
display notification "$1" with title "📦 Install Anaconda3 2023.09-0"
EOF
fi
logger -p "install.info" "$1" || echo "$1"
}

unset DYLD_LIBRARY_PATH

PREFIX="$LoggedinHomeFolder/anaconda3"
PREFIX=$(cd "$PREFIX"; pwd)
export PREFIX
echo "PREFIX=$PREFIX"
CONDA_EXEC="$PREFIX/conda.exe"
# /COMMON UTILS

chmod +x "$CONDA_EXEC"

# Create a blank history file so conda thinks this is an existing env
mkdir -p "$PREFIX/conda-meta"
touch "$PREFIX/conda-meta/history"

# Extract the conda packages but avoiding the overwriting of the
# custom metadata we have already put in place
notify "Preparing packages..."
if ! "$CONDA_EXEC" constructor --prefix "$PREFIX" --extract-conda-pkgs; then
    echo "ERROR: could not extract the conda packages"
    exit 1
fi

####
# Run installation Script
#####

# Created by constructor 3.4.5

# COMMON UTILS
# If you update this block, please propagate changes to the other scripts using it
set -euo pipefail

unset DYLD_LIBRARY_PATH

PREFIX="$LoggedinHomeFolder/anaconda3"
PREFIX=$(cd "$PREFIX"; pwd)
export PREFIX
echo "PREFIX=$PREFIX"
CONDA_EXEC="$PREFIX/conda.exe"
# /COMMON UTILS

# Perform the conda install
notify "Installing packages. This might take a few minutes."
if ! CONDA_SAFETY_CHECKS=disabled \
CONDA_EXTRA_SAFETY_CHECKS=no \
CONDA_CHANNELS=https://repo.anaconda.com/pkgs/main \
CONDA_PKGS_DIRS="$PREFIX/pkgs" \
"$CONDA_EXEC" install --offline --file "$PREFIX/pkgs/env.txt" -yp "$PREFIX"; then
    echo "ERROR: could not complete the conda install"
    exit 1
fi

# Move the prepackaged history file into place
mv "$PREFIX/pkgs/conda-meta/history" "$PREFIX/conda-meta/history"
rm -f "$PREFIX/env.txt"

# Same, but for the extra environments

mkdir -p "$PREFIX/envs"

for env_pkgs in "${PREFIX}"/pkgs/envs/*/; do
    env_name="$(basename "${env_pkgs}")"
    if [[ "${env_name}" == "*" ]]; then
        continue
    fi

    notify "Installing ${env_name} packages..."
    mkdir -p "$PREFIX/envs/$env_name/conda-meta"
    touch "$PREFIX/envs/$env_name/conda-meta/history"

    if [[ -f "${env_pkgs}channels.txt" ]]; then
        env_channels="$(cat "${env_pkgs}channels.txt")"
        rm -f "${env_pkgs}channels.txt"
    else
        env_channels="https://repo.anaconda.com/pkgs/main"
    fi
    # TODO: custom channels per env?
    # TODO: custom shortcuts per env?
    CONDA_SAFETY_CHECKS=disabled \
    CONDA_EXTRA_SAFETY_CHECKS=no \
    CONDA_CHANNELS="$env_channels" \
    CONDA_PKGS_DIRS="$PREFIX/pkgs" \
    "$CONDA_EXEC" install --offline --file "${env_pkgs}env.txt" -yp "$PREFIX/envs/$env_name" || exit 1
    # Move the prepackaged history file into place
    mv "${env_pkgs}/conda-meta/history" "$PREFIX/envs/$env_name/conda-meta/history"
    rm -f "${env_pkgs}env.txt"
done

# Cleanup!
rm -f "$CONDA_EXEC"
find "$PREFIX/pkgs" -type d -empty -exec rmdir {} \; 2>/dev/null || :



if ! "$PREFIX/bin/python" -V; then
    echo "ERROR running Python"
    exit 1
fi

# This is unneeded for the default install to "$LoggedinHomeFolder", but if the user changes the
# install location, the permissions will default to root unless this is done.
chown -R "$USER" "$PREFIX"

notify "Done! Installation is available in $PREFIX."

####
# User Post Installation 
#####

# COMMON UTILS
# If you update this block, please propagate changes to the other scripts using it
set -euo pipefail

unset DYLD_LIBRARY_PATH

PREFIX="$LoggedinHomeFolder/anaconda3"
PREFIX=$(cd "$PREFIX"; pwd)
export PREFIX
echo "PREFIX=$PREFIX"
CONDA_EXEC="$PREFIX/conda.exe"
# /COMMON UTILS

# Expose these to user scripts as well
export INSTALLER_NAME="Anaconda3"
export INSTALLER_VER="2023.09-0"
export INSTALLER_PLAT="osx-arm64"
export INSTALLER_TYPE="PKG"
export PRE_OR_POST="post_install"

# Run user-provided script
if [ -f "$PREFIX/pkgs/user_${PRE_OR_POST}" ]; then
    notify "Running ${PRE_OR_POST} scripts..."
    chmod +x "$PREFIX/pkgs/user_${PRE_OR_POST}"
    if ! "$PREFIX/pkgs/user_${PRE_OR_POST}"; then
        echo "ERROR: could not run user-provided ${PRE_OR_POST} script!"
        exit 1
    fi
else
    echo "ERROR: SHOULD HAVE RUN!"
    exit 1
fi

# "$LoggedinHomeFolder" is the install location, which is "$LoggedinHomeFolder" by default, but which the user can
# change.
set -eux

PREFIX="$LoggedinHomeFolder/anaconda3"
PREFIX=$(cd "$PREFIX"; pwd)
"$PREFIX/bin/python" -m conda init --all

#Clean up
/bin/rm -rf "$LoggedinHomeFolder"/anaconda3.sh

exit 0