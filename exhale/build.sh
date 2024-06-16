#!/bin/bash
set -eo pipefail

export CC="ccache clang"
export CXX="ccache clang++"
export LD="ccache ld.lld"
export AR="ccache llvm-ar"
export STRIP=llvm-strip
# export CFLAGS="-O3 -fno-strict-aliasing"

case $ARCH in
  x86_64)  PLATFORM=x64 ;;
  x86)     PLATFORM=x86 ;;
  aarch64) PLATFORM=arm64 ;;
  armhf)   PLATFORM=arm ;;
  *)       PLATFORM=$ARCH ;;
esac

cd "$GITHUB_WORKSPACE/$PKG_NAME"

git clone https://gitlab.com/ecodis/exhale.git "$PKG_NAME" && \
( cd "$PKG_NAME" && \
  git tag | sort -V | tail -1 | xargs git checkout && \
  mkdir -p _build && \
  cmake -S . -B _build \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX=/usr \
    -DCMAKE_EXE_LINKER_FLAGS="-static-libgcc -static-libstdc++ -static" && \
  cmake --build _build -j --target install/strip -- DESTDIR=$GITHUB_WORKSPACE/AppDir || exit 1 )

PKG_VERSION=$(git -C $PKG_NAME describe --tags | sed 's/v//')

tar -C $GITHUB_WORKSPACE/AppDir/usr/bin -cJvf "$GITHUB_WORKSPACE/$PKG_NAME-$PKG_VERSION-$PLATFORM.tar.xz" .
