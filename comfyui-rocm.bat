@echo off
setlocal enabledelayedexpansion
title [comfyui-rocm]

:: paths
set "PYTHON_DIR=%~dp0python_env"
set "PATH=%PYTHON_DIR%;%PYTHON_DIR%\Scripts;%PATH%"

.\python_env\scripts\rocm-sdk init >nul 2>&1
if errorlevel 1 (
    echo [!] Warning: rocm-sdk init failed. ROCm may not be set up correctly.
)

for /f "delims=" %%i in ('rocm-sdk path --root') do set "HIP_PATH=%%i"
set "ROCM_PATH=%HIP_PATH%"

:: ------------------- detect GPU architecture for conditional settings ---------------- ::

set "GPU_ARCH="
for /f "delims=" %%A in ('.\python_env\python.exe detect_gpu.py 2^>nul') do set "GPU_ARCH=%%A"
set "IS_LEGACY_GPU=0"
if /I "!GPU_ARCH!"=="gfx101X" set "IS_LEGACY_GPU=1"
if /I "!GPU_ARCH!"=="gfx103X" set "IS_LEGACY_GPU=1"

:: disable Flash and MemEff SDP backends on RDNA1/2 only

if "!IS_LEGACY_GPU!"=="1" (
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

:: ------------------------------------------------------------------------------------- ::

:: ------------------- CHANGE THESE IF YOU KNOW WHAT YOU ARE DOING --------------------- ::
:: ----------------- comfyui-rocm STARTUP OPTIONS : modify to your needs --------------- ::

set PARAMS=--disable-api-nodes --cache-none --disable-smart-memory --disable-pinned-memory --enable-manager-legacy-ui

:: quad-cross is better for older generation (you can use --use-sage-attention too) 
if "!IS_LEGACY_GPU!"=="1" set "PARAMS=%PARAMS% --use-quad-cross-attention"

:: ------------------------------------------------------------------------------------- ::

echo ::: [comfyui-rocm] starting with these parameters ::: 
echo [ !PARAMS! ]
echo.
python_env\python.exe main.py %PARAMS%

pause
