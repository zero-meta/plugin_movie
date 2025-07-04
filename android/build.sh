#!/bin/sh

# This option is used to exit the script as
# soon as a command returns a non-zero value.
set -o errexit

path=`dirname $0`

TARGET_NAME=zip
CONFIG=Release
DEVICE_TYPE=all
BUILD_TYPE=clean

#
# Checks exit value for error
#
ANDROID_NDK=$HOME/Library/Android/sdk/ndk/28.1.13356709
# if [ -z "$ANDROID_NDK" ]
# then
# 	echo "ERROR: ANDROID_NDK environment variable must be defined"
# 	exit 0
# fi

# Canonicalize paths
pushd $path > /dev/null
dir=`pwd`
path=$dir
popd > /dev/null

######################
# Build .so          #
######################

pushd $path/jni > /dev/null

if [ "Release" == "$CONFIG" ]
then
	echo "Building RELEASE"
	OPTIM_FLAGS="release"
else
	echo "Building DEBUG"
	OPTIM_FLAGS="debug"
fi

if [ "clean" == "$BUILD_TYPE" ]
then
	echo "== Clean build =="
	rm -rf $path/obj/ $path/libs/
	FLAGS="-B"
else
	echo "== Incremental build =="
	FLAGS=""
fi

CFLAGS=

if [ "$OPTIM_FLAGS" = "debug" ]
then
	CFLAGS="${CFLAGS} -DRtt_DEBUG -g"
	FLAGS="$FLAGS NDK_DEBUG=1"
fi

# Copy .so files
unzip -u /Applications/CoronaEnterprise/Corona/android/lib/gradle/Corona.aar "jni/*/*.so" -d "$path/corona-libs"

if [ -z "$CFLAGS" ]
then
	echo "----------------------------------------------------------------------------"
	echo "$ANDROID_NDK/ndk-build $FLAGS V=1 APP_OPTIM=$OPTIM_FLAGS"
	echo "----------------------------------------------------------------------------"

	$ANDROID_NDK/ndk-build $FLAGS V=1 APP_OPTIM=$OPTIM_FLAGS
else
	echo "----------------------------------------------------------------------------"
	echo "$ANDROID_NDK/ndk-build $FLAGS V=1 MY_CFLAGS="$CFLAGS" APP_OPTIM=$OPTIM_FLAGS"
	echo "----------------------------------------------------------------------------"

	$ANDROID_NDK/ndk-build $FLAGS V=1 MY_CFLAGS="$CFLAGS" APP_OPTIM=$OPTIM_FLAGS
fi

find "$path/libs" \( -name liblua.so -or -name libcorona.so -or -name libopenal.so \)  -delete
echo "$path/libs"
rm -rf "$path/jniLibs"
mv "$path/libs" "$path/jniLibs"

popd > /dev/null

######################
# Post-compile Steps #
######################

echo Done.
