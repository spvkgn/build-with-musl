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
cd $GITHUB_WORKSPACE/opus-tools

get_sources() {
  SOURCES_URL=http://downloads.xiph.org/releases/
  NAME=$1
  case $NAME in
    *"opus"*) SOURCES_URL+="opus" ;;
    *"ogg"*)  SOURCES_URL+="ogg" ;;
    *"flac"*) SOURCES_URL+="flac" ;;
  esac
  echo "Download $NAME sources"
  wget -qO- $SOURCES_URL |\
    grep -Po "href=\"\K$NAME-(\d+\.)+\d+.*\.tar\.(gz|xz)(?=\")" | sort -V | tail -1 |\
    xargs -I{} wget -qO- $SOURCES_URL/{} | bsdtar -x
}

get_sources_github() {
  REPO=$1
  wget -qO- --header="Authorization: token $GH_TOKEN" "https://api.github.com/repos/$REPO/releases/latest" |\
    jq -r '.assets[] | select(.name | match("tar.(gz|xz)")) | .browser_download_url' |\
    xargs wget -qO- | bsdtar -x
}

# build libogg
get_sources libogg
( cd libogg-*/
  autoreconf -fi && \
  ./configure --prefix=$BUILD_DIR \
    --disable-shared --enable-static \
    --disable-dependency-tracking && \
  make -j$(nproc) install )

# build FLAC
get_sources flac
( cd flac-*/
  autoreconf -fi && \
  ./configure --prefix=$BUILD_DIR \
    --disable-shared --enable-static \
    --disable-dependency-tracking \
    --disable-debug \
    --disable-oggtest \
    --disable-programs \
    --disable-examples \
    --disable-cpplibs \
    --disable-doxygen-docs \
    --with-ogg="$BUILD_DIR" && \
  make -j$(nproc) install )

# build Opus
get_sources opus
OPUS_VERSION=$(grep -hPo '="\K(\d+\.)+\d' opus-*/package_version)
( cd opus-*/
  [[ "$PLATFORM" == "arm" ]] && EXTRA_CONFIG_FLAGS=--enable-fixed-point
  autoreconf -fi && \
  ./configure --prefix=$BUILD_DIR \
    --disable-shared --enable-static \
    --disable-dependency-tracking \
    --disable-maintainer-mode \
    --disable-doc \
    --disable-extra-programs $EXTRA_CONFIG_FLAGS && \
  make -j$(nproc) install )

# build opusfile
get_sources opusfile
( cd opusfile-*/
  [[ "$PLATFORM" == "arm" ]] && EXTRA_CONFIG_FLAGS=--enable-fixed-point
  autoreconf -fi && \
  ./configure --prefix=$BUILD_DIR \
    --disable-shared --enable-static \
    --disable-dependency-tracking \
    --disable-maintainer-mode \
    --disable-examples \
    --disable-doc \
    --disable-http $EXTRA_CONFIG_FLAGS && \
  make -j$(nproc) install )

# build libopusenc
get_sources libopusenc
( cd libopusenc-*/
  autoreconf -fi && \
  ./configure --prefix=$BUILD_DIR \
    --disable-shared --enable-static \
    --disable-dependency-tracking \
    --disable-maintainer-mode \
    --disable-examples \
    --disable-doc && \
  make -j$(nproc) install )

# build opus-tools
git clone --depth 1 https://github.com/xiph/opus-tools.git
( cd opus-tools
  ./autogen.sh && \
  sed -e 's/@LDFLAGS@/@LDFLAGS@ -all-static/' -i Makefile.in
  LDFLAGS="-Wl,-static -static -static-libgcc" \
  ./configure --prefix=$BUILD_DIR \
    --disable-dependency-tracking \
    --disable-maintainer-mode
  make -j$(nproc) install )

( cd $BUILD_DIR/bin ; $STRIP opus* ; tar -cJvf $GITHUB_WORKSPACE/opus-tools-libopus$OPUS_VERSION-$PLATFORM.tar.xz opus* )

ccache --show-stats
