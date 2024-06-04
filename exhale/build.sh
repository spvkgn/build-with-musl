#!/bin/bash
set -eo pipefail

# export CFLAGS="-O3 -fno-strict-aliasing"
export DESTDIR=$GITHUB_WORKSPACE/out

case $ARCH in
  x86_64)  PLATFORM=x64 ;;
  x86)     PLATFORM=x86 ;;
  aarch64) PLATFORM=arm64 ;;
  armhf)   PLATFORM=arm ;;
  *)       PLATFORM=$ARCH ;;
esac

cd "$GITHUB_WORKSPACE/$PKG_NAME"

git clone https://gitlab.com/ecodis/exhale.git "$PKG_NAME" && \
git -C "$PKG_NAME" tag | sort -V | tail -1 | xargs git -C "$PKG_NAME" checkout && \

mkdir -p "$PKG_NAME/_build" && \
cmake -S "$PKG_NAME" -B "$PKG_NAME/_build" \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX=/usr \
  -DCMAKE_EXE_LINKER_FLAGS="-static-libgcc -static-libstdc++ -static" && \
cmake --build "$PKG_NAME/_build" --target install/strip -- -j$(nproc) || exit 1

PKG_VERSION=$(grep -Poi 'exhale version \K(\d+\.)+\d+' "$PKG_NAME/CMakeLists.txt")

( cd $GITHUB_WORKSPACE/out/usr/bin && tar -cJvf "$GITHUB_WORKSPACE/$PKG_NAME-$PKG_VERSION-$PLATFORM.tar.xz" exhale )
