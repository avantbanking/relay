echo "Compiling..."
printenv
git submodule update --init --recursive
rome download
fastlane scan
