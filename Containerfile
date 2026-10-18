# syntax=docker/dockerfile:1
# proxmox-backup-client as a standalone container image (amd64 + arm64),
# built from the official Proxmox "pbs-client" repository for Debian trixie.
FROM docker.io/library/debian:trixie-slim

ARG TARGETARCH
# amd64 builds are published in "main"; arm64 builds currently only exist in "test".
ARG PBS_COMPONENTS=""

ADD --checksum=sha256:136673be77aba35dcce385b28737689ad64fd785a797e57897589aed08db6e45 \
    https://enterprise.proxmox.com/debian/proxmox-archive-keyring-trixie.gpg \
    /usr/share/keyrings/proxmox-archive-keyring.gpg

RUN set -eux; \
    chmod 0644 /usr/share/keyrings/proxmox-archive-keyring.gpg; \
    components="${PBS_COMPONENTS}"; \
    if [ -z "$components" ]; then \
        case "${TARGETARCH:-$(dpkg --print-architecture)}" in \
            arm64) components="main test" ;; \
            *)     components="main" ;; \
        esac; \
    fi; \
    printf '%s\n' \
        'Types: deb' \
        'URIs: http://download.proxmox.com/debian/pbs-client' \
        'Suites: trixie' \
        "Components: ${components}" \
        'Signed-By: /usr/share/keyrings/proxmox-archive-keyring.gpg' \
        > /etc/apt/sources.list.d/pbs-client.sources; \
    apt-get update; \
    apt-get install -y --no-install-recommends ca-certificates proxmox-backup-client; \
    rm -rf /var/lib/apt/lists/*; \
    install -d -m 0700 /run/user/0; \
    proxmox-backup-client version

# Ticket cache location; avoids the "unable to store ticket" warning.
ENV XDG_RUNTIME_DIR=/run/user/0

ENTRYPOINT ["/usr/bin/proxmox-backup-client"]
CMD ["help"]
