# forums

The [TripleA Forums](https://forums.triplea-game.org) — [NodeBB](https://github.com/NodeBB/NodeBB)
backed by Postgres, packaged as a Docker image and deployed to a Linode host
behind nginx.

## Run it locally

```
just up
```

Brings up NodeBB + Postgres locally on http://localhost:4567. Full flow —
including connecting to the local database — is in
[`docs/runbooks/run-forums-locally.md`](docs/runbooks/run-forums-locally.md).

## Deploy

On push to `master`, CI builds the NodeBB image, publishes it to GitHub Container
Registry, and deploys it (`just deploy`). The host side (compose file,
`config.json`, Postgres, secrets) is owned by the `forums` role in
`triplea-game/infrastructure`.

## Layout

- `node-bb/` — the NodeBB image (`Dockerfile`, `install/package.json` and its
  lockfile) and its [README](node-bb/README.md).
- `docker-compose.yml` + `justfile` — the local dev stack.
- `docs/runbooks/` — run locally, and upgrade the NodeBB version.
- `deploy/` — the Ansible playbook CI runs to deploy.
