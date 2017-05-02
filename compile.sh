echo "Compiling..."
git submodule update --init --recursive
carthage_cache install
fastlane scan
