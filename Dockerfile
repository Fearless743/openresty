# syntax=docker/dockerfile:1
#
# OpenResty 1.31.9.1 (nginx 1.31.9) — image with the nginx2root fixes.
# Build context: the OpenResty source tree (this repository).

# ------------------------- builder -------------------------
FROM ubuntu:noble AS builder

ARG RESTY_VERSION=1.31.9.1
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
      build-essential ca-certificates cmake curl git patch perl python3 \
      wget unzip gettext-base dos2unix libpcre2-dev libpcre3-dev \
      zlib1g-dev libncurses-dev libperl-dev \
      libreadline-dev libgd-dev libgeoip-dev libxslt1-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /src
COPY . /src

# openresty.org does not host nginx-1.31.9.tar.gz yet (404), so seed the
# util/get-tarball cache from nginx.org. The nginx.org tarball lacks
# docs/html/, which util/mirror-tarballs expects, so add that directory.
RUN mkdir -p /src/work /tmp/nginx-pack \
    && curl -fSL https://nginx.org/download/nginx-1.31.9.tar.gz \
         -o /tmp/nginx-1.31.9.tar.gz \
    && tar xzf /tmp/nginx-1.31.9.tar.gz -C /tmp/nginx-pack \
    && mkdir -p /tmp/nginx-pack/nginx-1.31.9/docs/html \
    && tar czf /src/work/nginx-1.31.9.tar.gz \
         -C /tmp/nginx-pack nginx-1.31.9 \
    && rm -rf /tmp/nginx-pack /tmp/nginx-1.31.9.tar.gz

# Generate the patched source tree ./openresty-${RESTY_VERSION}/
# (mirror-tarballs downloads the remaining bundled components).
RUN make

# Compile with HTTP/2 + HTTP/3 enabled, and with the same module set as the
# official OpenResty images (mail proxy protocols stay disabled).
RUN cd /src/openresty-${RESTY_VERSION} \
    && ./configure \
         --prefix=/usr/local/openresty \
         --with-compat \
         --with-http_ssl_module \
         --with-http_v2_module \
         --with-http_v3_module \
         --with-http_realip_module \
         --with-http_stub_status_module \
         --with-stream \
         --with-stream_ssl_module \
         --with-mail --with-mail_ssl_module \
         --without-mail_pop3_module \
         --without-mail_imap_module \
         --without-mail_smtp_module \
    && make -j"$(nproc)" \
    && make install

# ------------------------- runtime -------------------------
FROM ubuntu:noble

ENV DEBIAN_FRONTEND=noninteractive \
    PATH=/usr/local/openresty/nginx/sbin:/usr/local/openresty/bin:/usr/local/openresty/luajit/bin:$PATH

RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates libpcre2-8-0 zlib1g libgd3 libgeoip1 libxslt1.1 libxml2 perl \
    && rm -rf /var/lib/apt/lists/* \
    && mkdir -p /etc/nginx/conf.d /var/run/openresty /usr/local/openresty/nginx/logs

COPY --from=builder /usr/local/openresty/ /usr/local/openresty/
RUN ln -sf /dev/stdout /usr/local/openresty/nginx/logs/access.log \
    && ln -sf /dev/stderr /usr/local/openresty/nginx/logs/error.log

EXPOSE 80 443

CMD ["openresty", "-g", "daemon off;"]
