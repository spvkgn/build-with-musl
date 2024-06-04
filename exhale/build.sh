#!/bin/bash
set -eo pipefail

STRIP=llvm-strip
# export CFLAGS="-O3 -fno-strict-aliasing"
export CCACHE_DIR="$GITHUB_WORKSPACE/.ccache"
export DESTDIR=$GITHUB_WORKSPACE/out

case $ARCH in
  x86_64)  PLATFORM=x64 ;;
  x86)     PLATFORM=x86 ;;
  aarch64) PLATFORM=arm64 ;;
  armhf)   PLATFORM=arm ;;
  *)       PLATFORM=$ARCH ;;
esac

cd $GITHUB_WORKSPACE/exhale

git clone --depth 1 https://gitlab.com/ecodis/exhale.git && \
mkdir -p exhale/_build && \

cmake -S exhale -B exhale/_build \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX=/usr \
  -DCMAKE_CXX_COMPILER_LAUNCHER=ccache \
  -DCMAKE_EXE_LINKER_FLAGS="-static-libgcc -static-libstdc++ -static" && \
cmake --build exhale/_build --target install/strip -- -j$(nproc) || exit 1

( cd $GITHUB_WORKSPACE/out/usr/bin && tar -cJvf $GITHUB_WORKSPACE/exhale-$PLATFORM.tar.xz exhale )

ccache --show-stats

# make -j$(nproc) -C exhale/_build install DESTDIR=$GITHUB_WORKSPACE/out || exit 1
  # -DCMAKE_CXX_COMPILER=clang \
