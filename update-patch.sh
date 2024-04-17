#!/bin/bash

# Check if patch-config.txt exists
if [ ! -f patch-config.txt ]; then
    echo "Config file 'patch-config.txt' not found! Assuming no patching needed."
    exit 0
fi

# Read configuration from file
source patch-config.txt

# Get the latest hash
echo "Getting latest commit SHA hash"
latest_patch_sha=$(curl -s "https://api.github.com/repos/$username/$repo/branches/$branch" | jq -r '.commit.sha')

# Check if previous_patch_sha.txt exists
if [ ! -f previous_patch_sha.txt ]; then
    echo "Previous SHA hash not found!"
    echo "Assuming first time patching..."
    download_extract
else
    # Read the stored SHA from previous check
    previous_patch_sha=$(<previous_patch_sha.txt)

    # Compare trimmed SHAs
    if [ "$latest_patch_sha" != "$previous_patch_sha" ]; then
        echo "Update found! Patching..."
        download_extract
    else
        echo "Patch is up to date."
    fi
fi

exit 0

download_extract() {
    # Download zip file
    echo "Downloading latest patch..."
    curl -sL "https://codeload.github.com/$username/$repo/zip/refs/heads/$branch" -o repo.zip

    # Extract contents, overwriting conflicts
    echo "Extracting..."
    unzip -qo repo.zip
    echo "Applying patch..."
    if [ -d "$repo-$branch/"www ]; then
        cp -r "$repo-$branch/"* .
        jq --arg repo "$repo" 'if (.name | test("^[[:space:]]*$")) then .name = $repo else . end' package.json > package.json
    else
        cp -r "$repo-$branch/"* ./www
    fi

    if [ -f "$repo-$branch/www/js/plugins.js" ]; then
        [ "$(id -u)" = 0 ] && echo "Please run without root perms" && exit

        echo "Searching for and patching RPGM Plugins.js"
        PATTERN='/];/i ,{"name":"Cheat_Menu","status":true,"description":"","parameters":{}}'
        if [ -f "www/js/plugins.js" ]; then
            file_path="www/js/plugins.js"
        elif [ -f "js/plugins.js" ]; then
            file_path="js/plugins.js"
        else
            echo "No RPGM installation found."
        fi


        # Find the line number of the last occurrence of "];"
        last_occurrence=$(grep -n '];' "$file_path" | tail -n 1 | cut -d ':' -f 1)

        # If there is an occurrence of "];"
        if [ -n "$last_occurrence" ]; then
            # Remove the last occurrence of "];"
            sed -i "${last_occurrence}d" "$file_path"
            sed -i "/^[[:space:]]*$/d" "$file_path"
            sed -i "$ s/,$//" "$file_path"
            echo ',{"name":"Cheat_Menu","status":true,"description":"","parameters":{}}];' >> "$file_path"
        fi
    fi

    # Clean up
    echo "Cleaning up..."
    rm repo.zip
    rm -rf "$repo-$branch"
    rm latest_patch_sha.txt

    # Store latest SHA for next check
    echo "$latest_patch_sha" > previous_patch_sha.txt
}
