FROM alpine:3.21 AS downloader

RUN apk add --no-cache curl unzip

RUN curl -fsSL -o /tmp/xray.zip "https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-64.zip" \
    && unzip -q /tmp/xray.zip -d /tmp/xray \
    && install -m 0755 /tmp/xray/xray /usr/local/bin/xray

RUN curl -fsSL -o /usr/local/bin/cloudflared "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64" \
    && chmod 0755 /usr/local/bin/cloudflared

FROM alpine:3.21

RUN apk add --no-cache ca-certificates tzdata caddy \
    && addgroup -S app \
    && adduser -S -D -H -G app app

COPY --from=downloader /usr/local/bin/xray /usr/local/bin/xray
COPY --from=downloader /usr/local/bin/cloudflared /usr/local/bin/cloudflared

COPY docker/entrypoint.sh /entrypoint.sh
COPY docker/Caddyfile /etc/caddy/Caddyfile
COPY config/xray.example.json /etc/xray/config.example.json

RUN chmod 0755 /entrypoint.sh \
    && mkdir -p /etc/xray /var/lib/caddy /var/log \
    && chown -R app:app /etc/caddy /etc/xray /var/lib/caddy /var/log

USER app
WORKDIR /home/app

ENV XRAY_CONFIG=/etc/xray/config.json \
    CADDY_CONFIG=/etc/caddy/Caddyfile \
    CADDY_DOMAIN=example.com \
    CADDY_EMAIL=admin@example.com \
    VLESS_ID=11111111-1111-1111-1111-111111111111 \
    VMESS_ID=22222222-2222-2222-2222-222222222222 \
    WS_VLESS_PATH=/ws-vless \
    WS_VMESS_PATH=/ws-vmess \
    VLESS_UPSTREAM=127.0.0.1:10000 \
    VMESS_UPSTREAM=127.0.0.1:10001 \
    CF_METRICS=127.0.0.1:49312

EXPOSE 80 443

ENTRYPOINT ["/entrypoint.sh"]
