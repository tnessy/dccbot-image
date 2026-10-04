# dccbot (IRC XDCC download bot with an HTTP/WebSocket API) as a single plain image. No compose.
# Local build:  docker build --build-arg DCCBOT_VERSION="$(cat DCCBOT_VERSION)" -t dccbot-image:dev .
FROM python:3.13-slim

ARG DCCBOT_VERSION=0.5.0

# python-magic needs libmagic; curl is only used to fetch the release tarball.
RUN apt-get update \
 && apt-get install -y --no-install-recommends libmagic1 curl ca-certificates \
 && apt-get clean

RUN curl -fsSL "https://github.com/luni/dccbot/archive/refs/tags/v${DCCBOT_VERSION}.tar.gz" -o /tmp/dccbot.tar.gz \
 && mkdir /tmp/src && tar -xzf /tmp/dccbot.tar.gz -C /tmp/src --strip-components=1 \
 && pip install --no-cache-dir /tmp/src

# Renders config.json from config.example.json plus environment values (used by post-deploy.sh).
COPY render_config.py /opt/render_config.py

# /config holds config.json; /data is the download root (map your downloads share here).
# Run as the NAS user with --user (for example 99:100 on Unraid) so files are owned correctly.
RUN mkdir -p /config /data && chmod 777 /config /data
WORKDIR /config
VOLUME ["/config", "/data"]

LABEL org.opencontainers.image.description="dccbot XDCC download bot packaged for a personal NAS" \
      org.opencontainers.image.source="https://github.com/luni/dccbot"

# The HTTP API port from config.json ("http.port"). The API documents no authentication: publish it to the LAN only.
EXPOSE 9999
HEALTHCHECK --interval=60s --timeout=5s --start-period=20s \
  CMD python -c "import urllib.request as u; u.urlopen('http://127.0.0.1:9999/info', timeout=3)" || exit 1

ENTRYPOINT ["dccbot"]
CMD ["--config", "/config/config.json"]
