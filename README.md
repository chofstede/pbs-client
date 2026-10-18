# pbs-client container

Minimal `proxmox-backup-client` image (Debian trixie-slim) for amd64 and arm64,
installed from the official Proxmox `pbs-client` repository. It replaces
`docker.io/ayufan/proxmox-backup-server:v3.4`; the entrypoint is the client
itself, so there is no need for `--entrypoint` overrides.

Background, the SELinux and mount details, and caveats are in the blog article
[No Proxmox Backup Client for RHEL? Hold My Container Runtime](https://blog.hofstede.it/pbs-client-rhel-container/).

- amd64: `main` component (current stable client)
- arm64: Proxmox only publishes arm64 builds in the `test` component so far,
  so arm64 images pick those up automatically. Force a component set with
  `--build-arg PBS_COMPONENTS="main"`.

## Prebuilt image

`.github/workflows/build.yml` builds amd64 + arm64 on every push to `main`, weekly
(Monday 04:17 UTC, to pick up new client releases), and on manual dispatch, and pushes to:

```
ghcr.io/chofstede/pbs-client:latest      # newest build
ghcr.io/chofstede/pbs-client:YYYYMMDD    # dated, for pinning
ghcr.io/chofstede/pbs-client:sha-<short> # per commit
```

Pull requests are built but not pushed. The package is public, so hosts can pull without a login.

## Build locally

```sh
# single arch (native)
podman build -t localhost/pbs-client .

# multi-arch manifest (needs qemu-user-static for the foreign arch)
podman build --platform linux/amd64,linux/arm64 --manifest localhost/pbs-client:latest .
podman manifest push --all localhost/pbs-client:latest docker://ghcr.io/chofstede/pbs-client:latest
```

## Usage

Secrets go in root's Podman secret store and are passed in as the env vars the client reads:

```sh
printf '%s' 'repo-password'  | podman secret create pbs_password -
printf '%s' 'key-passphrase' | podman secret create pbs_encryption_password -
```

Back up the host root filesystem:

```sh
podman run --rm \
  --hostname server01 \
  --security-opt label=type:spc_t \
  --secret pbs_password,type=env,target=PBS_PASSWORD \
  --secret pbs_encryption_password,type=env,target=PBS_ENCRYPTION_PASSWORD \
  -e PBS_REPOSITORY='backup@pbs@pbs.example.com:datastore' \
  -v /:/host:ro \
  -v /root/.config/proxmox-backup/encryption-key.json:/key.json:ro,Z \
  localhost/pbs-client \
  backup root.pxar:/host --keyfile /key.json
```

Other subcommands work the same way (`snapshot list`, `restore`, `key create`, ...).
`proxmox-backup-client mount`/`map` additionally need `--device /dev/fuse --cap-add SYS_ADMIN`.

The same caveats as with the old image apply: mount points below `/host` are
skipped unless added with `--include-dev`, and live databases need their own dumps.
