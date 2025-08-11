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

REM Install promise package to resolve circular dependency in Bazel requirements.update
echo Installing promise via pip...
pip install promise
if errorlevel 1 (
    echo ERROR: Failed to install promise via pip
    exit 1
)
set "PIP_USE_PEP517=false"
set "PIP_NO_BUILD_ISOLATION=true"
set "PIP_DISABLE_PIP_VERSION_CHECK=1"

REM Set PYTHONPATH for Bazel subprocesses
for /f "delims=" %%i in ('python -c "import site; print(';'.join(site.getsitepackages()))"') do set "PYTHONPATH=%%i"

REM Copy bazel for bash environment
copy "%BUILD_PREFIX%\Library\bin\bazel.exe" "%BUILD_PREFIX%\bin\bazel" >nul

REM Copy perl for bash environment (TensorFlow flatbuffer processing requires perl)
echo Copying perl.exe for bash environment...
copy "%BUILD_PREFIX%\Library\bin\perl.exe" "%BUILD_PREFIX%\bin\perl" >nul 2>&1
if errorlevel 1 (
    echo WARNING: Could not copy perl.exe - checking if perl is available...
    where perl >nul 2>&1
    if errorlevel 1 (
        echo ERROR: perl not found and could not be copied for bash environment
        exit 1
    ) else (
        echo perl found in system PATH
    )
) else (
    echo perl copied successfully for bash environment
)

REM Create shorter Bazel output directory to avoid Windows long path issues
echo Creating Bazel output directory to avoid long path issues...
if not exist "C:\tmp" mkdir "C:\tmp"
if not exist "C:\tmp\bazel" mkdir "C:\tmp\bazel"

REM Apply essential patches directly
echo Applying patches to upstream scripts...
powershell -Command "(Get-Content 'oss_scripts/run_build.sh') -replace 'bazel run \$\{BUILD_ARGS\[\@\]\} --enable_runfiles', 'bazel run ${BUILD_ARGS[@]} --enable_runfiles --jobs=1 --output_user_root=C:/tmp/bazel' | Set-Content 'oss_scripts/run_build.sh'"
powershell -Command "(Get-Content 'oss_scripts/pip_package/build_pip_package.sh') -replace '\$installed_python setup\.py bdist_wheel --universal \$plat_name', '$installed_python setup.py bdist_wheel --universal #$plat_name' | Set-Content 'oss_scripts/pip_package/build_pip_package.sh'"

REM Run the upstream build script
echo Starting upstream build process...
bash oss_scripts/run_build.sh
if errorlevel 1 exit 1
echo Upstream build completed successfully!

REM Restore PIP_NO_INDEX and install the wheel immediately
echo Installing built wheel into conda environment...
set "PIP_NO_INDEX=%PIP_NO_INDEX_BACKUP%"
%PYTHON% -m pip install tensorflow_text-*.whl --no-deps --no-build-isolation
if errorlevel 1 exit 1
echo Wheel installation completed successfully!

REM run the tests here since the build and host requirements are necessary for building
REM tensorflow-datasets temporarily disabled due to protobuf conflicts with TF 2.18.1
REM if not "%PY_VER%"=="3.13" (
REM     bash oss_scripts/run_tests.sh
REM     if errorlevel 1 exit 1
REM )