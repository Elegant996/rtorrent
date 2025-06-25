# syntax=docker/dockerfile:1.7-labs

FROM alpine:3.22 AS build-sysroot

ARG LIBTORRENT_TAG
ARG RTORRENT_TAG

ADD --exclude=*.md --exclude=\.* https://github.com/rakshasa/libtorrent.git#${LIBTORRENT_TAG} /libtorrent
ADD --exclude=*.md --exclude=\.* https://github.com/rakshasa/rtorrent.git#${RTORRENT_TAG} /rtorrent

# Fetch build dependencies
RUN apk add --no-cache \
    autoconf \
    automake \
    cppunit-dev \
    curl-dev \
    dos2unix \
    gcc \
    g++ \
    libsigc++3-dev \
    libtool \
    linux-headers \
    make \
    ncurses-dev \
    openssl-dev>3 \
    tinyxml2-dev \
    zlib-dev

# Prepare libtorrent
WORKDIR /libtorrent
RUN find . -type f -print0 | xargs -0 dos2unix
RUN autoreconf -iv

# Build libtorrent
RUN ./configure \
    --build=$CBUILD \
    --host=$CHOST \
    --prefix=/usr/local \
    --disable-debug
RUN make

# Check libtorrent
RUN make check

# Install libtorrent
RUN make install

# Prepare rtorrent
WORKDIR /rtorrent
RUN find . -type f -print0 | xargs -0 dos2unix
RUN autoreconf -iv

# Build rtorrent
RUN ./configure \
    --build=$CBUILD \
    --host=$CHOST \
    --prefix=/usr/local \
    --sysconfdir=/etc \
    --mandir=/usr/share/man \
    --localstatedir=/var \
    --enable-ipv6 \
    --disable-debug \
    --with-xmlrpc-tinyxml2
RUN make

# Check rtorrent
RUN make check

# Install rtorrent to new system root
RUN make DESTDIR="/sysroot" install
RUN install -Dm644 doc/rtorrent.rc /sysroot/etc/rtorrent/rtorrent.rc
RUN mkdir -p /sysroot/download /sysroot/session /sysroot/watch

# Prepare sysroot
RUN mkdir -p /sysroot/etc/apk && cp -r /etc/apk/* /sysroot/etc/apk/

# Fetch runtime dependencies
RUN apk add --no-cache --initdb -p /sysroot \
    alpine-baselayout \
    busybox \
    ca-certificates \
    curl \
    jq \
    mktorrent \
    ncurses-terminfo-base \
    tini \
    tzdata \
    unzip
RUN rm -rf /sysroot/etc/apk /sysroot/lib/apk /sysroot/var/cache

# Install entrypoint
COPY --chmod=755 ./entrypoint.sh /sysroot/entrypoint.sh

# Build image
FROM scratch
COPY --from=build-sysroot /sysroot /

STOPSIGNAL SIGHUP
EXPOSE 5000
VOLUME [ "/download" ]
ENV HOME="/download"
WORKDIR $HOME
ENTRYPOINT [ "/sbin/tini", "--", "/entrypoint.sh" ]
CMD [ "/usr/local/bin/rtorrent" ]