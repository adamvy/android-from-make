SHELL = /bin/bash

.ONESHELL:
.DELETE_ON_ERROR:

# Build Configuration

APP_NAME = hello
ANDROID_API_LEVEL = 30

JAVA_SRCS = \
java/ca/vany/HelloActivity.java \
java/ca/vany/HelloApplication.java

# Alternatively to pick up all java files
# JAVA_SRCS = $(shell find java -type f -iname '*.java')


# Build system below

.PHONY: all

all: $(APP_NAME)-aligned-debugsigned.apk


## Rules to fetch build tools from android sdk
##
## This can be avoided by providing the tool paths to make
## by doing "make AAPT2=/path/to/aapt2 D8=/path/to/d8 APKSIGNER=/path/to/apksigner ZIPALIGN=... ADB=..."

ifeq ($(shell uname -s),Darwin)
  PLAT = mac
else
  PLAT = linux
endif

SDK_URL = "https://dl.google.com/android/repository/commandlinetools-$(PLAT)-6858069_latest.zip"
BUILD_TOOLS_VERSION = 30.0.3
PLATFORM_JAR = android-sdk/platforms/android-$(ANDROID_API_LEVEL)/android.jar
AAPT2 = android-sdk/build-tools/$(BUILD_TOOLS_VERSION)/aapt2
D8 = android-sdk/build-tools/$(BUILD_TOOLS_VERSION)/d8
APKSIGNER = android-sdk/build-tools/$(BUILD_TOOLS_VERSION)/apksigner
ZIPALIGN = android-sdk/build-tools/$(BUILD_TOOLS_VERSION)/zipalign
ADB = android-sdk/platform-tools/adb


crypto/debug.keystore:
	mkdir -p crypto
	keytool -genkeypair -keystore $@ -storepass android.debug -keypass android.debug -alias android.debug

android-sdk/cmdline-tools/bin/sdkmanager:
	wget -O sdk.zip "$(SDK_URL)"
	unzip -d android-sdk sdk.zip
	rm sdk.zip

android-sdk/platform-tools/%: android-sdk/cmdline-tools/bin/sdkmanager
	$< --sdk_root=android-sdk --install "platform-tools"

android-sdk/platforms/android-%/android.jar: android-sdk/cmdline-tools/bin/sdkmanager
	version=$@
	version=$${version##*android-}
	version=$${version%%/android.jar}
	android-sdk/cmdline-tools/bin/sdkmanager --sdk_root=android-sdk --install "platforms;android-$$version"

android-sdk/build-tools/%: android-sdk/cmdline-tools/bin/sdkmanager
	version=$@
	version=$${version##android-sdk/build-tools/}
	version=$${version%%/*}
	android-sdk/cmdline-tools/bin/sdkmanager --sdk_root=android-sdk --install "build-tools;$$version"


clean-sdk:
	rm -rf android-sdk

clean-crypto:
	rm -rf crypto

clean:
	rm -rf build
	rm -f $(APP_NAME).apk
	rm -f $(APP_NAME)-aligned.apk
	rm -f $(APP_NAME)-aligned-debugsigned.apk
	rm -f $(APP_NAME)-aligned-debugsigned.apk.idsig

distclean: clean-sdk clean-crypto clean

build/compile-timestamp: $(JAVA_SRCS)
	mkdir -p build/classes
	javac --release 8 -cp $(PLATFORM_JAR) -d build/classes $(JAVA_SRCS)
	touch $@

build/apk/classes.dex: build/compile-timestamp $(PLATFORM_JAR) $(D8)
	mkdir -p build/apk
	$(D8) --output $(dir $@) --lib $(PLATFORM_JAR) $(shell find build/classes -iname '*.class')

build/apk/resources.arsc: AndroidManifest.xml $(PLATFORM_JAR) $(AAPT2)
	mkdir -p build/apk
	$(AAPT2) link -o $(dir $@) --output-to-dir --target-sdk-version 30 -I $(PLATFORM_JAR) --manifest AndroidManifest.xml

$(APP_NAME).apk: build/apk/resources.arsc build/apk/classes.dex
	jar --create --no-compress --file $@ -C build/apk .

%-aligned.apk: %.apk $(ZIPALIGN)
	$(ZIPALIGN) -p -f -v 4 $< $@

%-aligned-debugsigned.apk: %-aligned.apk crypto/debug.keystore $(APKSIGNER)
	$(APKSIGNER) sign --ks crypto/debug.keystore --ks-key-alias android.debug --ks-pass pass:android.debug --key-pass pass:android.debug --out $@ $<

.PHONY: install
install: $(APP_NAME)-aligned-debugsigned.apk $(ADB)
	$(ADB) install $<

## TODO: Native Support
# Native support can be done with something like
#
#build/lib/arm64-v8a/libfoo.so: native/foo.c
#	mkdir -p $(dir $@)
#	aarch64-linux-gnu-gcc -shared -o $@ native/foo.c
#
# and include lib/arm64-v8a/libfoo.so in the apk
# but that's for another day

## TODO: Actually process resoucres via something like
# generated/R.java: <resource xml files>
# 	$(AAPT2) ...
