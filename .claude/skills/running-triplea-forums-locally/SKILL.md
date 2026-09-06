---
name: running-triplea-forums-locally
description: Run the TripleA Forums (NodeBB + Postgres) locally with `just up`, and connect to the local database. Use when asked to run/start the forums locally, bring up a local NodeBB, spin up the local forums stack, or get a psql shell on the local forums DB. Mirrors the Postgres-backed production stack.
---

# Running the TripleA Forums locally

The local stack is `docker-compose.yml` (NodeBB + Postgres 18) driven by the
`justfile`. The full procedure — prerequisites, DB access, the rootless-Podman
config-ownership gotcha, and troubleshooting — lives in the runbook and is the
source of truth:

**`docs/runbooks/run-forums-locally.md`**

Read it before acting. This skill is the trigger and the happy path only; when
the two disagree, the runbook wins.

## Happy path

1. **Start it** — `just up`. First run builds the image, starts Postgres, sets up
   the schema and an admin account, then starts NodeBB; later runs just start the
   stack.
2. **Open it** — http://localhost:4567, log in as `admin` / `admin-local-123`
   (override on first run with `ADMIN_USER` / `ADMIN_PASSWORD` / `ADMIN_EMAIL`).
3. **Connect to the DB** — `just psql`, or a host client on `127.0.0.1:5432`
   (database `nodebb`, user `nodebb`, password `nodebb`).
4. **Stop / reset** — `just down` keeps data; `just reset` wipes the DB, uploads,
   and local config for a clean install.

Stop and consult the runbook for: an `EACCES`/`EROFS` crash on `config.json`, a
port already in use, or setup hanging on a rejected admin password.

## Not for production

These recipes never touch production — prod is deployed by CI (`just deploy`) and
its config comes from the infrastructure `forums` role. Local-only settings
(container-root, plaintext DB password, `http://localhost` without `trust_proxy`)
must not be copied into the prod templates.
