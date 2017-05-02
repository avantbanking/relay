echo "Compiling..."
git submodule update --init --recursive
carthage bootstrap --platform iOS
fastlane scan