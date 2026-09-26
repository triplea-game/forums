#!/bin/bash
# Wraps the base image's entrypoint.sh: ensure NodeBB's database indices exist
# and its session table is UNLOGGED, then hand over. See ensure-indices.js and
# ensure-unlogged-session.js for why.
#
# Skipped when there's no config yet or setup is running: those paths go
# through `nodebb setup`, which creates the indices itself.
#
# A failure is logged and the forum starts anyway. Neither step is needed for
# the forum to work, and a database that isn't up yet fails NodeBB's own start
# too, so the container restarts and this runs again.

export CONFIG="${CONFIG_DIR:-/opt/config}/config.json"

if [ -z "${SETUP:-}" ] && [ -f "$CONFIG" ]; then
  node /usr/src/app/ensure-indices.js ||
    echo "ensure-indices failed; starting NodeBB without them" >&2
  node /usr/src/app/ensure-unlogged-session.js ||
    echo "ensure-unlogged-session failed; starting NodeBB with a logged session table" >&2
fi

exec entrypoint.sh "$@"
