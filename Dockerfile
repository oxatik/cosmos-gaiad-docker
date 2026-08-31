# syntax=docker/dockerfile:1
#
# Builds gaiad from source. Uses Debian (glibc) instead of Alpine because
# gaia depends on CosmWasm's wasmvm, which ships a prebuilt glibc shared
# library - it will not link against musl (Alpine's libc).
#
# docker build --build-arg GAIA_VERSION=v21.0.0 -t cosmos-gaiad:v21.0.0 .

FROM golang:1.23-bookworm AS build-env

ARG GAIA_VERSION=v21.0.0
ARG GAIA_REPO=https://github.com/cosmos/gaia.git

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential git ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /root
RUN git clone --depth 1 --branch ${GAIA_VERSION} ${GAIA_REPO} gaia

WORKDIR /root/gaia
# ledger disabled - no hardware wallet on a server node
RUN LEDGER_ENABLED=false make build

FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates bash curl jq tini \
    && rm -rf /var/lib/apt/lists/*

COPY --from=build-env /root/gaia/build/gaiad /usr/local/bin/gaiad
COPY scripts/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

ENV DAEMON_HOME=/root/.gaia
ENV DAEMON_NAME=gaiad
ENV CHAIN_ID=cosmoshub-4
ENV MONIKER=docker-gaia-node

WORKDIR /root
VOLUME ["/root/.gaia"]

# p2p, rpc, rest, grpc, prometheus
EXPOSE 26656 26657 1317 9090 26660

# tini so SIGTERM actually gets handled right on stop/restart
ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/entrypoint.sh"]
CMD ["start"]
