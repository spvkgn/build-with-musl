#!/bin/bash
set -eo pipefail

BUILD_DIR=$GITHUB_WORKSPACE/build

# export CC="ccache gcc"
# export LD="ccache ld"
# export AR="ccache ar"
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

get_sources_github() {
  REPO=$1
  wget -qO- --header="Authorization: token $GH_TOKEN" "https://api.github.com/repos/$REPO/releases/latest" |\
    jq -r '.assets[] | select(.name | match("tar.(gz|xz)")) | .browser_download_url' |\
    xargs wget -qO- | bsdtar -x
}

# build libogg
get_sources_github 'xiph/ogg'
( cd libogg-*/
  autoreconf -fi && \
  ./configure \
    --prefix=$BUILD_DIR \
    --disable-shared --enable-static \
    --disable-dependency-tracking && \
  make -j$(nproc) install || exit 1 )

# build FLAC
get_sources_github 'xiph/flac'
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
    --with-ogg=$BUILD_DIR && \
  make -j$(nproc) install-strip DESTDIR=$GITHUB_WORKSPACE/AppDir || exit 1 )

PKG_VERSION=$($GITHUB_WORKSPACE/AppDir/usr/bin/$PKG_NAME -v | awk '{print $2}')
tar -C $GITHUB_WORKSPACE/AppDir/usr/bin -cJvf $GITHUB_WORKSPACE/$PKG_NAME-$PKG_VERSION-$PLATFORM.tar.xz .

ccache --show-stats
