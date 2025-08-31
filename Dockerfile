# syntax=docker/dockerfile:1.7-labs

FROM alpine:3.22 AS build-sysroot

ARG RTORRENT_VERSION
ENV RTORRENT_VERSION=${RTORRENT_VERSION}

# Fetch build dependencies
RUN apk add --no-cache \
    make \
    pkgconf

# Prepare build script
COPY --chmod=755 ./build.sh .

# Build rtorrent and install to new system root
RUN ./build.sh ${RTORRENT_VERSION}

# Prepare sysroot
RUN mkdir -p /sysroot/download /sysroot/session /sysroot/watch
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
    netcat-openbsd \
    tini \
    tzdata
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
HEALTHCHECK --start-period=10s \
  CMD /usr/bin/nc -z 127.0.0.1 5000 || exit 1