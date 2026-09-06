# Pinned by digest as well as tag: the tag is mutable upstream, and this image
# is what deploys to production on every push to master.
FROM ghcr.io/nodebb/nodebb:4.15.2@sha256:80e60a49ab1e600ad707cbdf96432150092e9d190c8b362a4d49cabbb845a752

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
