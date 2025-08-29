# ---- base ----------------------------------------------------------
FROM node:22.18.0-bookworm-slim AS base

ARG IMAGE_VERSION=dev
ENV CUBEJS_DOCKER_IMAGE_VERSION=$IMAGE_VERSION \
    CUBEJS_DOCKER_IMAGE_TAG=dev \
    NODE_ENV=development \
    CI=0

# Deps build system + JDK pour JDBC
RUN DEBIAN_FRONTEND=noninteractive \
  && apt-get update \
  && apt-get install -y --no-install-recommends \
       ca-certificates curl git openssh-client \
       build-essential gcc g++ make cmake \
       python3 python3.11 libpython3.11-dev \
       openjdk-17-jdk-headless \
  && rm -rf /var/lib/apt/lists/*

# Rust (pour les packages Rust si besoin)
ENV RUSTUP_HOME=/usr/local/rustup \
    CARGO_HOME=/usr/local/cargo \
    PATH=/usr/local/cargo/bin:$PATH
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs \
  | sh -s -- --profile minimal --default-toolchain nightly-2022-03-08 -y

# Eviter les postinstall lourds côté CubeStore/CubeSQL
ENV CUBESTORE_SKIP_POST_INSTALL=true \
    CUBESQL_SKIP_POST_INSTALL=true

WORKDIR /cubejs

# Fichiers racine du monorepo
COPY package.json lerna.json yarn.lock tsconfig.base.json rollup.config.js ./

# Paquets nécessaires au build (on copie d’abord les package.json pour le cache)
# Backend
COPY packages/cubejs-backend-shared/package.json                packages/cubejs-backend-shared/package.json
COPY packages/cubejs-base-driver/package.json                   packages/cubejs-base-driver/package.json
COPY packages/cubejs-backend-native/package.json                packages/cubejs-backend-native/package.json
COPY packages/cubejs-testing-shared/package.json                packages/cubejs-testing-shared/package.json
COPY packages/cubejs-backend-cloud/package.json                 packages/cubejs-backend-cloud/package.json
COPY packages/cubejs-api-gateway/package.json                   packages/cubejs-api-gateway/package.json
COPY packages/cubejs-athena-driver/package.json                 packages/cubejs-athena-driver/package.json
COPY packages/cubejs-bigquery-driver/package.json               packages/cubejs-bigquery-driver/package.json
COPY packages/cubejs-cli/package.json                           packages/cubejs-cli/package.json
COPY packages/cubejs-clickhouse-driver/package.json             packages/cubejs-clickhouse-driver/package.json
COPY packages/cubejs-crate-driver/package.json                  packages/cubejs-crate-driver/package.json
COPY packages/cubejs-dremio-driver/package.json                 packages/cubejs-dremio-driver/package.json
COPY packages/cubejs-druid-driver/package.json                  packages/cubejs-druid-driver/package.json
COPY packages/cubejs-duckdb-driver/package.json                 packages/cubejs-duckdb-driver/package.json
COPY packages/cubejs-elasticsearch-driver/package.json          packages/cubejs-elasticsearch-driver/package.json
COPY packages/cubejs-firebolt-driver/package.json               packages/cubejs-firebolt-driver/package.json
COPY packages/cubejs-hive-driver/package.json                   packages/cubejs-hive-driver/package.json
COPY packages/cubejs-mongobi-driver/package.json                packages/cubejs-mongobi-driver/package.json
COPY packages/cubejs-mssql-driver/package.json                  packages/cubejs-mssql-driver/package.json
COPY packages/cubejs-mysql-driver/package.json                  packages/cubejs-mysql-driver/package.json
COPY packages/cubejs-cubestore-driver/package.json              packages/cubejs-cubestore-driver/package.json
COPY packages/cubejs-oracle-driver/package.json                 packages/cubejs-oracle-driver/package.json
COPY packages/cubejs-redshift-driver/package.json               packages/cubejs-redshift-driver/package.json
COPY packages/cubejs-postgres-driver/package.json               packages/cubejs-postgres-driver/package.json
COPY packages/cubejs-questdb-driver/package.json                packages/cubejs-questdb-driver/package.json
COPY packages/cubejs-materialize-driver/package.json            packages/cubejs-materialize-driver/package.json
COPY packages/cubejs-prestodb-driver/package.json               packages/cubejs-prestodb-driver/package.json
COPY packages/cubejs-trino-driver/package.json                  packages/cubejs-trino-driver/package.json
COPY packages/cubejs-pinot-driver/package.json                  packages/cubejs-pinot-driver/package.json
COPY packages/cubejs-query-orchestrator/package.json            packages/cubejs-query-orchestrator/package.json
COPY packages/cubejs-schema-compiler/package.json               packages/cubejs-schema-compiler/package.json
COPY packages/cubejs-server/package.json                        packages/cubejs-server/package.json
COPY packages/cubejs-server-core/package.json                   packages/cubejs-server-core/package.json
COPY packages/cubejs-snowflake-driver/package.json              packages/cubejs-snowflake-driver/package.json
COPY packages/cubejs-sqlite-driver/package.json                 packages/cubejs-sqlite-driver/package.json
COPY packages/cubejs-ksql-driver/package.json                   packages/cubejs-ksql-driver/package.json
COPY packages/cubejs-dbt-schema-extension/package.json          packages/cubejs-dbt-schema-extension/package.json
COPY packages/cubejs-jdbc-driver/package.json                   packages/cubejs-jdbc-driver/package.json
COPY packages/cubejs-vertica-driver/package.json                packages/cubejs-vertica-driver/package.json

# Rust workspaces (package.json uniquement pour le cache + postinstall stubs plus tard)
COPY rust/cubesql/package.json                                   rust/cubesql/package.json
COPY rust/cubestore/package.json                                  rust/cubestore/package.json

# Front (on garde seulement les package.json, mais on ne compilera pas)
COPY packages/cubejs-templates/package.json                      packages/cubejs-templates/package.json
COPY packages/cubejs-client-core/package.json                    packages/cubejs-client-core/package.json
COPY packages/cubejs-client-react/package.json                   packages/cubejs-client-react/package.json
COPY packages/cubejs-client-vue/package.json                     packages/cubejs-client-vue/package.json
COPY packages/cubejs-client-vue3/package.json                    packages/cubejs-client-vue3/package.json
COPY packages/cubejs-client-ngx/package.json                     packages/cubejs-client-ngx/package.json
COPY packages/cubejs-client-ws-transport/package.json            packages/cubejs-client-ws-transport/package.json
COPY packages/cubejs-playground/package.json                     packages/cubejs-playground/package.json

RUN yarn policies set-version v1.22.22 \
 && yarn config set network-timeout 120000 -g

# ---- prod_base_dependencies ---------------------------------------
FROM base AS prod_base_dependencies

# Le driver Databricks-JDBC a un postinstall: on stub pour passer en CI
COPY packages/cubejs-databricks-jdbc-driver/package.json packages/cubejs-databricks-jdbc-driver/package.json
RUN mkdir -p packages/cubejs-databricks-jdbc-driver/bin \
 && printf '#!/usr/bin/env node\n' > packages/cubejs-databricks-jdbc-driver/bin/post-install \
 && chmod +x packages/cubejs-databricks-jdbc-driver/bin/post-install

# *** IMPORTANT *** : stub aussi le postinstall de rust/cubesql
RUN mkdir -p rust/cubesql/bin \
 && printf '#!/usr/bin/env node\n' > rust/cubesql/bin/post-install \
 && chmod +x rust/cubesql/bin/post-install

# Install prod deps (scripts autorisés, mais nos stubs évitent les plantages)
RUN yarn install --prod

# ---- prod_dependencies --------------------------------------------
FROM prod_base_dependencies AS prod_dependencies
COPY packages/cubejs-databricks-jdbc-driver/bin packages/cubejs-databricks-jdbc-driver/bin
RUN yarn install --prod --ignore-scripts

# ---- build ---------------------------------------------------------
FROM base AS build

# Dépendances complètes pour build
RUN yarn install

# Copier le code des paquets (après l’install pour maximiser le cache)
# Rust
COPY rust/cubestore/ rust/cubestore/
COPY rust/cubesql/   rust/cubesql/
# Backend
COPY packages/cubejs-backend-shared/       packages/cubejs-backend-shared/
COPY packages/cubejs-base-driver/          packages/cubejs-base-driver/
COPY packages/cubejs-backend-native/       packages/cubejs-backend-native/
COPY packages/cubejs-testing-shared/       packages/cubejs-testing-shared/
COPY packages/cubejs-backend-cloud/        packages/cubejs-backend-cloud/
COPY packages/cubejs-api-gateway/          packages/cubejs-api-gateway/
COPY packages/cubejs-athena-driver/        packages/cubejs-athena-driver/
COPY packages/cubejs-bigquery-driver/      packages/cubejs-bigquery-driver/
COPY packages/cubejs-cli/                  packages/cubejs-cli/
COPY packages/cubejs-clickhouse-driver/    packages/cubejs-clickhouse-driver/
COPY packages/cubejs-crate-driver/         packages/cubejs-crate-driver/
COPY packages/cubejs-dremio-driver/        packages/cubejs-dremio-driver/
COPY packages/cubejs-druid-driver/         packages/cubejs-druid-driver/
COPY packages/cubejs-duckdb-driver/        packages/cubejs-duckdb-driver/
COPY packages/cubejs-elasticsearch-driver/ packages/cubejs-elasticsearch-driver/
COPY packages/cubejs-firebolt-driver/      packages/cubejs-firebolt-driver/
COPY packages/cubejs-hive-driver/          packages/cubejs-hive-driver/
COPY packages/cubejs-mongobi-driver/       packages/cubejs-mongobi-driver/
COPY packages/cubejs-mssql-driver/         packages/cubejs-mssql-driver/
COPY packages/cubejs-mysql-driver/         packages/cubejs-mysql-driver/
COPY packages/cubejs-cubestore-driver/     packages/cubejs-cubestore-driver/
COPY packages/cubejs-oracle-driver/        packages/cubejs-oracle-driver/
COPY packages/cubejs-redshift-driver/      packages/cubejs-redshift-driver/
COPY packages/cubejs-postgres-driver/      packages/cubejs-postgres-driver/
COPY packages/cubejs-questdb-driver/       packages/cubejs-questdb-driver/
COPY packages/cubejs-materialize-driver/   packages/cubejs-materialize-driver/
COPY packages/cubejs-prestodb-driver/      packages/cubejs-prestodb-driver/
COPY packages/cubejs-trino-driver/         packages/cubejs-trino-driver/
COPY packages/cubejs-pinot-driver/         packages/cubejs-pinot-driver/
COPY packages/cubejs-query-orchestrator/   packages/cubejs-query-orchestrator/
COPY packages/cubejs-schema-compiler/      packages/cubejs-schema-compiler/
COPY packages/cubejs-server/               packages/cubejs-server/
COPY packages/cubejs-server-core/          packages/cubejs-server-core/
COPY packages/cubejs-snowflake-driver/     packages/cubejs-snowflake-driver/
COPY packages/cubejs-sqlite-driver/        packages/cubejs-sqlite-driver/
COPY packages/cubejs-ksql-driver/          packages/cubejs-ksql-driver/
COPY packages/cubejs-dbt-schema-extension/ packages/cubejs-dbt-schema-extension/
COPY packages/cubejs-jdbc-driver/          packages/cubejs-jdbc-driver/
COPY packages/cubejs-databricks-jdbc-driver/ packages/cubejs-databricks-jdbc-driver/
COPY packages/cubejs-vertica-driver/       packages/cubejs-vertica-driver/
# (Front non compilé)

# Build monorepo (script officiel gère l’ordre)
RUN yarn build

# Nettoyage
RUN find . -name 'node_modules' -type d -prune -exec rm -rf '{}' +

# ---- final ---------------------------------------------------------
FROM base AS final

ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONUNBUFFERED=1 \
    NODE_PATH=/cube/conf/node_modules:/cube/node_modules

# Quelques libs python pour drivers qui en ont besoin
RUN apt-get update \
 && apt-get install -y --no-install-recommends python3.11 libpython3.11-dev \
 && apt-get clean && rm -rf /var/lib/apt/lists/*

# Artefacts du build + deps prod
COPY --from=build            /cubejs /cubejs
COPY --from=prod_dependencies/cubejs /cubejs

# Binaire cubejs + liens utiles
COPY packages/cubejs-docker/bin/cubejs-dev /usr/local/bin/cubejs
RUN ln -s /cubejs/packages/cubejs-docker /cube \
 && ln -s /cubejs/rust/cubestore/bin/cubestore-dev /usr/local/bin/cubestore-dev

WORKDIR /cube/conf
EXPOSE 4000

CMD ["cubejs", "server"]
