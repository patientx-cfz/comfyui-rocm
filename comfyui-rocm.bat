@echo off
setlocal enabledelayedexpansion
title ComfyUI-AMD-ROCM

:: paths
set "PYTHON_DIR=%~dp0python_env"
set "PATH=%PYTHON_DIR%;%PYTHON_DIR%\Scripts;%PATH%"

.\python_env\scripts\rocm-sdk init >nul 2>&1

for /f "delims=" %%i in ('rocm-sdk path --root') do set "HIP_PATH=%%i"

REM Launch ComfyUI with your parameters
python_env\python.exe main.py ^
--use-quad-cross-attention ^
--disable-api-nodes ^
--cache-none ^
--disable-smart-memory ^
--disable-pinned-memory ^
--enable-manager

pause
