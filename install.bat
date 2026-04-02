@echo off
cls
setlocal enabledelayedexpansion
title comfyui-rocm Installer
echo ====================================================
echo        comfyui-rocm - Automatic Installer
echo [AMD RDNA1 * RDNA2 * RDNA3 * RDNA4 (6000s to 9000s)]
echo ====================================================
echo.

:: 1. Check if Python exists
if exist "python_env\python.exe" (
    echo [*] Python environment found. Skipping download.
    goto :setup_environment
)

:: 2. Download Python Portable (3.12.9)
echo [*] [1/5] Downloading Python 3.12 Portable...
if not exist "python_env" mkdir "python_env"
curl -L "https://www.python.org/ftp/python/3.12.9/python-3.12.9-embed-amd64.zip" -o "python_env\python.zip" >nul 2>&1
if errorlevel 1 (
    echo [!] Error: Failed to download Python
    pause
    exit /b 1
)

:: 3. Unzip
echo [*] [2/5] Extracting Python...
tar -xf "python_env\python.zip" -C "python_env" >nul 2>&1
if errorlevel 1 (
    echo [!] Error: Failed to extract Python
    pause
    exit /b 1
)
del "python_env\python.zip"

:: 4. Patch ._pth file (enable import site)
echo [*] [3/5] Configuring Python...
(
echo python312.zip
echo ..
echo import site
) > "python_env\python312._pth"

:: 5. Install Pip
echo [*] [4/5] Installing Pip Package Manager...
curl -L "https://bootstrap.pypa.io/get-pip.py" -o "get-pip.py" >nul 2>&1
if errorlevel 1 (
    echo [!] Error: Failed to download get-pip.py
    pause
    exit /b 1
)
.\python_env\python.exe get-pip.py --no-warn-script-location >nul 2>&1
if errorlevel 1 (
    echo [!] Error: Failed to install pip
    pause
    exit /b 1
)
del "get-pip.py"

:: 6. Install build Tools
echo [*] [5/5] Installing Build Tools...
.\python_env\python.exe -m pip install --upgrade pip setuptools wheel --no-warn-script-location >nul 2>&1
if errorlevel 1 (
    echo [!] Error: Failed to install build tools
    pause
    exit /b 1
)

:setup_environment
:: Set PATH for portable installation
set "PYTHON_DIR=%~dp0python_env"
set "PATH=%PYTHON_DIR%;%PYTHON_DIR%\Scripts;%PATH%"

:detect_gpu
echo.
echo [*] Detecting GPU...

:: Check if detect_gpu.py exists
if not exist "detect_gpu.py" (
    echo [!] Error: detect_gpu.py not found!
    pause
    exit /b 1
)

for /f "delims=" %%A in ('.\python_env\python.exe detect_gpu.py 2^>nul') do (
    if not "%%A"=="" (
        set "arch=%%A"
    )
)

if "!arch!"=="" (
    echo [!] GPU detection failed or unsupported GPU
    pause
    exit /b 1
)

echo [*] Detected GPU architecture: !arch!

:: Install PyTorch based on detected GPU
if "!arch!"=="gfx101X" (
    echo [*] Installing ROCm for RDNA1 ^(gfx101X^)...
    .\python_env\python.exe -m pip install rocm[devel,libraries] --index-url https://rocm.nightlies.amd.com/v2-staging/gfx101X-dgpu/ --no-warn-script-location >nul 2>&1
    if errorlevel 1 goto :install_failed
    .\python_env\scripts\rocm-sdk init >nul 2>&1 
    if errorlevel 1 (
        echo [!] Warning: rocm-sdk init failed, continuing anyway...
    )
	echo [*] Installing PyTorch for RDNA1 ^(gfx101X^)...
    .\python_env\python.exe -m pip install --index-url https://rocm.nightlies.amd.com/v2-staging/gfx101X-dgpu/ torch torchaudio torchvision --no-warn-script-location >nul 2>&1
    if errorlevel 1 goto :install_failed
    goto :install_requirements
)

if "!arch!"=="gfx103X" (
    echo [*] Installing ROCm for RDNA2 ^(gfx103X^)...
    .\python_env\python.exe -m pip install rocm[devel,libraries] --index-url https://rocm.nightlies.amd.com/v2-staging/gfx103X-dgpu/ --no-warn-script-location >nul 2>&1
    if errorlevel 1 goto :install_failed
    .\python_env\scripts\rocm-sdk init >nul 2>&1 
    if errorlevel 1 (
        echo [!] Warning: rocm-sdk init failed, continuing anyway...
    )
	echo [*] Installing PyTorch for RDNA2 ^(gfx103X^)...
    .\python_env\python.exe -m pip install --index-url https://rocm.nightlies.amd.com/v2-staging/gfx103X-dgpu/ torch torchaudio torchvision --no-warn-script-location >nul 2>&1
    if errorlevel 1 goto :install_failed
    goto :install_requirements
)

if "!arch!"=="gfx110X" (
    echo [*] Installing ROCm for RDNA3 ^(gfx110X^)...
    .\python_env\python.exe -m pip install rocm[devel,libraries] --index-url https://rocm.nightlies.amd.com/v2/gfx110X-all/ --no-warn-script-location >nul 2>&1
    if errorlevel 1 goto :install_failed
    .\python_env\scripts\rocm-sdk init >nul 2>&1 
    if errorlevel 1 (
        echo [!] Warning: rocm-sdk init failed, continuing anyway...
    )
	echo [*] Installing PyTorch for RDNA3 ^(gfx110X^)...
    .\python_env\python.exe -m pip install --index-url https://rocm.nightlies.amd.com/v2/gfx110X-all/ torch torchaudio torchvision --no-warn-script-location >nul 2>&1	
    if errorlevel 1 goto :install_failed
    goto :install_requirements
)

if "!arch!"=="gfx1150" (
    echo [*] Installing ROCm for Strix Point ^(gfx1150^)...
    .\python_env\python.exe -m pip install rocm[devel,libraries] --index-url https://rocm.nightlies.amd.com/v2-staging/gfx1150/ --no-warn-script-location >nul 2>&1
    if errorlevel 1 goto :install_failed
    .\python_env\scripts\rocm-sdk init >nul 2>&1 
    if errorlevel 1 (
        echo [!] Warning: rocm-sdk init failed, continuing anyway...
    )
	echo [*] Installing PyTorch for Strix Point ^(gfx1150^)...
    .\python_env\python.exe -m pip install --index-url https://rocm.nightlies.amd.com/v2-staging/gfx1150/ torch torchaudio torchvision --no-warn-script-location >nul 2>&1
    if errorlevel 1 goto :install_failed
    goto :install_requirements
)

if "!arch!"=="gfx1151" (
    echo [*] Installing ROCm for Strix Halo ^(gfx1151^)...
    .\python_env\python.exe -m pip install rocm[devel,libraries] --index-url https://rocm.nightlies.amd.com/v2/gfx1151/ --no-warn-script-location >nul 2>&1
    if errorlevel 1 goto :install_failed
    .\python_env\scripts\rocm-sdk init >nul 2>&1 
    if errorlevel 1 (
        echo [!] Warning: rocm-sdk init failed, continuing anyway...
    )
	echo [*] Installing PyTorch for Strix Halo ^(gfx1151^)...
    .\python_env\python.exe -m pip install --index-url https://rocm.nightlies.amd.com/v2/gfx1151/ torch torchaudio torchvision --no-warn-script-location >nul 2>&1	
    if errorlevel 1 goto :install_failed
    goto :install_requirements
)

if "!arch!"=="gfx1152" (
    echo [*] Installing ROCm for Krackan Point ^(gfx1152^)...
    .\python_env\python.exe -m pip install rocm[devel,libraries] --index-url https://rocm.nightlies.amd.com/v2-staging/gfx1152/ --no-warn-script-location >nul 2>&1
    if errorlevel 1 goto :install_failed
    .\python_env\scripts\rocm-sdk init >nul 2>&1 
    if errorlevel 1 (
        echo [!] Warning: rocm-sdk init failed, continuing anyway...
    )
	echo [*] Installing PyTorch for Krackan Point ^(gfx1152^)...
    .\python_env\python.exe -m pip install --index-url https://rocm.nightlies.amd.com/v2-staging/gfx1152/ torch torchaudio torchvision --no-warn-script-location >nul 2>&1	
    if errorlevel 1 goto :install_failed
    goto :install_requirements
)

if "!arch!"=="gfx1153" (
    echo [*] Installing ROCm for RDNA 3.5 ^(gfx1153^)...
    .\python_env\python.exe -m pip install rocm[devel,libraries] --index-url https://rocm.nightlies.amd.com/v2-staging/gfx1153/ --no-warn-script-location >nul 2>&1
    if errorlevel 1 goto :install_failed
    .\python_env\scripts\rocm-sdk init >nul 2>&1 
    if errorlevel 1 (
        echo [!] Warning: rocm-sdk init failed, continuing anyway...
    )
	echo [*] Installing PyTorch for RDNA 3.5 ^(gfx1153^)...
    .\python_env\python.exe -m pip install --index-url https://rocm.nightlies.amd.com/v2-staging/gfx1153/ torch torchaudio torchvision --no-warn-script-location >nul 2>&1
    if errorlevel 1 goto :install_failed
    goto :install_requirements
)

if "!arch!"=="gfx120X" (
    echo [*] Installing ROCm for RDNA4 ^(gfx120X^)...
    .\python_env\python.exe -m pip install rocm[devel,libraries] --index-url https://rocm.nightlies.amd.com/v2/gfx120X-all/ --no-warn-script-location >nul 2>&1
    if errorlevel 1 goto :install_failed
    .\python_env\scripts\rocm-sdk init >nul 2>&1 
    if errorlevel 1 (
        echo [!] Warning: rocm-sdk init failed, continuing anyway...
    )
	echo [*] Installing PyTorch for RDNA4 ^(gfx120X^)...
    .\python_env\python.exe -m pip install --index-url https://rocm.nightlies.amd.com/v2/gfx120X-all/ torch torchaudio torchvision --no-warn-script-location >nul 2>&1
    if errorlevel 1 goto :install_failed
    goto :install_requirements
)

if "!arch!"=="gfx90X" (
    echo [*] Installing ROCm for Radeon Pro VII ^(gfx90X^)...
    .\python_env\python.exe -m pip install rocm[devel,libraries] --index-url https://rocm.nightlies.amd.com/v2-staging/gfx90X-dcgpu/ --no-warn-script-location >nul 2>&1
    if errorlevel 1 goto :install_failed
    .\python_env\scripts\rocm-sdk init >nul 2>&1 
    if errorlevel 1 (
        echo [!] Warning: rocm-sdk init failed, continuing anyway...
    )
	echo [*] Installing PyTorch for Radeon Pro VII ^(gfx90X^)...
    .\python_env\python.exe -m pip install --index-url https://rocm.nightlies.amd.com/v2-staging/gfx90X-dcgpu/ torch torchaudio torchvision --no-warn-script-location >nul 2>&1
    if errorlevel 1 goto :install_failed
    goto :install_requirements
)

if "!arch!"=="gfx94X" (
    echo [*] Installing ROCm for MI300/MI325 ^(gfx94X^)...
    .\python_env\python.exe -m pip install rocm[devel,libraries] --index-url https://rocm.nightlies.amd.com/v2-staging/gfx94X-dcgpu/ --no-warn-script-location >nul 2>&1
    if errorlevel 1 goto :install_failed
    .\python_env\scripts\rocm-sdk init >nul 2>&1 
    if errorlevel 1 (
        echo [!] Warning: rocm-sdk init failed, continuing anyway...
    )
	echo [*] Installing PyTorch for Radeon Pro VII ^(gfx90X^)...
    .\python_env\python.exe -m pip install --index-url https://rocm.nightlies.amd.com/v2-staging/gfx94X-dcgpu/ torch torchaudio torchvision --no-warn-script-location >nul 2>&1
    if errorlevel 1 goto :install_failed
    goto :install_requirements
)

if "!arch!"=="gfx950" (
    echo [*] Installing ROCm for MI350/MI355 ^(gfx950^)...
    .\python_env\python.exe -m pip install rocm[devel,libraries] --index-url https://rocm.nightlies.amd.com/v2-staging/gfx950-dcgpu/ --no-warn-script-location >nul 2>&1
    if errorlevel 1 goto :install_failed
    .\python_env\scripts\rocm-sdk init >nul 2>&1 
    if errorlevel 1 (
        echo [!] Warning: rocm-sdk init failed, continuing anyway...
    )
	echo [*] Installing PyTorch for MI350/MI355 ^(gfx950^)...
    .\python_env\python.exe -m pip install --index-url https://rocm.nightlies.amd.com/v2-staging/gfx950-dcgpu/ torch torchaudio torchvision --no-warn-script-location >nul 2>&1
    if errorlevel 1 goto :install_failed
    goto :install_requirements
)

echo [!] Unknown GPU architecture detected: !arch!
pause
exit /b 1

:install_requirements
echo.
echo [*] Installing comfyui-rocm...

:: Check if requirements.txt exists
if not exist "requirements.txt" (
    echo [!] Error: requirements.txt not found!
    pause
    exit /b 1
)

.\python_env\python.exe -m pip install -r requirements.txt --no-warn-script-location >nul 2>&1
if errorlevel 1 goto :install_failed
.\python_env\python.exe -m pip install -r manager_requirements.txt --no-warn-script-location >nul 2>&1
if errorlevel 1 goto :install_failed
.\python_env\python.exe -m pip install matrix-nio --no-warn-script-location >nul 2>&1
if errorlevel 1 goto :install_failed

echo [*] Installing extensions...

cd custom_nodes
if not exist CFZ-SwitchMenu git clone https://github.com/patientx/CFZ-SwitchMenu.git --quiet
if not exist CFZ-Caching git clone https://github.com/patientx/CFZ-Caching --quiet
cd ..

echo [*] Installing triton - sageattention(v1)
.\python_env\python.exe -m pip install triton-windows==3.6.0.post25 --quiet
if errorlevel 1 goto :install_failed
.\python_env\python.exe -m pip install sageattention==1.0.6 --quiet
if errorlevel 1 goto :install_failed

echo [*] Patching sage-attention...
del python_env\Lib\site-packages\sageattention\attn_qk_int8_per_block.py >NUL
curl -sL -o python_env\Lib\site-packages\sageattention\attn_qk_int8_per_block.py https://raw.githubusercontent.com/patientx/ComfyUI-Zluda/refs/heads/master/comfy/customzluda/sa/attn_qk_int8_per_block.py
del python_env\Lib\site-packages\sageattention\attn_qk_int8_per_block_causal.py >NUL
curl -sL -o python_env\Lib\site-packages\sageattention\attn_qk_int8_per_block_causal.py https://raw.githubusercontent.com/patientx/ComfyUI-Zluda/refs/heads/master/comfy/customzluda/sa/attn_qk_int8_per_block_causal.py
del python_env\Lib\site-packages\sageattention\quant_per_block.py >NUL
curl -sL -o python_env\Lib\site-packages\sageattention\quant_per_block.py https://raw.githubusercontent.com/patientx/ComfyUI-Zluda/refs/heads/master/comfy/customzluda/sa/quant_per_block.py

echo [*] Installing bitsandbytes if available...

set "install_bnb_new=0"

REM ---- check newer supported architectures ----
for %%G in (gfx90a gfx942 gfx950 gfx1100 gfx1101 gfx1150 gfx1151 gfx1200 gfx1201) do (
    if /I "!arch!"=="%%G" set "install_bnb_new=1"
)

REM ---- check gfx103x family safely ----
if /I "!arch:~0,6!"=="gfx103" (
    echo [*] Installing bitsandbytes for gfx103x...
    .\python_env\python.exe -m pip install https://github.com/0xDELUXA/bitsandbytes_win_rocm/releases/download/v0.49.2.dev0-py312-rocm7.12/bitsandbytes-0.49.2.dev0-cp312-cp312-win_amd64.whl --quiet
    if errorlevel 1 goto :install_failed
    goto :bnb_done
)

REM ---- install multi-arch build if matched ----
if /I "!install_bnb_new!"=="1" goto :install_bnb_new

goto :after_bnb_new

:install_bnb_new
echo [*] Installing bitsandbytes (multi-arch build)...
.\python_env\python.exe -m pip install https://github.com/0xDELUXA/bitsandbytes_win_rocm/releases/download/v0.49.2.dev0-py312-rocm7.12-all/bitsandbytes-0.49.2.dev0-cp312-cp312-win_amd64.whl --quiet
if errorlevel 1 goto :install_failed
goto :bnb_done

:after_bnb_new

echo No compatible bitsandbytes build for !arch!

:bnb_done

if errorlevel 1 goto :install_failed

echo [*] Installing flash-attention if available...

set "install_fa=0"
for %%G in (gfx90X gfx94X gfx950 gfx110X gfx1150 gfx1151 gfx1152 gfx1153 gfx120X) do (
    if /I "!arch!"=="%%G" set "install_fa=1"
)
if /I "!install_fa!"=="1" goto :install_fa
echo [*] Skipping flash-attention on !arch!...
goto :fa_done

:install_fa
echo [*] Installing flash-attention for !arch!...
.\python_env\python.exe -m pip install https://github.com/0xDELUXA/flash-attention/releases/download/v2.8.4_win-rocm/flash_attn-2.8.4-py3-none-any.whl --no-deps --quiet
if errorlevel 1 echo [!] Warning: flash-attention install failed, skipping...

:fa_done

:verify_installation
echo.
echo [*] Verifying installation...
echo.
.\python_env\python.exe -c "import torch; print(f'PyTorch Version: {torch.__version__}'); print(f'ROCm Available: {torch.cuda.is_available()}'); print(f'ROCm Version: {torch.version.hip if torch.cuda.is_available() else \"N/A\"}')"
if errorlevel 1 (
    echo [!] Warning: Installation verification failed
    echo [!] PyTorch may not be properly installed
)

goto :install_complete

:install_complete
echo.
echo ====================================================
echo   Installation Complete!
echo   Run "comfyui-rocm.bat" to start comfyui-rocm
echo ====================================================
goto :end

:install_failed
echo.
echo ====================================================
echo   Installation Failed!
echo   Check the error messages above for details.
echo ====================================================
goto :end

:end
pause
exit /b
