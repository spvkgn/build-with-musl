#!/bin/bash
set -eo pipefail

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

cd "$GITHUB_WORKSPACE/$PKG_NAME"

git clone https://gitlab.com/ecodis/exhale.git && \
mkdir -p "$PKG_NAME/_build" && \

cmake -S "$PKG_NAME" -B "$PKG_NAME/_build" \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX=/usr \
  -DCMAKE_CXX_COMPILER=clang \
  -DCMAKE_CXX_COMPILER_LAUNCHER=ccache \
  -DCMAKE_LINKER_TYPE=LLD \
  -DCMAKE_EXE_LINKER_FLAGS="-static-libgcc -static-libstdc++ -static" && \
cmake --build "$PKG_NAME/_build" --target install/strip -- -j$(nproc) || exit 1

( cd $GITHUB_WORKSPACE/out/usr/bin && tar -cJvf $GITHUB_WORKSPACE/$PKG_NAME-$PLATFORM.tar.xz exhale )

ccache --show-stats

  # -DCMAKE_CXX_COMPILER=clang \
