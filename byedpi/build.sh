#!/bin/bash
set -eo pipefail

case $ARCH in
  x86_64)  PLATFORM=x64 ;;
  x86)     PLATFORM=x86 ;;
  aarch64) PLATFORM=arm64 ;;
  armhf)   PLATFORM=arm ;;
  *)       PLATFORM=$ARCH ;;
esac

cd "$GITHUB_WORKSPACE/$PKG_NAME"

git clone https://github.com/hufrea/byedpi.git "$PKG_NAME" && \
( cd "$PKG_NAME" && \
  git tag | sort -V | tail -1 | xargs git checkout && \
  CC="ccache gcc -static-libgcc -static" make -j$(nproc) || exit 1
  strip -s ciadpi )

PKG_VERSION=$(git -C $PKG_NAME describe --tags | sed 's/v//')

tar -C $PKG_NAME -cJvf "$GITHUB_WORKSPACE/$PKG_NAME-$PKG_VERSION-$PLATFORM.tar.xz" ciadpi
