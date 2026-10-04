#!/bin/sh
# Post-deploy on the NAS: render the real config from config.example.json and (re)start the container.
#   cp deploy.env.example deploy.env   # fill in real values
#   ./post-deploy.sh                   # or: ./post-deploy.sh path/to/other.env
# The existing config.json is never overwritten unless FORCE=1 is set.
set -eu

ENV_FILE="${1:-deploy.env}"
[ -f "$ENV_FILE" ] || { echo "missing $ENV_FILE (copy deploy.env.example and fill it in)" >&2; exit 1; }
# shellcheck disable=SC1090
. "$ENV_FILE"

: "${IMAGE:?set IMAGE in $ENV_FILE, for example ghcr.io/OWNER/dccbot-image:latest}"
APPDATA_DIR="${APPDATA_DIR:-/mnt/user/appdata/dccbot}"
DOWNLOADS_DIR="${DOWNLOADS_DIR:-/mnt/user/downloads}"
XDCC_SUBDIR="${XDCC_SUBDIR:-_spike/xdcc}"
API_BIND_IP="${API_BIND_IP:?set API_BIND_IP to the NAS LAN address; the API has no authentication}"
API_PORT="${API_PORT:-9999}"
PUID="${PUID:-99}"
PGID="${PGID:-100}"
UMASK="${UMASK:-000}"
CONTAINER_NAME="${CONTAINER_NAME:-dccbot}"
HERE="$(cd "$(dirname "$0")" && pwd)"

mkdir -p "$APPDATA_DIR" "$DOWNLOADS_DIR/$XDCC_SUBDIR"
docker pull "$IMAGE"

if [ -f "$APPDATA_DIR/config.json" ] && [ "${FORCE:-0}" != "1" ]; then
  echo "keeping existing $APPDATA_DIR/config.json (FORCE=1 to re-render)"
else
  # Render inside the image so the NAS needs nothing but Docker.
  docker run --rm --entrypoint python \
    -v "$HERE/config.example.json:/in/config.example.json:ro" \
    -v "$APPDATA_DIR:/out" \
    -e XDCC_NICK="${XDCC_NICK:-}" \
    -e NICKSERV_PASSWORD="${NICKSERV_PASSWORD:-}" \
    -e XDCC_DOWNLOAD_PATH="/data/$XDCC_SUBDIR" \
    -e XDCC_PASSIVE_LISTEN_IP="${XDCC_PASSIVE_LISTEN_IP:-}" \
    -e XDCC_PASSIVE_PORT_MIN="${XDCC_PASSIVE_PORT_MIN:-15000}" \
    -e XDCC_PASSIVE_PORT_MAX="${XDCC_PASSIVE_PORT_MAX:-15010}" \
    "$IMAGE" /opt/render_config.py /in/config.example.json /out/config.json
  chown "$PUID:$PGID" "$APPDATA_DIR/config.json" 2>/dev/null || true
fi

PASSIVE_PORTS=""
if [ -n "${XDCC_PASSIVE_LISTEN_IP:-}" ]; then
  PASSIVE_PORTS="-p ${XDCC_PASSIVE_PORT_MIN:-15000}-${XDCC_PASSIVE_PORT_MAX:-15010}:${XDCC_PASSIVE_PORT_MIN:-15000}-${XDCC_PASSIVE_PORT_MAX:-15010}"
fi

docker rm -f "$CONTAINER_NAME" >/dev/null 2>&1 || true
# shellcheck disable=SC2086
docker run -d --name "$CONTAINER_NAME" --restart unless-stopped \
  --user "$PUID:$PGID" \
  -e UMASK="$UMASK" \
  -v "$APPDATA_DIR:/config" \
  -v "$DOWNLOADS_DIR:/data" \
  -p "$API_BIND_IP:$API_PORT:9999" \
  $PASSIVE_PORTS \
  "$IMAGE"

echo "dccbot running. API: http://$API_BIND_IP:$API_PORT/info  Swagger: http://$API_BIND_IP:$API_PORT/swagger"
