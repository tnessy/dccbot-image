# dccbot-image

A plain Docker image (no compose) for [dccbot](https://github.com/luni/dccbot), an IRC XDCC download bot with an HTTP/WebSocket API, built and published by GitHub Actions so a NAS can pull it. Part of the anime-catalog download-acquisition spike. **Untested**: it was written on a machine without Docker.

## What is here

| File | Purpose |
|---|---|
| `Dockerfile` | `python:3.13-slim` + `libmagic1` + the pinned dccbot release; entrypoint `dccbot --config /config/config.json` |
| `DCCBOT_VERSION` | the single place to bump the dccbot release (read by the workflow) |
| `config.example.json` | spike defaults: Rizon over TLS, downloads to `/data/_spike/xdcc`, passive DCC off |
| `render_config.py` | copies `config.example.json` to `config.json` with the real values from the environment |
| `post-deploy.sh` + `deploy.env.example` | on the NAS: pull the image, render the real config, (re)start the container |
| `.github/workflows/publish.yml` | on a `v*` tag: build, push to GHCR, create a GitHub Release with the deploy files |

## Publish

1. Create an empty GitHub repo and push this folder as its root.
2. Tag a release: `git tag v0.1.0 && git push origin v0.1.0`.
3. The workflow pushes `ghcr.io/<owner>/dccbot-image:0.1.0` (and `latest`) and creates a Release containing `post-deploy.sh`, `config.example.json` and `deploy.env.example`.
4. A package from a private repo is private. Either make the package public in its GitHub settings, or log in on the NAS once: `echo <PAT with read:packages> | docker login ghcr.io -u <user> --password-stdin`.

## Deploy on the NAS

    curl -LO https://github.com/<owner>/dccbot-image/releases/download/v0.1.0/{post-deploy.sh,config.example.json,deploy.env.example}
    chmod +x post-deploy.sh
    cp deploy.env.example deploy.env      # set IMAGE, API_BIND_IP, XDCC_NICK, ...
    ./post-deploy.sh

`post-deploy.sh` never overwrites an existing `config.json` (set `FORCE=1` to re-render). The real values live only in `deploy.env` and the rendered `config.json` (mode 600); both are gitignored.

## Notes

- The API documents no authentication, so `post-deploy.sh` publishes it only on `API_BIND_IP`. Swagger UI: `http://<API_BIND_IP>:9999/swagger`.
- Passive DCC is off. Normal DCC needs no inbound port. For a passive-only bot, set `XDCC_PASSIVE_LISTEN_IP` to a public IP and forward the port range on the router (a LAN address will not work).
- dccbot's own repo shows no license in its GitHub metadata (its README badge says MIT); this image downloads the release at build time and does not redistribute its source.
- Action versions in the workflow use major tags (`@v4`, `@v3`, `@v5`, `@v6`) from memory; check they are current when you first push.
