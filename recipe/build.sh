# adding host environment bin to the path because on some platforms it uses _build_env/bin/python
# instead of the host environment python
export PATH=$PREFIX/bin:$PATH

# Build environment has no PyPI access, but Bazel still runs requirements.update directly
# Remove problematic dependencies that can't be resolved from PyPI
echo "Removing PyPI-inaccessible dependencies from requirements files..."

# Remove PyPI-inaccessible constraints that cause failures
find . -name "requirements*.in" -o -name "requirements*.txt" | while read file; do
    if [ -f "$file" ]; then
        # Check for and remove problematic dependencies
        if grep -q "setuptools==70.0.0\|tensorflow\|tf-keras" "$file" 2>/dev/null; then
            echo "Removing PyPI-inaccessible dependencies from $file"
            sed -i '/setuptools==70.0.0/d' "$file" || true
            sed -i '/tensorflow/d' "$file" || true
            sed -i '/tf-keras/d' "$file" || true
        fi
    fi
done

echo "Using conda-provided dependencies for compilation"

# Create a minimal @pypi_tensorflow repository for Bazel since we removed tensorflow from requirements
# but BUILD files still expect this repository to exist
echo "Creating @pypi_tensorflow repository stub for Bazel..."
mkdir -p external/pypi_tensorflow/site-packages

# Get the real tensorflow path (not keras redirect)
TENSORFLOW_PATH=$(python -c "import tensorflow as tf; import os; print(os.path.dirname(tf.__file__))")
ln -sf "$TENSORFLOW_PATH" external/pypi_tensorflow/site-packages/tensorflow
echo "Created: external/pypi_tensorflow/site-packages/tensorflow -> $TENSORFLOW_PATH"

# Create a minimal BUILD file for the repository
cat > external/pypi_tensorflow/BUILD << 'EOF'
package(default_visibility = ["//visibility:public"])

filegroup(
    name = "tensorflow_pkg",
    srcs = glob(["site-packages/tensorflow/**"]),
)
EOF
echo "Created: external/pypi_tensorflow/BUILD"

# Skip the problematic tensorflow_build_info target that requires @pypi_tensorflow
# and build the main pip package directly
echo "Building TensorFlow Text pip package directly..."
bazel run //oss_scripts/pip_package:build_pip_package -- "$(realpath .)"

$PYTHON -m pip install tensorflow_text-*.whl -vv --no-deps --no-build-isolation

# run the tests here since the build and host requirements are necessary for building
# tensorflow-datasets temporarily disabled due to protobuf conflicts with TF 2.18.1
# if [[ $PY_VER != "3.13" ]]
# then
#     source ./oss_scripts/run_tests.sh
# fi