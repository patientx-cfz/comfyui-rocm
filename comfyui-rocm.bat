@echo off
setlocal enabledelayedexpansion
title [comfyui-rocm]

set PYTHONUTF8=1

:: ANSI color support (Windows 10+)
for /f %%a in ('echo prompt $E ^| cmd') do set "ESC=%%a"
set "GREEN=%ESC%[32m"
set "YELLOW=%ESC%[33m"
set "CYAN=%ESC%[36m"
set "RESET=%ESC%[0m"

:: read installed version from hash file
set "HASH_FILE=%~dp0.last_update_hash"
set "VERSION=unknown"
if exist "!HASH_FILE!" set /p VERSION=<"!HASH_FILE!"
set "VERSION=!VERSION:~0,10!"
title [comfyui-rocm] - !VERSION!

:: paths
set "PYTHON_DIR=%~dp0python_env"
set "PATH=%PYTHON_DIR%;%PYTHON_DIR%\Scripts;%PATH%"

echo %GREEN%[INFO]%RESET% Initializing rocm-sdk...
.\python_env\scripts\rocm-sdk init >nul 2>&1
if errorlevel 1 (
    echo %YELLOW%[WARN]%RESET% rocm-sdk init failed. ROCm may not be set up correctly.
)

for /f "delims=" %%i in ('rocm-sdk path --root') do set "HIP_PATH=%%i"
set "ROCM_PATH=%HIP_PATH%"

:: ------------------- detect GPU architecture for conditional settings ---------------- ::
echo %GREEN%[INFO]%RESET% Detecting GPU architecture...
set "GPU_ARCH="
for /f "delims=" %%A in ('.\python_env\python.exe detect_gpu.py 2^>nul') do set "GPU_ARCH=%%A"
set "IS_LEGACY_GPU=0"
if /I "!GPU_ARCH:~0,6!"=="gfx101" set "IS_LEGACY_GPU=1"
if /I "!GPU_ARCH:~0,6!"=="gfx103" set "IS_LEGACY_GPU=1"

set "IS_RDNA4_GPU=0"
if /I "!GPU_ARCH:~0,6!"=="gfx120" set "IS_RDNA4_GPU=1"

if "!GPU_ARCH!"=="" (
    echo %YELLOW%[WARN]%RESET% Could not detect GPU architecture.
) else (
    echo %GREEN%[INFO]%RESET% GPU arch: %CYAN%!GPU_ARCH!%RESET%
)

:: disable Flash and MemEff SDP backends on RDNA1/2 only

if "!IS_LEGACY_GPU!"=="1" (
    echo %GREEN%[INFO]%RESET% Legacy GPU detected — applying RDNA1/2 SDP overrides.
    set TORCH_BACKENDS_CUDA_FLASH_SDP_ENABLED=0
    set TORCH_BACKENDS_CUDA_MEM_EFF_SDP_ENABLED=0
    set TORCH_BACKENDS_CUDA_MATH_SDP_ENABLED=1
) else (
    set TORCH_ROCM_AOTRITON_ENABLE_EXPERIMENTAL=1
)
:: ------------------------------------------------------------------------------------- ::

:: ------------------------- cache and database paths (relative) ------------------------::
set "PYTORCH_TUNABLEOP_CACHE_DIR=%~dp0tunableop-cache"

set "TRITON_CACHE_DIR=%~dp0triton-cache"
:: if you already have a previous triton cache you can define it here so you won't have to rebuild it.

if not exist "%TRITON_CACHE_DIR%" (
    mkdir "%TRITON_CACHE_DIR%"
)

if not exist "%PYTORCH_TUNABLEOP_CACHE_DIR%" (
    mkdir "%PYTORCH_TUNABLEOP_CACHE_DIR%"
)

:: Skip MIOpen and ROCBlas paths for gfx1100 (RDNA3) - not present atm
if /I NOT "!GPU_ARCH!"=="gfx1100" (
    set "MIOPEN_SYSTEM_DB_PATH=%~dp0python_env\Lib\site-packages\_rocm_sdk_devel\bin"
    set "ROCBLAS_TENSILE_DB_PATH=%~dp0python_env\Lib\site-packages\_rocm_sdk_devel\bin\rocblas"
    set "ROCBLAS_TENSILE_LIBPATH=%~dp0python_env\Lib\site-packages\_rocm_sdk_devel\bin\rocblas\library"
)
:: ------------------------------------------------------------------------------------- ::

:: ------------------- CHANGE THESE IF YOU KNOW WHAT YOU ARE DOING --------------------- ::
:: ---------------------- advanced settings (miopen , triton etc.) --------------------- ::
set COMFYUI_ENABLE_MIOPEN=0
set FLASH_ATTENTION_TRITON_AMD_ENABLE=TRUE
set MIOPEN_FIND_ENFORCE=1
set MIOPEN_FIND_MODE=2
set MIOPEN_DEBUG_DISABLE_FIND_DB=0
set MIOPEN_SEARCH_CUTOFF=1
set MIOPEN_ENABLE_LOGGING=0
set MIOPEN_LOG_LEVEL=0
set MIOPEN_ENABLE_LOGGING_CMD=0
set TRITON_PRINT_AUTOTUNING=0
set TRITON_CACHE_AUTOTUNING=0

:: if you are getting this error "torch.AcceleratorError: CUDA error: invalid kernel file" enable the line below by removing the "::"  
:: set HIP_VISIBLE_DEVICES=1																																	   
							
:: ------------------------------------------------------------------------------------- ::

:: ------------------- CHANGE THESE IF YOU KNOW WHAT YOU ARE DOING --------------------- ::
:: ----------------- comfyui-rocm STARTUP OPTIONS : modify to your needs --------------- ::

:: triton-backend works for rdna3 & rdna4 BUT the included ComfyUI-INT8-Fast-ROCM crashes comfy with it enabled AND that node is faster than native even on rdna4 so it is better to use than native nodes
:: so triton-backend should be disabled for newer gpu's (it already won't activate for older gens) , if you update triton-windows to >= 3.7.1.post27 it activates itself for rdna3 and above. 
:: if you have rdna3 or rdna4 and despite them being slower, you want to continue using native nodes, uninstall triton-windows. OR let it be disabled and use the custom node.

:: enabling dynamic-vram because it is much better than what it was when it first released of course regarding to amd gpu compability. If you have problems with it remove it.
set PARAMS=--disable-api-nodes --cache-lru 20 --disable-smart-memory --disable-pinned-memory --enable-manager --enable-manager-legacy-ui --disable-triton-backend --enable-dynamic-vram

:: quad-cross is better for older generation (you can use --use-sage-attention too) 
if "!IS_LEGACY_GPU!"=="1" set "PARAMS=%PARAMS% --use-quad-cross-attention"

:: ck-attention (comfy-kitchen attention) is best for rdna4
if "!IS_RDNA4_GPU!"=="1" set "PARAMS=--enable-manager --enable-manager-legacy-ui --use-ck-attention"

:: ------------------------------------------------------------------------------------- ::

:: --------------------------- keeping the necessary packages up-to-date --------------- ::
echo %GREEN%[INFO]%RESET% Syncing tracked packages from requirements.txt...
for %%P in (comfyui-frontend-package comfyui-workflow-templates comfyui-embedded-docs comfy-kitchen comfy-aimdo av) do (
    for /f "tokens=1,2 delims==" %%A in ('findstr /i "^%%P==" "%~dp0requirements.txt"') do (
        .\python_env\python.exe -m pip show %%A 2>nul | findstr /i "^Version:" > "%TEMP%\pkgver.txt"
        set INSTALLED=
        for /f "tokens=2" %%V in (%TEMP%\pkgver.txt) do set INSTALLED=%%V
        if not "!INSTALLED!"=="%%B" (
            .\python_env\python.exe -m pip install "%%A==%%B" --quiet 2>nul
            echo %YELLOW%[UPDATED]%RESET% %%A  !INSTALLED! ^> %%B
        )
    )
)
:: ------------------------------------------------------------------------------------ ::

set "DISPLAY_PARAMS=%PARAMS:--=%"
echo %GREEN%[INFO]%RESET% [comfyui-rocm] %CYAN%!VERSION!%RESET% starting with: [ %CYAN%!DISPLAY_PARAMS!%RESET% ]
echo.
python_env\python.exe main.py %PARAMS%

pause
