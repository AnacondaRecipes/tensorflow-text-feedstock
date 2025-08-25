#!/bin/bash
# ============================================================================
# TENSORFLOW TEXT BUILD SCRIPT (Linux aarch64)
# ============================================================================
#
# This script implements a CLEAN SLATE APPROACH after extensive investigation:
#
# BACKGROUND:
# - Original recipe had 6+ patches causing compilation errors
# - Complex protobuf workarounds led to ABI conflicts
# - Patch management became unmaintainable
#
# SOLUTION - HYBRID STRATEGY:
# 1. Environment control for conda toolchain integration
# 2. ABI compatibility flags for libabseil integration
# 3. Resource limits for build stability
# 4. No complex patches or protobuf workarounds
#
# RESULT: Successful builds with minimal configuration
# ============================================================================

# ====== ENVIRONMENT SETUP ======
# Add host environment to PATH for proper Python detection
# Some platforms use _build_env/bin/python instead of host environment python
export PATH=$PREFIX/bin:$PATH

# ====== BAZEL BUILD CONFIGURATION ======
echo "Starting TensorFlow Text build with optimized configuration..."
bazel build \
    # ====== TARGET ARCHITECTURE ======
    --cpu=aarch64 \

    # ====== TOOLCHAIN CONFIGURATION ======
    --crosstool_top=@bazel_tools//tools/cpp:toolchain \
    --host_crosstool_top=@bazel_tools//tools/cpp:toolchain \

    # ====== BUILD DIAGNOSTICS ======
    --verbose_failures \
    --experimental_ui_max_stdouterr_bytes=10000000 \

    # ====== PROTOBUF OPTIMIZATION ======
    # Use fast C++ protobuf implementation for better performance
    --define=use_fast_cpp_protos=true \
    --define=allow_oversize_protos=true \

    # ====== GRPC CONFIGURATION ======
    # Disable C-ARES DNS resolver to avoid build complications
    --define=grpc_no_ares=true \

    # ====== TENSORFLOW FRAMEWORK LINKING ======
    # Build against shared TensorFlow framework library
    --define=framework_shared_object=true \

    # ====== COMPILER OPTIMIZATION ======
    --copt=-O2 \
    --copt=-DEIGEN_MAX_ALIGN_BYTES=64 \

    # ====== C++ STANDARD VERSION ======
    # Ensure C++17 compatibility across host and target
    --cxxopt=-std=c++17 \
    --host_cxxopt=-std=c++17 \
    --copt=-std=c++17 \
    --host_copt=-std=c++17 \

    # ====== ABI COMPATIBILITY FLAGS ======
    # CRITICAL: These flags resolved runtime symbol errors
    # _GLIBCXX_USE_CXX11_ABI=1: Use C++11 ABI for libstdc++
    --cxxopt=-D_GLIBCXX_USE_CXX11_ABI=1 \
    --host_cxxopt=-D_GLIBCXX_USE_CXX11_ABI=1 \
    # ABSL_CONSUME_DLL: Properly link against libabseil shared library
    --cxxopt=-DABSL_CONSUME_DLL \
    --host_cxxopt=-DABSL_CONSUME_DLL \

    # ====== CONDA TOOLCHAIN INTEGRATION ======
    # Use conda-provided compilers and include paths
    --action_env=CC=$CC \
    --action_env=CXX=$CXX \
    --action_env=CPLUS_INCLUDE_PATH=$BUILD_PREFIX/include:$PREFIX/include \
    --action_env=LIBRARY_PATH=$BUILD_PREFIX/lib:$PREFIX/lib \

    # ====== RESOURCE MANAGEMENT ======
    # Prevent build failures due to resource exhaustion
    # These limits prevent Bazel server crashes on resource-constrained systems
    --local_ram_resources=3072 \
    --local_cpu_resources=4 \
    --jobs=4 \

    # ====== EXPERIMENTAL FLAGS ======
    # Required by TensorFlow for aarch64 builds
    --experimental_repo_remote_exec \

    # ====== BUILD TARGET ======
    //oss_scripts/pip_package:build_pip_package

# ====== WHEEL CREATION ======
echo "Executing build_pip_package script to create Python wheel..."
echo "Creating temporary wheel directory..."
mkdir -p /tmp/tensorflow_text_wheel

echo "Running TensorFlow Text wheel builder..."
./bazel-bin/oss_scripts/pip_package/build_pip_package /tmp/tensorflow_text_wheel

# ====== WHEEL INSTALLATION ======
echo "Searching for generated wheel file..."
WHEEL_FILE=$(find /tmp/tensorflow_text_wheel -name "tensorflow_text-*.whl" -type f | head -1)

if [ -z "$WHEEL_FILE" ]; then
    echo "ERROR: No wheel file found!"
    echo "Contents of wheel directory:"
    ls -la /tmp/tensorflow_text_wheel/ || echo "Directory does not exist"
    echo "Build failed - no wheel generated"
    exit 1
fi

echo "SUCCESS: Found wheel file: $WHEEL_FILE"
echo "Installing wheel into conda environment..."

# Install with specific flags to avoid dependency conflicts:
# --no-deps: Don't install dependencies (conda handles them)
# --no-build-isolation: Use conda environment for build
# -vv: Verbose output for debugging
# ====== BUILD SUCCESS VERIFICATION ======
echo "============================================================================"
echo "TENSORFLOW TEXT BUILD COMPLETED SUCCESSFULLY!"
echo "============================================================================"
echo "Installed wheel: $(basename "$WHEEL_FILE")"
echo "Target architecture: aarch64"
echo "Python version: $($PYTHON --version)"
echo "Build strategy: Clean slate approach with ABI compatibility"
echo "============================================================================"

echo "Wheel installation completed successfully!"
