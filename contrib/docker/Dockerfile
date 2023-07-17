# Builder stage
FROM alpine AS builder

COPY rootfs_prefix/ /usr/src/rootfs_prefix/

RUN apk update \
 && apk add --virtual build-dependencies \
    build-base \
    gcc \
    musl-dev \
 && make -C /usr/src/rootfs_prefix/

# Production stage
FROM alpine AS production

COPY --from=builder /usr/src/rootfs_prefix/rootfs_prefix.so /usr/src/rootfs_prefix/rootfs_prefix.so
COPY collectd.conf /etc/collectd/collectd.conf
COPY collectd.conf.d/ /etc/collectd/collectd.conf.d/

RUN apk update \
 && apk add --no-cache \
    collectd \
    collectd-disk \
    collectd-utils

ENV LD_PRELOAD /usr/src/rootfs_prefix/rootfs_prefix.so

ENTRYPOINT ["/usr/sbin/collectd"]
CMD ["-f"]
