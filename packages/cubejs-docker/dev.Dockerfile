# packages/cubejs-docker/dev.Dockerfile
# Build "classique" depuis les sources, orienté backend + CLI

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

# On copie TOUT le repo (incl. rust/) pour que les postinstall trouvent leurs scripts
COPY . .

# Yarn v1 + timeout réseau (utile sur CI)
RUN yarn policies set-version v1.22.22 && yarn config set network-timeout 120000 -g
ENV NODE_OPTIONS=--max-old-space-size=4096

# Install complète AVEC scripts (postinstall cubestore, databricks, etc.)
RUN yarn install --frozen-lockfile

# --- Build des packages backend uniquement (on évite les clients front qui peuvent casser) ---
RUN yarn lerna run build \
  --scope @cubejs-backend/* \
  --include-dependencies \
  --ignore @cubejs-client/* \
  --ignore @cubejs-playground/* \
  --stream --no-prefix

# --- Build explicite du CLI pour garantir la présence du dist ---
RUN yarn workspace @cubejs-backend/cli build

# Garde-fou : échoue si le dist du CLI n'existe pas
RUN test -f packages/cubejs-cli/dist/src/index.js || \
  (echo 'ERROR: packages/cubejs-cli/dist/src/index.js manquant (CLI non buildé)'; exit 1)

# Optionnel : petit nettoyage (sans casser les artefacts buildés)
# (on ne supprime PAS les node_modules ici, on veut un runtime complet)
# Si vous voulez affiner la taille, faites-le plutôt par prune sélectif.


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

# Entrypoint (fourni par le repo)
COPY packages/cubejs-docker/bin/cubejs-dev /usr/local/bin/cubejs
RUN chmod +x /usr/local/bin/cubejs

# Liens/vars utiles (comme dans leurs images dev)
ENV NODE_PATH=/cube/conf/node_modules:/cube/node_modules \
    PYTHONUNBUFFERED=1

# Lien vers le dossier docker interne et vers le binaire cubestore-dev
RUN ln -s /cubejs/packages/cubejs-docker /cube || true \
 && ln -s /cubejs/rust/cubestore/bin/cubestore-dev /usr/local/bin/cubestore-dev || true

WORKDIR /cube/conf
EXPOSE 4000

CMD ["cubejs", "server"]
