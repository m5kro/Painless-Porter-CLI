#!/bin/bash
set -e
command -v attr >/dev/null 2>&1 || { echo >&2 "attr is required but it's not installed. Aborting."; exit 1; }

nwjs_loc=~/.local/share/porter/nwjs/nw
cicpoffs_loc=~/.local/share/porter/cicpoffs

if [ -f ./nw ] && [ -f ./cicpoffs ]; then
    echo "using nwjs and cicpoffs version found in the same directory!"
    nwjs_loc=./nw
    cicpoffs_loc=./cicpoffs
else
    if [ -f ~/.local/share/porter/nwjs/nw ]; then
        echo "nwjs found!"
    else
        echo "nwjs not found! Downloading version 0.84.0 (latest as of this script)"
        mkdir ~/.local/share/porter
        if command -v curl > /dev/null 2>&1; then
            echo "curl found! Downloading..."
            curl https://dl.nwjs.io/v0.84.0/nwjs-sdk-v0.84.0-linux-x64.tar.gz -o ~/.local/share/porter/nwjs.tar.gz
            tar -xzvf ~/.local/share/porter/nwjs.tar.gz -C ~/.local/share/porter/
            mv ~/.local/share/porter/nwjs-sdk-v0.84.0-linux-x64 ~/.local/share/porter/nwjs
            rm -f ~/.local/share/porter/nwjs.tar.gz
            echo "0.84.0" > ~/.local/share/porter/nwjs/nwjs-version.txt
            curl -L https://github.com/m5kro/cicpoffs/releases/download/binary/cicpoffs -o  ~/.local/share/porter/cicpoffs
            chmod +x ~/.local/share/porter/cicpoffs
        else
            echo "curl not found! Please install it from your package manager!"
            exit
        fi
    fi
fi

if [ -d ./www ] && [ -f ./package.json ]; then
    echo "www folder and package.json found!"
else
    echo "www folder or package.json missing!"
    exit
fi

if command -v fusermount > /dev/null 2>&1; then
    echo "FUSE found! Moving to case insensitive."
    mv "www" "www-case"
    mkdir "www"
    "$cicpoffs_loc" "./www-case" "./www"
    echo "Waiting for FUSE..."
    sleep 3
else
    echo "FUSE not found! Sticking with case sensitive."
fi

if [[ "$XDG_SESSION_TYPE" == "wayland" ]]; then
echo "wayland detected"
"$nwjs_loc" . --ozone-platform=wayland
else
echo "wayland not detected, starting in x11"
"$nwjs_loc" . --ozone-platform=x11
fi

if command -v fusermount > /dev/null 2>&1; then
    if [ -d ./www ]; then
    	echo "unmounting..."
    	fusermount -u "./www"
    	rm -rf www
    	mv "www-case" "www"
    else
    	echo "www mount point missing!"
    fi
fi
