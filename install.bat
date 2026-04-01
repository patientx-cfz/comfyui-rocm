@echo off
setlocal enabledelayedexpansion
title ComfyUI - AMD ROCM Installer
echo ===================================================
echo   ComfyUI - AMD ROCM - Automatic Installer
echo   (AMD RDNA2-RDNA3-RDNA4)
echo ===================================================
echo.

:: 1. Check if Python exists
if exist "python_env\.\python_env\python.exe" (
    echo [*] Python environment found. Skipping download.
    goto :INSTALL_PACKAGES
)

:: 2. Download Python Portable (3.12.9)
echo [*] [1/4] Downloading Python 3.12 Portable...
if not exist "python_env" mkdir "python_env"
curl -L "https://www.python.org/ftp/python/3.12.9/python-3.12.9-embed-amd64.zip" -o "python_env\python.zip"

:: 3. Unzip
echo [*] [2/4] Extracting Python...
tar -xf "python_env\python.zip" -C "python_env"
del "python_env\python.zip"

:: 4. Patch ._pth file (enable import site)
echo [*] [3/4] Configuring Python...
(
echo python312.zip
echo .
echo import site
) > "python_env\python312._pth"

:: 5. Install Pip
echo [*] [4/4] Installing Pip Package Manager...
curl -L "https://bootstrap.pypa.io/get-pip.py" -o "get-pip.py"
.\python_env\python.exe get-pip.py --no-warn-script-location
del "get-pip.py"

:detect_gpu
echo.
echo [*] Detecting GPU...
for /f "delims=" %%A in ('.\python_env\python.exe detect_gpu.py 2^>nul') do (
    if not "%%A"=="" (
        set "arch=%%A"
    )
)

if "!arch!"=="" (
    echo GPU detection failed or unsupported GPU
    pause
    exit /b 1
)

echo [*] Detected GPU architecture: !arch!
echo.

:: Install PyTorch based on detected GPU
if "!arch!"=="gfx103X" (
    echo [*] Installing PyTorch for RDNA2 ^(gfx103X^)...
	echo.
    .\python_env\python.exe -m pip install --pre torch==2.10 torchaudio==2.10 torchvision --index-url https://rocm.nightlies.amd.com/v2-staging/gfx103X-dgpu/ --no-warn-script-location
    if errorlevel 1 goto :install_failed
    goto :install_requirements
)

if "!arch!"=="gfx110X" (
    echo [*] Installing PyTorch for RDNA3 ^(gfx110X^)...
	echo.
    .\python_env\python.exe -m pip install --pre torch==2.10 torchaudio==2.10 torchvision --index-url https://rocm.nightlies.amd.com/v2/gfx110X-all/ --no-warn-script-location
    if errorlevel 1 goto :install_failed
    goto :install_requirements
)

if "!arch!"=="gfx1150" (
    echo [*] Installing PyTorch for Strix Point ^(gfx1150^)...
	echo.
    .\python_env\python.exe -m pip install --pre torch==2.10 torchaudio==2.10 torchvision --index-url https://rocm.nightlies.amd.com/v2-staging/gfx1150/ --no-warn-script-location
    if errorlevel 1 goto :install_failed
    goto :install_requirements
)

if "!arch!"=="gfx1151" (
    echo [*] Installing PyTorch for Strix Halo ^(gfx1151^)...
	echo.
    .\python_env\python.exe -m pip install --pre torch==2.10 torchaudio==2.10 torchvision --index-url https://rocm.nightlies.amd.com/v2/gfx1151/ --no-warn-script-location
    if errorlevel 1 goto :install_failed
    goto :install_requirements
)

if "!arch!"=="gfx1152" (
    echo [*] Installing PyTorch for Krackan Point ^(gfx1152^)...
	echo.
    .\python_env\python.exe -m pip install --pre torch==2.10 torchaudio==2.10 torchvision --index-url https://rocm.nightlies.amd.com/v2-staging/gfx1152/ --no-warn-script-location
    if errorlevel 1 goto :install_failed
    goto :install_requirements
)

if "!arch!"=="gfx1153" (
    echo [*] Installing PyTorch for RDNA 3.5 ^(gfx1153^)...
	echo.
    .\python_env\python.exe -m pip install --pre torch==2.10 torchaudio==2.10 torchvision --index-url https://rocm.nightlies.amd.com/v2-staging/gfx1153/ --no-warn-script-location
    if errorlevel 1 goto :install_failed
    goto :install_requirements
)

if "!arch!"=="gfx120X" (
    echo [*] Installing PyTorch for RDNA4 ^(gfx120X^)...
	echo.
    .\python_env\python.exe -m pip install --pre torch==2.10 torchaudio==2.10 torchvision --index-url https://rocm.nightlies.amd.com/v2/gfx120X-all/ --no-warn-script-location
    if errorlevel 1 goto :install_failed
    goto :install_requirements
)

if "!arch!"=="gfx90X" (
    echo [*] Installing PyTorch for Radeon Pro VII ^(gfx90X^)...
	echo.
    .\python_env\python.exe -m pip install --pre torch==2.10 torchaudio==2.10 torchvision --index-url https://rocm.nightlies.amd.com/v2-staging/gfx90X-dcgpu/ --no-warn-script-location
    if errorlevel 1 goto :install_failed
    goto :install_requirements
)

if "!arch!"=="gfx94X" (
    echo [*] Installing PyTorch for MI300/MI325 ^(gfx94X^)...
	echo.
    .\python_env\python.exe -m pip install --pre torch==2.10 torchaudio==2.10 torchvision --index-url https://rocm.nightlies.amd.com/v2-staging/gfx94X-dcgpu/ --no-warn-script-location
    if errorlevel 1 goto :install_failed
    goto :install_requirements
)

if "!arch!"=="gfx950" (
    echo [*] Installing PyTorch for MI350/MI355 ^(gfx950^)...
	echo.
    .\python_env\python.exe -m pip install --pre torch==2.10 torchaudio==2.10 torchvision --index-url https://rocm.nightlies.amd.com/v2-staging/gfx950-dcgpu/ --no-warn-script-location
    if errorlevel 1 goto :install_failed
    goto :install_requirements
)

echo [*] Unknown GPU architecture detected: !arch!
pause
exit /b 1

:install_requirements
echo.
echo [*] Installing ComfyUI - AMD ROCM ...
.\python_env\python.exe -m pip install --upgrade pip
.\python_env\python.exe -m pip install -r requirements.txt --no-warn-script-location
if errorlevel 1 goto :install_failed
goto :install_complete

:install_failed
echo.
echo ===================================================
echo   Installation Failed!
echo ===================================================
pause
exit /b 1

:install_complete
echo.
echo ===================================================
echo   Installation Complete!
echo   Run "start.bat" to start qwen-tts...
echo ===================================================
pause
exit /b 0
