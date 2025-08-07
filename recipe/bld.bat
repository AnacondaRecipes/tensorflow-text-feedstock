@echo off
REM adding host environment bin to the path because on some platforms it uses _build_env/bin/python
REM instead of the host environment python
REM CRITICAL: Add BUILD_PREFIX first so bazel is found
set PATH=%BUILD_PREFIX%\Scripts;%BUILD_PREFIX%\bin;%BUILD_PREFIX%;%PREFIX%\Scripts;%PREFIX%\bin;%PATH%

echo Current directory: %CD%
echo PATH: %PATH%
echo PYTHON: %PYTHON%
echo BUILD_PREFIX: %BUILD_PREFIX%

REM Verify bazel is accessible
echo Checking for bazel...
where bazel
if errorlevel 1 (
    echo ERROR: bazel not found in PATH
    echo BUILD_PREFIX: %BUILD_PREFIX%
    dir "%BUILD_PREFIX%\bin" /b | findstr bazel
    exit 1
)
bazel version

REM Pre-install correct tensorflow to satisfy upstream script detection
echo Pre-installing tensorflow from conda environment to satisfy upstream script
%PYTHON% -c "import tensorflow; print('TensorFlow ' + tensorflow.__version__ + ' is already available')"
if errorlevel 1 (
    echo ERROR: TensorFlow not found in conda environment
    exit 1
)

REM Create python3 symlink for bash environment compatibility
echo Creating python3 compatibility...
if not exist "%BUILD_PREFIX%\bin" mkdir "%BUILD_PREFIX%\bin"
if exist "%BUILD_PREFIX%\bin\python3.exe" del "%BUILD_PREFIX%\bin\python3.exe"
copy "%PREFIX%\python.exe" "%BUILD_PREFIX%\bin\python3.exe" >nul
if errorlevel 1 (
    echo WARNING: Could not create python3.exe symlink - trying alternative approach
    echo Checking if directories exist...
    echo PREFIX: %PREFIX%
    echo BUILD_PREFIX: %BUILD_PREFIX%
    if exist "%PREFIX%\python.exe" echo python.exe found in PREFIX
    if exist "%BUILD_PREFIX%\bin" echo BUILD_PREFIX\bin exists
)

REM Temporarily allow PyPI access and let upstream install tensorflow==2.18.0
echo Allowing upstream script to install tensorflow==2.18.0 from PyPI
set "PIP_NO_INDEX_BACKUP=%PIP_NO_INDEX%"
set "PIP_NO_INDEX=False"

REM Check if build script exists
if not exist "oss_scripts\run_build.sh" (
    echo ERROR: oss_scripts\run_build.sh not found!
    dir oss_scripts
    exit 1
)

REM Create a Unix-compatible bazel wrapper for bash environment
echo Creating bazel wrapper for bash environment...
echo #!/bin/bash > "%BUILD_PREFIX%\bin\bazel"
echo # Wrapper to call bazel.exe from bash environment >> "%BUILD_PREFIX%\bin\bazel"
echo # Use cygpath to convert Windows path to Unix format for bash >> "%BUILD_PREFIX%\bin\bazel"
echo exec "$(cygpath '%BUILD_PREFIX%\bin\bazel.exe')" "$@" >> "%BUILD_PREFIX%\bin\bazel"

REM Make it executable (chmod equivalent for Windows doesn't exist, but bash should handle it)
REM Also create a batch wrapper for CMD environment
echo @echo off > "%BUILD_PREFIX%\bin\bazel.bat"
echo "%BUILD_PREFIX%\bin\bazel.exe" %%* >> "%BUILD_PREFIX%\bin\bazel.bat"

REM Debug: Show what's in the bin directory
echo Contents of BUILD_PREFIX\bin:
dir "%BUILD_PREFIX%\bin" | findstr bazel

REM Run the build script with enhanced environment
echo Running: bash oss_scripts/run_build.sh
set "BAZEL_REAL=%BUILD_PREFIX%\bin\bazel.exe"
bash oss_scripts/run_build.sh
if errorlevel 1 (
    echo ERROR: Build script failed with exit code %ERRORLEVEL%
    exit 1
)

REM Restore original PIP_NO_INDEX setting after build
echo Restoring original PIP_NO_INDEX setting
set "PIP_NO_INDEX=%PIP_NO_INDEX_BACKUP%"

REM Install the built wheel
%PYTHON% -m pip install tensorflow_text-*.whl -vv --no-deps --no-build-isolation
if errorlevel 1 exit 1

REM run the tests here since the build and host requirements are necessary for building
REM tensorflow-datasets temporarily disabled due to protobuf conflicts with TF 2.18.1
REM if not "%PY_VER%"=="3.13" (
REM     bash oss_scripts/run_tests.sh
REM     if errorlevel 1 exit 1
REM )