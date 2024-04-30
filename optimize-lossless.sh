#!/usr/bin/env bash

set -e

command -v pngcheck >/dev/null 2>&1 || { echo >&2 "pngcheck is required but it's not installed. Aborting."; exit 1; }
command -v oxipng >/dev/null 2>&1 || { echo >&2 "oxipng is required but it's not installed. Aborting."; exit 1; }
command -v cwebp >/dev/null 2>&1 || { echo >&2 "cwebp is required but it's not installed. Aborting."; exit 1; }

# Check if the user provide a directory path.
if [ $# -ne 1 ]
then
    echo "Usage: $0 path/to/game_dir"; exit 1
fi

game_dir="${1%/}"

# Check if input path is a RPG Maker MV/MZ game
if [[ ! -d "$game_dir"/www ]]
then
    echo "Error: Input path is not a RPG Maker MV/MZ game."; exit 1
fi

optimize_images()
{
    local file="$1"
    if pngcheck -v "$file" | grep -q -E "acTL" # Check if a file is an APNG file
    then
        oxipng --opt max --strip safe "$file" || echo >&2 "oxipng failed on $file. Continuing"
    else
        cwebp -lossless "$file" -o "$file" || echo >&2 "cwebp failed on $file. Continuing."
    fi
}

export -f optimize_images

[ -d "$game_dir" ] || { echo >&2 "$game_dir doesn't exist. Aborting."; exit 1; }


if [ ! -d "$game_dir"/www_backup ]
then
    cp -R "$game_dir"/www "$game_dir"/www_backup
else
    echo "Backup already exists. Skipping backup."
fi

if [ -f "$game_dir"/www/icon/icon.png ]
then
    oxipng --opt max --fix --strip all "$game_dir"/www/icon/icon.png
else
    echo >&2 "Icon doesn't exist. Ignoring."
fi

if command -v parallel >/dev/null 2>&1
then
    find "$game_dir"/www -type f -name "*.png" ! -name "icon.png" | parallel optimize_images
else
    find "$game_dir"/www -type f -name "*.png" ! -name "icon.png" -exec optimize_images {} \;
fi

echo "Finished!"
