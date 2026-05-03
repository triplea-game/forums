# Prompt: Ansible Role - MongoDB Backup via rsync

## Task

Create an Ansible role called `forums_backup` that sets up a daily MongoDB backup job on a
Linux server running MongoDB inside Docker Compose. The backup is compressed and rsync'd to
a separate server over SSH.

---

## Context

- MongoDB runs as a Docker Compose service named `mongodb`.
- The compose file is at `/srv/triplea-forums/docker-compose.yml`.
- The database name is `nodebb`.
- The dumped output is NOT pre-compressed; the script must compress it with gzip.
- The backup is transferred to a remote server via rsync over SSH.
- A dedicated SSH key (no passphrase) is used for the rsync connection.
  The key is placed on the host manually - Ansible must NOT manage the private key file.
- Old backups on the remote must be pruned to avoid unbounded disk growth.

---

## Role Structure to Create

```
roles/forums_backup/
  defaults/main.yml      # all tuneable variables with sensible defaults
  tasks/main.yml         # deploys the script and installs the cron job
  templates/backup.sh.j2 # the backup shell script (Jinja2 template)
```

---

## Variables (defaults/main.yml)

| Variable | Default | Description |
|---|---|---|
| `backup_remote_user` | `"backups"` | SSH user on the remote server |
| `backup_remote_host` | `""` | Hostname/IP of the remote server (required - no default) |
| `backup_remote_path` | `"/backups/forums"` | Directory on the remote server to store backups |
| `backup_ssh_key_path` | `"/root/.ssh/id_backup"` | Path to the SSH private key on the forums server |
| `backup_retention_days` | `14` | Days of backup files to keep on the remote |
| `backup_tmp_dir` | `"/tmp"` | Local temp directory used during dump + transfer |
| `backup_cron_hour` | `"3"` | Hour for the cron job (24h) |
| `backup_cron_minute` | `"0"` | Minute for the cron job |

---

## Backup Script Logic (templates/backup.sh.j2)

The script must:

1. Use `set -euo pipefail` so any failure stops the script immediately.
2. Build a timestamped filename like `nodebb-YYYYMMDD-HHMMSS.gz`.
3. Run mongodump via `docker compose exec -T` piped through `gzip` into a temp file:
   ```bash
   docker compose -f /srv/triplea-forums/docker-compose.yml exec -T mongodb \
     mongodump --db nodebb --archive | gzip > "$BACKUP_FILE"
   ```
4. rsync the file to the remote using the dedicated SSH key:
   ```bash
   rsync -az -e "ssh -i {{ backup_ssh_key_path }} -o StrictHostKeyChecking=no" \
     "$BACKUP_FILE" \
     {{ backup_remote_user }}@{{ backup_remote_host }}:{{ backup_remote_path }}/
   ```
5. Delete the local temp file after successful rsync.
6. Prune files on the remote older than `backup_retention_days` days:
   ```bash
   ssh -i {{ backup_ssh_key_path }} -o StrictHostKeyChecking=no \
     {{ backup_remote_user }}@{{ backup_remote_host }} \
     "find {{ backup_remote_path }}/ -name 'nodebb-*.gz' -mtime +{{ backup_retention_days }} -delete"
   ```
7. Log each major step to stdout with a timestamp prefix (the cron daemon captures this).

---

## Ansible Tasks (tasks/main.yml)

1. Ensure `/usr/local/bin` exists (it usually does, but be explicit).
2. Template `backup.sh.j2` to `/usr/local/bin/forums-backup.sh` with mode `0750`, owner `root`.
3. Install a cron job running as root:
   - Command: `/usr/local/bin/forums-backup.sh >> /var/log/forums-backup.log 2>&1`
   - Schedule: `backup_cron_hour` / `backup_cron_minute` daily.
   - Name the cron entry `forums-mongodb-backup` so Ansible can manage it idempotently.

---

## playbook.yml Integration

Add the role to the existing play:

```yaml
- hosts: forums
  tags: forums
  roles:
    - nginx_forums_conf
    - role: forums_backup
      vars:
        backup_remote_host: "your-backup-server.example.com"
```

The `backup_remote_host` must be overridden - either in the inventory file, in a group_vars
file, or with `--extra-vars` at run time. The role should fail with a clear error if it is
empty.

Add a task at the top of `tasks/main.yml` to assert `backup_remote_host != ""`:
```yaml
- name: check backup_remote_host is set
  assert:
    that: backup_remote_host | length > 0
    fail_msg: "backup_remote_host must be set (hostname or IP of the rsync destination)"
```

---

## Manual Setup Required on the Remote Server (document in a README)

These steps are NOT automated by Ansible (they are done once by an operator):

```bash
# On the remote server:
useradd -m -s /bin/bash backups
mkdir -p /backups/forums
chown backups:backups /backups/forums

# Authorize the forums server's public key
mkdir -p /home/backups/.ssh
echo "<contents of /root/.ssh/id_backup.pub from the forums server>" \
  >> /home/backups/.ssh/authorized_keys
chmod 700 /home/backups/.ssh
chmod 600 /home/backups/.ssh/authorized_keys
chown -R backups:backups /home/backups/.ssh
```

---

## Testing the Script Manually

After Ansible deploys the script:

```bash
# Run once by hand to verify it works end-to-end
sudo /usr/local/bin/forums-backup.sh

# Check what landed on the remote
ssh -i /root/.ssh/id_backup backups@<remote-host> \
  "ls -lh /backups/forums/"
```

