# TripleA Forums — local dev
#
# Runs the forums stack (NodeBB + Postgres) on your machine, mirroring the
# production database (Postgres 18). Production itself is deployed by CI on push
# to master (`just deploy`); nothing here touches production.
#
# First run: `just up` builds the image, starts Postgres, sets up the schema and
# an admin user, then starts NodeBB on http://localhost:4567.

set shell := ["bash", "-euo", "pipefail", "-c"]

compose := "docker compose"
config := "node-bb/config.local.json"

# Local admin created on first `just up`; override inline, eg `ADMIN_PASSWORD=… just up`.
export ADMIN_USER := env_var_or_default("ADMIN_USER", "admin")
export ADMIN_PASSWORD := env_var_or_default("ADMIN_PASSWORD", "admin-local-123")
export ADMIN_EMAIL := env_var_or_default("ADMIN_EMAIL", "admin@localhost.local")

# Deploy uses this ssh user (defaults to $USER); CI passes SSH_USER=deploy.
ssh_user := env_var_or_default("SSH_USER", env_var_or_default("USER", ""))

# List recipes
default:
    @just --list

# Build the image, then start Postgres + NodeBB; sets up the DB on first run.
up: _seed-config
    {{compose}} up -d --build postgres
    @just _wait-pg
    @just _setup-if-needed
    {{compose}} up -d --build nodebb
    @echo "forums up → http://localhost:4567  (admin: $ADMIN_USER / $ADMIN_PASSWORD)"

# Stop the stack, keeping the database and uploads.
down:
    {{compose}} down

# Stop and wipe all local state — Postgres data, uploads, and config.local.json.
reset:
    {{compose}} down -v
    rm -f {{config}}

# Follow NodeBB logs.
logs:
    {{compose}} logs -f nodebb

# Open a psql shell on the local Postgres (database 'nodebb', user 'nodebb').
psql:
    {{compose}} exec postgres psql -U nodebb -d nodebb

# Deploy to production — CI runs this on push to master; nothing local touches prod.
deploy:
    ANSIBLE_CONFIG="deploy/ansible.cfg" ansible-playbook -e ansible_user={{ssh_user}} --inventory deploy/ansible/inventory.linode.yml deploy/ansible/playbook.yml

# Seed a gitignored local config from the tracked example if it does not exist.
_seed-config:
    @test -f {{config}} || { cp node-bb/example/config.json {{config}}; echo "seeded {{config}} from example"; }

# Block until Postgres accepts connections.
_wait-pg:
    @for i in $(seq 1 30); do {{compose}} exec -T postgres pg_isready -U nodebb -q && exit 0; sleep 1; done; \
      echo "postgres did not become ready" >&2; exit 1

# Run NodeBB's non-interactive setup once, when the schema is absent.
_setup-if-needed:
    @if [ "$({{compose}} exec -T postgres psql -U nodebb -d nodebb -tAc "select to_regclass('public.legacy_object') is not null")" = t ]; then \
      echo "database already set up — skipping setup"; \
    else \
      echo "fresh database — running NodeBB setup"; \
      {{compose}} run --rm --no-deps \
        -e SETUP=true \
        -e NODEBB_ADMIN_USERNAME="$ADMIN_USER" \
        -e NODEBB_ADMIN_PASSWORD="$ADMIN_PASSWORD" \
        -e NODEBB_ADMIN_EMAIL="$ADMIN_EMAIL" \
        nodebb; \
    fi
