BUILD_FLAGS=-Xswiftc "-sdk" \
	-Xswiftc "`xcrun --sdk iphonesimulator --show-sdk-path`" \
	-Xswiftc "-target" \
	-Xswiftc "x86_64-apple-ios13.0-simulator"

build:
	swift build $(BUILD_FLAGS)
