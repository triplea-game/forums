# TripleA Forums (NodeBB)

The TripleA Forums run [NodeBB](https://github.com/NodeBB/NodeBB), backed by
Postgres, packaged as a Docker image built from this directory's `Dockerfile`
and `install/package.json` + `package-lock.json`.

## Running locally

The whole local stack (NodeBB + Postgres) is the repo's `docker-compose.yml`,
driven by `just`:

```
just up
```

See **`docs/runbooks/run-forums-locally.md`** for the full flow — the admin
login, connecting to the local database, and troubleshooting.

## Production

Production is built and deployed by CI on push to `master`: the
`Publish Docker Image` workflow builds this image, publishes it as
`ghcr.io/triplea-game/forums/nodebb:latest`, and deploys it. The host side (the
compose file, `config.json`, Postgres, secrets) is owned by the `forums` role in
`triplea-game/infrastructure`, not this repo.

To move NodeBB to a new version, follow **`docs/runbooks/upgrade-nodebb.md`** —
it is the source of truth for the bump-and-ship procedure and its gotchas.

## Configuration

NodeBB is configured by a JSON file, `config.json`. The tracked
`example/config.json` is the local-dev template (Postgres, `localhost`); the
production file is rendered by the infrastructure `forums` role. NodeBB's own
reference for every option is [here](https://docs.nodebb.org/configuring/config/).

Points worth knowing:

- `url` is the address NodeBB serves — locally `http://localhost:4567`, in prod
  the public `https` URL.
- `port` is the port inside the container; Docker maps a host port onto it.
- The `postgres` block (`host`, `port`, `username`, `password`, `database`) is the
  database connection. `host` is the Postgres service name on the Docker network,
  not the host machine.
- NodeBB rewrites `config.json` on setup and on boot, so the file must be
  writable — never mount it `:ro`.

## NodeBB version

This is the NodeBB version the forums currently run; the README and
`install/package.json` are written to it.

| TripleA Forums | NodeBB Version | Package Json |
|----------------|----------------|--------------|
| Current        | 4.16.0         | [source](https://github.com/NodeBB/NodeBB/blob/v4.16.0/install/package.json) |

## Plugins

NodeBB customizations are plugins, installed by pinning them in
`install/package.json` (the `nodebb-plugin-*` and `nodebb-theme-*` entries),
running `just lock`, and rebuilding the image. That file is the authoritative
list. It is NodeBB's own `install/package.json` plus one addition,
`nodebb-plugin-cloudflare-turnstile`, so a version bump is a copy of upstream
with that line re-applied, plus a lock regeneration (see
`docs/runbooks/upgrade-nodebb.md`).

## Database indices

NodeBB creates its database indices only during `nodebb setup`, so a database
that arrives any other way (a restore, or the forums' old Mongo-to-Postgres
migration) runs without them, and every write full-scans `legacy_object`. The
image's entrypoint (`startup/entrypoint.sh`) runs NodeBB's own `createIndices`
before every start, which is a no-op once they exist. It's skipped during setup
and before a config exists, and a failure is logged without blocking the start.

## Session table

Every cookieless page render stores a CSRF token in a new session, so guest
and scraper traffic turns into a steady stream of writes to the `session`
table. The entrypoint makes that table UNLOGGED (`startup/ensure-unlogged-session.js`),
which skips the WAL for those writes. The tradeoff: after a Postgres crash or
unclean shutdown the table comes back empty and everyone is logged out. The
first start after this lands rewrites the table under an exclusive lock, which
lengthens that one boot; later starts see it's already UNLOGGED and do nothing.
