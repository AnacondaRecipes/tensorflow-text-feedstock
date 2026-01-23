@echo off
setlocal enabledelayedexpansion

REM Skip macOS-specific parts (we're on Windows)
REM On macOS, this would update .so to .dylib extensions

REM Run configure.
call oss_scripts\configure.bat
if errorlevel 1 exit /b 1

REM Skip prepare_tf_dep.sh (only for non-Apple macOS)
REM On macOS, this would prepare TensorFlow dependencies

REM Build the pip package.
REM Execute only one action at a time instead of utilizing multiple parallel jobs
bazel run --enable_runfiles --jobs=1 //oss_scripts/pip_package:build_pip_package -- "%CD%"
if errorlevel 1 exit /b 1

REM Skip auditwheel (Linux only)
REM On Linux, this would audit and repair the wheel

REM Clean up
bazel clean --expunge
if errorlevel 1 exit /b 1
bazel shutdown
if errorlevel 1 exit /b 1

endlocal
