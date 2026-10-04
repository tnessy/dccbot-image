# dccbot (IRC XDCC download bot with an HTTP/WebSocket API) as a single plain image. No compose.
# Local build:  docker build --build-arg DCCBOT_VERSION="$(cat DCCBOT_VERSION)" -t dccbot-image:dev .
FROM python:3.13-slim

ARG DCCBOT_VERSION=0.5.0

# python-magic needs libmagic; curl is only used to fetch the release tarball.
RUN apt-get update \
 && apt-get install -y --no-install-recommends libmagic1 curl ca-certificates \
 && apt-get clean

# dccbot looks for its web assets at <package dir>/../static (STATIC_DIR in dccbot/app.py), so a normal
# `pip install .` into site-packages crashes at start ("site-packages/static does not exist").
# Install it editable from the extracted source tree so the package and static/ stay side by side.
RUN mkdir -p /opt/dccbot \
 && curl -fsSL "https://github.com/luni/dccbot/archive/refs/tags/v${DCCBOT_VERSION}.tar.gz" \
    | tar -xz -C /opt/dccbot --strip-components=1 \
 && pip install --no-cache-dir -e /opt/dccbot \
 && chmod -R a+rX /opt/dccbot

# Fail the build (not the container) if the static assets are not where dccbot expects them.
RUN python -c "from dccbot.app import STATIC_DIR; assert STATIC_DIR.is_dir() and (STATIC_DIR / 'index.html').is_file(), STATIC_DIR"

# Renders config.json from config.example.json plus environment values (used by post-deploy.sh).
COPY render_config.py /opt/render_config.py
COPY entrypoint.sh /opt/entrypoint.sh
RUN chmod 755 /opt/entrypoint.sh

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

ENV UMASK=000
ENTRYPOINT ["/opt/entrypoint.sh"]
CMD ["--config", "/config/config.json"]
