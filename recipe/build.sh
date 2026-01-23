#!/bin/bash
set -ex

bazel clean --expunge
bazel shutdown

source gen-bazel-toolchain

export PATH=$PREFIX/bin:$PATH

# Tell Bazel to use conda-provided system abseil (critical for ABI compatibility)
export TF_SYSTEM_LIBS="com_google_absl"

if [[ "${target_platform}" == osx-* ]]; then
  export LDFLAGS="${LDFLAGS} -lz -framework CoreFoundation"
  export BAZEL_NO_APPLE_CPP_TOOLCHAIN=1
  export DEVELOPER_DIR=/Library/Developer/CommandLineTools
  export SDKROOT=${CONDA_BUILD_SYSROOT}
fi

cat >> .bazelrc.user <<EOF

build --crosstool_top=//bazel_toolchain:toolchain
build --platforms=//bazel_toolchain:target_platform
build --host_platform=//bazel_toolchain:build_platform
build --extra_toolchains=//bazel_toolchain:cc_cf_toolchain
build --extra_toolchains=//bazel_toolchain:cc_cf_host_toolchain
build --define=PREFIX=${PREFIX}
build --define=PROTOBUF_INCLUDE_PATH=${PREFIX}/include
build --define=with_cross_compiler_support=true
build --repo_env=GRPC_BAZEL_DIR=${PREFIX}/share/bazel/grpc/bazel

# Use system abseil instead of vendored version (critical for ABI compatibility)
build --repo_env=TF_SYSTEM_LIBS=com_google_absl
build --action_env=TF_SYSTEM_LIBS=com_google_absl
build --host_action_env=TF_SYSTEM_LIBS=com_google_absl

# Tell compiler/linker to find abseil in conda's paths
build --action_env=CPLUS_INCLUDE_PATH=${PREFIX}/include
build --host_action_env=CPLUS_INCLUDE_PATH=${PREFIX}/include
build --action_env=LIBRARY_PATH=${PREFIX}/lib
build --host_action_env=LIBRARY_PATH=${PREFIX}/lib
build --linkopt=-L${PREFIX}/lib
build --host_linkopt=-L${PREFIX}/lib

# Needed for access to _deflate()
build --linkopt=-lz
build --host_linkopt=-lz

# Suppress warnings for TensorFlow's std::is_signed specializations
build --copt=-Wno-invalid-specialization
build --host_copt=-Wno-invalid-specialization
EOF

if [[ "${target_platform}" == osx-* ]]; then
  cat >> .bazelrc.user <<EOF

# macOS: Use flat namespace for runtime symbol resolution
build --linkopt=-Wl,-flat_namespace
build --linkopt=-Wl,-undefined,dynamic_lookup
EOF
fi

./oss_scripts/run_build.sh

$PYTHON -m pip install tensorflow_text-*.whl -vv --no-deps --no-build-isolation