"""Render a real dccbot config.json from config.example.json plus environment values.

Usage (inside the image):  python /opt/render_config.py <example.json> <out.json>

Environment (all optional; unset means keep the example's value):
  XDCC_NICK                  IRC nick for irc.rizon.net
  NICKSERV_PASSWORD          NickServ password (omit for an unregistered nick)
  XDCC_DOWNLOAD_PATH         download root inside the container, default keeps the example
  XDCC_PASSIVE_LISTEN_IP     public IP the bot advertises; setting it turns passive DCC on
  XDCC_PASSIVE_PORT_MIN/MAX  passive DCC listen range (default 15000-15010 when passive is on)
"""
import json
import os
import sys

SERVER = "irc.rizon.net"


def main(src: str, dst: str) -> int:
    with open(src) as f:
        cfg = json.load(f)
    env = os.environ.get
    server = cfg["servers"][SERVER]
    if env("XDCC_NICK"):
        server["nick"] = env("XDCC_NICK")
        server["random_nick"] = False
    if env("NICKSERV_PASSWORD"):
        server["nickserv_password"] = env("NICKSERV_PASSWORD")
    if env("XDCC_DOWNLOAD_PATH"):
        cfg["default_download_path"] = env("XDCC_DOWNLOAD_PATH")
    if env("XDCC_PASSIVE_LISTEN_IP"):
        cfg["passive_dcc"] = True
        cfg["passive_dcc_listen_ip"] = env("XDCC_PASSIVE_LISTEN_IP")
        cfg["passive_dcc_port_range"] = [int(env("XDCC_PASSIVE_PORT_MIN", "15000")), int(env("XDCC_PASSIVE_PORT_MAX", "15010"))]
    fd = os.open(dst, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    with os.fdopen(fd, "w") as f:
        json.dump(cfg, f, indent=2)
        f.write("\n")
    print(f"wrote {dst} (passive_dcc={cfg.get('passive_dcc')}, download path {cfg['default_download_path']})")
    return 0


if __name__ == "__main__":
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    sys.exit(main(sys.argv[1], sys.argv[2]))
