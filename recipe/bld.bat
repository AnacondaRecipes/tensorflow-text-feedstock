@echo off
REM ============================================================================
REM TENSORFLOW TEXT WINDOWS BUILD SCRIPT (ABANDONED)
REM ============================================================================
REM
REM *** IMPORTANT: THIS FILE IS MAINTAINED FOR HISTORICAL REFERENCE ONLY ***
REM
REM WINDOWS BUILDS ARE STRATEGICALLY ABANDONED DUE TO:
REM 1. TensorFlow Text BUILD files hardcode Unix library names (.so files)
REM 2. Windows TensorFlow provides .dll files instead
REM 3. Bazel workspace cleanup removes pre-placed compatibility files
REM 4. Cross-platform fixes require upstream TensorFlow Text changes
REM
REM This extensive Windows implementation demonstrates the complexity involved
REM and serves as documentation for future reference if upstream support improves.
REM ============================================================================
REM
REM ====== ENVIRONMENT SETUP ======
REM Add host environment to PATH for proper Python and tool detection
REM CRITICAL: BUILD_PREFIX must come first so bazel is found
set PATH=%BUILD_PREFIX%\Scripts;%BUILD_PREFIX%\bin;%BUILD_PREFIX%;%PREFIX%\Scripts;%PREFIX%\bin;%PATH%

REM ====== ENVIRONMENT DIAGNOSTICS ======
echo Current directory: %CD%
echo PATH: %PATH%
echo PYTHON: %PYTHON%
echo BUILD_PREFIX: %BUILD_PREFIX%

REM ====== BAZEL VERIFICATION ======
REM Ensure Bazel build system is properly accessible
echo Checking for bazel...
where bazel
if errorlevel 1 (
    echo ERROR: bazel not found in PATH
    echo BUILD_PREFIX: %BUILD_PREFIX%
    dir "%BUILD_PREFIX%\bin" /b | findstr bazel
    exit 1
)
bazel version

REM ====== TENSORFLOW DETECTION ======
REM Verify TensorFlow is available in conda environment
REM This satisfies upstream script requirements for TensorFlow detection
echo Pre-installing tensorflow from conda environment to satisfy upstream script
%PYTHON% -c "import tensorflow; print('TensorFlow ' + tensorflow.__version__ + ' is already available')"
if errorlevel 1 (
    echo ERROR: TensorFlow not found in conda environment
    exit 1
)

REM ====== PYTHON3 COMPATIBILITY ======
REM Create python3 symlink for bash script compatibility
REM Many TensorFlow build scripts expect 'python3' command
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

REM ====== PYPI ACCESS CONTROL ======
REM Temporarily allow PyPI access for upstream dependency installation
REM This is required because TensorFlow Text build scripts install specific versions
echo Allowing upstream script to install tensorflow==2.18.0 from PyPI
set "PIP_NO_INDEX_BACKUP=%PIP_NO_INDEX%"
set "PIP_NO_INDEX=False"

REM ====== DEPENDENCY RESOLUTION ======
REM Install promise package to resolve circular dependency in Bazel requirements
REM This prevents build failures during dependency resolution phase
echo Installing promise via pip...
pip install promise
if errorlevel 1 (
    echo ERROR: Failed to install promise via pip
    exit 1
)
REM Configure pip for build environment compatibility
set "PIP_USE_PEP517=false"
set "PIP_NO_BUILD_ISOLATION=true"
set "PIP_DISABLE_PIP_VERSION_CHECK=1"

REM ====== PYTHON PATH CONFIGURATION ======
REM Set PYTHONPATH for Bazel subprocesses to find conda packages
for /f "delims=" %%i in ('python -c "import site; print(';'.join(site.getsitepackages()))"') do set "PYTHONPATH=%%i"

REM ====== BAZEL BASH COMPATIBILITY ======
REM Copy bazel executable for bash script compatibility
REM Bash scripts expect 'bazel' command without .exe extension
echo Creating simple bazel copy for bash environment...
copy "%BUILD_PREFIX%\Library\bin\bazel.exe" "%BUILD_PREFIX%\bin\bazel" >nul
if errorlevel 1 (
    echo ERROR: Could not copy bazel.exe to bin directory
    exit 1
)

REM ====== PERL BASH COMPATIBILITY ======
REM Copy perl executable for bash script compatibility
REM TensorFlow flatbuffer processing requires perl during build
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

REM ====== BAZEL WINDOWS CONFIGURATION ======
REM Create .bazelrc to handle Windows-specific build issues
REM Disable symlinks to avoid Windows permission problems
echo Creating .bazelrc to disable symlinks...
echo startup --nowindows_enable_symlinks > .bazelrc
echo common --nowindows_enable_symlinks >> .bazelrc
echo build --experimental_allow_unresolved_symlinks >> .bazelrc
echo build --experimental_ignore_unresolved_symlinks >> .bazelrc
echo build --define framework_shared_object=false >> .bazelrc
echo build --config=monolithic >> .bazelrc

REM ====== UPSTREAM SCRIPT PATCHING ======
REM Apply essential patches to upstream build scripts for Windows compatibility
REM These patches modify build flags and wheel creation for Windows environment
echo Applying patches to upstream scripts...
REM Modify run_build.sh to use Windows-compatible flags
powershell -Command "(Get-Content 'oss_scripts/run_build.sh') -replace 'bazel run \$\{BUILD_ARGS\[\@\]\} --enable_runfiles', 'bazel run ${BUILD_ARGS[@]} --enable_runfiles --jobs=1 --keep_going --config=monolithic --define framework_shared_object=false' | Set-Content 'oss_scripts/run_build.sh'"
REM Modify build_pip_package.sh to handle Windows wheel creation
powershell -Command "(Get-Content 'oss_scripts/pip_package/build_pip_package.sh') -replace '\$installed_python setup\.py bdist_wheel --universal \$plat_name', '$installed_python setup.py bdist_wheel --universal #$plat_name' | Set-Content 'oss_scripts/pip_package/build_pip_package.sh'"

REM ====== DYNAMIC LIBRARY COMPATIBILITY SYSTEM ======
REM *** THIS IS THE CORE WINDOWS COMPATIBILITY CHALLENGE ***
REM
REM PROBLEM: TensorFlow Text BUILD files expect Unix library names:
REM   Expected: libtensorflow_framework.so.2
REM   Windows:  tensorflow_framework.dll
REM
REM SOLUTION ATTEMPT: Create compatibility layer by:
REM 1. Finding Windows .dll files
REM 2. Creating .so.2 copies/symlinks
REM 3. Pre-placing files in expected Bazel locations
REM
REM *** LIMITATION: Bazel workspace cleanup removes these files ***
REM
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

REM Execute initial library fix
python fix_libraries.py
if errorlevel 1 (
    echo WARNING: Could not run initial library fix
) else (
    echo Initial library fix completed
)

REM ====== COMPREHENSIVE BAZEL LOCATION PREPARATION ======
REM Attempt to pre-create library files in all potential Bazel workspace locations
REM This tries to work around Bazel's workspace cleanup by pre-populating expected paths
echo Creating comprehensive library fix for all potential Bazel locations...
echo import os > comprehensive_fix.py
echo import shutil >> comprehensive_fix.py
echo import glob >> comprehensive_fix.py
echo. >> comprehensive_fix.py
echo # Source file from conda environment >> comprehensive_fix.py
echo source_candidates = [ >> comprehensive_fix.py
echo     r'%PREFIX%\Lib\site-packages\tensorflow\tensorflow_framework.dll', >> comprehensive_fix.py
echo     r'%PREFIX%\Lib\site-packages\tensorflow\python\_pywrap_tensorflow_internal.pyd', >> comprehensive_fix.py
echo     r'%PREFIX%\Lib\site-packages\tensorflow\libtensorflow_framework.so' >> comprehensive_fix.py
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
echo # Create standard Bazel external repository structure >> comprehensive_fix.py
echo bazel_external_paths = [ >> comprehensive_fix.py
echo     'external/pypi_tensorflow/site-packages/tensorflow', >> comprehensive_fix.py
echo     'bazel-bin/external/pypi_tensorflow/site-packages/tensorflow', >> comprehensive_fix.py
echo     'bazel-out/x64_windows-opt/bin/external/pypi_tensorflow/site-packages/tensorflow' >> comprehensive_fix.py
echo ] >> comprehensive_fix.py
echo. >> comprehensive_fix.py
echo created_count = 0 >> comprehensive_fix.py
echo for path in bazel_external_paths: >> comprehensive_fix.py
echo     target_file = os.path.join(path, 'libtensorflow_framework.so.2') >> comprehensive_fix.py
echo     if not os.path.exists(target_file): >> comprehensive_fix.py
echo         os.makedirs(path, exist_ok=True) >> comprehensive_fix.py
echo         if source_file: >> comprehensive_fix.py
echo             shutil.copy2(source_file, target_file) >> comprehensive_fix.py
echo             print(f'Created: {target_file}') >> comprehensive_fix.py
echo         else: >> comprehensive_fix.py
echo             open(target_file, 'a').close() >> comprehensive_fix.py
echo             print(f'Created placeholder: {target_file}') >> comprehensive_fix.py
echo         created_count += 1 >> comprehensive_fix.py
echo     else: >> comprehensive_fix.py
echo         print(f'Already exists: {target_file}') >> comprehensive_fix.py
echo. >> comprehensive_fix.py
echo print(f'Comprehensive fix completed - created {created_count} files') >> comprehensive_fix.py

REM Execute comprehensive library fix
python comprehensive_fix.py
if errorlevel 1 (
    echo WARNING: Comprehensive library fix failed
) else (
    echo Comprehensive library fix completed
)

REM ====== UPSTREAM BUILD EXECUTION ======
REM Execute the modified upstream build script
REM This will likely fail due to library naming issues despite our preparations
echo Starting upstream build process...
bash oss_scripts/run_build.sh
if errorlevel 1 exit 1
echo Upstream build completed successfully!

REM ====== WHEEL INSTALLATION ======
REM Restore original pip configuration and install generated wheel
echo Installing built wheel into conda environment...
set "PIP_NO_INDEX=%PIP_NO_INDEX_BACKUP%"
%PYTHON% -m pip install tensorflow_text-*.whl --no-deps --no-build-isolation
if errorlevel 1 exit 1
echo Wheel installation completed successfully!

REM ====== TESTING (DISABLED) ======
REM Testing is disabled due to protobuf compatibility conflicts
REM tensorflow-datasets temporarily disabled due to protobuf conflicts with TF 2.18.1
REM Even if the build succeeded, testing would likely fail due to:
REM 1. Protobuf version mismatches
REM 2. Library loading issues
REM 3. Cross-platform path problems
REM
REM if not "%PY_VER%"=="3.13" (
REM     bash oss_scripts/run_tests.sh
REM     if errorlevel 1 exit 1
REM )
REM
REM ============================================================================
REM END OF WINDOWS BUILD SCRIPT
REM
REM *** SUMMARY: COMPREHENSIVE WINDOWS APPROACH ***
REM This script demonstrates extensive efforts to support Windows builds:
REM - Environment compatibility layers
REM - Library name translation systems
REM - Bazel configuration workarounds
REM - Upstream script modifications
REM
REM *** FUNDAMENTAL LIMITATION ***
REM Despite these efforts, Windows builds are abandoned due to:
REM 1. TensorFlow Text hardcoded Unix library names in BUILD files
REM 2. Bazel workspace cleanup defeating compatibility measures
REM 3. Need for upstream TensorFlow Text project changes
REM
REM This script serves as documentation of the complexity involved
REM and provides a foundation if upstream Windows support improves.
REM ============================================================================