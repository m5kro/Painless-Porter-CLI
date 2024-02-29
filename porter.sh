#!/bin/env bash

# Function to display usage information
function display_usage {
  echo "Usage: $0 [--folder] [--no-upload] [--no-compress] [--no-cleanup] [--no-cheats] <input_file>"
  exit 1
}

# nwjs version
nwjsv=0.84.0

# Parse command line arguments
extract=true
upload=true
compress=true
cleanup=true
cheats=true

while [ "$#" -gt 0 ]; do
  case "$1" in
    --folder)
      extract=false
      ;;
    --no-upload)
      upload=false
      cleanup=false
      ;;
    --no-compress)
      compress=false
      upload=false
      cleanup=false
      ;;
    --no-cleanup)
      cleanup=false
      ;;
    --no-cheats)
      cheats=false
      ;;
    -*)
      display_usage
      ;;
    *)
      input_file="$1"
      break
      ;;
  esac
  shift
done

# Check if input_file is provided
if [ -z "$input_file" ]; then
  display_usage
fi

input_file="$1"

# Clear out old links
rm -rf pixeldrain.txt
touch pixeldrain.txt
rm -rf gofile.txt
touch gofile.txt

# Extract nwjs files
unzip nwjs-sdk-v"$nwjsv"-osx-arm64.zip
unzip nwjs-sdk-v"$nwjsv"-osx-x64.zip

# Prep osx
mkdir nwjs-sdk-v"$nwjsv"-osx-arm64/nwjs.app/Contents/Resources/app.nw
mkdir nwjs-sdk-v"$nwjsv"-osx-x64/nwjs.app/Contents/Resources/app.nw

# Prep linux
mkdir linux

# Prep Game_en.exe extraction location
mkdir en-extracted

# Check if the input file exists
if [ ! -f "$input_file" ]; then
  echo "Error: Input file not found."
  exit 1
fi

# Make temporary folder for gamefiles
mkdir extracted

# Check if archive extraction is required
if [ "$extract" = true ]; then
  # Determine compression format
  case "$input_file" in
    *.zip)
      unzip "$input_file" -d ./extracted/ ;;
    *.7z)
      7z x "$input_file" "-o./extracted/" ;;
    *.rar)
      unrar x "$input_file" ./extracted/ ;;
    *.tar.gz)
      tar xvzf "$input_file" -C ./extracted/ ;;
    *)
      echo "Error: Unsupported compression format."
      exit 1 ;;
  esac
fi

# Look for the game path
game_exe_path=$(find ./extracted/ -type f -name *exe -printf '%h\n' -quit)

# Look for the 'www' folder
www_folder=$(find ./extracted/ -type d -name "www" -print -quit)
if [ -n "$www_folder" ]; then
  echo "rpg mv detected"
else
  echo "rpg mz detected"
  # If 'www' folder does not exist, look for specific folders and files for rpgmz
  mkdir "$game_exe_path"/www
  for folder in audio css js img data effects fonts icon; do
    folder_path=$(find ./extracted/ -type d -name "$folder" -print -quit)
    if [ -n "$folder_path" ]; then
      cp -r "$folder_path" "$game_exe_path"/www/"$folder"
    fi
  done

  # If movies folder exists
  movies_path=$(find ./extracted/ -type d -name movies -print -quit)
  if [ -n "$movies_path" ]; then
    cp -r "$movies_path" "$game_exe_path"/www/movies
  fi

  # Look for index.html and copy it if found
  index_html=$(find ./extracted/ -type f -name "index.html" -print -quit)
  if [ -n "$index_html" ]; then
    cp "$index_html" "$game_exe_path"/www
  fi

  # Find the topmost instance of package.json and copy it to the www folder
  package_json=$(find ./extracted/ -type f -name "package.json" -print -quit)
  if [ -n "$package_json" ]; then
    cp "$package_json" "$game_exe_path"/www
  fi
fi

game_en_exe=$(find ./extracted/ -type f -iname "game_en.exe" -print -quit)
if [ -n "$game_en_exe" ]; then
  echo "Game_en.exe detected! assuming packed with enigmavb!"

  command -v python  >/dev/null 2>&1 || { echo >&2 "python is required but it's not installed. Aborting."; exit 1; }
  if [ ! -d ./evbunpack ]; then
    python -m venv $XDG_DATA_HOME/porter/evbunpack
    source $XDG_DATA_HOME/porter/evbunpack/bin/activate
    pip install evbunpack
    deactivate
  else echo "evbunpack found, skipping venv creation."
  fi

  source $XDG_DATA_HOME/porter/evbunpack/bin/activate
  evbunpack "$game_en_exe" ./en-extracted/
  deactivate

  translation=$(find ./en-extracted/ -type d -name "www" -print -quit)
  if [ -n "$translation" ]; then
  echo "patch extracted and found! applying..."
  cp -r "$translation" "$game_exe_path"
  else
  echo "failed to extract patch! manual extraction needed later."
  fi
fi

if [ "$cheats" = true ]; then
  cp -r -f ./Cheat_Menu/* "$game_exe_path"
  current_path=$(pwd)
  cd "$game_exe_path"
  ./patchPlugins.sh
  cd "$current_path"
fi

# Look for the 'www' folder again
www_folder=$(find ./extracted/ -type d -name "www" -print -quit)

if [ -n "$www_folder" ]; then
  # If 'www' folder exists, copy it to the uncompressed nwjs folder
  cp -r "$www_folder" linux/www
  cp -r "$www_folder" nwjs-sdk-v"$nwjsv"-osx-arm64/nwjs.app/Contents/Resources/app.nw
  cp -r "$www_folder" nwjs-sdk-v"$nwjsv"-osx-x64/nwjs.app/Contents/Resources/app.nw
  # Put the game name in package.json so it runs
  game_name=$(basename "$input_file" | sed 's/\(.*\)\..*/\1/')
  jq ".name = \"$game_name\"" package-template.json > package.json
  cp package.json linux/
  cp package.json nwjs-sdk-v"$nwjsv"-osx-arm64/nwjs.app/Contents/Resources/app.nw
  cp package.json nwjs-sdk-v"$nwjsv"-osx-x64/nwjs.app/Contents/Resources/app.nw
else
  echo "www folder missing"
  exit
fi

# Copy start.sh to the linux folder
cp start.sh linux
cp nwjs-manager.sh linux

# Extract name without extension and append -Linux
new_linux_folder_name=$(basename "$input_file" | sed 's/\(.*\)\..*/\1/')"-Linux"
mv linux "$new_linux_folder_name"

new_osx_arm64_folder_name=$(basename "$input_file" | sed 's/\(.*\)\..*/\1/')"-macos-arm64.app"
mv nwjs-sdk-v"$nwjsv"-osx-arm64/nwjs.app "$new_osx_arm64_folder_name"

new_osx_x64_folder_name=$(basename "$input_file" | sed 's/\(.*\)\..*/\1/')"-macos-x64.app"
mv nwjs-sdk-v"$nwjsv"-osx-x64/nwjs.app "$new_osx_x64_folder_name"

rm -rf nwjs-sdk-v"$nwjsv"-osx-arm64
rm -rf nwjs-sdk-v"$nwjsv"-osx-x64

echo "Unpacking and copying completed successfully."
if [ "$compress" = true ]; then
  echo "Compressing"
fi

if [ "$compress" = true ]; then
    new_linux_archive_name=$(basename "$input_file" | sed 's/\(.*\)\..*/\1/')"-Linux.7z"
    7z a -mx1 -mf- -m0=lzma2:a0 "$new_linux_archive_name" ./"$new_linux_folder_name"
    if [ "$upload" = true ]; then
      json_data=$(curl -s https://api.gofile.io/getServer)
      store_value=$(echo "$json_data" | jq -r '.data.server')
      echo https://pixeldrain.com/u/$(curl -T "$new_linux_archive_name" https://pixeldrain.com/api/file/ | jq -r '.id') >> pixeldrain.txt &
      curl -F file=@"$new_linux_archive_name" https://"$store_value".gofile.io/uploadFile | jq -r '.data.downloadPage'>> gofile.txt &
    fi
  
    new_osx_arm64_archive_name=$(basename "$input_file" | sed 's/\(.*\)\..*/\1/')"-macos-arm64.7z"
    7z a -mx1 -mf- -m0=lzma2:a0 "$new_osx_arm64_archive_name" ./"$new_osx_arm64_folder_name"
    if [ "$upload" = true ]; then
      json_data=$(curl -s https://api.gofile.io/getServer)
      store_value=$(echo "$json_data" | jq -r '.data.server')
      echo https://pixeldrain.com/u/$(curl -T "$new_osx_arm64_archive_name" https://pixeldrain.com/api/file/ | jq -r '.id') >> pixeldrain.txt &
      curl -F file=@"$new_osx_arm64_archive_name" https://"$store_value".gofile.io/uploadFile | jq -r '.data.downloadPage' >> gofile.txt &
    fi
  
    new_osx_x64_archive_name=$(basename "$input_file" | sed 's/\(.*\)\..*/\1/')"-macos-x64.7z"
    7z a -mx1 -mf- -m0=lzma2:a0 "$new_osx_x64_archive_name" ./"$new_osx_x64_folder_name"
    if [ "$upload" = true ]; then
      json_data=$(curl -s https://api.gofile.io/getServer)
      store_value=$(echo "$json_data" | jq -r '.data.server')
      echo https://pixeldrain.com/u/$(curl -T "$new_osx_x64_archive_name" https://pixeldrain.com/api/file/ | jq -r '.id') >> pixeldrain.txt &
      #last one not put in background to keep script alive, useful for timing
      curl -F file=@"$new_osx_x64_archive_name" https://"$store_value".gofile.io/uploadFile | jq -r '.data.downloadPage' >> gofile.txt
    fi
  
  wait
  
  echo "Uploading Complete!"
fi


# Cleanup
if [ "$cleanup" = true ]; then
  echo "Cleaning Up!"
  rm -rf extracted
  rm -rf en-extracted
  rm -rf "$new_linux_folder_name"
  rm -rf "$new_osx_arm64_folder_name"
  rm -rf "$new_osx_x64_folder_name"
  rm -f "$new_linux_archive_name"
  rm -f "$new_osx_arm64_archive_name"
  rm -f "$new_osx_x64_archive_name"
  rm -f "$input_file"
fi
echo "Completed Successfully."
