#!/bin/bash

download() {
    curl https://dl.nwjs.io/v"$1"/nwjs-sdk-v"$1"-linux-x64.tar.gz -o ~/.local/share/porter/nwjs.tar.gz
	tar -xzvf ~/.local/share/porter/nwjs.tar.gz -C ~/.local/share/porter/
	mv ~/.local/share/porter/nwjs-sdk-v"$1"-linux-x64 ~/.local/share/porter/nwjs
	rm -f ~/.local/share/porter/nwjs.tar.gz
	echo "$1" > ~/.local/share/porter/nwjs/nwjs-version.txt
}

if command -v curl > /dev/null 2>&1; then
    echo "curl found!"
	if [ -f ~/.local/share/porter/nwjs/nw ]; then
        echo "nwjs found!"
        current=$(cat ~/.local/share/porter/nwjs/nwjs-version.txt)
        echo "current version is:" "$current"
        others=$(find ~/.local/share/porter/ -type d -name "nwjs-*" -print -quit)
        if [ -n "$others" ]; then
        	echo "other downloaded versions:"
        	list=$(ls ~/.local/share/porter/ | grep "nwjs-")
        	echo "${list//nwjs-/}"
        fi
        echo "which version would you like to install/switch to (recommended 0.54.0 and above)"
        read new
        if [ "$new" = "$current" ]; then
        	echo "same version! would you like to reinstall (y/n)"
        	read reinstall
        	if [ "$reinstall" = "y" ]; then
        	echo "reinstalling..."
        	rm -rf ~/.local/share/porter/nwjs
        	download "$new"
        	echo "done!"
        	fi
        else
        	mv ~/.local/share/porter/nwjs ~/.local/share/porter/nwjs-"$current"
        	if [ -d ~/.local/share/porter/nwjs-"$new" ]; then
        		echo "$new already downloaded! switching..."
        		mv ~/.local/share/porter/nwjs-"$new" ~/.local/share/porter/nwjs
        		echo "done!"
        	else
        		echo "downloading $new"
        		download "$new"
        		echo "done!"
        	fi
        fi
    else
        echo "nwjs not found! Downloading version 0.78.1 (default version)"
        mkdir ~/.local/share/porter
        download 0.78.1
        curl -L https://github.com/m5kro/cicpoffs/releases/download/binary/cicpoffs -o  ~/.local/share/porter/cicpoffs
        chmod +x ~/.local/share/porter/cicpoffs
	fi
else
    echo "curl not found! Please install it from your package manager!"
    exit
fi
