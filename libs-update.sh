#!/bin/bash

set -e

# Check if the user provide a directory path.
if [ $# -ne 1 ]
then
    echo "Usage: $0 path/to/game_dir"; exit 1
fi

game_dir="${1%/}"

# Check if input path is a RPG Maker MV/MZ game
if [[ ! -f "$game_dir"/www/js/libs/pixi.js ]]
then
    echo "Error: Input path is not a RPG Maker MV/MZ game."; exit 1
else
	pixi="$game_dir"/www/js/libs/pixi.js
fi

copy_files() {
    local variant=$1
    echo "Game is $variant."
    if [[ ! -d "$game_dir"/www/js/libs_backup ]]
    then
        cp -R "$game_dir"/www/js/libs "$game_dir"/www/js/libs_backup
    fi
    cp -R ./"$variant libs"/* "$game_dir"/www/js/libs
}

# Find which variant the game is.
if grep -q "pixi.js - v4." "$pixi"
then
    copy_files "MV"
elif grep -q "pixi.js - v5." "$pixi"
then
    copy_files "MZ"
else
    echo "Error: Can't detect pixi.js version. Aborting."
fi

echo "Finished!"
