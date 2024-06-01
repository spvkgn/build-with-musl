#!/bin/bash
set -eo pipefail

export CC="ccache clang"
export LD="ld.lld"
export OPT_FLAGS="-fno-strict-aliasing -O3"
export CCACHE_DIR="$GITHUB_WORKSPACE/.ccache"

BUILD_DIR=$GITHUB_WORKSPACE/build
export PKG_CONFIG_PATH="$BUILD_DIR/lib/pkgconfig"

case $ARCH in
  x86_64)  PLATFORM=x64 ;;
  x86)     PLATFORM=x86 ;;
  aarch64) PLATFORM=arm64 ;;
  armhf)   PLATFORM=arm ;;
  *)       PLATFORM=$ARCH ;;
esac

mkdir -p "$BUILD_DIR"
cd $GITHUB_WORKSPACE/opus-tools

# build libogg
git clone https://github.com/xiph/ogg.git
( cd ogg
  git checkout v1.3.5 && \
  ./autogen.sh && \
  CC=$CC CFLAGS="$OPT_FLAGS" \
  ./configure --prefix=$BUILD_DIR \
    --disable-shared --enable-static \
    --disable-dependency-tracking && \
  make -j$(nproc) install )

# build FLAC
git clone https://github.com/xiph/flac.git
( cd flac
  git checkout 1.4.3 && \
  ./autogen.sh && \
  CC=$CC CFLAGS="$OPT_FLAGS" \
  ./configure --prefix=$BUILD_DIR \
    --disable-shared --enable-static \
    --disable-dependency-tracking \
    --disable-debug \
    --disable-oggtest \
    --disable-cpplibs \
    --disable-doxygen-docs \
    --with-ogg="$BUILD_DIR" && \
  make -j$(nproc) install )

# build Opus
git clone https://github.com/xiph/opus.git
( cd opus
  git checkout v1.4 && \
  ./autogen.sh && \
  CC=$CC CFLAGS="$OPT_FLAGS" \
  ./configure --prefix=$BUILD_DIR \
    --disable-shared --enable-static \
    --disable-dependency-tracking \
    --disable-maintainer-mode \
    --disable-doc \
    --disable-extra-programs && \
  make -j$(nproc) install )

# build opusfile
git clone https://github.com/xiph/opusfile.git
( cd opusfile
  git checkout v0.12 && \
  ./autogen.sh && \
  CC=$CC CFLAGS="$OPT_FLAGS" \
  ./configure --prefix=$BUILD_DIR \
    --disable-shared --enable-static \
    --disable-dependency-tracking \
    --disable-maintainer-mode \
    --disable-examples \
    --disable-doc \
    --disable-http && \
  make -j$(nproc) install )

# build libopusenc
git clone https://github.com/xiph/libopusenc.git
( cd libopusenc
  git checkout v0.2.1 && \
  ./autogen.sh && \
  CC=$CC CFLAGS="$OPT_FLAGS" \
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
  CC=$CC CFLAGS="$OPT_FLAGS" \
  LDFLAGS="-Wl,-static -static -static-libgcc -no-pie" \
  ./configure --prefix=$BUILD_DIR \
    --disable-dependency-tracking \
    --disable-maintainer-mode
  make -j$(nproc) install )

( cd $BUILD_DIR/bin ; tar -cJvf $GITHUB_WORKSPACE/opus-tools-$PLATFORM.tar.xz opus* )

ccache --max-size=50M --show-stats
