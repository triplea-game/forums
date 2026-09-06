# Runbook: Upgrade the NodeBB version

How to move the TripleA Forums to a newer NodeBB release. The forums run
NodeBB in Docker, backed by Postgres, behind the host's nginx.

The whole upgrade is two edits in **this repo** (`triplea-game/forums`)
followed by a push. The image is built and deployed by CI; there is no manual
build or SSH step for a normal version bump.

## How the pieces fit

- The image is built from `node-bb/Dockerfile` (its `FROM` pins the NodeBB
  version by tag and digest) plus `node-bb/install/package.json` and
  `package-lock.json` (the dependency tree, installed with `npm ci` so a build
  reproduces the lock exactly or fails).
- On push to `master`, `.github/workflows/publish-docker.yml` builds that
  image, publishes it as `ghcr.io/triplea-game/forums/nodebb:latest`, and then
  runs the `deploy` job. Deploy runs `just deploy`, whose playbook SSHes to the
  forums host and runs `/usr/local/bin/deploy-forums.sh` — `docker compose pull
  nodebb && docker compose up -d --no-deps nodebb`.
- The host side (the compose file, `config.json`, Postgres, secrets, the
  `deploy-forums.sh` script itself) is owned by the `forums` role in the
  `triplea-game/infrastructure` repo. You only touch that repo when the deploy
  *shape* changes; a version bump does not.

So: **push to `master` is the deploy.** The current running version is
whatever `node-bb/Dockerfile` `FROM` points at on `master`.

## Preflight

1. **Back up Postgres first.** A major NodeBB bump runs schema upgrades against
   the database on first boot, and those are not cleanly reversible. Take a dump
   before pushing — the forums host already has the tooling:

   ```
   sudo /usr/local/bin/backup-forums.sh
   ```

   (rendered from the `forums` role's `backup.sh.j2`; it `pg_dump`s the `nodebb`
   database and rsyncs it to the backup host). Confirm a fresh dump landed
   before continuing.

2. **Pick the target version and read its release notes.** NodeBB documents
   breaking changes and required plugin versions per release. Note the tag, eg
   `v4.16.0`.

3. **Line up plugin compatibility.** An incompatible plugin blocks boot. The
   plugins and themes in `install/package.json` are NodeBB's own bundled set,
   so the target release's file already carries compatible versions; this step
   only bites for a plugin this repo has added on top of stock.

## Make the change

All three files live under `node-bb/`.

1. **Bump the base image** in `node-bb/Dockerfile`, tag and digest together.
   The digest is what actually pins the build; get it from the registry rather
   than trusting the tag:

   ```
   docker pull ghcr.io/nodebb/nodebb:<new-version>
   docker inspect --format '{{index .RepoDigests 0}}' ghcr.io/nodebb/nodebb:<new-version>
   ```

   ```
   FROM ghcr.io/nodebb/nodebb:<new-version>@sha256:<digest>
   ```

2. **Sync `node-bb/install/package.json`** to the new release. Take NodeBB's
   own `install/package.json` at the target tag —
   `https://github.com/NodeBB/NodeBB/blob/v<new-version>/install/package.json` —
   and re-apply whatever this repo has changed on top of stock. Today that is
   nothing: the file is byte-identical to upstream, and every plugin and theme
   the forums run ships in NodeBB's own dependency list. Diff before you copy
   so a future TripleA-only entry does not get lost.

3. **Regenerate `node-bb/install/package-lock.json`** inside the new base
   image, so the lock resolves against the tree that image already carries
   rather than whatever the registry serves today:

   ```
   just lock
   ```

   The image build runs `npm ci`, which refuses to build if package.json and
   the lock disagree, so a bump that skips this step fails in CI before it can
   reach production. Review the lock diff like any other dependency change.

## Ship it

1. Commit and push to `master`.
2. Watch the `Publish Docker Image` workflow. `build-and-push` must go green
   (a plugin or dependency that can't install fails here, before anything
   reaches production), then `deploy` runs automatically.

## Verify

Pull the NodeBB logs — via the `debugging-triplea-production` skill, or on the
host `docker compose -f /opt/triplea-forums/docker-compose.yml logs nodebb`.
A healthy startup shows:

```
info: 🎉 NodeBB Ready
info: 🤝 Setting 'trust proxy' to 1
info: 🔗 Canonical URL: https://forums.triplea-game.org
info: 📡 NodeBB is now listening on: 0.0.0.0:4567
```

Then load `https://forums.triplea-game.org` and confirm the site renders, you
can log in, and a topic loads.

## If it goes wrong

- **Roll back the version.** Deploys track the `:latest` tag, so there is no
  "redeploy the old one" button — revert the forums-repo commit and push again
  to rebuild `:latest` from the previous `Dockerfile`. If you need to roll back
  faster than a rebuild, pin the compose `image:` to the previous image digest
  on the host and `up -d`, then fix forward in the repo.
- **Restore the database** from the preflight dump only if a schema migration
  ran and left the DB in a state the older NodeBB can't read. A version bump
  without a completed migration usually needs only the image rollback.

## Gotchas

- **`config.json` must be writable and owned by the container user (uid 1001).**
  NodeBB writes migration state back to `config.json` on boot. A read-only
  (`:ro`) mount crash-loops with `EROFS`; wrong ownership crash-loops with
  `EACCES`. The production compose (infra `forums` role) already mounts it
  writable with the right owner — the failure mode is *reintroducing* `:ro`.
  The local-dev stack solves the same requirement differently (writable mount,
  container-root under rootless Podman); see `run-forums-locally.md`. Its local
  settings must never be copied into the prod template.
- **`trust_proxy: 1` must stay in `config.json`.** The forums sit behind
  nginx; without it, redirects and canonical URLs break. It is `1`, not
  `true`, on purpose: `1` trusts exactly the nginx hop, whereas `true` trusts
  every hop and lets a client spoof its IP via `X-Forwarded-For`.
- **Plugins gate the boot.** If NodeBB starts but a plugin errors, the plugin
  version is likely behind the new NodeBB major — bump it in
  `install/package.json`, run `just lock`, and re-push.
- **`npm ci` fails the build on a stale lock.** A `build-and-push` failure
  right after the `COPY` step means `package.json` changed without `just lock`;
  regenerate and re-push.
