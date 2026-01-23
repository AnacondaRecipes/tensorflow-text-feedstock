@echo off
setlocal enabledelayedexpansion

REM Copyright 2018 The TensorFlow Authors. All Rights Reserved.
REM Licensed under the Apache License, Version 2.0

REM Remove .bazelrc if it already exists
if exist .bazelrc del .bazelrc

REM Copy the current bazelversion of TF.
curl -s https://raw.githubusercontent.com/tensorflow/tensorflow/r2.19/.bazelversion -o .bazelversion
if errorlevel 1 (
    echo Failed to download .bazelversion
    exit /b 1
)

REM Copy the building configuration of TF.
curl -s https://raw.githubusercontent.com/tensorflow/tensorflow/r2.19/.bazelrc -o .bazelrc
if errorlevel 1 (
    echo Failed to download .bazelrc
    exit /b 1
)

REM This line breaks Windows builds, so we remove it.
REM Using PowerShell to remove the problematic line
powershell -Command "(Get-Content .bazelrc) | Where-Object {$_ -notmatch 'build --noincompatible_remove_legacy_whole_archive'} | Set-Content .bazelrc"
if errorlevel 1 (
    REM Fallback: use findstr to filter out the line
    findstr /V "build --noincompatible_remove_legacy_whole_archive" .bazelrc > .bazelrc.tmp
    if errorlevel 1 (
        echo Failed to remove problematic line from .bazelrc
        exit /b 1
    )
    move /Y .bazelrc.tmp .bazelrc
)

REM Get Python version for HERMETIC_PYTHON_VERSION
if defined PY_VERSION (
    set "HERMETIC_PYTHON_VERSION=%PY_VERSION%"
) else (
    REM Find Python executable
    where python3 >nul 2>&1
    if errorlevel 1 (
        where python >nul 2>&1
        if errorlevel 1 (
            echo Python not found
            exit /b 1
        )
        set "installed_python=python"
    ) else (
        set "installed_python=python3"
    )
    
    REM Get Python version from Python itself
    for /f "delims=" %%i in ('%installed_python% -c "import sys; print('.'.join(map(str, sys.version_info[:2])))"') do set "HERMETIC_PYTHON_VERSION=%%i"
)
if defined HERMETIC_PYTHON_VERSION (
    set "HERMETIC_PYTHON_VERSION=%HERMETIC_PYTHON_VERSION: =%"
)

echo TF_VERSION=%TF_VERSION%
set "REQUIREMENTS_EXTRA_FLAGS=--upgrade"
if defined TF_VERSION (
    echo %TF_VERSION% | findstr /C:"rc" >nul
    if not errorlevel 1 (
        set "REQUIREMENTS_EXTRA_FLAGS=%REQUIREMENTS_EXTRA_FLAGS% --pre"
    )
)

REM Skip requirements.update (using vendored lock files from upstream)
REM Original: bazel run //oss_scripts/pip_package:requirements.update -- %REQUIREMENTS_EXTRA_FLAGS%
echo Skipping requirements.update (using vendored lock files from upstream)

REM Get TF_ABIFLAG using bazel
echo Getting TF_ABIFLAG...
for /f "delims=" %%i in ('bazel run //oss_scripts/pip_package:tensorflow_build_info -- abi 2^>nul') do (
    set "TF_ABIFLAG=%%i"
    set "TF_ABIFLAG=!TF_ABIFLAG: =!"
)
if not defined TF_ABIFLAG (
    echo Warning: Failed to get TF_ABIFLAG, using default value
    set "TF_ABIFLAG=0"
)
echo TF_ABIFLAG=%TF_ABIFLAG%

REM Write TF_CXX11_ABI_FLAG to .bazelrc
echo build --action_env TF_CXX11_ABI_FLAG=%TF_ABIFLAG% >> .bazelrc

REM Set SHARED_LIBRARY_NAME for Windows (use .dll extension)
set "SHARED_LIBRARY_NAME=libtensorflow_framework.dll"

endlocal
