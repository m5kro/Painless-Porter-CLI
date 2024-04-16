#!/bin/env bash

if [[ -z "$XDG_DATA_HOME" ]]; then
    XDG_DATA_HOME="$HOME/.local/share"
fi

# Function to display usage information
function display_usage {
  echo "Usage: $0 [--folder] [--no-upload] [--no-compress] [--no-cleanup] [--no-cheats] [--no-decrypt] [--no-asset-clean] [--no-img-rencode] [--lossy] [--no-audio-rencode] [--no-video-rencode] [--no-pixijs-upgrade] [--custom-tl-link] [--upload-timeout <timeout>] <input_file>"
  exit 1
}

# nwjs version
nwjsv=0.85.0

# Parse command line arguments
extract=true
upload=true
compress=true
cleanup=true
cheats=true
decrypt=true
clean=true
webp=true
lossless=true
pixi=true
opus=true
vp9=true
custom-tl-link=false
# Default upload timeout
upload_timeout=120

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
    --no-asset-clean)
      clean=false
      ;;
    --no-img-rencode)
      webp=false
      ;;
    --lossy)
      lossless=false
      ;;
    --no-audio-rencode)
      opus=false
      ;;
    --no-video-rencode)
      vp9=false
      ;;
    --no-pixijs-upgrade)
      pixi=false
      ;;
    --custom-tl-link)
      custom_tl_link=true
      ;;
    --upload-timeout)
      shift
      upload_timeout="$1"
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

# Prep windows + linux
mkdir win-linux

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
game_exe_path=$(find ./extracted/ -type f -name *.exe -printf '%h\n' -quit)

game_exe=$(find ./extracted/ -type f -iname "game.exe" -print -quit)
game_exe_size=$(stat -c %s "$game_exe")
game_exe_size_mb=$(echo "scale=2; $game_exe_size / (1024 * 1024)" | bc)
if (( $(echo "$game_exe_size_mb > 5" | bc -l) )); then
    echo "Game.exe is bigger than 5 megabytes, assuming evb packed..."
    echo "Extracting..."
    evbunpack "$game_exe" ./game-extracted/
    cp -r ./game-extracted/* "$game_exe_path"
    rm -rf ./game-extracted
else
    echo "Game.exe is not bigger than 5 megabytes, assuming regular nwjs executable..."
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
    "node.dll"
    "nw_elf.dll"
    "v8_context_snapshot.bin"
    "update-patch.bat"
    "patch-config.txt"
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

patchconfig=$(find ./extracted/ -type f -name "patch-config.txt" -print -quit)
if [ -n "$patchconfig" ]; then
  cp "$patchconfig" ./win-linux/patch-config.txt
  echo "Patch config found!"
fi

if [ "$custom_tl_link" = true ]; then
  echo "Using custom translation variables!"
  cp ./patch-config.txt ./win-linux/patch-config.txt
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

if [ "$clean" = true ]; then
  echo "Removing unused assets..."
  python3 ./asset-cleaner/main_rpgmaker_strip_files.py -e titles2 -n -i "$www_folder"
  rm -rf "$www_folder"/removed
fi

if [ "$webp" = true ]; then
  echo "Converting images to webp..."
  if [ "$lossless" = true ]; then
  	echo "Converting lossessly..."
  	./optimize-lossless.sh "$game_exe_path"
  else
    ./optimize.sh "$game_exe_path"
  fi
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

if [ "$vp9" = true ]; then
  echo "Converting Videos to vp9..."
  ./vp9.sh "$www_folder"
fi

if [ -n "$images_encrypted" ]; then
  echo "Images were encrypted. Encrypting..."
  mkdir ./encrypt
  java -jar RPG.Maker.MV.Decrypter_0.4.2.jar encrypt "$www_folder" ./encrypt 
  find "$www_folder/img" -mindepth 1 -maxdepth 1 ! -name 'system' -exec rm -rf {} +
  rm -rf "$www_folder"/audio
  new_www_folder=$(find ./encrypt -type d -name "www" -print -quit)
  cp -r "$new_www_folder"/* "$www_folder"
  rm -rf ./encrypt
fi

if [ "$pixi" = true ]; then
  echo "Upgrading pixi.js..."
  ./libs-update.sh "$game_exe_path"
fi

if [ -n "$www_folder" ]; then
  # If 'www' folder exists, copy it to the uncompressed nwjs folder
  cp -r "$www_folder" win-linux/www
  cp -r "$www_folder" nwjs-sdk-v"$nwjsv"-osx-arm64/nwjs.app/Contents/Resources/app.nw
  cp -r "$www_folder" nwjs-sdk-v"$nwjsv"-osx-x64/nwjs.app/Contents/Resources/app.nw
  # Put the game name in package.json so it runs
  game_name=$(basename "$input_file" | sed 's/\(.*\)\..*/\1/')
  jq ".name = \"$game_name\"" package.json.old > package.json
  rm -rf ./package.json.old
  cp package.json win-linux/
  cp package.json nwjs-sdk-v"$nwjsv"-osx-arm64/nwjs.app/Contents/Resources/app.nw
  cp package.json nwjs-sdk-v"$nwjsv"-osx-x64/nwjs.app/Contents/Resources/app.nw
else
  echo "www folder missing"
  exit
fi

# Copy run files to the win-linux folder
cp start.sh win-linux/
cp update-patch.sh win-linux/
cp nwjs-manager.sh win-linux/
cp pacapt win-linux/
cp start.bat win-linux/
cp update-patch.bat win-linux/

# Extract name without extension and append Operating systems

new_linux_folder_name=$(basename "$input_file" | sed 's/\(.*\)\..*/\1/')"-Win-Linux"
mv win-linux "$new_linux_folder_name"

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
	new_win_archive_name=$(basename "$input_file" | sed 's/\(.*\)\..*/\1/')"-windows.7z"
    new_linux_archive_name=$(basename "$input_file" | sed 's/\(.*\)\..*/\1/')"-Win-Linux.7z"
    7z a -mx1 -mf- -m0=lzma2:a0 "$new_linux_archive_name" ./"$new_linux_folder_name"
    if [ "$upload" = true ]; then
      json_data=$(curl -s https://api.gofile.io/getServer)
      store_value=$(echo "$json_data" | jq -r '.data.server')
      echo https://pixeldrain.com/u/$(curl --connect-timeout 5 --max-time "$upload_timeout" --retry 5 --retry-delay 0 --retry-max-time 40 --limit-rate 30M -T "$new_linux_archive_name" https://pixeldrain.com/api/file/ | jq -r '.id') >> pixeldrain.txt &
      curl --connect-timeout 5 --max-time "$upload_timeout" --retry 5 --retry-delay 0 --retry-max-time 40 -F file=@"$new_linux_archive_name" https://"$store_value".gofile.io/uploadFile | jq -r '.data.downloadPage'>> gofile.txt &
    fi

    new_osx_x64_archive_name=$(basename "$input_file" | sed 's/\(.*\)\..*/\1/')"-macos-x64.7z"
    7z a -mx1 -mf- -m0=lzma2:a0 "$new_osx_x64_archive_name" ./"$new_osx_x64_folder_name"
    if [ "$upload" = true ]; then
      json_data=$(curl -s https://api.gofile.io/getServer)
      store_value=$(echo "$json_data" | jq -r '.data.server')
      echo https://pixeldrain.com/u/$(curl --connect-timeout 5 --max-time "$upload_timeout" --retry 5 --retry-delay 0 --retry-max-time 40 --limit-rate 30M -T "$new_osx_x64_archive_name" https://pixeldrain.com/api/file/ | jq -r '.id') >> pixeldrain.txt &
      curl --connect-timeout 5 --max-time "$upload_timeout" --retry 5 --retry-delay 0 --retry-max-time 40 -F file=@"$new_osx_x64_archive_name" https://"$store_value".gofile.io/uploadFile | jq -r '.data.downloadPage' >> gofile.txt &
    fi
  
    new_osx_arm64_archive_name=$(basename "$input_file" | sed 's/\(.*\)\..*/\1/')"-macos-arm64.7z"
    7z a -mx1 -mf- -m0=lzma2:a0 "$new_osx_arm64_archive_name" ./"$new_osx_arm64_folder_name"
    if [ "$upload" = true ]; then
      json_data=$(curl -s https://api.gofile.io/getServer)
      store_value=$(echo "$json_data" | jq -r '.data.server')
      echo https://pixeldrain.com/u/$(curl --connect-timeout 5 --max-time "$upload_timeout" --retry 5 --retry-delay 0 --retry-max-time 40 --limit-rate 30M -T "$new_osx_arm64_archive_name" https://pixeldrain.com/api/file/ | jq -r '.id') >> pixeldrain.txt &
      curl --connect-timeout 5 --max-time "$upload_timeout" --retry 5 --retry-delay 0 --retry-max-time 40 -F file=@"$new_osx_arm64_archive_name" https://"$store_value".gofile.io/uploadFile | jq -r '.data.downloadPage' >> gofile.txt &
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
