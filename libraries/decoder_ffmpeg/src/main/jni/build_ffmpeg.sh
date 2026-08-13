#!/bin/bash
#
# Copyright (C) 2019 The Android Open Source Project
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
set -eu

FFMPEG_MODULE_PATH="$1"
echo "FFMPEG_MODULE_PATH is ${FFMPEG_MODULE_PATH}"
NDK_PATH="$2"
echo "NDK path is ${NDK_PATH}"
HOST_PLATFORM="$3"
echo "Host platform is ${HOST_PLATFORM}"
ANDROID_ABI="$4"
echo "ANDROID_ABI is ${ANDROID_ABI}"
ENABLED_DECODERS=("${@:5}")
echo "Enabled decoders are ${ENABLED_DECODERS[@]}"
JOBS="$(nproc 2> /dev/null || sysctl -n hw.ncpu 2> /dev/null || echo 4)"
echo "Using $JOBS jobs for make"
COMMON_OPTIONS="
    --target-os=android
    --enable-static
    --disable-shared
    --disable-doc
    --disable-programs
    --disable-everything
    --disable-avdevice
    --disable-avformat
    --disable-swscale
    --disable-avfilter
    --disable-symver
    --enable-swresample
    --extra-ldexeflags=-pie
    --disable-v4l2-m2m
    --disable-vulkan
    --enable-libarcdav3a
    "
TOOLCHAIN_PREFIX="${NDK_PATH}/toolchains/llvm/prebuilt/${HOST_PLATFORM}/bin"
if [[ ! -d "${TOOLCHAIN_PREFIX}" ]]
then
    echo "Please set correct NDK_PATH, $NDK_PATH is incorrect"
    exit 1
fi

for decoder in "${ENABLED_DECODERS[@]}"
do
    COMMON_OPTIONS="${COMMON_OPTIONS} --enable-decoder=${decoder}"
done

ARMV7_CLANG="${TOOLCHAIN_PREFIX}/armv7a-linux-androideabi${ANDROID_ABI}-clang"
if [[ ! -e "$ARMV7_CLANG" ]]
then
    echo "AVMv7 Clang compiler with path $ARMV7_CLANG does not exist"
    echo "It's likely your NDK version doesn't support ANDROID_ABI $ANDROID_ABI"
    echo "Either use older version of NDK or raise ANDROID_ABI (be aware that ANDROID_ABI must not be greater than your application's minSdk)"
    exit 1
fi
ANDROID_ABI_64BIT="$ANDROID_ABI"
if [[ "$ANDROID_ABI_64BIT" -lt 21 ]]
then
    echo "Using ANDROID_ABI 21 for 64-bit architectures"
    ANDROID_ABI_64BIT=21
fi

# --- Build AV3A (avs3a) external library for armeabi-v7a ---
AV3A_SRC="${FFMPEG_MODULE_PATH}/jni/ffmpeg/dependency/avs3a"
AV3A_INSTALL_ARMV7="${FFMPEG_MODULE_PATH}/jni/ffmpeg/dependency/avs3a/install/armeabi-v7a"
mkdir -p "${AV3A_INSTALL_ARMV7}"
cmake -B "${AV3A_SRC}/build-armeabi-v7a" -S "${AV3A_SRC}" \
    -DCMAKE_TOOLCHAIN_FILE="${NDK_PATH}/build/cmake/android.toolchain.cmake" \
    -DANDROID_ABI=armeabi-v7a -DANDROID_PLATFORM=android-${ANDROID_ABI} \
    -DCMAKE_INSTALL_PREFIX="${AV3A_INSTALL_ARMV7}"
cmake --build "${AV3A_SRC}/build-armeabi-v7a" --parallel $JOBS
cmake --install "${AV3A_SRC}/build-armeabi-v7a"

cd "${FFMPEG_MODULE_PATH}/jni/ffmpeg"
PKG_CONFIG_BIN="$(which pkg-config)"
PKG_CONFIG_LIBDIR="${AV3A_INSTALL_ARMV7}/lib/pkgconfig" \
./configure \
    --libdir=android-libs/armeabi-v7a \
    --arch=arm \
    --cpu=armv7-a \
    --cross-prefix="${TOOLCHAIN_PREFIX}/armv7a-linux-androideabi${ANDROID_ABI}-" \
    --nm="${TOOLCHAIN_PREFIX}/llvm-nm" \
    --ar="${TOOLCHAIN_PREFIX}/llvm-ar" \
    --ranlib="${TOOLCHAIN_PREFIX}/llvm-ranlib" \
    --strip="${TOOLCHAIN_PREFIX}/llvm-strip" \
    --pkg-config="${PKG_CONFIG_BIN}" \
    --extra-cflags="-march=armv7-a -mfloat-abi=softfp -I${AV3A_INSTALL_ARMV7}/include" \
    --extra-ldflags="-Wl,--fix-cortex-a8 -L${AV3A_INSTALL_ARMV7}/lib" \
    ${COMMON_OPTIONS}
make -j$JOBS
make install-libs
make clean
# --- Build AV3A (avs3a) external library for arm64-v8a ---
AV3A_INSTALL_ARM64="${FFMPEG_MODULE_PATH}/jni/ffmpeg/dependency/avs3a/install/arm64-v8a"
mkdir -p "${AV3A_INSTALL_ARM64}"
cmake -B "${AV3A_SRC}/build-arm64-v8a" -S "${AV3A_SRC}" \
    -DCMAKE_TOOLCHAIN_FILE="${NDK_PATH}/build/cmake/android.toolchain.cmake" \
    -DANDROID_ABI=arm64-v8a -DANDROID_PLATFORM=android-${ANDROID_ABI_64BIT} \
    -DCMAKE_INSTALL_PREFIX="${AV3A_INSTALL_ARM64}"
cmake --build "${AV3A_SRC}/build-arm64-v8a" --parallel $JOBS
cmake --install "${AV3A_SRC}/build-arm64-v8a"

PKG_CONFIG_LIBDIR="${AV3A_INSTALL_ARM64}/lib/pkgconfig" \
./configure \
    --libdir=android-libs/arm64-v8a \
    --arch=aarch64 \
    --cpu=armv8-a \
    --cross-prefix="${TOOLCHAIN_PREFIX}/aarch64-linux-android${ANDROID_ABI_64BIT}-" \
    --nm="${TOOLCHAIN_PREFIX}/llvm-nm" \
    --ar="${TOOLCHAIN_PREFIX}/llvm-ar" \
    --ranlib="${TOOLCHAIN_PREFIX}/llvm-ranlib" \
    --strip="${TOOLCHAIN_PREFIX}/llvm-strip" \
    --pkg-config="${PKG_CONFIG_BIN}" \
    --extra-cflags="-I${AV3A_INSTALL_ARM64}/include" \
    --extra-ldflags="-L${AV3A_INSTALL_ARM64}/lib" \
    ${COMMON_OPTIONS}
make -j$JOBS
make install-libs
make clean
# x86 and x86_64 skipped — only armeabi-v7a and arm64-v8a are needed.
