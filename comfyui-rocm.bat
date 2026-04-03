@echo off
setlocal enabledelayedexpansion
title ComfyUI-AMD-ROCM

:: comfyui startup options : modify to your needs
set PARAMS=--use-quad-cross-attention --disable-api-nodes --cache-none --disable-smart-memory --disable-pinned-memory --enable-manager-legacy-ui

:: paths
set "PYTHON_DIR=%~dp0python_env"
set "PATH=%PYTHON_DIR%;%PYTHON_DIR%\Scripts;%PATH%"

:: advanced settings
set COMFYUI_ENABLE_MIOPEN=0
set FLASH_ATTENTION_TRITON_AMD_ENABLE=TRUE
set FLASH_ATTENTION_FWD_TRITON_AMD_CONFIG_JSON={"BLOCK_M": 64,"BLOCK_N": 32,"PRE_LOAD_V": false,"waves_per_eu": 2,"num_warps": 4,"num_stages": 1}
set SAGE_ATTENTION_TRITON_AMD_ENABLE=TRUE
SET MIOPEN_FIND_ENFORCE=1
SET MIOPEN_FIND_MODE=2
SET MIOPEN_DEBUG_DISABLE_FIND_DB=0
SET MIOPEN_SEARCH_CUTOFF=1
SET MIOPEN_ENABLE_LOGGING=0
SET MIOPEN_LOG_LEVEL=0
SET MIOPEN_ENABLE_LOGGING_CMD=0
SET TORCH_BACKENDS_CUDA_FLASH_SDP_ENABLED=0
SET TORCH_BACKENDS_CUDA_MEM_EFF_SDP_ENABLED=0
SET TORCH_BACKENDS_CUDA_MATH_SDP_ENABLED=1
SET TRITON_PRINT_AUTOTUNING=0
SET TRITON_CACHE_AUTOTUNING=0
::

.\python_env\scripts\rocm-sdk init >nul 2>&1

for /f "delims=" %%i in ('rocm-sdk path --root') do set "HIP_PATH=%%i"

REM Launch ComfyUI with your parameters
python_env\python.exe main.py %PARAMS%

pause
