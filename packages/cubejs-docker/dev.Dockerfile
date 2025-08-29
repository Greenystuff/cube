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
