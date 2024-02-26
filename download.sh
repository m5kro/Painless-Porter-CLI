#!/bin/bash

# Check if exactly 2 arguments are provided
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <output_filename> <id>"
    exit 1
fi

# Assign input arguments to variables
output_filename="$1"
id="$2"

# Run the curl command
curl -o "$output_filename" "https://pixeldrain.com/api/file/$id"
