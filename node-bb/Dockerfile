# Pinned by digest as well as tag: the tag is mutable upstream, and this image
# is what deploys to production on every push to master.
FROM ghcr.io/nodebb/nodebb:4.16.0@sha256:a7e3334de7ce667e8ce434657204f3f9fcc6fabf61f66d16c3e5013aab2154ce

WORKDIR /usr/src/app

# 'npm ci' installs exactly what package-lock.json says and fails the build if
# package.json and the lock disagree, so a dependency change can only reach
# production through a reviewed lockfile diff. The base image's entrypoint runs
# 'npm install' again at container start against this same lock, which is a
# no-op once the two are in sync.
COPY install/package.json install/package-lock.json ./

RUN npm ci --omit=dev && \
    npm cache clean --force

EXPOSE 4567

COPY startup/ensure-indices.js ./
COPY startup/entrypoint.sh /usr/local/bin/triplea-entrypoint.sh
ENTRYPOINT ["tini", "--", "triplea-entrypoint.sh"]
