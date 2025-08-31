#!/bin/sh

# The toolchain
toolchain=$(mktemp -d "tmp_XXXXXX")
wget -qO- https://skarnet.org/toolchains/cross/x86_64-linux-musl_pc-14.2.0.tar.xz | tar -xvJf - -C "${toolchain}" --strip-components=1

# Flag sets
RELEASE_VERSION=${1}
OPTIMIZATION_FLAGS="-O3 -flto=auto -pipe -fdata-sections -ffunction-sections -pthread"
PREPROCESSOR_FLAGS="-U_FORTIFY_SOURCE -D_FORTIFY_SOURCE=3"
SECURITY_FLAGS="-fstack-clash-protection -fstack-protector-strong -fno-plt -fno-delete-null-pointer-checks -fno-strict-overflow -fno-strict-aliasing -ftrivial-auto-var-init=zero -fexceptions"
LINKER_FLAGS="-flto=auto -pthread -s -Wl,-O1,--gc-sections,--sort-common,--strip-all,-z,nodlopen,-z,noexecstack,-z,max-page-size=65536"
STATIC_FLAGS="-static --static"

# Compiler configurations
export RTORRENT_RELEASE=${RELEASE_VERSION}
export CC="x86_64-linux-musl-gcc"
export CXX="x86_64-linux-musl-g++"
export AR="x86_64-linux-musl-ar"
export CFLAGS="${OPTIMIZATION_FLAGS} ${SECURITY_FLAGS} ${STATIC_FLAGS}"
export CXXFLAGS="${CFLAGS}"
export CPPFLAGS="${PREPROCESSOR_FLAGS}"
export LDFLAGS="${LINKER_FLAGS} ${STATIC_FLAGS}"

# Environmental care
export HOST="x86_64-linux-musl"
export PATH="${pwd}/${toolchain}/bin:${PATH}"
export PREFIX="${pwd}/${toolchain}/${HOST}"
export PKG_CONFIG_PATH="${PREFIX}/lib/pkgconfig"
export PKG_CONFIG="pkg-config --static"

# Build helper function
build_tarball() {
  local url="${1}"
  local configure_args="${2}"
  local temp_name
  temp_name=$(mktemp -d "tmp_XXXXXX")

  (
    cd "${temp_name}"
    wget -qO- "${url}" | tar -xvzf - --strip-components=1

    ./configure --prefix="${PREFIX}" ${configure_args}
    make -j"$(nproc)"
    make install
  )

  rm -rf "${temp_name}"
}

build_rtorrent() {
  local url="${1}"
  local configure_args="${2}"
  local temp_name
  temp_name=$(mktemp -d "tmp_XXXXXX")

  (
    cd "${temp_name}"
    wget -qO- "${url}" | tar -xvzf - --strip-components=1

    ./configure ${configure_args} \
        --prefix=/usr/local \
        --sysconfdir=/etc \
        --mandir=/usr/share/man \
        --localstatedir=/var
    make -j"$(nproc)"
    make DESTDIR="/sysroot" install
    install -Dm644 doc/rtorrent.rc /sysroot/etc/rtorrent/rtorrent.rc
  )

  rm -rf "${temp_name}"
}

# Build zlib
build_tarball "https://zlib.net/zlib-1.3.1.tar.gz" \
  "--64 --static"

# Build c-ares
build_tarball "https://github.com/c-ares/c-ares/releases/download/v1.34.5/c-ares-1.34.5.tar.gz" \
  "--disable-shared --enable-static --host=${HOST}"

# Build libressl
build_tarball "https://ftp.openbsd.org/pub/OpenBSD/LibreSSL/libressl-4.1.0.tar.gz" \
  "--disable-shared --enable-static --host=${HOST}"

# Setup SSL certs and build curl
# cacert.pem needs to be in same location on target host
mkdir -p /opt/etc/ssl
wget https://curl.se/ca/cacert.pem -O /opt/etc/ssl/cacert.pem
build_tarball "https://curl.se/download/curl-8.15.0.tar.gz" \
  "--disable-shared --enable-ares --enable-static --without-libpsl --host=${HOST} \
   --with-ca-bundle=/opt/etc/ssl/cacert.pem --with-openssl \
   --disable-docs --disable-manual --disable-dict --disable-gopher --disable-gophers --disable-imap \
   --disable-imaps --disable-ipfs --disable-mqtt --disable-pop3 --disable-pop3s --disable-rtsp \
   --disable-smb --disable-smbs --disable-smtp --disable-smtps --disable-telnet --disable-tftp"

# Build ncurses
# adjust terminfo dir to match target system
build_tarball "https://ftpmirror.gnu.org/ncurses/ncurses-6.5.tar.gz" \
  "--disable-shared --disable-stripping --host=${HOST} \
   --enable-pc-files --enable-widec \
   --with-default-terminfo-dir=/usr/share/terminfo \
   --with-normal --with-termlib --enable-static"

# Build libtorrent
build_tarball "https://github.com/rakshasa/rtorrent/releases/download/v${RTORRENT_RELEASE}/libtorrent-${RTORRENT_RELEASE}.tar.gz" \
  "--disable-debug --disable-shared --enable-static --host=${HOST}"

# Build rtorrent
build_rtorrent "https://github.com/rakshasa/rtorrent/releases/download/v${RTORRENT_RELEASE}/rtorrent-${RTORRENT_RELEASE}.tar.gz" \
  "--disable-debug --disable-shared --enable-static --with-xmlrpc-tinyxml2 --host=${HOST}"

# Clean up
rm -rf "${toolchain}"