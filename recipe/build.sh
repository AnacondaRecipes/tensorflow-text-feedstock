# adding host environment bin to the path because on some platforms it uses _build_env/bin/python
# instead of the host environment python
export PATH=$PREFIX/bin:$PATH

# Fix setuptools version issue by modifying requirements files before build
if [ -f "release_or_nightly/requirements.in" ]; then
    echo "Patching requirements.in to use compatible setuptools version..."
    sed -i 's/setuptools==70.0.0/setuptools>=78.0.0,<80.0.0/' release_or_nightly/requirements.in || true
fi

# Also patch any other requirements files that might contain the problematic constraint
find . -name "requirements*.in" -o -name "requirements*.txt" | while read file; do
    if grep -q "setuptools==70.0.0" "$file" 2>/dev/null; then
        echo "Patching $file to use compatible setuptools version..."
        sed -i 's/setuptools==70.0.0/setuptools>=78.0.0,<80.0.0/' "$file" || true
    fi
done

./oss_scripts/run_build.sh

$PYTHON -m pip install tensorflow_text-*.whl -vv --no-deps --no-build-isolation

# run the tests here since the build and host requirements are necessary for building
# tensorflow-datasets temporarily disabled due to protobuf conflicts with TF 2.18.1
# if [[ $PY_VER != "3.13" ]]
# then
#     source ./oss_scripts/run_tests.sh
# fi