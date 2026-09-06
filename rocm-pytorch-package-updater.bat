@echo off
setlocal enabledelayedexpansion
cls
title comfyui-rocm - ROCm / PyTorch Package Updater

for /f %%a in ('echo prompt $E ^| cmd') do set "ESC=%%a"
set "GREEN=%ESC%[32m"
set "YELLOW=%ESC%[33m"
set "RED=%ESC%[31m"
set "CYAN=%ESC%[36m"
set "RESET=%ESC%[0m"

:: Parse --debug flag (mirrors install.bat)
set "Q=>nul 2>&1"
set "QQ=--quiet"
for %%A in (%*) do (
    if /I "%%A"=="--debug" (
        set "Q="
        set "QQ=--verbose"
    )
)

echo %CYAN%====================================================%RESET%
echo %CYAN%   comfyui-rocm - ROCm / PyTorch Package Updater%RESET%
echo %CYAN%====================================================%RESET%
echo.

set "INSTALL_DIR=%~dp0"
if "%INSTALL_DIR:~-1%"=="\" set "INSTALL_DIR=%INSTALL_DIR:~0,-1%"
set "PYTHON=%INSTALL_DIR%\python_env\python.exe"

echo %GREEN%[*]%RESET% Install dir : %INSTALL_DIR%
echo %GREEN%[*]%RESET% Python      : %PYTHON%
echo.

if not exist "%PYTHON%" (
    echo %RED%[!]%RESET% Python not found at: %PYTHON%
    echo %RED%[!]%RESET% Run install.bat first.
    pause
    exit /b 1
)

cd /d "%INSTALL_DIR%"

if not exist "detect_gpu.py" (
    echo %RED%[!]%RESET% detect_gpu.py not found in %INSTALL_DIR%
    pause
    exit /b 1
)

:: -------------------------------------------------------
:: 1. Detect GPU architecture
:: -------------------------------------------------------
echo %GREEN%[*]%RESET% Detecting GPU...
set "arch="
for /f "delims=" %%A in ('.\python_env\python.exe detect_gpu.py 2^>"%INSTALL_DIR%\gpu_detect_debug.log"') do (
    if not "%%A"=="" set "arch=%%A"
)

if "!arch!"=="" (
    echo %RED%[!]%RESET% GPU detection failed or unsupported GPU
    echo.
    type "%INSTALL_DIR%\gpu_detect_debug.log" 2>nul
    pause
    exit /b 1
)

echo %GREEN%[*]%RESET% Detected GPU architecture: %CYAN%!arch!%RESET%
echo.

:: -------------------------------------------------------
:: 2. Build the uninstall list.
:: -------------------------------------------------------
echo %GREEN%[*]%RESET% Scanning current environment for ROCm/PyTorch packages...

set "UNINSTALL_LIST=rocm rocm-sdk-devel rocm-sdk-core rocm-sdk-libraries torch torchaudio torchvision"

for /f "delims=" %%P in ('.\python_env\python.exe -m pip freeze ^| findstr /I /R "^rocm ^amd-torch ^amd-torchvision"') do (
    for /f "tokens=1 delims=<>=~! " %%N in ("%%P") do (
        echo !UNINSTALL_LIST! | findstr /I /C:"%%N" >nul
        if errorlevel 1 set "UNINSTALL_LIST=!UNINSTALL_LIST! %%N"
    )
)

echo %GREEN%[*]%RESET% Packages to remove:%CYAN% !UNINSTALL_LIST!%RESET%
echo.

echo %GREEN%[*]%RESET% Uninstalling old ROCm / PyTorch packages...
.\python_env\python.exe -m pip uninstall -y !UNINSTALL_LIST! %Q%
echo.

:: -------------------------------------------------------
:: 3. Reinstall - same branching as install.bat:
:: -------------------------------------------------------
set "USE_LEGACY_URL=0"
for %%G in (gfx942 gfx950) do (
    if /I "!arch!"=="%%G" set "USE_LEGACY_URL=1"
)

if !USE_LEGACY_URL!==1 (
    echo %YELLOW%[*]%RESET% Using legacy URL for %CYAN%!arch!%RESET% - Not available in multi-arch yet
    echo %GREEN%[*]%RESET% Installing ROCm for !arch!...
    .\python_env\python.exe -m pip install --no-cache-dir rocm[devel,libraries] --index-url https://rocm.nightlies.amd.com/v2-staging/!arch!-dcgpu/ %Q%
    if errorlevel 1 goto :update_failed
    .\python_env\Scripts\rocm-sdk init %Q%
    if errorlevel 1 echo %YELLOW%[!]%RESET% Warning: rocm-sdk init failed, continuing anyway...
    echo %GREEN%[*]%RESET% Installing PyTorch for !arch!...
    .\python_env\python.exe -m pip install --no-cache-dir --index-url https://rocm.nightlies.amd.com/v2-staging/!arch!-dcgpu/ torch torchaudio torchvision %Q%
    if errorlevel 1 goto :update_failed
) else (
    echo %GREEN%[*]%RESET% Using multi-arch ROCm nightly for %CYAN%!arch!%RESET%
    .\python_env\python.exe -m pip install "torch[device-!arch!]" "torchvision[device-!arch!]" torchaudio rocm-sdk-devel --no-cache-dir --pre --index-url https://nightly.repo.amd.com/rocm/whl-next/ %Q%
    if errorlevel 1 goto :update_failed
)

:: -------------------------------------------------------
:: 4. Verify
:: -------------------------------------------------------
echo.
echo %CYAN%------------------------------------------------------------%RESET%
echo %CYAN%  PYTORCH CONFIGURATION%RESET%
echo %CYAN%------------------------------------------------------------%RESET%
.\python_env\python.exe -c "import torch; print(f'  PyTorch Version: {torch.__version__}'); print(f'  ROCm Available: {torch.cuda.is_available()}'); print(f'  HIP Version: {torch.version.hip if torch.cuda.is_available() else \"N/A\"}'); print(f'  Device Count: {torch.cuda.device_count() if torch.cuda.is_available() else 0}'); print(f'  Device Name: {torch.cuda.get_device_name(0) if torch.cuda.is_available() else \"No ROCm device detected\"}')"

echo.
echo %GREEN%====================================================%RESET%
echo %GREEN%  ROCm / PyTorch update complete!%RESET%
echo %GREEN%  GPU Architecture: !arch!%RESET%
echo %GREEN%====================================================%RESET%
goto :end

:update_failed
echo.
echo %RED%====================================================%RESET%
echo %RED%  Update failed!%RESET%
echo %RED%  Check the error messages above for details.%RESET%
echo %RED%====================================================%RESET%
goto :end

:end
pause
