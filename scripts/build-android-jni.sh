#!/usr/bin/env bash
# 交叉编译 vnt-jni 的三个 Android ABI，并安装到 VntApp 的 jniLibs。
#
# 在 WSL 中执行：bash /mnt/c/projects/VntApp/scripts/build-android-jni.sh
# 复用本机已有的 Rust target 与 NDK（默认 /opt/android/android-ndk-r27d），
# 以及 /opt/vnt-android-target 的硬链接拷贝作为 CARGO_TARGET_DIR 增量缓存，
# 不安装任何工具链。可用环境变量覆盖：VNT_DIR / APP_DIR / NDK_HOME / TARGET_DIR。
set -euo pipefail

VNT_DIR="${VNT_DIR:-/mnt/c/projects/vnt}"
APP_DIR="${APP_DIR:-/mnt/c/projects/VntApp}"
NDK_HOME="${NDK_HOME:-/opt/android/android-ndk-r27d}"
TARGET_DIR="${TARGET_DIR:-/home/ubuntu/vnt-android-target}"
TOOLCHAIN="$NDK_HOME/toolchains/llvm/prebuilt/linux-x86_64/bin"

build_abi() {
  local target="$1" abi="$2" clang="$3" cargo_env="$4" cc_env="$5" ar_env="$6"
  echo "==> 构建 $abi ($target)"
  export CARGO_TARGET_DIR="$TARGET_DIR"
  export "CARGO_TARGET_${cargo_env}_LINKER=$TOOLCHAIN/$clang"
  export "CARGO_TARGET_${cargo_env}_RUSTFLAGS=-C link-arg=-Wl,-z,max-page-size=16384"
  export "$cc_env=$TOOLCHAIN/$clang"
  export "$ar_env=$TOOLCHAIN/llvm-ar"
  cargo build --locked --release --manifest-path "$VNT_DIR/Cargo.toml" \
    -p vnt-jni --target "$target"
  local library="$TARGET_DIR/$target/release/libvnt_jni.so"
  test -s "$library"
  # 新 JNI 接口符号在位，旧接口符号已移除
  "$TOOLCHAIN/llvm-nm" -D --defined-only "$library" | grep -q Java_com_vnt_VntManager_nativeInit
  "$TOOLCHAIN/llvm-nm" -D --defined-only "$library" | grep -q Java_com_vnt_VntNetwork_nativeNextEvent
  "$TOOLCHAIN/llvm-nm" -D --defined-only "$library" | grep -q Java_com_vnt_VntNetwork_nativeApplyRuntimeChangeFd
  if "$TOOLCHAIN/llvm-nm" -D --defined-only "$library" | grep -q Java_com_vnt_VntNetwork_nativeRegister; then
    echo "!! $library 仍包含已删除的 nativeRegister 符号" >&2
    exit 1
  fi
  "$TOOLCHAIN/llvm-readelf" -l "$library" \
    | awk '/ LOAD / { found=1; if ($NF != "0x4000") bad=1 } END { exit (!found || bad) }'
  mkdir -p "$APP_DIR/app/src/main/jniLibs/$abi"
  cp -f "$library" "$APP_DIR/app/src/main/jniLibs/$abi/libvnt_jni.so"
  echo "==> 已安装 $APP_DIR/app/src/main/jniLibs/$abi/libvnt_jni.so"
}

build_abi aarch64-linux-android arm64-v8a aarch64-linux-android24-clang \
  AARCH64_LINUX_ANDROID CC_aarch64_linux_android AR_aarch64_linux_android
build_abi armv7-linux-androideabi armeabi-v7a armv7a-linux-androideabi24-clang \
  ARMV7_LINUX_ANDROIDEABI CC_armv7_linux_androideabi AR_armv7_linux_androideabi
build_abi x86_64-linux-android x86_64 x86_64-linux-android24-clang \
  X86_64_LINUX_ANDROID CC_x86_64_linux_android AR_x86_64_linux_android

echo "全部 ABI 构建并安装完成"
