# TeamOS Terraform Deployment

One-click infrastructure deployment for TeamOS.

## Prerequisites

1. [Terraform](https://terraform.io) >= 1.0
2. [gcloud CLI](https://cloud.google.com/sdk) authenticated
3. GCP project with billing enabled

## Quick Start

```bash
cd terraform

cp terraform.tfvars.example terraform.tfvars

terraform init

terraform plan

terraform apply
```

## What Gets Created

| Resource | Description |
|----------|-------------|
| VPC Network | `teamos-vpc` with auto subnets |
| Firewall Rules | SSH (22), Gitea (3000, 2222) |
| Data Disk | 200GB SSD at `/data` |
| VM Instance | Ubuntu 24.04, e2-standard-4 |
| Service Accounts | OpenCode (Vertex AI), Fluent-bit (Logging) |
| Log Bucket | 180-day retention |
| OS Login IAM | Team group SSH access |

## What Gets Installed Automatically

The startup script installs and configures:

| Component | Purpose |
|-----------|---------|
| Docker + Gitea + MeiliSearch | Git hosting + full-text search |
| OpenCode + oh-my-opencode | AI coding assistant |
| auditd + fluent-bit | Audit logging to GCP |
| Session recording | SSH session capture |
| Health monitoring | Service health checks |
| **Knowledge Base Tools** | |
| Python venv + dependencies | meilisearch, frontmatter, watchdog, mcp |
| `kb` CLI | Search/read/list knowledge base |
| `indexer.py` | MeiliSearch document indexer |
| `kb-watcher.py` | Real-time file change indexing |
| `kb-mcp-server.py` | MCP server for AI agent access |
| Gitea custom styling | TeamOS branding |

## After Deployment

### Step 1: Get the Gitea URL

```bash
gcloud compute ssh teamos-server --zone=europe-west1-b --project=it-services-automations --command="cat /var/log/teamos-setup.log | grep 'Gitea URL'"
```

The URL will be something like: `http://34-22-146-168.nip.io:3000`

### Step 2: Create Google OAuth Credentials

1. Go to: https://console.cloud.google.com/apis/credentials

2. Click **"+ CREATE CREDENTIALS"** → **"OAuth client ID"**

3. If prompted for consent screen:
   - User Type: **Internal** (Workspace users only)
   - App name: **TeamOS Gitea**

4. Create OAuth Client:
   - Application type: **Web application**
   - Name: **Gitea**
   - Authorized redirect URI: `http://<GITEA_DOMAIN>:3000/user/oauth2/Google/callback`
   
   (Replace `<GITEA_DOMAIN>` with your nip.io domain from Step 1)

5. Save the **Client ID** and **Client Secret**

### Step 3: Configure Google OAuth in Gitea

SSH into the server and add the OAuth source:

```bash
gcloud compute ssh teamos-server --zone=europe-west1-b --project=it-services-automations

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

### Step 4: Create Knowledge Base Repository

1. Open Gitea at `http://<GITEA_DOMAIN>:3000`
2. Login as `admin` / `TeamOS-Admin-2025!`
3. Click **"+"** → **"New Repository"**
4. Name: `knowledge-base`
5. Check **"Initialize Repository"**
6. Click **"Create Repository"**

### Step 5: Initialize Knowledge Base

```bash
# SSH to server
gcloud compute ssh teamos-server --zone=europe-west1-b --project=it-services-automations

# Clone the repo
cd /data/shared
sudo rm -rf knowledge
git clone http://localhost:3000/admin/knowledge-base.git knowledge
cd knowledge

# Create folder structure
mkdir -p api-docs runbooks decisions guides templates

# Configure git
git config user.email "teamos@example.com"
git config user.name "TeamOS System"

# Create AGENTS.md for AI agents
cat > AGENTS.md << 'EOF'
# AI Agent Guide for TeamOS Knowledge Base

## MCP Server
Path: `/opt/teamos/bin/kb-mcp-server.py`

Tools: `kb_search`, `kb_read`, `kb_list`, `kb_recent`

## CLI Access
```bash
kb search "query"
kb read path/to/doc.md
kb list category
kb recent 7
```
EOF

# Commit and push
git add -A
git commit -m "Initial structure"
git push origin main

# Start file watcher service
sudo systemctl start kb-watcher

# Run initial indexing
kb reindex
```

### Step 6: Verify Setup

1. Test search: `kb search "agent"`
2. Check index: `kb stats`
3. Open Gitea and verify the knowledge-base repo is visible

### Admin Access

- **Username:** `admin`
- **Password:** `TeamOS-Admin-2025!`

### SSH Access

```bash
gcloud compute ssh teamos-server --zone=europe-west1-b --project=it-services-automations
```

Or add this alias to your `~/.zshrc`:
```bash
alias teamos="gcloud compute ssh teamos-server --zone=europe-west1-b --project=it-services-automations"
```

## From Machine Image (Faster)

To deploy from the existing machine image instead of running the startup script:

```bash
gcloud compute instances create teamos-server-new \
  --source-machine-image=teamos-server-image-v1 \
  --zone=europe-west1-b \
  --project=it-services-automations
```

## Upgrading

```bash
gcloud compute instances stop teamos-server --zone=europe-west1-b
gcloud compute instances set-machine-type teamos-server --machine-type=n2-standard-8 --zone=europe-west1-b
gcloud compute instances start teamos-server --zone=europe-west1-b
```

## Knowledge Base Usage

### CLI Commands

```bash
kb search "authentication API"   # Search documents
kb read runbooks/onboarding.md   # Read a document
kb list api-docs                 # List by category
kb recent 7                      # Recently modified
kb stats                         # Index statistics
kb reindex                       # Full reindex
```

### MCP Server for AI Agents

The MCP server at `/opt/teamos/bin/kb-mcp-server.py` provides:

| Tool | Purpose |
|------|---------|
| `kb_search` | Search by query, category, project |
| `kb_read` | Read full document content |
| `kb_list` | List documents with filters |
| `kb_recent` | Recently modified documents |

### Document Frontmatter

All documents require YAML frontmatter:

```yaml
---
title: "Document Title"
created: 2025-01-11
created_by: your.email@company.com
category: guide  # guide, runbook, decision, api-doc, project, meeting-note
status: draft    # draft, review, published, deprecated
tags: [tag1, tag2]
---
```

## Troubleshooting

| Issue | Solution |
|-------|----------|
| MeiliSearch not responding | `docker restart meilisearch` |
| File watcher not running | `sudo systemctl restart kb-watcher` |
| Search returns no results | `kb reindex` |
| Gitea OAuth not working | Verify redirect URI matches domain |
