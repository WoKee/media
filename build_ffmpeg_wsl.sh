#!/bin/bash
set -eu

echo "=== [1/4] Installing build dependencies ==="
apt-get update -qq
apt-get install -y -qq build-essential git nasm pkg-config cmake 2>&1 | tail -3

FFMPEG_SRC="/mnt/d/AndroidStudioProjects/media/libraries/decoder_ffmpeg/src/main"
NDK_PATH="/opt/android-ndk-r29"

echo "=== [2/4] Cloning FFmpeg source ==="
cd "${FFMPEG_SRC}/jni"
if [ -d "ffmpeg/.git" ]; then
    echo "FFmpeg source already exists, skipping clone"
else
    rm -rf ffmpeg
    git clone https://github.com/WoKee/FFmpeg --branch=release-9.0-fongmi --depth=1 ffmpeg
fi

echo "=== [3/4] Building FFmpeg static libraries ==="
cd "${FFMPEG_SRC}"
chmod +x jni/build_ffmpeg.sh
./jni/build_ffmpeg.sh "${FFMPEG_SRC}" "${NDK_PATH}" "linux-x86_64" 21 \
    vorbis opus flac eac3 libarcdav3a \
    aac mp3 mp1 mp2 als truehd dca alac \
    amrnb amrwb pcm_mulaw pcm_alaw \
    dsd_msbf dsd_lsbf_planar dsd_msbf_planar dst \
    cook sipr ralf atrac3 atrac3plus \
    wmav1 wmav2 wmapro wmalossless wmavoice

echo "=== [4/4] Verifying output ==="
for abi in armeabi-v7a arm64-v8a; do
    echo "--- ${abi} ---"
    ls -lh "${FFMPEG_SRC}/jni/ffmpeg/android-libs/${abi}/"
done

echo ""
echo "=== BUILD COMPLETE ==="
