#!/bin/bash
set -eo pipefail

BUILD_DIR=$GITHUB_WORKSPACE/build

export CC="ccache clang"
export LD="ccache ld.lld"
export AR="ccache llvm-ar"
export STRIP=llvm-strip
# export CFLAGS="-O3 -fno-strict-aliasing"
export PKG_CONFIG_PATH="$BUILD_DIR/lib/pkgconfig"
export CCACHE_DIR="$GITHUB_WORKSPACE/.ccache"

case $ARCH in
  x86_64)  PLATFORM=x64 ;;
  x86)     PLATFORM=x86 ;;
  aarch64) PLATFORM=arm64 ;;
  armhf)   PLATFORM=arm ;;
  *)       PLATFORM=$ARCH ;;
esac

mkdir -p "$BUILD_DIR"
cd $GITHUB_WORKSPACE/$PKG_NAME

get_sources() {
  SOURCES_URL=http://downloads.xiph.org/releases/
  NAME=$1
  case $NAME in
    *"ogg"*)  SOURCES_URL+="ogg" ;;
    *"flac"*) SOURCES_URL+="flac" ;;
  esac
  echo "Download $NAME sources"
  wget -qO- $SOURCES_URL |\
    grep -Po "href=\"\K$NAME-(\d+\.)+\d+.*\.tar\.(gz|xz)(?=\")" | sort -V | tail -1 |\
    xargs -I{} wget -qO- $SOURCES_URL/{} | bsdtar -x
}

# build libogg
get_sources libogg
( cd libogg-*/
  autoreconf -fi && \
  ./configure \
    --prefix=$BUILD_DIR \
    --disable-shared --enable-static \
    --disable-dependency-tracking && \
  make -j$(nproc) install || exit 1 )

# build FLAC
get_sources $PKG_NAME
( cd $PKG_NAME-*/
  autoreconf -fi && \
  sed -e 's/@LDFLAGS@/@LDFLAGS@ -all-static/' -i Makefile.in
  LDFLAGS="-Wl,-static -static-libgcc -no-pie" \
  ./configure \
    --prefix=/usr \
    --disable-shared --disable-static \
    --disable-dependency-tracking \
    --disable-debug \
    --disable-oggtest \
    --disable-examples \
    --disable-cpplibs \
    --disable-doxygen-docs \
    --with-ogg="$BUILD_DIR" && \
  make -j$(nproc) install-strip DESTDIR=$GITHUB_WORKSPACE/AppDir || exit 1 )

PKG_VERSION=$($GITHUB_WORKSPACE/AppDir/usr/bin/$PKG_NAME -v | awk '{print $2}')
tar -C $GITHUB_WORKSPACE/AppDir/usr/bin -cJvf $GITHUB_WORKSPACE/$PKG_NAME-$PKG_VERSION-$PLATFORM.tar.xz .

ccache --show-stats
