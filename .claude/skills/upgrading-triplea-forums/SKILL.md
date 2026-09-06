---
name: upgrading-triplea-forums
description: Upgrade the TripleA Forums to a newer NodeBB version — bump the base image and package.json in the forums repo, push, and let CI build and deploy. Use when asked to upgrade the forums, bump NodeBB, or move the forums to a new NodeBB release. Postgres-backed NodeBB behind nginx.
---

# Upgrading the TripleA Forums (NodeBB)

The full procedure — preflight, rollback, and the gotchas that have caused
outages — lives in the runbook and is the source of truth:

**`docs/runbooks/upgrade-nodebb.md`**

Read it before acting. This skill is the trigger and the happy path only; when
the two disagree, the runbook wins.

## Happy path

A version bump is two edits in this repo (`triplea-game/forums`) plus a push —
CI builds the image and deploys it; there is no manual build or SSH step.

1. **Back up Postgres first** — `sudo /usr/local/bin/backup-forums.sh` on the
   forums host. Schema upgrades run on first boot and aren't cleanly reversible.
2. **Bump `node-bb/Dockerfile`** — `FROM ghcr.io/nodebb/nodebb:<new-version>`.
3. **Sync `node-bb/install/package.json`** — take NodeBB's `install/package.json`
   at the target tag as the baseline, then re-apply the TripleA plugin/theme
   entries at versions compatible with the new NodeBB major.
4. **Push to `master`** — `.github/workflows/publish-docker.yml` builds/publishes
   `ghcr.io/triplea-game/forums/nodebb:latest` and runs the deploy job.
5. **Verify** — logs show `🎉 NodeBB Ready` and `Setting 'trust proxy' to true`;
   `https://forums.triplea-game.org` loads and login works.

Stop and consult the runbook for: plugin-compatibility failures, rollback, or
any `config.json` / `trust_proxy` / `EROFS` / `EACCES` boot crash.
