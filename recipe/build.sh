#!/bin/bash
set -ex

source gen-bazel-toolchain

export PATH=$PREFIX/bin:$PATH

# Tell Bazel to use conda-provided system abseil (critical for ABI compatibility)
TF_PATH=$(python -c "import tensorflow as tf; import os; print(os.path.dirname(tf.__file__))")
export TF_SYSTEM_LIBS="com_google_absl,com_google_protobuf"
export SYSTEM_LIBS_PREFIX="${PREFIX}"

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

# Use system abseil and protobuf instead of vendored version (critical for ABI compatibility)
build --repo_env=TF_SYSTEM_LIBS=com_google_absl,com_google_protobuf
build --action_env=TF_SYSTEM_LIBS=com_google_absl,com_google_protobuf
build --host_action_env=TF_SYSTEM_LIBS=com_google_absl,com_google_protobuf

# Use system tensorflow
build --override_repository=pypi_tensorflow=${TF_PATH}

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

# Fix memchr not declared in re2 with newer gcc
build --per_file_copt=external/com_googlesource_code_re2/.*@-include,cstring
build --host_per_file_copt=external/com_googlesource_code_re2/.*@-include,cstring

EOF

if [[ "${target_platform}" == osx-* ]]; then
  cat >> .bazelrc.user <<EOF
# macOS: Use flat namespace for runtime symbol resolution
build --linkopt=-Wl,-flat_namespace
build --linkopt=-Wl,-undefined,dynamic_lookup

# macOS: redirect apple-toolchain config away from local_config_apple_cc
# (which is an empty stub when BAZEL_NO_APPLE_CPP_TOOLCHAIN=1 is set)
build:apple-toolchain --apple_crosstool_top=//bazel_toolchain:toolchain
build:apple-toolchain --crosstool_top=//bazel_toolchain:toolchain
build:apple-toolchain --host_crosstool_top=//bazel_toolchain:toolchain

# Suppress warnings for TensorFlow's std::is_signed specializations
build --copt=-Wno-invalid-specialization
build --host_copt=-Wno-invalid-specialization
EOF
fi

bash ${RECIPE_DIR}/gen-tf-bazel-repo.sh "${TF_PATH}"

PY_SITE=$(${PYTHON} -c "import site; print(site.getsitepackages()[0])")
sed -i.bak "s|CONDA_TF_SITE_PACKAGES|${PY_SITE}|g" \
  oss_scripts/pip_package/tensorflow_build_info.py
rm -f oss_scripts/pip_package/tensorflow_build_info.py.bak

./oss_scripts/run_build.sh

$PYTHON -m pip install tensorflow_text-*.whl -vv --no-deps --no-build-isolation
