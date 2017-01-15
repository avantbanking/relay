git submodule update --init --recursive
carthage bootstrap --platform iOS
xcodebuild test -project Relay.xcodeproj -scheme Relay -sdk iphonesimulator10.2 -destination 'platform=iOS Simulator,OS=10.2,id=22FA2149-1241-469C-BF6D-462D3837DB72'
jazzy