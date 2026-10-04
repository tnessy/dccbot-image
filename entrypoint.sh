#!/bin/sh
# Apply a umask before starting dccbot so downloads are group/world-writable the way other NAS containers
# (SABnzbd, qBittorrent) leave them. Without this, dccbot's folders are 755 under its own user and the SMB
# user (and the importer) cannot rename or delete what it downloaded.
# Override with -e UMASK=022 to get the old behaviour.
umask "${UMASK:-000}"
exec dccbot "$@"
