# xray + caddy + optional cloudflared

## Build

```bash
docker build -t xray-caddy:latest .
```

Build source behavior:
- Xray: downloads `releases/latest/download/Xray-linux-64.zip`
- cloudflared: downloads `releases/latest/download/cloudflared-linux-amd64`
- Caddy: installed from Alpine package (`apk add caddy`)

## Run

```bash
docker run -d --name xray-caddy \
  -p 80:80 -p 443:443 \
  -e CADDY_DOMAIN=your.domain.tld \
  -e CADDY_EMAIL=you@example.com \
  xray-caddy:latest
```

If `/etc/xray/config.json` is not mounted, container will auto-generate it from built-in default template.

## Optional: enable cloudflared tunnel

```bash
docker run -d --name xray-caddy \
  -p 80:80 -p 443:443 \
  -e CADDY_DOMAIN=your.domain.tld \
  -e CADDY_EMAIL=you@example.com \
  -e CLOUDFLARED_TOKEN=xxxx \
  -v $(pwd)/config.json:/etc/xray/config.json:ro \
  xray-caddy:latest
```

## Environment variables

- `XRAY_CONFIG` default `/etc/xray/config.json`
- `CADDY_CONFIG` default `/etc/caddy/Caddyfile`
- `CADDY_DOMAIN` public domain for TLS
- `CADDY_EMAIL` ACME email
- `VLESS_ID` default `11111111-1111-1111-1111-111111111111`
- `VMESS_ID` default `22222222-2222-2222-2222-222222222222`
- `WS_VLESS_PATH` default `/ws-vless`
- `WS_VMESS_PATH` default `/ws-vmess`
- `VLESS_UPSTREAM` default `127.0.0.1:10000`
- `VMESS_UPSTREAM` default `127.0.0.1:10001`
- `CLOUDFLARED_TOKEN` if set, `cloudflared tunnel run --token` is started

When auto-generating config, `VLESS_ID` and `VMESS_ID` are injected into the default template. If env vars are unset, defaults above are used.

See [config/xray.example.json](./config/xray.example.json) as a starter template.

## GitHub Actions: auto build and push to GHCR

Workflow file: [`.github/workflows/build-and-push-ghcr.yml`](./.github/workflows/build-and-push-ghcr.yml)

- Trigger: `push` (except markdown/license/gitignore-only changes) and manual `workflow_dispatch`
- Push target: `ghcr.io/<owner>/<repo>`
- Branch behavior:
  - default branch: build + push
  - non-default branches: build only (no push)
- Multi-arch: `linux/amd64,linux/arm64`
- Tags:
  - `sha-<commit>`
  - `<branch-name>`
  - `latest` (default branch only)

### Prerequisites (GitHub repo settings)

1. **Actions permissions**
   - Go to `Settings -> Actions -> General`
   - Workflow permissions: choose **Read and write permissions**
   - This workflow uses `${{ secrets.GITHUB_TOKEN }}` and needs `packages: write` to push to GHCR.

2. **Package visibility (optional but recommended)**
   - After first push, open `https://github.com/<owner>?tab=packages`
   - Find package `<repo>` and set visibility to:
     - **private** (default, safer), or
     - **public** (if you want anonymous pull access)

3. **No extra secrets required by default**
   - This workflow does **not** require custom secrets for GHCR push.
   - It uses the auto-provided `GITHUB_TOKEN`.

### Optional custom secrets

You only need additional secrets if you extend the workflow:

- `CR_PAT` (optional): personal access token for cross-repo/org package publish scenarios.
- `DOCKERHUB_USERNAME` / `DOCKERHUB_TOKEN` (optional): if you also push to Docker Hub.

### Pull image from GHCR

Image name format:

```bash
ghcr.io/<owner>/<repo>:<tag>
```

Examples:

```bash
docker pull ghcr.io/<owner>/<repo>:latest
docker pull ghcr.io/<owner>/<repo>:sha-<commit>
```

For **public** package, you can pull directly.

For **private** package, login first:

```bash
echo "<YOUR_GITHUB_TOKEN>" | docker login ghcr.io -u <YOUR_GITHUB_USERNAME> --password-stdin
docker pull ghcr.io/<owner>/<repo>:latest
```

Token requirement for private package pull:

- classic PAT with at least `read:packages`, or
- fine-grained token with package read permission.
