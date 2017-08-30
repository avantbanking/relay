echo "Compiling..."
printenv
echo "we got $AWS_SECRET_ACCESS_KEY and $AWS_ACCESS_KEY_ID"
git submodule update --init --recursive
rome download
fastlane scan
