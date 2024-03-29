#!/bin/env bash

if [[ -z "$XDG_DATA_HOME" ]]; then
    XDG_DATA_HOME="$HOME/.local/share"
fi

# Function to display usage information
function display_usage {
  echo "Usage: $0 [--folder] [--no-upload] [--no-compress] [--no-cleanup] [--no-cheats] [--no-decrypt] [--no-img-rencode] [--no-audio-rencode] [--no-pixijs-upgrade] <input_file>"
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
decrypt=true
webp=true
pixi=true
opus=true

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
    --no-decrypt)
      decrypt=false
      webp=false
      ;;
    --no-img-rencode)
      webp=false
      ;;
    --no-audio-rencode)
      opus=false
      ;;
    --no-pixijs-upgrade)
      pixi=false
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
  echo "patch extracted and found! applying..."
  cp -r ./en-extracted/* "$game_exe_path"
fi

# Look for the 'www' folder
www_folder=$(find ./extracted/ -type d -name "www" -print -quit)
if [ -n "$www_folder" ]; then
  echo "rpg mv detected"
  package_json_old=$(find ./extracted/ -type f -not -path '*/www/*' -name "package.json" -print -quit | head -n 1)
  cp "$package_json_old" ./package.json.old
else
  echo "rpg mz detected"
  # If 'www' folder does not exist, look for specific folders and files for rpgmz
  mkdir "$game_exe_path"/www
  # Copy the game files to the www folder except for the nwjs files
  exclude_list=(
    "credits.html"
    "www"
    "icudtl.dat"
    "notification_helper.exe"
    "package.json"
    "d3dcompiler_47.dll"
    "libegl.dll"
    "nw_100_percent.pak"
    "resources.pak"
    "debug.log"
    "libglesv2.dll"
    "nw_200_percent.pak"
    "ffmpeg.dll"
    "locales"
    "nw.dll"
    "swiftshader"
    "game.exe"
    "game_en.exe"
    "game_en_original.exe"
    "node.dll"
    "nw_elf.dll"
    "v8_context_snapshot.bin"
  )
  # Loop through files and folders in the game directory
  for item in "$game_exe_path"/*; do
      # Get the basename of the item and convert it to lowercase
    base=$(basename "$item" | tr '[:upper:]' '[:lower:]')
    # Check if the lowercase basename is in the lowercase exclude list
    if [[ ! " ${exclude_list[@]} " =~ " ${base} " ]]; then
          # Copy the item to the www folder
          cp -r "$item" "$game_exe_path"/www
      fi
  done

  # Find the topmost instance of package.json, and modify it to point to the index.html in www
  package_json=$(find ./extracted/ -type f -name "package.json" -print -quit)
  if [ -n "$package_json" ]; then
    jq '.main = "www/index.html" | .window.icon = "www/icon/icon.png" | ."chromium-args" = "--enable-gpu-rasterization --force-color-profile=srgb"' "$package_json" > ./package.json.old
  else
    echo "package.json missing"
    exit 1
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

# Check if images are already webp
if [ "$webp" = true ]; then
  img=$(file $(find "$www_folder"/img -type f \( -name "*.png" ! \( -name "Loading.png" -o -name "Window.png" -o -name "icon.png" \) \) -print -quit | head -n 1) | grep Web/P)
  if [ -n "$img" ]; then
    echo "Images are already webp"
    webp=false
  else
    echo "Images are not webp, converting after decryption"
  fi
fi

# Check if images are encrypted
images_encrypted=$(jq -r .hasEncryptedImages "$www_folder/data/System.json")
if [ -n "$images_encrypted" ]; then
  if $images_encrypted; then
    echo "Images are encrypted. Decrypting..."
    mkdir ./decrypted
    java -jar RPG.Maker.MV.Decrypter_0.4.2.jar decrypt "$www_folder" ./decrypted
    find "$game_exe_path" -type f \( -name "*.rpgmvp" -o -name "*.rpgmvm" -o -name "*.rpgmvo" -o -name "*.png_" -o -name "*.m4a_" -o -name "*.ogg_" \) -delete
    jq '.hasEncryptedImages = false | .hasEncryptedAudio = false' "$www_folder"/data/System.json > ./System.json.new
    rm -f "$www_folder"/data/System.json
    mv ./System.json.new "$www_folder"/data/System.json
    www_folder_decrypted=$(find ./decrypted -type d -name "www" -print -quit)
    cp -r "$www_folder_decrypted"/* "$www_folder"
    rm -rf ./decrypted
  else
    echo "Images are unencrypted"
  fi
else
  # Exclude Loading.png and Window.png from the check
  manual_check=$(find "$www_folder"/img -type f \( -name "*.png" ! \( -name "Loading.png" -o -name "Window.png" \) \) -print -quit)
  if [ -n "$manual_check" ]; then
    echo "Images are unencrypted"
  else
    echo "Unable to determine encryption! Manual decryption needed. Would you like to continue?"
    read -p "Continue? (y/n) " -n 1 -r
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
      echo "Exiting"
      exit 1
    fi
    webp=false
  fi
fi

if [ "$webp" = true ]; then
  echo "Converting images to webp..."
  ./optimize.sh "$game_exe_path"
fi

if [ -f "$www_folder"/js/plugins.js ]; then
    # Search for the line containing "AudioStreaming"
    if grep -q '"name":"AudioStreaming"' "$www_folder"/js/plugins.js; then
        # Replace the line with status set to false to unload
        sed -i 's/\("name"\s*:\s*"AudioStreaming"\s*,"status"\s*:\s*\)true/\1false/' "$www_folder"/js/plugins.js
        echo "Status of AudioStreaming set to false."
    else
        echo "Line containing AudioStreaming not found."
    fi
else
    echo "plugins.js not found!"
    exit 1
fi

if [ "$opus" = true ]; then
  echo "Converting audio to opus..."
  ./RMMVOpusConverter --ConverterLocation /usr/bin/ --SourceLocation "$www_folder" --OutputLocation ./opus
  cp -r ./opus/* "$www_folder"
  rm -rf ./opus
fi

if [ "$pixi" = true ]; then
  echo "Upgrading pixi.js..."
  ./libs-update.sh "$game_exe_path"
fi

if [ -n "$www_folder" ]; then
  # If 'www' folder exists, copy it to the uncompressed nwjs folder
  cp -r "$www_folder" linux/www
  cp ./pacapt linux/
  cp -r "$www_folder" nwjs-sdk-v"$nwjsv"-osx-arm64/nwjs.app/Contents/Resources/app.nw
  cp -r "$www_folder" nwjs-sdk-v"$nwjsv"-osx-x64/nwjs.app/Contents/Resources/app.nw
  # Put the game name in package.json so it runs
  game_name=$(basename "$input_file" | sed 's/\(.*\)\..*/\1/')
  jq ".name = \"$game_name\"" package.json.old > package.json
  rm -rf ./package.json.old
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
