#!/bin/bash
set -eo pipefail

BUILD_DIR=$GITHUB_WORKSPACE/build

export CC="ccache clang"
export CXX="ccache clang++"
export LD="ccache ld.lld"
export AR="ccache llvm-ar"
export STRIP=llvm-strip
# export CFLAGS="-O3 -fno-strict-aliasing"
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

# build FDK AAC library
git clone https://github.com/mstorsjo/fdk-aac.git && \
( cd fdk-aac
  git tag | sort -V | tail -1 | xargs git checkout && \
  mkdir -p build && \
  cmake -S . -B build \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX=/usr \
    -DBUILD_SHARED_LIBS=OFF && \
  cmake --build build -j --target install/strip -- DESTDIR=$BUILD_DIR || exit 1 )

# build fdkaac
git clone https://github.com/nu774/fdkaac.git && \
( cd fdkaac
  git tag | sort -V | tail -1 | xargs git checkout && \
  autoreconf -fi && \
  CPPFLAGS="-I$BUILD_DIR/usr/include" \
  LDFLAGS="-L$BUILD_DIR/usr/lib -Wl,-static -static -static-libgcc" \
  PKG_CONFIG_PATH="$BUILD_DIR/usr/lib/pkgconfig" \
  ./configure \
    --prefix=/usr \
    --disable-dependency-tracking
  make -j$(nproc) install-strip DESTDIR=$GITHUB_WORKSPACE/AppDir || exit 1 )

PKG_VERSION=$(git -C fdkaac describe --tags | sed 's/v//')
tar -C $GITHUB_WORKSPACE/AppDir/usr/bin -cJvf $GITHUB_WORKSPACE/$PKG_NAME-$PKG_VERSION-$PLATFORM.tar.xz .

ccache --show-stats
