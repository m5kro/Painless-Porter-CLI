#!/bin/bash

# Function to convert webm files to vp9 codec with Opus audio
convert_to_vp9_opus() {
    local file="$1"
    local dirname=$(dirname "$file")
    local filename=$(basename "$file")
    local filename_noext="${filename%.*}"
    local output_file="${filename_noext}_vp9.webm"

    ffmpeg -i "$file" -c:v vp9 -b:v 0 -crf 23 -c:a libopus "$output_file" -y
    if [ $? -eq 0 ]; then
        echo "Converted: $file"
        rm "$file"
        mv "$output_file" "$file"
        echo "Replaced: $file"
    else
        echo "Failed to convert: $file"
    fi
}

# Function to process directory recursively
process_directory() {
    local dir="$1"
    local file="$2"
    if [[ $file == *.webm ]]; then
        convert_to_vp9_opus "$file"
    fi
}

# Main script
if [ $# -ne 1 ]; then
    echo "Usage: $0 <directory>"
    exit 1
fi

directory="$1"

if [ ! -d "$directory" ]; then
    echo "Error: $directory is not a directory"
    exit 1
fi

export -f convert_to_vp9_opus
export -f process_directory

find "$directory" -type f -name '*.webm' | parallel process_directory "$directory"
