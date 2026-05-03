.PHONY: build-engine-macos build-engine-android all

# MacOS build
build-engine-macos:
	cd engine && go build -o libengine.dylib -buildmode=c-shared main.go
	mv engine/libengine.dylib app/macos/libengine.dylib

# Android build (requires Android NDK)
NDK_PATH ?= /Users/soeilkeisen/Library/Android/sdk/ndk/28.2.13676358
CC_ARM64 = $(NDK_PATH)/toolchains/llvm/prebuilt/darwin-x86_64/bin/aarch64-linux-android30-clang

build-engine-android:
	mkdir -p app/android/app/src/main/jniLibs/arm64-v8a
	cd engine && GOOS=android GOARCH=arm64 CGO_ENABLED=1 CC=$(CC_ARM64) \
		go build -o ../app/android/app/src/main/jniLibs/arm64-v8a/libengine.so -ldflags="-checklinkname=0" -buildmode=c-shared main.go

all: build-engine-macos
