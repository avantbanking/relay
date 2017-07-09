echo "Compiling..."
git submodule update --init --recursive
carthage bootstrap --platform ios --cache-builds
fastlane scan
