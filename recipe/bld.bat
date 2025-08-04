@echo off
REM adding host environment bin to the path because on some platforms it uses _build_env/bin/python
REM instead of the host environment python
set PATH=%PREFIX%\Scripts;%PREFIX%\bin;%PATH%

echo Current directory: %CD%
echo PATH: %PATH%
echo PYTHON: %PYTHON%

REM Pre-install correct tensorflow to satisfy upstream script detection
echo Pre-installing tensorflow from conda environment to satisfy upstream script
%PYTHON% -c "import tensorflow; print('TensorFlow ' + tensorflow.__version__ + ' is already available')"
if errorlevel 1 (
    echo ERROR: TensorFlow not found in conda environment
    exit 1
)

REM Temporarily enable PyPI access for upstream tensorflow detection
echo Temporarily setting PIP_NO_INDEX=False for upstream script compatibility
set "PIP_NO_INDEX_BACKUP=%PIP_NO_INDEX%"
set "PIP_NO_INDEX=False"

REM Check if build script exists
if not exist "oss_scripts\run_build.sh" (
    echo ERROR: oss_scripts\run_build.sh not found!
    dir oss_scripts
    exit 1
)

REM Run the build script
echo Running: bash oss_scripts/run_build.sh
bash oss_scripts/run_build.sh
if errorlevel 1 (
    echo ERROR: Build script failed with exit code %ERRORLEVEL%
    exit 1
)

REM Restore original PIP_NO_INDEX setting
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