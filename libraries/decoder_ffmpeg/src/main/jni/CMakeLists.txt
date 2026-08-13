#
# Copyright 2021 The Android Open Source Project
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

# LINT.IfChange
cmake_minimum_required(VERSION 3.21.0 FATAL_ERROR)
# LINT.ThenChange(../../../build.gradle.kts)

# FFmpeg 9.0 public headers use standard C++17 attributes.
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

project(libffmpegJNI C CXX)

set(decoder_ffmpeg_main "${CMAKE_CURRENT_SOURCE_DIR}/..")
set(ffmpeg_include "${decoder_ffmpeg_main}/ffmpeg/include")
# Static FFmpeg archives produced by build_ffmpeg.sh (--enable-static --disable-shared).
set(ffmpeg_static_dir "${decoder_ffmpeg_main}/jni/ffmpeg/android-libs/${ANDROID_ABI}")

set(supported_ffmpeg_abis "armeabi-v7a" "arm64-v8a")
list(FIND supported_ffmpeg_abis "${ANDROID_ABI}" supported_ffmpeg_abi_index)
if(supported_ffmpeg_abi_index EQUAL -1)
    message(FATAL_ERROR "Unsupported FFmpeg ABI: ${ANDROID_ABI}")
endif()

# ── FFmpeg static libraries ──────────────────────────────────────────
# Only avcodec, swresample and avutil are needed; build_ffmpeg.sh disables
# avformat, swscale, avdevice, avfilter and postproc.
foreach(ffmpeg_lib avcodec swresample avutil)
    set(ffmpeg_lib_filename lib${ffmpeg_lib}.a)
    set(ffmpeg_lib_file_path ${ffmpeg_static_dir}/${ffmpeg_lib_filename})
    if(NOT EXISTS "${ffmpeg_lib_file_path}")
        message(FATAL_ERROR
                "Missing FFmpeg static library for ${ANDROID_ABI}: ${ffmpeg_lib_file_path}")
    endif()
    add_library(
            ${ffmpeg_lib}
            STATIC
            IMPORTED)
    set_target_properties(
            ${ffmpeg_lib} PROPERTIES
            IMPORTED_LOCATION
            ${ffmpeg_lib_file_path})
endforeach()

# ── AV3A (avs3a) external library ────────────────────────────────────
# libarcdav3a.a is built by CMake in build_ffmpeg.sh from dependency/avs3a/.
set(av3a_lib_dir "${decoder_ffmpeg_main}/jni/ffmpeg/dependency/avs3a/install/${ANDROID_ABI}/lib")
set(av3a_lib_file "${av3a_lib_dir}/libarcdav3a.a")
if(NOT EXISTS "${av3a_lib_file}")
    message(FATAL_ERROR "Missing AV3A library for ${ANDROID_ABI}: ${av3a_lib_file}")
endif()
add_library(arcdav3a STATIC IMPORTED)
set_target_properties(arcdav3a PROPERTIES IMPORTED_LOCATION ${av3a_lib_file})

find_library(android_log_lib log)
find_library(android_egl_lib EGL)
find_library(android_gles_lib GLESv3)
find_library(android_dl_lib dl)
find_library(android_math_lib m)

add_library(ffmpegJNI
            SHARED
            ffmain.cc
            ffcommon.cc
            ffaudio.cc
            ffvideo.cc
            ffvideo_frame.cc
            ffvideo_surface.cc)

target_include_directories(ffmpegJNI
                           PRIVATE ${ffmpeg_include})

# Hide all C/C++ symbols by default; only JNIEXPORT-marked functions are visible.
# This prevents FFmpeg symbols from conflicting with other libraries (e.g. MPV)
# loaded in the same process.
target_compile_options(ffmpegJNI
                       PRIVATE -Wall -Wextra -pthread -fvisibility=hidden)

target_link_libraries(ffmpegJNI
                      PRIVATE avcodec
                      PRIVATE arcdav3a
                      PRIVATE swresample
                      PRIVATE avutil
                      PRIVATE ${android_egl_lib}
                      PRIVATE ${android_gles_lib}
                      PRIVATE ${android_dl_lib}
                      PRIVATE ${android_math_lib}
                      PRIVATE ${android_log_lib})

# --exclude-libs,ALL hides ALL symbols originating from static archives
# (the FFmpeg .a files) so they do not appear in the dynamic symbol table
# of libffmpegJNI.so.  This is the key mechanism that avoids conflicts
# with the main project's MPV which ships its own FFmpeg.
target_link_options(ffmpegJNI
                    PRIVATE "-Wl,--exclude-libs,ALL"
                    PRIVATE -pthread)

# Additional flags needed for "arm64-v8a" from NDK 23.1.7779620 and above.
# See https://github.com/google/ExoPlayer/issues/9933#issuecomment-1029775358.
if(ANDROID_ABI STREQUAL "arm64-v8a")
    target_link_options(ffmpegJNI PRIVATE "-Wl,-Bsymbolic")
endif()
