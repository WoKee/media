#!/bin/bash
set -eux

echo "ANDROID_NDK_HOME=$ANDROID_NDK_HOME"
echo "NDK_PATH=$NDK_PATH"

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
SYSROOT="${NDK_PATH}/toolchains/llvm/prebuilt/linux-x86_64/sysroot"

# Verify paths
echo "AV3A_SRC=${AV3A_SRC}"
ls "${AV3A_SRC}/src/"
ls "${AV3A_SRC}/include/"
echo "TOOLCHAIN=${TOOLCHAIN}"
ls "${TOOLCHAIN}/aarch64-linux-android21-clang"

build_av3a_for_arch() {
    local arch="$1"
    local target="$2"
    local opt_cflags="$3"

    echo "=== Building AV3A for ${arch} (target: ${target}) ==="
    local prefix="${AV3A_BASE}/${arch}"
    mkdir -p "${prefix}/include" "${prefix}/lib"

    local cc="${TOOLCHAIN}/${target}-clang"

    # Compile all source files
    local obj_list="${prefix}/lib/objs.txt"
    > "${obj_list}"
    for src in "${AV3A_SRC}/src/"*.c; do
        local base
        base=$(basename "${src}" .c)
        local obj="${prefix}/lib/${base}.o"
        echo "  CC ${base}.c"
        "${cc}" -c "${src}" -o "${obj}" \
            --sysroot="${SYSROOT}" \
            -I"${AV3A_SRC}/include" -I"${AV3A_SRC}/src" \
            ${opt_cflags} -fPIC -O2
        echo "${obj}" >> "${obj_list}"
    done

    # Create static library
    echo "  AR libarcdav3a.a"
    "${TOOLCHAIN}/llvm-ar" rcs "${prefix}/lib/libarcdav3a.a" $(cat "${obj_list}")

    # Copy headers
    cp "${AV3A_SRC}/include/"*.h "${prefix}/include/"

    # Clean object files
    rm -f $(cat "${obj_list}") "${obj_list}"

    echo "  Done: $(ls -lh "${prefix}/lib/libarcdav3a.a")"
}

build_av3a_for_arch "armeabi-v7a" "armv7a-linux-androideabi21" "-march=armv7-a -mfloat-abi=softfp"
build_av3a_for_arch "arm64-v8a"  "aarch64-linux-android21"  ""
build_av3a_for_arch "x86"       "i686-linux-android21"      ""
build_av3a_for_arch "x86_64"    "x86_64-linux-android21"    ""

echo "All AV3A builds complete!"

# ============================================================
# 3. Build FFmpeg (all architectures)
# ============================================================
echo "Build FFmpeg"

ANDROID_ABI=21
HOST_PLATFORM="linux-x86_64"
ENABLED_DECODERS=(vorbis opus flac alac pcm_mulaw pcm_alaw mp3 aac ac3 eac3 dca mlp truehd)

# Enable external libraries (av3a via ArcVideo SDK)
export ENABLED_EXTERNALS="libarcdav3a"

echo "NDK path is ${NDK_PATH}"
echo "FFMPEG_MODULE_PATH is ${FFMPEG_MODULE_PATH}"
echo "Enabled decoders: ${ENABLED_DECODERS[*]}"
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
