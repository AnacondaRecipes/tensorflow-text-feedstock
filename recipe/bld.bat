@echo on
setlocal enabledelayedexpansion

REM Clean and shutdown Bazel
bazel clean --expunge
if errorlevel 1 exit 1
bazel shutdown
if errorlevel 1 exit 1

:: Necessary variables to make conda-build working
set BAZEL_VS="%VSINSTALLDIR%"
set BAZEL_VC="%VSINSTALLDIR%/VC"
set BAZEL_LLVM=%BUILD_PREFIX:\=/%/Library/
set CLANG_COMPILER_PATH=%BUILD_PREFIX:\=/%/Library/bin/clang.exe

REM Convert PREFIX to forward-slash format for .bazelrc.user
set "pfx=%PREFIX:\=/%"

REM Tell Bazel to use conda-provided system abseil (critical for ABI compatibility)
set "TF_SYSTEM_LIBS=com_google_absl"

REM Append to .bazelrc.user file
(
echo.
echo build --crosstool_top=//bazel_toolchain:toolchain
echo build --platforms=//bazel_toolchain:target_platform
echo build --host_platform=//bazel_toolchain:build_platform
echo build --extra_toolchains=//bazel_toolchain:cc_cf_toolchain
echo build --extra_toolchains=//bazel_toolchain:cc_cf_host_toolchain
echo build --define=PREFIX=%pfx%
echo build --define=PROTOBUF_INCLUDE_PATH=%pfx%/include
echo build --define=with_cross_compiler_support=true
echo build --repo_env=GRPC_BAZEL_DIR=%pfx%/share/bazel/grpc/bazel
echo.
echo # Use system abseil instead of vendored version (critical for ABI compatibility)
echo build --repo_env=TF_SYSTEM_LIBS=com_google_absl
echo build --action_env=TF_SYSTEM_LIBS=com_google_absl
echo build --host_action_env=TF_SYSTEM_LIBS=com_google_absl
echo.
echo # Tell compiler/linker to find abseil in conda's paths
echo build --action_env=CPLUS_INCLUDE_PATH=%pfx%/include
echo build --host_action_env=CPLUS_INCLUDE_PATH=%pfx%/include
echo build --action_env=LIBRARY_PATH=%pfx%/lib
echo build --host_action_env=LIBRARY_PATH=%pfx%/lib
echo build --linkopt=-L%pfx%/lib
echo build --host_linkopt=-L%pfx%/lib
echo.
echo # Needed for access to _deflate()
echo build --linkopt=-lz
echo build --host_linkopt=-lz
echo.
echo # Suppress warnings for TensorFlow's std::is_signed specializations
echo build --copt=-Wno-invalid-specialization
echo build --host_copt=-Wno-invalid-specialization
) >> .bazelrc.user

REM Copy Windows batch files to replace bash scripts in source
copy /Y "%RECIPE_DIR%\configure.bat" oss_scripts\configure.bat
if errorlevel 1 exit 1
copy /Y "%RECIPE_DIR%\run_build.bat" oss_scripts\run_build.bat
if errorlevel 1 exit 1

REM Run the build script (which will call configure.bat)
call oss_scripts\run_build.bat
if errorlevel 1 exit 1

REM Install the wheel
%PYTHON% -m pip install tensorflow_text-*.whl -vv --no-deps --no-build-isolation
if errorlevel 1 exit 1
