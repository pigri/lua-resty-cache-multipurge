FROM golang:1.23-bookworm AS builder

COPY cache_keyfinder /app/cache_keyfinder

WORKDIR /app/cache_keyfinder
RUN go build cache_keyfinder.go

FROM openresty/openresty:1.27.1.2-2-noble

RUN apt-get update && apt-get install -y build-essential && mkdir -p /tmp/cache && luarocks install md5

COPY . /app

COPY --from=builder /app/cache_keyfinder/cache_keyfinder /usr/local/openresty/bin/cache_keyfinder

WORKDIR /app
RUN chmod +x /usr/local/openresty/bin/cache_keyfinder \
    && /usr/local/openresty/bin/cache_keyfinder /tmp something -d


