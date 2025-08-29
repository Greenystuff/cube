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
COPY packages/cubejs
