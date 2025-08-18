# adding host environment bin to the path because on some platforms it uses _build_env/bin/python
# instead of the host environment python
export PATH=$PREFIX/bin:$PATH

# Fix dependency version issues by removing requirements that conda already provides
# since we already have them from conda and Bazel's isolated environment can't access them
if [ -f "release_or_nightly/requirements.in" ]; then
    echo "Removing conda-provided dependencies from requirements.in..."
    sed -i '/setuptools==70.0.0/d' release_or_nightly/requirements.in || true
    sed -i '/tensorflow/d' release_or_nightly/requirements.in || true
    sed -i '/tf-keras/d' release_or_nightly/requirements.in || true
fi

# Also patch any other requirements files that might contain problematic constraints
find . -name "requirements*.in" -o -name "requirements*.txt" | while read file; do
    if grep -q "setuptools==70.0.0\|tensorflow\|tf-keras" "$file" 2>/dev/null; then
        echo "Removing conda-provided dependencies from $file..."
        sed -i '/setuptools==70.0.0/d' "$file" || true
        sed -i '/tensorflow/d' "$file" || true
        sed -i '/tf-keras/d' "$file" || true
    fi
done

# Let prepare_tf_dep.sh run to set up @pypi_tensorflow repository properly
# Our dependency removal should prevent the pip conflicts that were blocking it before
echo "Allowing prepare_tf_dep.sh to run with cleaned requirements files..."

./oss_scripts/run_build.sh

$PYTHON -m pip install tensorflow_text-*.whl -vv --no-deps --no-build-isolation

# run the tests here since the build and host requirements are necessary for building
# tensorflow-datasets temporarily disabled due to protobuf conflicts with TF 2.18.1
# if [[ $PY_VER != "3.13" ]]
# then
#     source ./oss_scripts/run_tests.sh
# fi