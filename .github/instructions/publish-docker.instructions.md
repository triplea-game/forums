---
applyTo: ".github/workflows/publish-docker.yml"
---

## Linode Token Scope

The `LINODE_READ_ONLY_TOKEN` secret is intentionally read-only. The deploy job uses it
only to query Linode's API for existing server metadata (IP addresses, tags, etc.) so the
Ansible dynamic inventory knows what hosts to connect to. No servers are created, modified,
or destroyed during deployment - that is out of scope for this workflow.

