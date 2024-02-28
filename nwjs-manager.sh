#!/bin/env bash

URL="https://nwjs.io/versions"
TMP_FILE="/tmp/versions.json"
CURRENT="$XDG_DATA_HOME/porter/nwjs-version.txt"

download() {
    local version=$1
    local url="https://dl.nwjs.io/${version}/nwjs-sdk-${version}-linux-x64.tar.gz"
    local tmp_file="/tmp/nwjs.tar.gz"
    local extract_dir="/tmp/nwjs-sdk-${version}-linux-x64"
    local target_dir="$XDG_DATA_HOME/porter/nwjs"

    echo -e "\nDownloading $version:"
    if curl -fSL -o "$tmp_file" "$url" && tar -xzf "$tmp_file" -C "/tmp"
    then
        rm -rf "$target_dir"
        mv "$extract_dir" "$target_dir"
        mkdir "$target_dir"/www
        echo "$version" > "$CURRENT"
        echo "Finished!"
    else
        echo "Failed to download or extract $url"
        exit 1
    fi
}

if command -v curl > /dev/null 2>&1; then
    if command -v jq > /dev/null 2>&1; then
        # Query the URL and store the response in /tmp.
        echo -e "Querying available versions...\n"
        if ! curl -fsSL -o "$TMP_FILE" "$URL"
        then
            echo "Failed to download $URL"
            exit 1
        fi

        # Get LATEST version from response.
        LATEST=$(jq -r '.latest' "$TMP_FILE")

        # Get valid VERSIONS from response.
        VERSIONS=$(jq -r '.versions[].version' "$TMP_FILE" | head -10 | awk '{ORS = (NR%5 ? ", " : "\n")} {print}')
        echo -e "Available versions:\n$VERSIONS\n"

        echo "This script will download the latest version by default."

        # Wait for user input for 10 seconds.
        read -t 10 -p "You have 10 seconds to enter a specific version number (including the v) if you wish to: " INPUT

        # Check if the user entered something.
        if [ -n "$INPUT" ]
        then
            # Check if the entered version is valid.
            if [[ "$VERSIONS" =~ "$INPUT" ]]
            then
                download "$INPUT"
            else
                echo "Error: $INPUT is not a valid version."
                exit 1
            fi
        # If the user didn't enter anything.
        else
            # If nwjs-version.txt doesn't exist OR if CURRENT version is not LATEST, download the latest version.
            if [[ ! -f "$CURRENT" ]] || [[ $(cat "$CURRENT") != "$LATEST" ]]; then
                echo -e "\n"
                download "$LATEST"
            else
                echo -e "\n$LATEST is already up to date."
            fi
        fi
    else
        echo "jq is not installed! Please install it through your package manager."
    fi
else
    echo "curl is not installed! Please install it through your package manager."
fi
