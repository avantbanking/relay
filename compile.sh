echo "Compiling..."
git submodule update --init --recursive
carthage bootstrap
fastlane scan