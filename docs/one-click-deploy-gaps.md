# One-Click Deploy Gap Analysis

**Date:** 2025-01-11  
**Goal:** True one-click deployment with minimal post-deploy configuration

---

## Current State

### Fully Automated ✅

| Component | Location | Notes |
|-----------|----------|-------|
| VPC + Firewall (SSH, Gitea) | `main.tf` | Ports 22, 3000, 2222 |
| VM + Data Disk | `main.tf` | e2-standard-4, 200GB SSD |
| Service Accounts | `main.tf` | OpenCode (Vertex AI), Fluent-bit (Logging) |
| Docker Engine | `startup.sh` | Data root on /data |
| MeiliSearch | `startup.sh` | Port 7700, localhost only |
| Gitea | `startup.sh` | Port 3000, admin user created |
| auditd + fluent-bit | `startup.sh` | Logs to GCP Cloud Logging |
| KB CLI (`kb`) | `startup.sh` | search, read, list, recent |
| KB Indexer | `startup.sh` | MeiliSearch indexing |
| KB File Watcher | `startup.sh` | systemd service |
| KB MCP Server | `startup.sh` | AI agent access |
| Session Recording | `startup.sh` | SSH sessions logged |
| Health Checks | `startup.sh` | Cron job every 5 min |

### Requires Manual Steps ❌

| Component | Current State | Gap |
|-----------|---------------|-----|
| **Gitea OAuth** | Manual CLI command | Could auto-configure if secrets provided |
| **Knowledge Base repo** | Manual creation | Can auto-create in startup.sh |
| **Qdrant** | Not deployed | Missing from docker-compose |
| **Hybrid Indexer** | Not created | Missing Python script |
| **Vertex AI SDK** | Not installed | Missing pip install |
| **Pomerium** | Not deployed | Missing from docker-compose |
| **Pomerium Config** | Not created | Missing config file |
| **OpenCode Server** | Not deployed | Missing systemd service |
| **Firewall (80, 443)** | Not open | Missing Terraform rules |

### Must Remain Manual (Secrets)

| Secret | Reason | Mitigation |
|--------|--------|------------|
| Google OAuth Client ID | Created in GCP Console UI | Document steps, provide post-deploy script |
| Google OAuth Client Secret | Created in GCP Console UI | Same as above |
| MeiliSearch Master Key | Security | Auto-generate on first boot |
| Pomerium Shared Secret | Security | Auto-generate on first boot |
| Pomerium Cookie Secret | Security | Auto-generate on first boot |

---

## Target State

### One-Click Deployment Flow

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                                                                             │
│   BEFORE DEPLOY (One-time setup)                                           │
│                                                                             │
│   1. Create Google OAuth credentials in GCP Console                        │
│   2. Copy terraform.tfvars.example → terraform.tfvars                      │
│   3. Fill in: project_id, oauth_client_id, oauth_client_secret            │
│                                                                             │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│   DEPLOY (One command)                                                      │
│                                                                             │
│   $ terraform apply                                                         │
│                                                                             │
│   Creates:                                                                  │
│   • VPC, Firewall, VM, Disk                                                │
│   • All services auto-start                                                │
│   • Secrets auto-generated                                                 │
│   • OAuth auto-configured                                                  │
│                                                                             │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│   AFTER DEPLOY (Zero steps for basic usage)                                │
│                                                                             │
│   Outputs:                                                                  │
│   • assistant_url = https://assistant.34-22-146-168.nip.io                 │
│   • gitea_url = https://git.34-22-146-168.nip.io                          │
│   • ssh_command = gcloud compute ssh teamos-server ...                     │
│                                                                             │
│   Just open the URL and login with Google!                                 │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Implementation Plan

### Phase 1: Secrets Management

**File: `variables.tf`**

Add variables for secrets that can be passed via tfvars or environment:

```hcl
variable "google_oauth_client_id" {
  description = "Google OAuth Client ID for Pomerium and Gitea"
  type        = string
  sensitive   = true
}

variable "google_oauth_client_secret" {
  description = "Google OAuth Client Secret"
  type        = string
  sensitive   = true
}

variable "allowed_domain" {
  description = "Google Workspace domain allowed to access (e.g., company.com)"
  type        = string
}

variable "meili_master_key" {
  description = "MeiliSearch master key (auto-generated if empty)"
  type        = string
  default     = ""
  sensitive   = true
}
```

**File: `main.tf`**

Pass secrets to startup script via instance metadata:

```hcl
metadata = {
  enable-oslogin           = "TRUE"
  google-oauth-client-id   = var.google_oauth_client_id
  google-oauth-secret      = var.google_oauth_client_secret
  allowed-domain           = var.allowed_domain
  meili-master-key         = var.meili_master_key != "" ? var.meili_master_key : random_password.meili_key.result
}
```

### Phase 2: Startup Script Updates

**Add to `startup.sh`:**

1. **Read secrets from metadata:**
```bash
GOOGLE_CLIENT_ID=$(curl -s -H "Metadata-Flavor: Google" \
  http://metadata.google.internal/computeMetadata/v1/instance/attributes/google-oauth-client-id)
GOOGLE_CLIENT_SECRET=$(curl -s -H "Metadata-Flavor: Google" \
  http://metadata.google.internal/computeMetadata/v1/instance/attributes/google-oauth-secret)
ALLOWED_DOMAIN=$(curl -s -H "Metadata-Flavor: Google" \
  http://metadata.google.internal/computeMetadata/v1/instance/attributes/allowed-domain)
```

2. **Add Qdrant to docker-compose**
3. **Add Pomerium to docker-compose**
4. **Create Pomerium config with secrets**
5. **Add OpenCode Server systemd service**
6. **Install Vertex AI SDK**
7. **Create hybrid indexer**
8. **Auto-configure Gitea OAuth**
9. **Auto-create knowledge-base repo**

### Phase 3: Terraform Updates

**File: `main.tf`**

Add firewall rules for Pomerium:

```hcl
resource "google_compute_firewall" "allow_https" {
  name    = "teamos-allow-https"
  network = google_compute_network.teamos_vpc.name

  allow {
    protocol = "tcp"
    ports    = ["80", "443"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["teamos-server"]
  description   = "Allow HTTP/HTTPS for Pomerium"
}
```

**File: `outputs.tf`**

Add useful outputs:

```hcl
output "assistant_url" {
  description = "URL to access the AI assistant"
  value       = "https://assistant.${replace(google_compute_instance.teamos_server.network_interface[0].access_config[0].nat_ip, ".", "-")}.nip.io"
}

output "auth_url" {
  description = "Pomerium auth URL"
  value       = "https://auth.${replace(google_compute_instance.teamos_server.network_interface[0].access_config[0].nat_ip, ".", "-")}.nip.io"
}
```

---

## New terraform.tfvars.example

```hcl
# =============================================================================
# REQUIRED - Must be set before deployment
# =============================================================================

project_id = "it-services-automations"

# Google OAuth credentials (create at console.cloud.google.com/apis/credentials)
# Redirect URI: https://auth.<IP-with-dashes>.nip.io/oauth2/callback
google_oauth_client_id     = ""  # REQUIRED
google_oauth_client_secret = ""  # REQUIRED

# Your Google Workspace domain (users must have @this-domain.com email)
allowed_domain = "yourcompany.com"  # REQUIRED

# Google Workspace group for SSH access
team_group_email = "it-team@yourcompany.com"  # REQUIRED

# =============================================================================
# OPTIONAL - Sensible defaults provided
# =============================================================================

region         = "europe-west1"
zone           = "europe-west1-b"
machine_type   = "e2-standard-4"
data_disk_size = 200

# Leave empty to auto-generate secure keys
meili_master_key = ""
```

---

## Post-Implementation Verification

### Automated Tests (in startup.sh)

```bash
# Wait for services
sleep 30

# Test MeiliSearch
curl -s http://localhost:7700/health | grep -q "available" || echo "FAIL: MeiliSearch"

# Test Qdrant
curl -s http://localhost:6333/collections | grep -q "collections" || echo "FAIL: Qdrant"

# Test Gitea
curl -s http://localhost:3000/api/v1/version | grep -q "version" || echo "FAIL: Gitea"

# Test Pomerium
curl -sk https://localhost/.pomerium/ping | grep -q "OK" || echo "FAIL: Pomerium"

# Test OpenCode Server
curl -s http://localhost:4096/health | grep -q "ok" || echo "FAIL: OpenCode"

echo "All services verified"
```

---

## Migration Path for Existing Deployment

If TeamOS is already deployed:

```bash
# SSH to server
gcloud compute ssh teamos-server --zone=europe-west1-b

# Pull latest startup script changes
# (Or run specific sections manually)

# Add Qdrant
docker compose -f /opt/teamos/docker-compose.yml up -d qdrant

# Install new Python deps
/opt/teamos/venv/bin/pip install qdrant-client google-cloud-aiplatform

# Update scripts
# (Copy new versions of hybrid_indexer.py, kb-watcher.py, kb-mcp-server.py)

# Reindex with vectors
/opt/teamos/venv/bin/python3 /opt/teamos/bin/hybrid_indexer.py --full

# Add Pomerium (requires OAuth secrets)
# ...
```

---

## Success Criteria

| Criteria | Measurement |
|----------|-------------|
| Deploy time | < 10 minutes from `terraform apply` |
| Manual steps | Only OAuth credential creation (unavoidable) |
| First login | Works immediately after deploy |
| All services | Health checks pass |
| Search works | `kb search` returns results |
| AI access | MCP server responds |

---

## Files to Modify

| File | Changes |
|------|---------|
| `terraform/variables.tf` | Add OAuth, domain, secret variables |
| `terraform/main.tf` | Add firewall rules, metadata, random secrets |
| `terraform/outputs.tf` | Add nip.io URLs |
| `terraform/terraform.tfvars.example` | Add new required variables |
| `terraform/scripts/startup.sh` | Major updates (see Phase 2) |
| `terraform/README.md` | Simplify post-deploy steps |

---

## Timeline

| Task | Estimate |
|------|----------|
| Terraform updates | 30 min |
| startup.sh updates | 2-3 hours |
| Testing | 1 hour |
| Documentation | 30 min |
| **Total** | **~4 hours** |
