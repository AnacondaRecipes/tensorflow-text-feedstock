@echo off
REM adding host environment bin to the path because on some platforms it uses _build_env/bin/python
REM instead of the host environment python
set PATH=%PREFIX%\Scripts;%PREFIX%\bin;%PATH%

REM Run the build script
bash oss_scripts/run_build.sh
if errorlevel 1 exit 1

REM Install the built wheel
%PYTHON% -m pip install tensorflow_text-*.whl -vv --no-deps --no-build-isolation
if errorlevel 1 exit 1

REM run the tests here since the build and host requirements are necessary for building
REM tensorflow-datasets temporarily disabled due to protobuf conflicts with TF 2.18.1
REM if not "%PY_VER%"=="3.13" (
REM     bash oss_scripts/run_tests.sh
REM     if errorlevel 1 exit 1
REM )