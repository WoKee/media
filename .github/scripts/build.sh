#!/bin/bash
set -eux

echo $ANDROID_NDK_HOME
echo $NDK_PATH

FFMPEG_MODULE_PATH="${GITHUB_WORKSPACE}/libraries/decoder_ffmpeg/src/main"
export MEDIA3_PATH="${GITHUB_WORKSPACE}"

cd "${MEDIA3_PATH}"

# ============================================================
# 1. Clone FFmpeg source
# ============================================================
cd "${FFMPEG_MODULE_PATH}/jni"
rm -rf ffmpeg
git clone --depth=1 -b release-9.0-fongmi https://github.com/WoKee/FFmpeg ffmpeg
cd ffmpeg
FFMPEG_SRC="$(pwd)"

# ============================================================
# 2. Build ArcVideo AV3A SDK (dependency/avs3a)
# ============================================================
echo "Building ArcVideo AV3A SDK..."
AV3A_PREFIX="${FFMPEG_SRC}/android-libs/avs3a"
mkdir -p "${AV3A_PREFIX}"

cd "${FFMPEG_SRC}/dependency/avs3a"
cmake -B build -DCMAKE_INSTALL_PREFIX="${AV3A_PREFIX}" -DCMAKE_C_COMPILER="${NDK_PATH}/toolchains/llvm/prebuilt/linux-x86_64/bin/clang"
cmake --build build -j$(nproc)
cmake --install build

echo "AV3A SDK installed to: ${AV3A_PREFIX}"
ls -lh "${AV3A_PREFIX}/include/"
ls -lh "${AV3A_PREFIX}/lib/"

# Set PKG_CONFIG_PATH so FFmpeg configure can find arcdav3a
export PKG_CONFIG_PATH="${AV3A_PREFIX}/lib/pkgconfig:${PKG_CONFIG_PATH:-}"
echo "PKG_CONFIG_PATH: ${PKG_CONFIG_PATH}"

# Verify pkg-config can find arcdav3a
pkg-config --libs --cflags arcdav3a || echo "WARNING: pkg-config cannot find arcdav3a"

# ============================================================
# 3. Build FFmpeg (all architectures)
# ============================================================
echo "Build FFmpeg"
echo $ANDROID_NDK_HOME
echo $NDK_PATH

ANDROID_ABI=21
HOST_PLATFORM="linux-x86_64"
ENABLED_DECODERS=(vorbis opus flac alac pcm_mulaw pcm_alaw mp3 aac ac3 eac3 dca mlp truehd)

# Enable external libraries (av3a via ArcVideo SDK)
export ENABLED_EXTERNALS="libarcdav3a"

echo "NDK path is ${NDK_PATH}"
echo "FFMPEG_MODULE_PATH is ${FFMPEG_MODULE_PATH}"
echo "Host platform is ${HOST_PLATFORM}"
echo "ANDROID_ABI is ${ANDROID_ABI}"
echo "Enabled decoders are ${ENABLED_DECODERS[@]}"
echo "Enabled externals: ${ENABLED_EXTERNALS}"

cd "${FFMPEG_MODULE_PATH}/jni"
chmod +x build_ffmpeg.sh

bash build_ffmpeg.sh \
    "${FFMPEG_MODULE_PATH}" \
    "${NDK_PATH}" \
    "${HOST_PLATFORM}" \
    "${ANDROID_ABI}" \
    "${ENABLED_DECODERS[@]}"

echo "FFmpeg Build Success"

# Verify
for arch in armeabi-v7a arm64-v8a x86 x86_64; do
    echo "--- ${arch} ---"
    ls -lh "${FFMPEG_MODULE_PATH}/jni/ffmpeg/android-libs/${arch}/" 2>/dev/null || echo "NOT FOUND"
done
