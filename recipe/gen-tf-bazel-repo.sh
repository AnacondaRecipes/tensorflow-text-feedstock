#!/bin/bash
# gen-tf-bazel-repo.sh
# Usage: gen-tf-bazel-repo.sh <tf_path>
set -e

TF_PATH="${1:?Usage: $0 <tf_path>}"

cat > "${TF_PATH}/BUILD.bazel" << 'EOF'
cc_library(
    name = "tf_header_lib",
    hdrs = glob(["include/**/*"]),
    strip_include_prefix = "include/",
    visibility = ["//visibility:public"],
)
cc_import(
    name = "libtensorflow_framework",
    shared_library = select({
        "@bazel_tools//src/conditions:darwin": "libtensorflow_framework.2.dylib",
        "//conditions:default": "libtensorflow_framework.so.2",
    }),
    visibility = ["//visibility:public"],
)
py_library(
    name = "pkg",
    visibility = ["//visibility:public"],
)
EOF

touch "${TF_PATH}/WORKSPACE"
echo "Generated BUILD.bazel and WORKSPACE in ${TF_PATH}"
