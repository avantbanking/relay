echo "Compiling..."
git submodule update --init --recursive
carthage_cache install
carthage bootstrap --platform iOS
fastlane scan