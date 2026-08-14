@echo off
cls
title comfyui-rocm Updater

echo ====================================================
echo  comfyui-rocm - Updater
echo ====================================================
echo.

:: Check if git is available
where git >nul 2>&1
if errorlevel 1 (
    echo [!] Git not found. Please install Git from https://git-scm.com/download/win
    pause
    exit /b 1
)

:: INSTALL_DIR = folder where this .bat lives, no trailing backslash
set "INSTALL_DIR=%~dp0"
if "%INSTALL_DIR:~-1%"=="\" set "INSTALL_DIR=%INSTALL_DIR:~0,-1%"

set "REPO_URL=https://github.com/patientx-cfz/comfyui-rocm"
set "TEMP_DIR=%INSTALL_DIR%\_update_temp"
set "PYTHON=%INSTALL_DIR%\python_env\python.exe"
set "HASH_FILE=%INSTALL_DIR%\.last_update_hash"

echo [*] Install dir : %INSTALL_DIR%
echo [*] Python      : %PYTHON%
echo.

:: Verify python exists before doing anything
if not exist "%PYTHON%" (
    echo [!] Python not found at: %PYTHON%
    echo [!] Make sure python_env is present in: %INSTALL_DIR%
    pause
    exit /b 1
)

echo [*] Checking for updates...
echo.

:: Get latest remote commit hash via git ls-remote (no clone needed)
set "REMOTE_HASH="
for /f "tokens=1" %%i in ('git ls-remote "%REPO_URL%" HEAD 2^>nul') do set "REMOTE_HASH=%%i"

if "%REMOTE_HASH%"=="" (
    echo [!] Could not reach GitHub. Check your internet connection.
    pause
    exit /b 1
)

:: Read locally stored hash from previous update (if any)
set "LOCAL_HASH=none"
if exist "%HASH_FILE%" set /p LOCAL_HASH=<"%HASH_FILE%"

echo [*] Remote commit : %REMOTE_HASH%
echo [*] Local  commit : %LOCAL_HASH%
echo.

if /i "%REMOTE_HASH%"=="%LOCAL_HASH%" (
    echo [*] You are already on the latest version. Nothing to do.
    echo.
    pause
    exit /b 0
)

echo [*] New version found - downloading...
echo.

:: Clone repo into temp folder (shallow)
if exist "%TEMP_DIR%" rd /s /q "%TEMP_DIR%"
git clone --depth 1 --quiet "%REPO_URL%" "%TEMP_DIR%"
if errorlevel 1 (
    echo [!] Failed to clone repository. Check your internet connection.
    if exist "%TEMP_DIR%" rd /s /q "%TEMP_DIR%"
    pause
    exit /b 1
)

echo [*] Applying updates...

:: robocopy exit codes 0-7 = success/partial success, 8+ = real errors
robocopy "%TEMP_DIR%" "%INSTALL_DIR%" /E /XD "%TEMP_DIR%\python_env" "%TEMP_DIR%\models" "%TEMP_DIR%\output" "%TEMP_DIR%\input" "%TEMP_DIR%\user" "%TEMP_DIR%\custom_nodes" /XF "comfyui-user.bat" /NFL /NDL /NJH /NJS
if errorlevel 8 (
    echo [!] Robocopy reported an error. Some files may not have updated.
)

:: Clean up temp
rd /s /q "%TEMP_DIR%"

echo [*] Checking Python dependencies...

:: Filter out torch/torchvision lines so pip never overwrites the pinned ROCm build
"%PYTHON%" -c "import re; lines=open(r'%INSTALL_DIR%\requirements.txt').readlines(); pat=re.compile(r'^\s*(torch|torchvision|torchaudio)\s*([=<>!~]|$)', re.I); out=[l for l in lines if not pat.match(l)]; open(r'%INSTALL_DIR%\requirements_filtered.txt','w').writelines(out)"

"%PYTHON%" -m pip install -r "%INSTALL_DIR%\requirements_filtered.txt" --no-warn-script-location --quiet
if errorlevel 1 (
    echo [!] Warning: dependency update had errors. comfyui-rocm may still work.
) else (
    echo [*] Dependencies are up to date.
)

:: Save remote hash so next run can detect if already current
echo %REMOTE_HASH%> "%HASH_FILE%"

echo.
echo ====================================================
echo  Update complete!
echo  Installed commit: %REMOTE_HASH%
echo  Your models, outputs, and custom_nodes were kept.
echo ====================================================
echo.
pause
