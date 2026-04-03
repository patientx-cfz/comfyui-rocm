@echo off
setlocal enabledelayedexpansion
title ComfyUI-AMD-ROCM

:: paths
set "PYTHON_DIR=%~dp0python_env"
set "PATH=%PYTHON_DIR%;%PYTHON_DIR%\Scripts;%PATH%"

.\python_env\scripts\rocm-sdk init >nul 2>&1

for /f "delims=" %%i in ('rocm-sdk path --root') do set "HIP_PATH=%%i"

:: detect GPU architecture for conditional settings
set "GPU_ARCH="
for /f "delims=" %%A in ('.\python_env\python.exe detect_gpu.py 2^>nul') do set "GPU_ARCH=%%A"

set "IS_LEGACY_GPU=0"
if /I "!GPU_ARCH!"=="gfx101X" set "IS_LEGACY_GPU=1"
if /I "!GPU_ARCH!"=="gfx103X" set "IS_LEGACY_GPU=1"

:: comfyui startup options : modify to your needs
set PARAMS=--disable-api-nodes --cache-none --disable-smart-memory --disable-pinned-memory --enable-manager-legacy-ui
if "!IS_LEGACY_GPU!"=="1" set "PARAMS=%PARAMS% --use-quad-cross-attention"

:: advanced settings
set COMFYUI_ENABLE_MIOPEN=0
set FLASH_ATTENTION_TRITON_AMD_ENABLE=TRUE
SET MIOPEN_FIND_ENFORCE=1
SET MIOPEN_FIND_MODE=2
SET MIOPEN_DEBUG_DISABLE_FIND_DB=0
SET MIOPEN_SEARCH_CUTOFF=1
SET MIOPEN_ENABLE_LOGGING=0
SET MIOPEN_LOG_LEVEL=0
SET MIOPEN_ENABLE_LOGGING_CMD=0
SET TRITON_PRINT_AUTOTUNING=0
SET TRITON_CACHE_AUTOTUNING=0

:: disable Flash and MemEff SDP backends on RDNA1/2 only
if "!IS_LEGACY_GPU!"=="1" (
    SET TORCH_BACKENDS_CUDA_FLASH_SDP_ENABLED=0
    SET TORCH_BACKENDS_CUDA_MEM_EFF_SDP_ENABLED=0
    SET TORCH_BACKENDS_CUDA_MATH_SDP_ENABLED=1
) else (
    SET TORCH_ROCM_AOTRITON_ENABLE_EXPERIMENTAL=1
)
::

REM Launch ComfyUI with your parameters
python_env\python.exe main.py %PARAMS%

pause
