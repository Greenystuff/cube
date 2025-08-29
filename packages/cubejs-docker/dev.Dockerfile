# packages/cubejs-docker/dev.Dockerfile
# Build "classique" depuis les sources, avec build explicite du CLI

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

# On copie TOUT le repo (les dossiers rust/ sont requis par les postinstall)
COPY . .

# Yarn v1 + timeout réseau
RUN yarn policies set-version v1.22.22 && yarn config set network-timeout 120000 -g
ENV NODE_OPTIONS=--max-old-space-size=4096

# Install complète AVEC scripts (postinstall cubestore, databricks, etc.)
RUN yarn install --frozen-lockfile

# (Optionnel) Build global du monorepo
RUN yarn build || true

# Build des packages backend seulement (évite les clients front)
RUN yarn lerna run build \
  --scope @cubejs-backend/* \
  --include-dependencies \
  --ignore @cubejs-client/* \
  --ignore @cubejs-playground/* \
  --stream --no-prefix

# 🔴 Build explicite du CLI (dossier: packages/cubejs-cli, workspace: @cubejs-backend/cli)
RUN yarn workspace @cubejs-backend/cli build

# ✅ Garde-fou : échoue si le dist du CLI n'existe pas
RUN test -f packages/cubejs-cli/dist/src/index.js || \
  (echo 'ERROR: packages/cubejs-cli/dist/src/index.js manquant (CLI non buildé)'; exit 1)


# ---------------- Runtime ----------------
FROM node:22.18.0-bookworm-slim AS runtime

RUN set -eux; \
  apt-get update; \
  DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    ca-certificates python3.11 libpython3.11-dev; \
  rm -rf /var/lib/apt/lists/*

WORKDIR /cubejs

# Pull everything we built
COPY --from=build /src /cubejs

# Entrypoint
COPY packages/cubejs-docker/bin/cubejs-dev /usr/local/bin/cubejs-dev
RUN chmod +x /usr/local/bin/cubejs-dev

# 🔧 Make image dependencies resolvable from your bind-mounted project (/cube/conf):
# Node resolves modules by walking up from /cube/conf to /cube. Provide node_modules there.
RUN mkdir -p /cube \
  && ln -s /cubejs/node_modules /cube/node_modules \
  && ln -s /cubejs/packages/cubejs-docker /cube || true

ENV NODE_ENV=development \
    NODE_PATH=/cube/conf/node_modules:/cube/node_modules:/cubejs/node_modules \
    PYTHONUNBUFFERED=1

WORKDIR /cube/conf
EXPOSE 4000
CMD ["cubejs-dev", "server"]