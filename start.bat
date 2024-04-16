@echo off
setlocal EnableDelayedExpansion

call update-patch.bat

set "nwjs_loc=%LOCALAPPDATA%\porter\nwjs\nw.exe"
set "nwjs_version=0.84.0"

if not exist %nwjs_loc% (
    echo nwjs not found!
    set /p choice="Do you want to download nwjs %nwjs_version% (required)? (Y/N): "
        if /i "!choice!"=="Y" (
        echo Downloading version %nwjs_version%...
        mkdir "%LOCALAPPDATA%\porter\nwjs"
        powershell -Command "(New-Object Net.WebClient).DownloadFile('https://dl.nwjs.io/v0.84.0/nwjs-sdk-v0.84.0-win-x64.zip', '%TEMP%\nwjs.zip')"
        powershell -Command "Expand-Archive -Path '%TEMP%\nwjs.zip' -DestinationPath '%LOCALAPPDATA%\porter\nwjs'"
        xcopy /s /e /y "%LOCALAPPDATA%\porter\nwjs\nwjs-sdk-v%nwjs_version%-win-x64\*" "%LOCALAPPDATA%\porter\nwjs\"
        del /s /q "%LOCALAPPDATA%\porter\nwjs\nwjs-sdk-v%nwjs_version%-win-x64"
        del "%TEMP%\nwjs.zip"
    ) else (
        echo "nwjs install declined."
        exit /b
    )
)

if exist .\www\ (
    if exist .\package.json (
        echo www folder and package.json found!
    ) else (
        echo package.json missing!
        exit /b
    )
) else (
    echo www folder missing!
    exit /b
)

echo Starting application...
start "" "%nwjs_loc%" .
echo Application finished.

endlocal