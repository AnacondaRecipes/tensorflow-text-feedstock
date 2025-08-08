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

REM Pre-install wheel globally to ensure it's available to all pip subprocesses
echo Pre-installing wheel to ensure availability in pip subprocesses...
pip install wheel
if errorlevel 1 (
    echo WARNING: Could not install wheel globally, attempting with python -m pip
    %PYTHON% -m pip install wheel --upgrade
)

REM Also ensure setuptools is up to date as it may help with bdist_wheel
echo Ensuring setuptools is up to date...
pip install setuptools --upgrade

REM Install perl which is required by TensorFlow build process
echo Installing perl for TensorFlow build requirements...
conda install -y perl
if errorlevel 1 (
    echo WARNING: Could not install perl via conda, build may fail
)

REM Pre-install problematic packages that cause metadata generation issues
echo Pre-installing promise package to avoid metadata generation issues...
pip install promise
if errorlevel 1 (
    echo WARNING: Could not pre-install promise package
)

REM Set environment variables to help with pip metadata generation issues
echo Setting pip environment variables to avoid metadata generation issues...
set "PIP_USE_PEP517=false"
set "PIP_DISABLE_PIP_VERSION_CHECK=1"
set "PIP_NO_BUILD_ISOLATION=true"

REM Set Bazel environment variables to handle Windows-specific issues (if needed)
REM echo Setting Bazel environment variables for Windows...
REM Commenting out hard-coded VS paths - let Bazel auto-detect or use conda's compiler
REM set "BAZEL_VS=C:\Program Files (x86)\Microsoft Visual Studio\2019\BuildTools"
REM set "BAZEL_VC=C:\Program Files (x86)\Microsoft Visual Studio\2019\BuildTools\VC"

REM Check if build script exists
if not exist "oss_scripts\run_build.sh" (
    echo ERROR: oss_scripts\run_build.sh not found!
    dir oss_scripts
    exit 1
)

REM Simple approach: just copy bazel.exe to bazel (without .exe) for bash
echo Creating simple bazel copy for bash environment...
copy "%BUILD_PREFIX%\Library\bin\bazel.exe" "%BUILD_PREFIX%\bin\bazel" >nul
if errorlevel 1 (
    echo ERROR: Could not copy bazel.exe to bin directory
    exit 1
)

REM Debug: Show what's in the bin directory
echo Contents of BUILD_PREFIX\bin:
dir "%BUILD_PREFIX%\bin" | findstr bazel

REM Ensure wheel package is available for upstream script
echo Verifying wheel package availability...
%PYTHON% -c "import wheel; print('wheel package is available:', wheel.__version__)"
if errorlevel 1 (
    echo ERROR: wheel package not found in Python environment
    echo Installing wheel package...
    %PYTHON% -m pip install wheel
    if errorlevel 1 exit 1
)

REM Debug: Check Python environment for bash
echo Checking Python environment for bash...
bash -c "echo Python in bash: && python --version && python -c 'import wheel; print(\"wheel available in bash:\", wheel.__version__)'"

REM Debug: Check if environment variables are being passed to bash
echo Checking if pip environment variables are accessible in bash...
bash -c "echo PIP_USE_PEP517: $PIP_USE_PEP517 && echo PIP_NO_BUILD_ISOLATION: $PIP_NO_BUILD_ISOLATION && python -c 'import promise; print(\"promise available in bash:\", promise.__version__)' 2>/dev/null || echo 'promise not found in bash'"

REM Set PYTHONPATH to include system site-packages for Bazel subprocesses
echo Setting PYTHONPATH to include system packages...
for /f "delims=" %%i in ('python -c "import site; print(';'.join(site.getsitepackages()))"') do set "PYTHONPATH=%%i"
echo PYTHONPATH: %PYTHONPATH%

REM Apply patch changes directly to upstream files (avoiding patch application issues)
echo Applying Windows-specific fixes directly to upstream files...

REM Fix 1: Add --jobs=1 to bazel run command in run_build.sh
echo Modifying oss_scripts/run_build.sh to add --jobs=1 for Windows stability...
powershell -Command "(Get-Content 'oss_scripts/run_build.sh') -replace 'bazel run \$\{BUILD_ARGS\[\@\]\} --enable_runfiles', 'bazel run ${BUILD_ARGS[@]} --enable_runfiles --jobs=1' | Set-Content 'oss_scripts/run_build.sh'"

REM Fix 2: Comment out $plat_name in build_pip_package.sh to avoid Windows platform issues
echo Modifying oss_scripts/pip_package/build_pip_package.sh to comment out plat_name...
powershell -Command "(Get-Content 'oss_scripts/pip_package/build_pip_package.sh') -replace '\$installed_python setup\.py bdist_wheel --universal \$plat_name', '$installed_python setup.py bdist_wheel --universal #$plat_name' | Set-Content 'oss_scripts/pip_package/build_pip_package.sh'"

REM Verify the changes were applied
echo Verifying changes were applied...
findstr /C:"--jobs=1" oss_scripts/run_build.sh
findstr /C:"#$plat_name" oss_scripts/pip_package/build_pip_package.sh

REM Run the build script with enhanced environment
echo Running: bash oss_scripts/run_build.sh
bash oss_scripts/run_build.sh
if errorlevel 1 (
    echo ERROR: Build script failed with exit code %ERRORLEVEL%
    exit 1
)

REM Debug: Check what was built
echo Checking for built wheel files...
dir tensorflow_text-*.whl 2>nul
if errorlevel 1 (
    echo No wheel files found in current directory, checking subdirectories...
    dir /s tensorflow_text-*.whl 2>nul
    if errorlevel 1 (
        echo ERROR: No tensorflow_text wheel files found anywhere!
        echo Current directory contents:
        dir
        exit 1
    )
)

REM Restore original PIP_NO_INDEX setting after build
echo Restoring original PIP_NO_INDEX setting
set "PIP_NO_INDEX=%PIP_NO_INDEX_BACKUP%"

REM Install the built wheel immediately after build completes
echo Installing the built wheel into conda environment...
%PYTHON% -m pip install tensorflow_text-*.whl -vv --no-deps --no-build-isolation
if errorlevel 1 (
    echo ERROR: Failed to install tensorflow_text wheel
    echo Looking for wheel files:
    dir tensorflow_text-*.whl
    exit 1
)

REM run the tests here since the build and host requirements are necessary for building
REM tensorflow-datasets temporarily disabled due to protobuf conflicts with TF 2.18.1
REM if not "%PY_VER%"=="3.13" (
REM     bash oss_scripts/run_tests.sh
REM     if errorlevel 1 exit 1
REM )