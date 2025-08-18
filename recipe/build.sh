# adding host environment bin to the path because on some platforms it uses _build_env/bin/python
# instead of the host environment python
export PATH=$PREFIX/bin:$PATH

# Skip the problematic requirements.update step by setting environment variables
# that tell the build system to use existing packages
export SKIP_REQUIREMENTS_UPDATE=1
export USE_SYSTEM_PACKAGES=1

./oss_scripts/run_build.sh

$PYTHON -m pip install tensorflow_text-*.whl -vv --no-deps --no-build-isolation

# run the tests here since the build and host requirements are necessary for building
# tensorflow-datasets temporarily disabled due to protobuf conflicts with TF 2.18.1
# if [[ $PY_VER != "3.13" ]]
# then
#     source ./oss_scripts/run_tests.sh
# fi