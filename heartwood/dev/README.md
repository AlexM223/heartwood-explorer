# Heartwood dev tooling

Local dev workflow for this mempool fork on Windows (Git Bash). This directory
is **purely additive** — it never modifies upstream files, so it stays a single
clean patch commit that will not conflict on rebase against upstream mempool.

There are two distinct workflows. Use the right one for the job.

## 1. Frontend — run natively (fast iteration)

The Angular frontend runs natively; **do not** use Docker for day-to-day
frontend iteration.

One-time machine setup (already applied on Alex's box, no repo footprint):

```bash
# Point npm at Git Bash so the sh-based npm scripts work on Windows.
npm config set script-shell "C:\\Program Files\\Git\\bin\\bash.exe"
```

Then:

```bash
cd frontend
npm install
npm run serve      # or: npm start
```

`serve` runs `generate-themes` + `generate-config` then `ng serve -c local`,
serving on http://localhost:4200 with live reload.

> Note: `npm run build` (production) is **not** expected to work natively — it
> depends on `rsync`, which we intentionally do not install/patch. Production
> builds happen only via Docker/CI (workflow 2).

## 2. Backend + production images — build via Docker buildx

Real image builds reproduce CI (`.github/workflows/docker.yml`) exactly:
`docker/init.sh` seeds the Dockerization tree, then `docker buildx build`
builds each image with named build contexts.

```bash
# From repo root. Optional arg = build tag (default: dev-local).
heartwood/dev/build-images.sh
```

This produces two local images:

- `heartwood-frontend:dev`
- `heartwood-backend:dev`

Bring the fork up locally using the base compose file plus the override in this
directory (which swaps the `mempool/*` image refs for the local `:dev` ones):

```bash
docker compose \
  -f docker/docker-compose.yml \
  -f heartwood/dev/docker-compose.override.yml \
  up
```

### What a full stack run needs

The compose stack has three services: `web` (frontend), `api` (backend), and
`db` (MariaDB). The `api` service expects a Bitcoin Core RPC endpoint
(`CORE_RPC_HOST`/`CORE_RPC_PORT` in `docker/docker-compose.yml`, default
`172.27.0.1:8332`) and, for a useful explorer, an electrs/esplora backend.
Building the images and starting `db` needs nothing extra; a *functional*
explorer needs bitcoind (and typically electrs) reachable from the `api`
container.

## Why `docker/init.sh` mutations don't show up in git

`docker/init.sh` copies files into `backend/` and `frontend/` and downloads
GeoIP databases. Those paths are already covered by the repo's `.gitignore`
and are additionally listed in `.git/info/exclude` (local-only, zero repo
footprint) so they never appear as `git status` noise.
