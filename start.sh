#!/bin/env bash
set -e

if ! command -v curl >/dev/null 2>&1 || ! command -v attr >/dev/null 2>&1; then
    echo "curl and/or attr is required but not installed. Attempting to install..."
    if sudo ./pacapt -S curl attr; then
        echo "curl and attr installed successfully."
    else
        echo "Failed to install curl and attr using pacapt. Please install using your preffered package manager. Aborting."
        exit 1
    fi
fi

# Seperate to prevent possible fuse2 and fuse3 conflict error
if ! command -v fusermount >/dev/null 2>&1; then
    echo "FUSE is required but not installed. Attempting to install..."
    if sudo ./pacapt -S fuse; then
        echo "FUSE installed successfully."
    else
        echo "Failed to install FUSE using pacapt. Please install using your preffered package manager. Aborting."
        exit 1
    fi
fi

nwjs_loc=~/.local/share/porter/nwjs/nw
cicpoffs_loc=~/.local/bin/cicpoffs

if [ -f ./nw ] && [ -f ./cicpoffs ]; then
    echo "using nwjs and cicpoffs version found in the same directory!"
    nwjs_loc=./nw
    cicpoffs_loc=./cicpoffs
else
    if [ -f ~/.local/share/porter/nwjs/nw ]; then
        echo "nwjs found!"
    else
        echo "nwjs not found! Downloading version 0.84.0 (latest as of this script)..."
        mkdir ~/.local/share/porter
        curl https://dl.nwjs.io/v0.84.0/nwjs-sdk-v0.84.0-linux-x64.tar.gz -o ~/.local/share/porter/nwjs.tar.gz
        tar -xzvf ~/.local/share/porter/nwjs.tar.gz -C ~/.local/share/porter/
        mv ~/.local/share/porter/nwjs-sdk-v0.84.0-linux-x64 ~/.local/share/porter/nwjs
        rm -f ~/.local/share/porter/nwjs.tar.gz
        echo "0.84.0" > ~/.local/share/porter/nwjs/nwjs-version.txt
    fi
    if [ -f ~/.local/bin/cicpoffs ]; then
        echo "cicpoffs found!"
    else
        echo "cicpoffs not found! Downloading..."
        curl -L https://github.com/m5kro/cicpoffs/releases/download/binary/cicpoffs -o  ~/.local/bin/cicpoffs
        chmod +x ~/.local/bin/cicpoffs
    fi
fi

if [ -d ./www ] && [ -f ./package.json ]; then
    echo "www folder and package.json found!"
else
    echo "www folder or package.json missing!"
    exit
fi

echo "Moving to case insensitive..."
mv "www" "www-case"
mkdir "www"
"$cicpoffs_loc" "./www-case" "./www"
echo "Waiting for FUSE..."
sleep 3

if [[ "$XDG_SESSION_TYPE" == "wayland" ]]; then
echo "wayland detected"
"$nwjs_loc" . --ozone-platform=wayland
else
echo "wayland not detected, starting in x11"
"$nwjs_loc" . --ozone-platform=x11
fi


if [ -d ./www ]; then
    echo "unmounting..."
    fusermount -u "./www"
    rm -rf www
    mv "www-case" "www"
else
    echo "www mount point missing!"
fi
