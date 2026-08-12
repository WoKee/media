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
# 2. Build ArcVideo AV3A SDK for all 4 Android architectures
# ============================================================
echo "Building ArcVideo AV3A SDK for all architectures..."

AV3A_SRC="${FFMPEG_SRC}/dependency/avs3a"
AV3A_BASE="${FFMPEG_SRC}/android-libs/avs3a"
TOOLCHAIN="${NDK_PATH}/toolchains/llvm/prebuilt/linux-x86_64/bin"
JOBS=$(nproc 2> /dev/null || echo 4)

# Collect all .c source files
AV3A_SRCS=$(ls "${AV3A_SRC}/src/"*.c)

# Architecture configurations: "arch|target|cflags"
ARCH_CONFIGS="
armeabi-v7a|armv7a-linux-androideabi21|-march=armv7-a -mfloat-abi=softfp
arm64-v8a|aarch64-linux-android21|
x86|i686-linux-android21|
x86_64|x86_64-linux-android21|
"

for entry in ${ARCH_CONFIGS}; do
    IFS='|' read -r arch target opt_cflags <<< "${entry}"
    [ -z "${arch}" ] && continue

    echo "=== Building AV3A for ${arch} ==="
    AV3A_PREFIX="${AV3A_BASE}/${arch}"
    mkdir -p "${AV3A_PREFIX}/include" "${AV3A_PREFIX}/lib"

    CC="${TOOLCHAIN}/${target}-clang"
    SYSROOT="${NDK_PATH}/toolchains/llvm/prebuilt/linux-x86_64/sysroot"

    # Compile all source files
    OBJ_FILES=""
    for src in ${AV3A_SRCS}; do
        obj="${AV3A_PREFIX}/lib/$(basename ${src} .c).o"
        echo "  Compiling $(basename ${src})..."
        ${CC} -c "${src}" -o "${obj}" \
            --sysroot="${SYSROOT}" \
            -I"${AV3A_SRC}/include" -I"${AV3A_SRC}/src" \
            ${opt_cflags} -fPIC -O2
        OBJ_FILES="${OBJ_FILES} ${obj}"
    done

    # Create static library
    echo "  Creating libarcdav3a.a..."
    ${TOOLCHAIN}/llvm-ar rcs "${AV3A_PREFIX}/lib/libarcdav3a.a" ${OBJ_FILES}

    # Copy headers
    cp "${AV3A_SRC}/include/"*.h "${AV3A_PREFIX}/include/"

    # Clean up object files
    rm -f ${OBJ_FILES}

    echo "  AV3A for ${arch} done: $(ls -lh ${AV3A_PREFIX}/lib/libarcdav3a.a)"
done

echo "All AV3A builds complete!"

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
