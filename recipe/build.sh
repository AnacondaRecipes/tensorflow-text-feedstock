#!/bin/bash
set -ex

bazel clean --expunge
bazel shutdown

export PATH=$PREFIX/bin:$PATH

# Disable pip hash checking if Bazel tries to install from requirements
export PIP_NO_BINARY=:none:
export PIP_REQUIRE_HASHES=0

# Tell Bazel to use conda-provided system libraries instead of vendored versions
export TF_SYSTEM_LIBS="com_google_absl"

source gen-bazel-toolchain

if [[ "${target_platform}" == osx-* ]]; then
  export LDFLAGS="${LDFLAGS} -lz -framework CoreFoundation -Xlinker -undefined -Xlinker dynamic_lookup"

  # Force Bazel to use the conda C++ toolchain instead of Bazel's Apple toolchain.
  export BAZEL_NO_APPLE_CPP_TOOLCHAIN=1
  export DEVELOPER_DIR=/Library/Developer/CommandLineTools
  export SDKROOT=${CONDA_BUILD_SYSROOT}
fi

./oss_scripts/run_build.sh

$PYTHON -m pip install tensorflow_text-*.whl -vv --no-deps --no-build-isolation