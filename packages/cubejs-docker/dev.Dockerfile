# packages/cubejs-docker/dev.Dockerfile
FROM node:22.18.0-bookworm-slim AS base

ARG IMAGE_VERSION=dev

ENV CUBEJS_DOCKER_IMAGE_VERSION=$IMAGE_VERSION
ENV CUBEJS_DOCKER_IMAGE_TAG=dev
ENV CI=0

RUN DEBIAN_FRONTEND=noninteractive \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
       libssl3 curl cmake python3 python3.11 libpython3.11-dev gcc g++ make openjdk-17-jdk-headless \
    && rm -rf /var/lib/apt/lists/*

# Rust toolchain (pour cubestore/cubesql)
ENV RUSTUP_HOME=/usr/local/rustup
ENV CARGO_HOME=/usr/local/cargo
ENV PATH=/usr/local/cargo/bin:$PATH
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | \
    sh -s -- --profile minimal --default-toolchain nightly-2022-03-08 -y

ENV CUBESTORE_SKIP_POST_INSTALL=true
ENV NODE_ENV=development

WORKDIR /cubejs

# Fichiers racine
COPY package.json .
COPY lerna.json .
COPY yarn.lock .
COPY tsconfig.base.json .
COPY rollup.config.js .

# Linter (utilisé par certains scripts)
COPY packages/cubejs-linter packages/cubejs-linter

# Déclarer tous les package.json aux workspaces pour un install rapide
# (backend)
COPY rust/cubesql/package.json rust/cubesql/package.json
COPY rust/cubestore/package.json rust/cubestore/package.json
COPY packages/cubejs-backend-shared/package.json packages/cubejs-backend-shared/package.json
COPY packages/cubejs-base-driver/package.json packages/cubejs-base-driver/package.json
COPY packages/cubejs-backend-native/package.json packages/cubejs-backend-native/package.json
COPY packages/cubejs-testing-shared/package.json packages/cubejs-testing-shared/package.json
COPY packages/cubejs-backend-cloud/package.json packages/cubejs-backend-cloud/package.json
COPY packages/cubejs-api-gateway/package.json packages/cubejs-api-gateway/package.json
COPY packages/cubejs-athena-driver/package.json packages/cubejs-athena-driver/package.json
COPY packages/cubejs-bigquery-driver/package.json packages/cubejs-bigquery-driver/package.json
COPY packages/cubejs-cli/package.json packages/cubejs-cli/package.json
COPY packages/cubejs-clickhouse-driver/package.json packages/cubejs-clickhouse-driver/package.json
COPY packages/cubejs-crate-driver/package.json packages/cubejs-crate-driver/package.json
COPY packages/cubejs-dremio-driver/package.json packages/cubejs-dremio-driver/package.json
COPY packages/cubejs-druid-driver/package.json packages/cubejs-druid-driver/package.json
COPY packages/cubejs-duckdb-driver/package.json packages/cubejs-duckdb-driver/package.json
COPY packages/cubejs-elasticsearch-driver/package.json packages/cubejs-elasticsearch-driver/package.json
COPY packages/cubejs-firebolt-driver/package.json packages/cubejs-firebolt-driver/package.json
COPY packages/cubejs-hive-driver/package.json packages/cubejs-hive-driver/package.json
COPY packages/cubejs-mongobi-driver/package.json packages/cubejs-mongobi-driver/package.json
COPY packages/cubejs-mssql-driver/package.json packages/cubejs-mssql-driver/package.json
COPY packages/cubejs-mysql-driver/package.json packages/cubejs-mysql-driver/package.json
COPY packages/cubejs-cubestore-driver/package.json packages/cubejs-cubestore-driver/package.json
COPY packages/cubejs-oracle-driver/package.json packages/cubejs-oracle-driver/package.json
COPY packages/cubejs-redshift-driver/package.json packages/cubejs-redshift-driver/package.json
COPY packages/cubejs-postgres-driver/package.json packages/cubejs-postgres-driver/package.json
COPY packages/cubejs-questdb-driver/package.json packages/cubejs-questdb-driver/package.json
COPY packages/cubejs-materialize-driver/package.json packages/cubejs-materialize-driver/package.json
COPY packages/cubejs-prestodb-driver/package.json packages/cubejs-prestodb-driver/package.json
COPY packages/cubejs-trino-driver/package.json packages/cubejs-trino-driver/package.json
COPY packages/cubejs-pinot-driver/package.json packages/cubejs-pinot-driver/package.json
COPY packages/cubejs-query-orchestrator/package.json packages/cubejs-query-orchestrator/package.json
COPY packages/cubejs-schema-compiler/package.json packages/cubejs-schema-compiler/package.json
COPY packages/cubejs-server/package.json packages/cubejs-server/package.json
COPY packages/cubejs-server-core/package.json packages/cubejs-server-core/package.json
COPY packages/cubejs-snowflake-driver/package.json packages/cubejs-snowflake-driver/package.json
COPY packages/cubejs-sqlite-driver/package.json packages/cubejs-sqlite-driver/package.json
COPY packages/cubejs-ksql-driver/package.json packages/cubejs-ksql-driver/package.json
COPY packages/cubejs-dbt-schema-extension/package.json packages/cubejs-dbt-schema-extension/package.json
COPY packages/cubejs-jdbc-driver/package.json packages/cubejs-jdbc-driver/package.json
COPY packages/cubejs-vertica-driver/package.json packages/cubejs-vertica-driver/package.json
# Front (déclarés mais on ne les build PAS)
COPY packages/cubejs-templates/package.json packages/cubejs-templates/package.json
COPY packages/cubejs-client-core/package.json packages/cubejs-client-core/package.json
COPY packages/cubejs-client-react/package.json packages/cubejs-client-react/package.json
COPY packages/cubejs-client-vue/package.json packages/cubejs-client-vue/package.json
COPY packages/cubejs-client-vue3/package.json packages/cubejs-client-vue3/package.json
COPY packages/cubejs-client-ngx/package.json packages/cubejs-client-ngx/package.json
COPY packages/cubejs-client-ws-transport/package.json packages/cubejs-client-ws-transport/package.json
COPY packages/cubejs-playground/package.json packages/cubejs-playground/package.json

RUN yarn policies set-version v1.22.22 \
 && yarn config set network-timeout 120000 -g

# --- Prod deps (jdbc databricks) pour l’image finale ---
FROM base AS prod_base_dependencies
COPY packages/cubejs-databricks-jdbc-driver/package.json packages/cubejs-databricks-jdbc-driver/package.json
RUN mkdir -p packages/cubejs-databricks-jdbc-driver/bin \
 && echo '#!/usr/bin/env node' > packages/cubejs-databricks-jdbc-driver/bin/post-install \
 && chmod +x packages/cubejs-databricks-jdbc-driver/bin/post-install \
 && yarn install --prod

FROM prod_base_dependencies AS prod_dependencies
COPY packages/cubejs-databricks-jdbc-driver/bin packages/cubejs-databricks-jdbc-driver/bin
RUN yarn install --prod --ignore-scripts

# --- Build (backend only) ---
FROM base AS build

RUN yarn install

# Copier **les sources** maintenant (pas juste les package.json)
COPY rust/cubestore/ rust/cubestore/
COPY rust/cubesql/   rust/cubesql/
COPY packages/       packages/

# ⚠️ NE PAS lancer `yarn build` (build monorepo complet -> clients/Angular cassent)
# Build sélectif backend + deps, on ignore tous les clients & playground & templates
RUN yarn lerna run build \
  --include-dependencies \
  --stream --no-prefix \
  --scope '@cubejs-backend/*' \
  --scope '@cubejs-*-driver' \
  --scope '@cubejs-query-orchestrator' \
  --scope '@cubejs-schema-compiler' \
  --scope '@cubejs-server' \
  --scope '@cubejs-server-core' \
  --ignore '@cubejs-client*' \
  --ignore '@cubejs-playground*' \
  --ignore '@cubejs-templates' \
  --ignore '@cubejs-kit*'

# alléger l’artefact
RUN find . -name 'node_modules' -type d -prune -exec rm -rf '{}' + || true

# --- Image finale ---
FROM base AS final

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates python3.11 libpython3.11-dev \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/*

COPY --from=build            /cubejs /cubejs
COPY --from=prod_dependencies /cubejs /cubejs

# binaire d’entrée
COPY packages/cubejs-docker/bin/cubejs-dev /usr/local/bin/cubejs
RUN chmod +x /usr/local/bin/cubejs

# PATH & liens utiles
ENV NODE_PATH=/cube/conf/node_modules:/cube/node_modules
ENV PYTHONUNBUFFERED=1
RUN ln -s /cubejs/packages/cubejs-docker /cube \
 && ln -s /cubejs/rust/cubestore/bin/cubestore-dev /usr/local/bin/cubestore-dev

WORKDIR /cube/conf
EXPOSE 4000

CMD ["cubejs", "server"]
