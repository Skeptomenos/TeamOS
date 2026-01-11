# TeamOS Terraform Deployment

One-click infrastructure deployment for TeamOS.

## Prerequisites

1. [Terraform](https://terraform.io) >= 1.0
2. [gcloud CLI](https://cloud.google.com/sdk) authenticated
3. GCP project with billing enabled

## Quick Start

### Step 1: Create Google OAuth Credentials

Before deploying, create OAuth credentials in GCP Console:

1. Go to: https://console.cloud.google.com/apis/credentials?project=it-services-automations

2. Click **"+ CREATE CREDENTIALS"** → **"OAuth client ID"**

3. If prompted for consent screen:
   - User Type: **Internal** (Workspace users only)
   - App name: **TeamOS**
   - Support email: Your email

4. Create OAuth Client:
   - Application type: **Web application**
   - Name: **TeamOS**
   - Authorized redirect URI: `https://auth.PLACEHOLDER.nip.io/oauth2/callback`
   
   > Note: You'll update this URI after deployment with the actual IP

5. Save the **Client ID** and **Client Secret**

### Step 2: Configure and Deploy

```bash
cd terraform

cp terraform.tfvars.example terraform.tfvars

# Edit terraform.tfvars with your values:
# - google_oauth_client_id
# - google_oauth_client_secret  
# - allowed_domain (your Google Workspace domain)
# - team_group_email

terraform init
terraform apply
```

### Step 3: Update OAuth Redirect URI

After deployment, Terraform outputs the correct redirect URI:

```bash
terraform output oauth_redirect_uri
# Example: https://auth.34-22-146-168.nip.io/oauth2/callback
```

Go back to GCP Console and update the OAuth client's redirect URI with this value.

### Step 4: Access TeamOS

```bash
terraform output assistant_url
# Open this URL in your browser and login with Google
```

## What Gets Created

| Resource | Description |
|----------|-------------|
| VPC Network | `teamos-vpc` with auto subnets |
| Firewall Rules | SSH (22), HTTP/HTTPS (80, 443), Gitea (3000, 2222) |
| Data Disk | 200GB SSD at `/data` |
| VM Instance | Ubuntu 24.04, e2-standard-4 |
| Service Accounts | OpenCode (Vertex AI), Fluent-bit (Logging) |
| Log Bucket | 180-day retention |
| OS Login IAM | Team group SSH access |

## What Gets Installed Automatically

| Component | Purpose |
|-----------|---------|
| **Docker Services** | |
| MeiliSearch | Full-text keyword search |
| Qdrant | Vector database for semantic search |
| Gitea | Git hosting with Google OAuth |
| Pomerium | Zero-trust proxy with Google SSO |
| **System Services** | |
| OpenCode Server | AI assistant backend |
| kb-watcher | Real-time file indexing |
| auditd + fluent-bit | Audit logging to GCP |
| **Knowledge Base Tools** | |
| `kb` CLI | Search/read/list knowledge base |
| Hybrid indexer | MeiliSearch + Qdrant dual indexing |
| MCP Server | AI agent access with hybrid search |

## Outputs

After deployment, these outputs are available:

| Output | Description |
|--------|-------------|
| `assistant_url` | AI assistant URL (via Pomerium) |
| `gitea_url` | Git hosting URL (via Pomerium) |
| `auth_url` | Pomerium authentication URL |
| `oauth_redirect_uri` | Use this in GCP OAuth settings |
| `ssh_command` | Command to SSH into server |
| `vm_external_ip` | Server's public IP |

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              Internet                                        │
└─────────────────────────────────┬───────────────────────────────────────────┘
                                  │
                                  ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                         Pomerium (ports 80, 443)                            │
│                         Google OAuth + Zero Trust                           │
└─────────────────────────────────┬───────────────────────────────────────────┘
                                  │
          ┌───────────────────────┼───────────────────────┐
          ▼                       ▼                       ▼
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│ OpenCode Server │     │     Gitea       │     │   (Future)      │
│   :4096         │     │     :3000       │     │                 │
└────────┬────────┘     └─────────────────┘     └─────────────────┘
         │
         ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                           MCP Tools                                          │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐        │
│  │ Knowledge   │  │ MeiliSearch │  │   Qdrant    │  │   (Future)  │        │
│  │    Base     │  │   :7700     │  │   :6333     │  │             │        │
│  └─────────────┘  └─────────────┘  └─────────────┘  └─────────────┘        │
└─────────────────────────────────────────────────────────────────────────────┘
```

## SSH Access

```bash
# Using gcloud
gcloud compute ssh teamos-server --zone=europe-west1-b --project=it-services-automations

# Or add alias to ~/.zshrc
alias teamos="gcloud compute ssh teamos-server --zone=europe-west1-b --project=it-services-automations"
```

## Knowledge Base Usage

### CLI Commands

```bash
kb search "authentication API"   # Hybrid search (keyword + semantic)
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
| `kb_search` | Hybrid search (keyword + semantic) |
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
category: guide  # guide, runbook, decision, api-doc
status: draft    # draft, review, published, deprecated
tags: [tag1, tag2]
---
```

## Service Management

```bash
# Check all services
docker ps
systemctl status kb-watcher opencode-server

# Restart services
docker compose -f /opt/teamos/docker-compose.yml restart
sudo systemctl restart kb-watcher opencode-server

# View logs
docker logs -f pomerium
docker logs -f meilisearch
docker logs -f qdrant
journalctl -u opencode-server -f
journalctl -u kb-watcher -f
```

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Can't access assistant URL | Check Pomerium logs: `docker logs pomerium` |
| OAuth redirect error | Verify redirect URI matches in GCP Console |
| Search returns no results | Run `kb reindex` |
| MeiliSearch not responding | `docker restart meilisearch` |
| Qdrant not responding | `docker restart qdrant` |
| File watcher not running | `sudo systemctl restart kb-watcher` |

## Upgrading

```bash
# SSH to server
gcloud compute ssh teamos-server --zone=europe-west1-b

# Pull latest images
cd /opt/teamos && docker compose pull

# Restart services
docker compose up -d

# Update Python dependencies
/opt/teamos/venv/bin/pip install --upgrade meilisearch qdrant-client google-cloud-aiplatform
```

## Destroying

```bash
# WARNING: This will delete all data!
terraform destroy
```

To preserve data, create a snapshot first:
```bash
gcloud compute disks snapshot teamos-data --zone=europe-west1-b --snapshot-names=teamos-backup-$(date +%Y%m%d)
```
