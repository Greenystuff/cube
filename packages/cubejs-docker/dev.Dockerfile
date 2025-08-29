# packages/cubejs-docker/dev.Dockerfile
# Build "classique" depuis les sources, avec garde-fou pour le CLI

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

# --- Yarn 3 (Corepack) ---
RUN corepack enable && corepack prepare yarn@3.6.4 --activate
RUN yarn --version

# 🔒 Force un .yarnrc.yml sain (dans l'image uniquement)
RUN printf '%s\n' \
  'nodeLinker: node-modules' \
  'enableGlobalCache: false' \
  'npmRegistryServer: "https://registry.npmjs.org"' \
  > .yarnrc.yml

ENV NODE_OPTIONS=--max-old-space-size=4096

# Install:
# - Si lockfile Berry (>= Yarn 2): install immutable directe
# - Sinon (lock Yarn 1): première install pour migrer, puis install immutable
RUN set -eux; \
  if grep -q "__metadata" yarn.lock >/dev/null 2>&1; then \
    echo "Berry lockfile détecté -> installation immutable"; \
    yarn install --immutable; \
  else \
    echo "Lockfile Yarn 1 détecté -> migration initiale"; \
    yarn install; \
    echo "Vérification immutable"; \
    yarn install --immutable; \
  fi

# (Optionnel) Build global du monorepo (lerna/Nx)
RUN yarn build || true

# Build des packages backend seulement (évite les clients front lourds)
RUN yarn lerna run build \
  --scope @cubejs-backend/* \
  --ignore @cubejs-backend/api-gateway \
  --ignore @cubejs-client/* \
  --ignore @cubejs-playground/* \
  --no-bail --stream --no-prefix

# ✅ Garde-fou : si le dist du CLI n'existe pas, on (re)build le package cubejs-cli
RUN if [ ! -f packages/cubejs-cli/dist/src/index.js ]; then \
      echo "Building cubejs-cli explicitly..."; \
      yarn --cwd packages/cubejs-cli build; \
    fi


# ---------------- Runtime ----------------
FROM node:22.18.0-bookworm-slim AS runtime

RUN set -eux; \
  apt-get update; \
  DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    ca-certificates python3.11 libpython3.11-dev; \
  rm -rf /var/lib/apt/lists/*

WORKDIR /cubejs

# On prend tout (sources + artefacts + node_modules) depuis le stage build
COPY --from=build /src /cubejs

# Entrypoint DEV (on lance cubejs-dev)
COPY packages/cubejs-docker/bin/cubejs-dev /usr/local/bin/cubejs-dev
RUN chmod +x /usr/local/bin/cubejs-dev

# 🔧 Rendez les deps de l'image visibles depuis ton projet bind-mounté (/cube/conf)
RUN mkdir -p /cube \
  && ln -s /cubejs/node_modules /cube/node_modules \
  && ln -s /cubejs/packages/cubejs-docker /cube || true

ENV NODE_ENV=development \
    NODE_PATH=/cube/conf/node_modules:/cube/node_modules:/cubejs/node_modules \
    PYTHONUNBUFFERED=1

WORKDIR /cube/conf
EXPOSE 4000

CMD ["cubejs-dev", "server"]
