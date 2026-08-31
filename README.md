# cosmos-gaiad-docker

Dockerized Cosmos Hub node (gaiad) with a Prometheus sidecar for monitoring.

## What's here

- `Dockerfile` — builds gaiad from source (pinned to a tag), multi-stage so the final image is just the binary on alpine
- `docker-compose.yml` — runs the node + prometheus
- `scripts/entrypoint.sh` — inits the node on first run, just starts it on every run after that
- `monitoring/prometheus.yml` — scrape config for the sidecar

## Running it

```bash
git clone https://github.com/<your-user>/cosmos-gaiad-docker.git
cd cosmos-gaiad-docker
cp .env.example .env

docker compose up -d --build
```

Check it's alive:

```bash
curl -s http://localhost:26657/status | jq '.result.sync_info'
```

Prometheus is at http://localhost:9091 (check /targets to make sure it's actually scraping the node).

`docker compose down` stops it, volume stays. Add `-v` if you actually want to wipe the chain data.

## Config

Everything's an env var, see `.env.example`. Main ones:

- `GAIA_VERSION` — which gaia tag to build (default v21.0.0)
- `CHAIN_ID` / `MONIKER` — passed straight to `gaiad init`
- `GENESIS_URL`, `SEEDS`, `PERSISTENT_PEERS` — leave blank and you get a working node with no peers, which is fine for testing the container itself. Fill these in with real values (from the [chain registry](https://github.com/cosmos/chain-registry/tree/master/cosmoshub)) if you actually want to sync mainnet.

## Testing

Things I checked before pushing this:

**Sync** — brought up a second container on the same network, pointed it at the first as a persistent peer, watched `catching_up` flip from true to false:

```bash
docker compose run -d --name gaiad-node-b \
  -e PERSISTENT_PEERS="$(docker compose exec -T gaiad-node gaiad tendermint show-node-id)@gaiad-node:26656" \
  gaiad-node

watch -n2 'docker exec gaiad-node-b gaiad status 2>&1 | jq "{height: .sync_info.latest_block_height, catching_up: .sync_info.catching_up}"'
```

**Volume persistence** — `down` (not `-v`), then `up` again, and the node picks up where it left off instead of re-initing. You can see this in the logs — entrypoint prints "existing data directory found" instead of running init again.

```bash
docker compose down
docker compose up -d
docker compose logs gaiad-node | grep "existing data directory"
```

If you actually want the data gone, `docker compose down -v` and it'll init fresh — logs say "no existing genesis found" that time instead.

**Restarts** — `docker compose restart gaiad-node` and a hard `docker kill` + `up` — in both cases it comes back up healthy without needing to re-init. Worth checking `docker compose ps` shows healthy and the logs don't have a panic in them.

## Notes

- Gaia source isn't vendored into this repo, the Dockerfile pulls it at build time from a pinned tag, keeps the repo small
- `LEDGER_ENABLED=false` in the build — no hardware wallet on a server node
- Runtime image is alpine, no Go toolchain in it, just the binary + curl/jq/bash/tini
