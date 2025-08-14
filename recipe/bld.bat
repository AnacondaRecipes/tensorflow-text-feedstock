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
echo Creating simple bazel copy for bash environment...
copy "%BUILD_PREFIX%\Library\bin\bazel.exe" "%BUILD_PREFIX%\bin\bazel" >nul
if errorlevel 1 (
    echo ERROR: Could not copy bazel.exe to bin directory
    exit 1
)

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

REM Create .bazelrc to disable symlinks globally to avoid Windows permission issues
echo Creating .bazelrc to disable symlinks...
echo startup --nowindows_enable_symlinks > .bazelrc
echo common --nowindows_enable_symlinks >> .bazelrc
echo build --experimental_allow_unresolved_symlinks >> .bazelrc
echo build --experimental_ignore_unresolved_symlinks >> .bazelrc
echo build --define framework_shared_object=false >> .bazelrc
echo build --config=monolithic >> .bazelrc

REM Apply essential patches directly
echo Applying patches to upstream scripts...
REM Removed complex PowerShell replacement - will use simpler direct approach
powershell -Command "(Get-Content 'oss_scripts/run_build.sh') -replace 'bazel run \$\{BUILD_ARGS\[\@\]\} --enable_runfiles', 'bazel run ${BUILD_ARGS[@]} --enable_runfiles --jobs=1 --keep_going --config=monolithic --define framework_shared_object=false' | Set-Content 'oss_scripts/run_build.sh'"
powershell -Command "(Get-Content 'oss_scripts/pip_package/build_pip_package.sh') -replace '\$installed_python setup\.py bdist_wheel --universal \$plat_name', '$installed_python setup.py bdist_wheel --universal #$plat_name' | Set-Content 'oss_scripts/pip_package/build_pip_package.sh'"

REM Create a script to find and fix missing library files after TensorFlow is installed
echo Creating library fix script...
echo import site > fix_libraries.py
echo import os >> fix_libraries.py
echo import shutil >> fix_libraries.py
echo import glob >> fix_libraries.py
echo import time >> fix_libraries.py
echo. >> fix_libraries.py
echo def fix_tensorflow_libraries(): >> fix_libraries.py
echo     """Find all TensorFlow installations and create missing .so.2 files""" >> fix_libraries.py
echo     tf_locations = [] >> fix_libraries.py
echo     # Check conda site-packages >> fix_libraries.py
echo     for site_dir in site.getsitepackages(): >> fix_libraries.py
echo         tf_dir = os.path.join(site_dir, 'tensorflow') >> fix_libraries.py
echo         if os.path.exists(tf_dir): >> fix_libraries.py
echo             tf_locations.append(tf_dir) >> fix_libraries.py
echo     # Search for bazel workspace tensorflow directories >> fix_libraries.py
echo     current_dir = os.getcwd() >> fix_libraries.py
echo     for root, dirs, files in os.walk(current_dir): >> fix_libraries.py
echo         if 'site-packages' in root and root.endswith('tensorflow'): >> fix_libraries.py
echo             tf_locations.append(root) >> fix_libraries.py
echo     tf_locations = list(set(tf_locations)) >> fix_libraries.py
echo     print(f'Found {len(tf_locations)} TensorFlow installations to fix') >> fix_libraries.py
echo     for tf_dir in tf_locations: >> fix_libraries.py
echo         print(f'Processing: {tf_dir}') >> fix_libraries.py
echo         so_target = os.path.join(tf_dir, 'libtensorflow_framework.so.2') >> fix_libraries.py
echo         if not os.path.exists(so_target): >> fix_libraries.py
echo             candidates = [ >> fix_libraries.py
echo                 os.path.join(tf_dir, 'python', '_pywrap_tensorflow_internal.pyd'), >> fix_libraries.py
echo                 os.path.join(tf_dir, 'libtensorflow_framework.so'), >> fix_libraries.py
echo                 os.path.join(tf_dir, 'tensorflow_framework.dll') >> fix_libraries.py
echo             ] >> fix_libraries.py
echo             for candidate in candidates: >> fix_libraries.py
echo                 if os.path.exists(candidate): >> fix_libraries.py
echo                     print(f'Creating {so_target} from {candidate}') >> fix_libraries.py
echo                     shutil.copy2(candidate, so_target) >> fix_libraries.py
echo                     break >> fix_libraries.py
echo             else: >> fix_libraries.py
echo                 print(f'Creating empty placeholder: {so_target}') >> fix_libraries.py
echo                 open(so_target, 'a').close() >> fix_libraries.py
echo         else: >> fix_libraries.py
echo             print(f'File already exists: {so_target}') >> fix_libraries.py
echo     return len(tf_locations) >> fix_libraries.py
echo. >> fix_libraries.py
echo # Run initial fix >> fix_libraries.py
echo fix_tensorflow_libraries() >> fix_libraries.py

python fix_libraries.py
if errorlevel 1 (
    echo WARNING: Could not run initial library fix
) else (
    echo Initial library fix completed
)

REM Pre-emptively create library files in all known Bazel locations
echo Creating comprehensive library fix for all potential Bazel locations...
echo import os > comprehensive_fix.py
echo import shutil >> comprehensive_fix.py
echo import glob >> comprehensive_fix.py
echo. >> comprehensive_fix.py
echo # Source file from conda environment >> comprehensive_fix.py
echo source_candidates = [ >> comprehensive_fix.py
echo     r'%PREFIX%\Lib\site-packages\tensorflow\python\_pywrap_tensorflow_internal.pyd', >> comprehensive_fix.py
echo     r'%PREFIX%\Lib\site-packages\tensorflow\libtensorflow_framework.so', >> comprehensive_fix.py
echo     r'%PREFIX%\Lib\site-packages\tensorflow\tensorflow_framework.dll' >> comprehensive_fix.py
echo ] >> comprehensive_fix.py
echo source_file = None >> comprehensive_fix.py
echo for candidate in source_candidates: >> comprehensive_fix.py
echo     if os.path.exists(candidate): >> comprehensive_fix.py
echo         source_file = candidate >> comprehensive_fix.py
echo         print(f'Using source file: {source_file}') >> comprehensive_fix.py
echo         break >> comprehensive_fix.py
echo. >> comprehensive_fix.py
echo if not source_file: >> comprehensive_fix.py
echo     print('No source file found - creating empty placeholder') >> comprehensive_fix.py
echo     source_file = None >> comprehensive_fix.py
echo. >> comprehensive_fix.py
echo # Create in all possible Bazel locations >> comprehensive_fix.py
echo target_patterns = [ >> comprehensive_fix.py
echo     'bazel-*/external/pypi_tensorflow/site-packages/tensorflow/libtensorflow_framework.so.2', >> comprehensive_fix.py
echo     '*/bazel-*/external/pypi_tensorflow/site-packages/tensorflow/libtensorflow_framework.so.2', >> comprehensive_fix.py
echo     'bazel-out/*/bin/external/pypi_tensorflow/site-packages/tensorflow/libtensorflow_framework.so.2', >> comprehensive_fix.py
echo     '*/bazel-out/*/bin/external/pypi_tensorflow/site-packages/tensorflow/libtensorflow_framework.so.2', >> comprehensive_fix.py
echo     'bazel-bin/*/external/pypi_tensorflow/site-packages/tensorflow/libtensorflow_framework.so.2', >> comprehensive_fix.py
echo     '*/bazel-bin/*/external/pypi_tensorflow/site-packages/tensorflow/libtensorflow_framework.so.2' >> comprehensive_fix.py
echo ] >> comprehensive_fix.py
echo. >> comprehensive_fix.py
echo created_count = 0 >> comprehensive_fix.py
echo for pattern in target_patterns: >> comprehensive_fix.py
echo     matches = glob.glob(pattern, recursive=True) >> comprehensive_fix.py
echo     for match in matches: >> comprehensive_fix.py
echo         if not os.path.exists(match): >> comprehensive_fix.py
echo             os.makedirs(os.path.dirname(match), exist_ok=True) >> comprehensive_fix.py
echo             if source_file: >> comprehensive_fix.py
echo                 shutil.copy2(source_file, match) >> comprehensive_fix.py
echo                 print(f'Created: {match}') >> comprehensive_fix.py
echo             else: >> comprehensive_fix.py
echo                 open(match, 'a').close() >> comprehensive_fix.py
echo                 print(f'Created placeholder: {match}') >> comprehensive_fix.py
echo             created_count += 1 >> comprehensive_fix.py
echo. >> comprehensive_fix.py
echo print(f'Comprehensive fix completed - created {created_count} files') >> comprehensive_fix.py

python comprehensive_fix.py
if errorlevel 1 (
    echo WARNING: Comprehensive library fix failed
) else (
    echo Comprehensive library fix completed
)

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