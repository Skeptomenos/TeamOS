# TeamOS VM Setup Documentation

**Last Updated:** 2025-01-10  
**Status:** Active  
**Owner:** Your Name

---

## Overview

This document describes the current TeamOS VM infrastructure running on Google Cloud Platform.

---

## Infrastructure Summary

| Property | Value |
|----------|-------|
| **VM Name** | `teamos-server` |
| **External IP** | `34.22.146.168` |
| **Zone** | `europe-west1-b` (Belgium) |
| **Machine Type** | `e2-standard-4` (4 vCPU, 16GB RAM) |
| **OS** | Ubuntu 24.04 LTS |
| **GCP Project** | `it-services-automations` |
| **VPC Network** | `teamos-vpc` |

### Disks

| Disk | Size | Type | Mount Point | Purpose |
|------|------|------|-------------|---------|
| Boot | 50GB | SSD | `/` | OS and applications |
| Data | 200GB | SSD | `/data` | Docker, shared data, knowledge base |

---

## Installed Software

### Shell Environment

| Component | Version | Notes |
|-----------|---------|-------|
| zsh | 5.9 | Default shell for all users |
| oh-my-zsh | latest | Shell framework |
| powerlevel10k | latest | Shell theme |
| zsh-autosuggestions | latest | Plugin |

### Development Tools

| Component | Version | Notes |
|-----------|---------|-------|
| Node.js | 22.21.0 | LTS version |
| Bun | 1.3.5 | JavaScript runtime |
| Git | system | Version control |
| Docker | 29.1.4 | Container runtime |

### AI/OpenCode Stack

| Component | Version | Notes |
|-----------|---------|-------|
| OpenCode | 1.1.12 | AI coding assistant |
| oh-my-opencode | latest | OpenCode enhancement plugin |
| opencode-gemini-auth | latest | Google OAuth for Gemini |

---

## Docker Services

All containers use `/data/docker` as their data root.

| Service | Container Name | Ports | Purpose |
|---------|---------------|-------|---------|
| **Gitea** | `gitea` | `3000` (web), `2222` (SSH) | Git repository hosting |
| **MeiliSearch** | `meilisearch` | `7700` (localhost only) | Full-text search engine |

### Docker Compose Location

```
/opt/teamos/docker-compose.yml
```

### Managing Services

```bash
# View status
docker ps

# Restart services
cd /opt/teamos && docker compose restart

# View logs
docker logs gitea
docker logs meilisearch
```

---

## Network & Firewall

### Firewall Rules

| Rule Name | Ports | Source | Purpose |
|-----------|-------|--------|---------|
| `teamos-allow-ssh` | TCP 22 | 0.0.0.0/0 | SSH access |
| `teamos-allow-gitea` | TCP 3000, 2222 | 0.0.0.0/0 | Gitea web and Git SSH |

### Access URLs

| Service | URL |
|---------|-----|
| SSH | `gcloud compute ssh teamos-server --zone=europe-west1-b --project=it-services-automations` |
| Gitea | http://34.22.146.168:3000 |
| MeiliSearch | localhost:7700 (internal only) |

### OS Login

SSH access is controlled via Google Workspace identity. Only members of `identity-n-productivity@example.com` can connect.

| Setting | Value |
|---------|-------|
| **OS Login** | Enabled |
| **Access Group** | `identity-n-productivity@example.com` |
| **Permission** | `roles/compute.osAdminLogin` (SSH + sudo) |

---

## User Management

### Two User Systems

The VM has two user systems running in parallel:

| System | How It Works | Username Format |
|--------|--------------|-----------------|
| **OS Login** | Google Workspace identity, auto-provisioned | `firstname_lastname_domain_com` |
| **Traditional** | Manual Linux users with SSH keys | Custom (e.g., `jsmith`) |

**OS Login is the primary access method.** Traditional users exist for legacy/template purposes.

### OS Login Users

When a team member connects via `gcloud compute ssh`, GCP automatically:
1. Verifies they're in `identity-n-productivity@example.com`
2. Creates a Linux user based on their email (e.g., `jsmith_example_com`)
3. Grants sudo access (via `osAdminLogin` role)

**Note:** OS Login users get a bare home directory by default. See "First Login Setup" below.

### Template User System

A `template` user exists with all configurations pre-installed for manual provisioning.

**Template location:** `/home/template/`

**Template includes:**
- oh-my-zsh + powerlevel10k configuration
- Bun installation
- OpenCode + oh-my-opencode configuration
- Google Cloud credentials

### Provisioning New Users (Manual Method)

For users who need traditional Linux accounts (not OS Login):

```bash
sudo /opt/teamos/bin/create-user.sh <username> "<ssh-public-key>"
```

**Example:**
```bash
sudo /opt/teamos/bin/create-user.sh jsmith "ssh-ed25519 AAAAC3... jsmith@example.com"
```

**What the script does:**
1. Creates Linux user with zsh shell
2. Adds user to `docker` and `teamos` groups
3. Copies template home directory (oh-my-zsh, bun, opencode configs)
4. Sets up SSH authorized_keys
5. Configures Google Cloud credentials

### User Groups

| Group | Purpose |
|-------|---------|
| `docker` | Access to Docker daemon |
| `teamos` | Shared access to TeamOS resources |

---

## Google Cloud Authentication

### Service Account

| Property | Value |
|----------|-------|
| **Name** | `teamos-opencode` |
| **Email** | `teamos-opencode@it-services-automations.iam.gserviceaccount.com` |
| **Key Location** | `~/.config/gcloud/teamos-opencode-key.json` |
| **Roles** | `roles/aiplatform.user` (Vertex AI access) |

### Environment Variables

Set in each user's `~/.zshrc`:

```bash
export GOOGLE_CLOUD_PROJECT="it-services-automations"
export GOOGLE_APPLICATION_CREDENTIALS="$HOME/.config/gcloud/teamos-opencode-key.json"
```

### OpenCode Authentication

Users can also authenticate with their personal Google Workspace account:

```bash
opencode auth login
# Select: Google -> OAuth with Google (Gemini CLI)
```

---

## OpenCode Configuration

### Config Files

| File | Purpose |
|------|---------|
| `~/.config/opencode/opencode.json` | Main OpenCode config, plugins, providers |
| `~/.config/opencode/oh-my-opencode.json` | Agent model assignments |

### Configured Models

| Agent | Model |
|-------|-------|
| Sisyphus (main) | `google/gemini-2.5-pro` |
| Oracle | `google/gemini-2.5-pro` |
| Frontend Engineer | `google/gemini-2.5-pro` |
| Librarian | `google/gemini-2.5-flash` |
| Explore | `google/gemini-2.5-flash` |
| Document Writer | `google/gemini-2.5-flash` |

### Plugins

- `oh-my-opencode` - Enhanced agent system
- `opencode-gemini-auth` - Google OAuth authentication

---

## Directory Structure

```
/data/
├── docker/                    # Docker data root
│   ├── gitea/                # Gitea data
│   └── meilisearch/          # MeiliSearch data
└── shared/
    └── knowledge/            # Git-versioned knowledge base
        ├── AGENTS.md         # AI agent guide
        ├── README.md
        ├── api-docs/         # API documentation
        ├── decisions/        # Architecture Decision Records
        ├── guides/           # How-to guides
        ├── runbooks/         # Operational procedures
        └── templates/        # Document templates

/opt/teamos/
├── bin/
│   ├── create-user.sh        # User provisioning script
│   ├── health-check.sh       # Service health monitoring
│   ├── audit-report.sh       # Daily audit report
│   ├── indexer.py            # MeiliSearch indexer
│   ├── kb-watcher.py         # File watcher for real-time indexing
│   ├── kb-mcp-server.py      # MCP server for AI agents
│   └── kb                    # Knowledge base CLI tool
├── venv/                     # Python virtual environment
├── docker-compose.yml        # Docker service definitions
└── credentials/              # Service account keys

/home/template/               # Template user for provisioning
├── .oh-my-zsh/
├── .bun/
├── .config/
│   ├── opencode/
│   └── gcloud/
└── .zshrc
```

---

## Maintenance

### Upgrading the VM

To upgrade machine type (e.g., when onboarding more users):

```bash
# Stop the VM
gcloud compute instances stop teamos-server --zone=europe-west1-b

# Change machine type
gcloud compute instances set-machine-type teamos-server \
  --machine-type=n2-standard-8 \
  --zone=europe-west1-b

# Start the VM
gcloud compute instances start teamos-server --zone=europe-west1-b
```

**Recommended sizes:**
- 1-3 users: `e2-standard-4` (current)
- 4-10 users: `n2-standard-8` (8 vCPU, 32GB)
- 10+ heavy users: `n2-highmem-8` (8 vCPU, 64GB)

### Updating Template User

After making configuration changes to your own account that should apply to new users:

```bash
sudo cp ~/.config/opencode/* /home/template/.config/opencode/
sudo cp ~/.zshrc /home/template/
sudo chown -R template:template /home/template/
```

### Viewing Logs

```bash
# Docker service logs
docker logs -f gitea
docker logs -f meilisearch

# System logs
sudo journalctl -u docker -f
```

### Creating a New Server from Template

**Option A: From Machine Image (fastest)**
```bash
gcloud compute instances create teamos-server-new \
  --source-machine-image=teamos-server-image-v1 \
  --zone=europe-west1-b \
  --project=it-services-automations
```

**Option B: From Terraform (reproducible)**
```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
terraform init
terraform apply
```

---

## Audit & Logging

### Overview

All actions on the VM are logged and forwarded to GCP Cloud Logging for immutable storage.

```
auditd + syslog + app logs
         ↓
     fluent-bit
         ↓
   GCP Cloud Logging (immutable, 30+ day retention)
```

### auditd (Kernel-Level Auditing)

**Config file:** `/etc/audit/rules.d/teamos.rules`

**What's logged:**

| Category | What's Captured |
|----------|-----------------|
| Knowledge Base | All file changes in `/data/shared/knowledge` |
| User Management | Changes to `/etc/passwd`, `/etc/group`, `/etc/shadow` |
| Sudo | All sudo configuration changes |
| SSH | SSH config modifications |
| Privileged Commands | All commands run as root by non-root users |
| File Deletions | All file deletions by users |
| Permission Changes | chmod, chown operations |

**Useful commands:**
```bash
# View Knowledge Base changes today
sudo ausearch -k knowledge_changes -ts today --interpret

# View sudo usage
sudo ausearch -k privileged_commands -ts today --interpret

# View failed access attempts
sudo ausearch --failed
```

### fluent-bit (Log Forwarding)

**Config file:** `/etc/fluent-bit/fluent-bit.conf`

**Service account:** `teamos-fluentbit@it-services-automations.iam.gserviceaccount.com`

**Logs collected:**
- System logs (sshd, docker)
- Audit logs (`/var/log/audit/audit.log`)
- Auth logs (`/var/log/auth.log`)
- Docker container logs

**Check status:**
```bash
sudo systemctl status fluent-bit
```

### Session Recording

All SSH sessions are recorded for audit purposes.

**Location:** `/var/log/sessions/`

**Format:** `<username>_<date>_<time>_<pid>.log`

**Replay a session:**
```bash
# View session file
cat /var/log/sessions/jsmith_example_com_20250110_143022_1234.log

# With timing (if available)
scriptreplay /var/log/sessions/<file>.timing /var/log/sessions/<file>.log
```

**Retention:** 30 days (via logrotate)

### GCP Cloud Logging

Logs are forwarded to GCP Cloud Logging for immutable storage.

**View logs:**
```bash
# Via gcloud
gcloud logging read "resource.type=gce_instance AND resource.labels.instance_id=teamos-server" --limit=50

# Or use GCP Console: https://console.cloud.google.com/logs
```

### Health Monitoring

**Health check script:** `/opt/teamos/bin/health-check.sh`

**Runs every 5 minutes via cron. Checks:**
- Critical services (sshd, auditd, fluent-bit, docker)
- Docker containers (meilisearch, gitea)
- Disk usage (alerts at 80%)
- Memory usage (alerts at 90%)
- MeiliSearch health endpoint

**Alert log:** `/var/log/teamos-alerts.log`

**Health log:** `/var/log/teamos-health.log`

### Daily Audit Report

**Script:** `/opt/teamos/bin/audit-report.sh`

**Runs daily at 8:00 AM UTC. Includes:**
- Recent logins
- Failed login attempts
- Knowledge Base changes
- Sudo usage
- Disk usage
- Service status
- Docker container status
- Recent alerts

**Report log:** `/var/log/teamos-audit-report.log`

---

## Security Notes

1. **SSH Keys**: Each user should have their own SSH key. Keys are stored in `~/.ssh/authorized_keys`.

2. **Service Account Key**: The shared service account key provides Vertex AI access. It's copied to each user's home directory with restricted permissions (600).

3. **Firewall**: SSH is open to all IPs. Consider restricting to known IPs or enabling OS Login with IAP for production use.

4. **Docker Access**: Users in the `docker` group have root-equivalent access via Docker. Only add trusted users.

5. **Audit Trail**: All actions are logged via auditd and forwarded to GCP Cloud Logging. Logs are immutable and retained for 30+ days.

6. **Session Recording**: All SSH sessions are recorded to `/var/log/sessions/` for forensic analysis.

---

## Gitea (Self-Hosted Git)

### Overview

Gitea provides self-hosted Git repositories with Google Workspace authentication.

| Property | Value |
|----------|-------|
| **URL** | http://34-22-146-168.nip.io:3000 |
| **Container** | `gitea` |
| **Data** | `/data/docker/gitea` |
| **Config** | `/data/docker/gitea/gitea/conf/app.ini` |
| **Auth** | Google OAuth (OpenID Connect) |

### Authentication

Users sign in with their `@example.com` Google Workspace accounts. No local passwords.

**OAuth Settings:**
- Provider: Google (OpenID Connect)
- Auto-registration: Enabled
- Account linking: Automatic

### User Provisioning

**Current approach: JIT (Just-In-Time)**

Users are automatically created when they first sign in with Google OAuth. No pre-provisioning required.

**How it works:**
1. User visits Gitea and clicks "Sign in with Google"
2. User authenticates with their `@example.com` account
3. Gitea automatically creates their account
4. User is ready to use Gitea

**Deprovisioning:** Manual. Admins must deactivate users who leave the team.

```bash
# Deactivate a user
docker exec -u git gitea gitea admin user change-password --username <name> --must-change-password
# Or via Gitea Admin UI: Site Administration → User Accounts
```

### Future Enhancement: API Sync (Not Implemented)

A sync script exists at `/opt/teamos/bin/sync-users.py` that could automatically sync users from a Google Workspace group to Gitea.

**Why it's not active:** Requires Domain-Wide Delegation in Google Workspace Admin, which is not appropriate for a test project in a large organization (16,000+ employees).

**If needed in the future:**
1. Configure Domain-Wide Delegation for service account `114273628278732506878`
2. Grant scope: `https://www.googleapis.com/auth/admin.directory.group.member.readonly`
3. Enable the cron job in `/etc/cron.d/teamos`

For now, JIT provisioning is sufficient for a 10-person team.

### Admin Access

| Username | Password | Notes |
|----------|----------|-------|
| `admin` | `TeamOS-Admin-2025!` | Initial admin account |

### Adding Google OAuth (Post-Deployment)

If deploying a new instance, Google OAuth must be configured manually:

1. **Create OAuth credentials** in GCP Console:
   - Go to: https://console.cloud.google.com/apis/credentials
   - Create OAuth client ID (Web application)
   - Redirect URI: `http://<GITEA_DOMAIN>:3000/user/oauth2/Google/callback`

2. **Add OAuth source** via CLI:
   ```bash
   docker exec -u git gitea gitea admin auth add-oauth \
     --name 'Google' \
     --provider openidConnect \
     --key '<CLIENT_ID>' \
     --secret '<CLIENT_SECRET>' \
     --auto-discover-url 'https://accounts.google.com/.well-known/openid-configuration' \
     --scopes 'openid' \
     --scopes 'email' \
     --scopes 'profile' \
     --skip-local-2fa
   ```

3. **Verify** by clicking "Sign in with Google" on the login page

### Gitea CLI Commands

```bash
# List users
docker exec -u git gitea gitea admin user list

# List auth sources
docker exec -u git gitea gitea admin auth list

# Add Google OAuth
docker exec -u git gitea gitea admin auth add-oauth --name 'Google' --provider openidConnect --key '<ID>' --secret '<SECRET>' --auto-discover-url 'https://accounts.google.com/.well-known/openid-configuration' --scopes 'openid' --scopes 'email' --scopes 'profile' --skip-local-2fa

# Create user manually
docker exec -u git gitea gitea admin user create --username <name> --email <email> --random-password

# Change user password
docker exec -u git gitea gitea admin user change-password --username <name> --password <new>

# Reset admin password
docker exec -u git gitea gitea admin user change-password --username admin --password 'NewPassword123!'
```

---

## Knowledge Base

### Overview

The TeamOS Knowledge Base is a Git-versioned Markdown repository with full-text search via MeiliSearch.

| Property | Value |
|----------|-------|
| **Repository** | `knowledge-base` in Gitea |
| **Location** | `/data/shared/knowledge/` |
| **Search Engine** | MeiliSearch (localhost:7700) |
| **Indexer** | `/opt/teamos/bin/indexer.py` |
| **File Watcher** | `kb-watcher.service` (systemd) |
| **MCP Server** | `/opt/teamos/bin/kb-mcp-server.py` |

### Document Categories

| Category | Purpose |
|----------|---------|
| `project` | Project plans, visions, design docs |
| `runbook` | Operational procedures |
| `decision` | Architecture Decision Records (ADRs) |
| `guide` | How-to guides, tutorials |
| `api-doc` | API documentation |
| `meeting-note` | Meeting notes |

### Required Frontmatter

All documents must include YAML frontmatter:

```yaml
---
title: "Document Title"
created: 2025-01-11
created_by: your.email@example.com
category: guide
status: draft
tags:
  - tag1
  - tag2
---
```

See `/data/shared/knowledge/templates/frontmatter-schema.md` for full schema.

### CLI Usage

```bash
# Search documents
kb search "authentication API"

# Read a document
kb read runbooks/onboarding/new-hire-checklist.md

# List by category
kb list api-docs

# Recent changes
kb recent 7

# Show index stats
kb stats

# Trigger full reindex
kb reindex
```

### Services

| Service | Status Command |
|---------|----------------|
| File Watcher | `sudo systemctl status kb-watcher` |
| MeiliSearch | `docker ps \| grep meilisearch` |

### AI Agent Access

AI agents can access the knowledge base via:

1. **MCP Server** - `/opt/teamos/bin/kb-mcp-server.py`
   - Tools: `kb_search`, `kb_read`, `kb_list`, `kb_recent`
   
2. **CLI** - `kb` command
   
3. **Direct API** - MeiliSearch at localhost:7700

See `/data/shared/knowledge/AGENTS.md` for AI agent guide.

---

## Pending Configuration

- [x] OS Login with Google Workspace (restrict SSH to team group)
- [x] First login setup hook for OS Login users
- [x] Audit logging (auditd + fluent-bit)
- [x] Session recording
- [x] Health monitoring and alerts
- [x] Gitea with Google OAuth
- [x] User provisioning (JIT via Google OAuth)
- [x] Knowledge base repository creation
- [x] MeiliSearch indexer configuration
- [x] Knowledge Base MCP Server for AI agents
- [x] Gitea customization (theme, branding)

---

## Quick Reference

```bash
# SSH to server (recommended - uses Google Workspace identity)
gcloud compute ssh teamos-server --zone=europe-west1-b --project=it-services-automations

# Or use the alias (add to your local ~/.zshrc)
alias teamos="gcloud compute ssh teamos-server --zone=europe-west1-b --project=it-services-automations"
teamos

# Create new user (manual method)
sudo /opt/teamos/bin/create-user.sh <username> "<ssh-key>"

# Check Docker services
docker ps

# Restart Docker services
cd /opt/teamos && docker compose restart

# View OpenCode models
opencode models

# Authenticate OpenCode with Google
opencode auth login
```

---

## New User Onboarding Guide

### For Team Members

1. **Ensure you're in the team group**
   - You must be a member of `identity-n-productivity@example.com` in Google Workspace

2. **Install gcloud CLI** (if not already installed)
   ```bash
   # macOS
   brew install google-cloud-sdk
   
   # Or download from https://cloud.google.com/sdk/docs/install
   ```

3. **Authenticate with Google**
   ```bash
   gcloud auth login
   ```

4. **Add the TeamOS alias to your shell** (optional but recommended)
   ```bash
   echo 'alias teamos="gcloud compute ssh teamos-server --zone=europe-west1-b --project=it-services-automations"' >> ~/.zshrc
   source ~/.zshrc
   ```

5. **Connect to TeamOS**
   ```bash
   teamos
   # Or: gcloud compute ssh teamos-server --zone=europe-west1-b --project=it-services-automations
   ```

6. **First login setup** (run once after first connection)
   ```bash
   # Copy template configs to your home directory
   cp -r /home/template/.oh-my-zsh ~/
   cp -r /home/template/.bun ~/
   cp -r /home/template/.config ~/
   cp /home/template/.zshrc ~/
   
   # Start a new zsh session
   exec zsh
   ```

7. **Authenticate OpenCode with your Google account**
   ```bash
   opencode auth login
   # Select: Google -> OAuth with Google (Gemini CLI)
   ```

8. **Verify setup**
   ```bash
   opencode models  # Should list available Gemini models
   docker ps        # Should show Gitea and MeiliSearch running
   ```

### Troubleshooting

| Issue | Solution |
|-------|----------|
| "Permission denied" on SSH | Verify you're in `identity-n-productivity@example.com` group |
| "Project not found" | Run `gcloud config set project it-services-automations` |
| No oh-my-zsh prompt | Run the first login setup commands above |
| OpenCode auth fails | Ensure you're using a `@example.com` Google account |
