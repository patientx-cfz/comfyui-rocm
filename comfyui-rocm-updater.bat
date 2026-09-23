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
    echo [*] Core repo already on the latest version. Checking custom nodes / packages...
    echo.
    goto :SkipCoreUpdate
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

:: If the updater script itself changed, relaunch the new copy under a
:: different filename before doing anything else. Robocopy below excludes
:: our own running filename (Windows can corrupt a batch file that gets
:: overwritten while it's still open/executing), so without this, anyone
:: already running the old updater.bat would never receive updater changes -
:: only files other than itself would ever get updated for them.
if /i not "%~nx0"=="_updater_relaunch.bat" (
    fc /b "%TEMP_DIR%\%~nx0" "%~f0" >nul 2>&1
    if errorlevel 1 (
        echo [*] Updater script itself changed - relaunching new version...
        copy /y "%TEMP_DIR%\%~nx0" "%INSTALL_DIR%\_updater_relaunch.bat" >nul
        rd /s /q "%TEMP_DIR%"
        start "" "%INSTALL_DIR%\_updater_relaunch.bat"
        exit /b 0
    )
)

echo [*] Applying updates...

:: robocopy exit codes 0-7 = success/partial success, 8+ = real errors
robocopy "%TEMP_DIR%" "%INSTALL_DIR%" /E /XD "%TEMP_DIR%\python_env" "%TEMP_DIR%\models" "%TEMP_DIR%\output" "%TEMP_DIR%\input" "%TEMP_DIR%\user" "%TEMP_DIR%\custom_nodes" /XF "comfyui-user.bat" "%~nx0" /NFL /NDL /NJH /NJS
if errorlevel 8 (
    echo [!] Robocopy reported an error. Some files may not have updated.
)

:: Clean up temp
rd /s /q "%TEMP_DIR%"

:: Save remote hash so next run can detect if already current
echo %REMOTE_HASH%> "%HASH_FILE%"

:SkipCoreUpdate

echo [*] Updating tracked custom nodes...
echo.

set "CUSTOM_NODES_DIR=%INSTALL_DIR%\custom_nodes"
if not exist "%CUSTOM_NODES_DIR%" mkdir "%CUSTOM_NODES_DIR%"

call :UpdateCustomNode "ComfyUI-Manager" "https://github.com/Comfy-Org/ComfyUI-Manager"
call :UpdateCustomNode "ComfyUI-INT8-Fast-ROCM" "https://github.com/patientx/ComfyUI-INT8-Fast-ROCM"
call :UpdateCustomNode "comfyui-h3-sla-attention-rocm" "https://github.com/patientx/comfyui-h3-sla-attention-rocm"

echo [*] Checking sageattention...
call :UpdateSageAttention

echo.

echo [*] Checking Python dependencies...

set "PYTHONNOUSERSITE=1"

:: Filter out torch/torchvision lines so pip never overwrites the pinned ROCm build
"%PYTHON%" -c "import re; lines=open(r'%INSTALL_DIR%\requirements.txt').readlines(); pat=re.compile(r'^\s*(torch|torchvision|torchaudio)\s*([=<>!~]|$)', re.I); out=[l for l in lines if not pat.match(l)]; open(r'%INSTALL_DIR%\requirements_filtered.txt','w').writelines(out)"

:: snapshot installed versions before the update
"%PYTHON%" -m pip freeze --quiet > "%INSTALL_DIR%\_pre_freeze.txt" 2>nul

"%PYTHON%" -m pip install -r "%INSTALL_DIR%\requirements_filtered.txt" --no-warn-script-location --quiet
if errorlevel 1 (
    echo [!] Warning: dependency update had errors. comfyui-rocm may still work.
) else (
    echo [*] Dependencies are up to date.
)

:: snapshot again and report what actually changed
"%PYTHON%" -m pip freeze --quiet > "%INSTALL_DIR%\_post_freeze.txt" 2>nul

echo.
echo [*] Package changes:
"%PYTHON%" -c "import re; pat=re.compile(r'^([^=]+)==(.+)$'); pre={}; post={};[pre.update({(m:=pat.match(l.strip())) and m.group(1).lower(): m.group(2)}) for l in open(r'%INSTALL_DIR%\_pre_freeze.txt', encoding='utf-8', errors='ignore') if pat.match(l.strip())]; [post.update({(m:=pat.match(l.strip())) and m.group(1).lower(): m.group(2)}) for l in open(r'%INSTALL_DIR%\_post_freeze.txt', encoding='utf-8', errors='ignore') if pat.match(l.strip())]; changed=[(k, pre.get(k,'new'), v) for k,v in post.items() if pre.get(k)!=v]; print('  none') if not changed else [print(f'  {k}: {a} -> {b}') for k,a,b in sorted(changed)]"

del "%INSTALL_DIR%\_pre_freeze.txt" 2>nul
del "%INSTALL_DIR%\_post_freeze.txt" 2>nul

echo.
echo ====================================================
echo  Update complete!
echo  Installed commit: %REMOTE_HASH%
echo  Your models, outputs, and custom_nodes were kept.
echo ====================================================
echo.
if /i "%~nx0"=="_updater_relaunch.bat" del "%~f0" >nul 2>&1
pause
goto :EOF

:UpdateCustomNode
set "NODE_NAME=%~1"
set "NODE_URL=%~2"
set "NODE_DIR=%CUSTOM_NODES_DIR%\%NODE_NAME%"

if exist "%NODE_DIR%\.git" (
    echo [*] Updating %NODE_NAME%...
    git -C "%NODE_DIR%" pull --ff-only --quiet
    if errorlevel 1 (
        echo [!] %NODE_NAME%: git pull failed ^(local changes or diverged history^) - update it manually.
    )
) else if exist "%NODE_DIR%" (
    echo [!] %NODE_NAME% exists but is not a git checkout - skipping, update it manually.
) else (
    echo [*] Installing %NODE_NAME%...
    git clone --quiet "%NODE_URL%" "%NODE_DIR%"
    if errorlevel 1 (
        echo [!] Failed to clone %NODE_NAME%.
    )
)
exit /b 0

:UpdateSageAttention
:: sageattention isn't a git checkout - it's a wheel installed via pip.
:: The version string (2.2.0) doesn't change between rebuilds, so --force-reinstall
:: is required or pip will think it's already satisfied and skip the update.
:: gfx1201 uses the native compiled wheel; all other GPUs keep sageattention-autotune.
:: Autotune asset filename must stay "sageattention-2.2.0-py3-none-any.whl".
:: Native gfx1201 asset filename must stay "sageattention-2.2.0-cp312-cp312-win_amd64.whl".
set "SAGE_ARCH="
if exist "%INSTALL_DIR%\detect_gpu.py" (
    for /f "delims=" %%A in ('call "%PYTHON%" "%INSTALL_DIR%\detect_gpu.py" 2^>nul') do set "SAGE_ARCH=%%A"
)
if /I "%SAGE_ARCH%"=="gfx1201" (
    set "SAGE_WHEEL_URL=https://github.com/thehybrid1337/sageattention-rocm-gfx1201-win/releases/latest/download/sageattention-2.2.0-cp312-cp312-win_amd64.whl"
    set "SAGE_LABEL=sageattention native gfx1201"
) else (
    set "SAGE_WHEEL_URL=https://github.com/patientx/sageattention-autotune/releases/latest/download/sageattention-2.2.0-py3-none-any.whl"
    set "SAGE_LABEL=sageattention-autotune"
)

"%PYTHON%" -m pip install --upgrade --force-reinstall --no-deps --quiet "%SAGE_WHEEL_URL%"
if errorlevel 1 (
    echo [!] %SAGE_LABEL%: update failed - check your internet connection.
) else (
    echo [*] %SAGE_LABEL% is up to date.
)
exit /b 0
