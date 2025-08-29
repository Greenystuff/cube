# packages/cubejs-docker/dev.Dockerfile
# Build "classique" depuis les sources (sans lister les paquets)

FROM node:22.18.0-bookworm-slim AS build

# Outils nécessaires aux builds Node/Rust/JDBC
RUN set -eux; \
  apt-get update; \
  DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    ca-certificates curl git make gcc g++ python3 python3.11 libpython3.11-dev \
    cmake openjdk-17-jdk-headless; \
  rm -rf /var/lib/apt/lists/*

# Rust toolchain (pour cubestore/cubesql)
ENV RUSTUP_HOME=/usr/local/rustup \
    CARGO_HOME=/usr/local/cargo \
    PATH=/usr/local/cargo/bin:$PATH
RUN curl -fsSL https://sh.rustup.rs | sh -s -- --profile minimal --default-toolchain nightly-2022-03-08 -y

WORKDIR /src

# On copie TOUT le repo (important : les dossiers rust/ existent donc les postinstall cubestore fonctionnent)
COPY . .

# Yarn v1 + timeout réseau
RUN yarn policies set-version v1.22.22 && yarn config set network-timeout 120000 -g
ENV NODE_OPTIONS=--max-old-space-size=4096

# Install complète AVEC scripts (postinstall cubestore, databricks, etc.)
RUN yarn install --frozen-lockfile

# Build de tout le monorepo (comme en release)
RUN yarn build

# ---------------- Runtime ----------------
FROM node:22.18.0-bookworm-slim AS runtime

RUN set -eux; \
  apt-get update; \
  DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    ca-certificates python3.11 libpython3.11-dev; \
  rm -rf /var/lib/apt/lists/*

WORKDIR /cubejs

# On prend les artefacts buildés + node_modules
COPY --from=build /src /cubejs

# Entrypoint (fourni par le repo)
COPY packages/cubejs-docker/bin/cubejs-dev /usr/local/bin/cubejs
RUN chmod +x /usr/local/bin/cubejs

# Quelques liens/vars utiles (comme dans leurs images)
ENV NODE_PATH=/cube/conf/node_modules:/cube/node_modules \
    PYTHONUNBUFFERED=1
RUN ln -s /cubejs/packages/cubejs-docker /cube || true

WORKDIR /cube/conf
EXPOSE 4000
CMD ["cubejs", "server"]
