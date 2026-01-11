# VM Setup Guide: Technical Breakdown

**Version:** 1.0  
**Date:** 2025-01-10  
**Status:** Implementation Guide  
**Author:** IT Architecture Team

---

## Overview

This document breaks down every technical component needed on the TeamOS VM. Each section covers what needs to be installed, configured, and why. Use this as a step-by-step implementation checklist.

---

## Table of Contents

1. [Infrastructure: GCP VM Provisioning](#1-infrastructure-gcp-vm-provisioning)
2. [Operating System: Base Configuration](#2-operating-system-base-configuration)
3. [User Management: Linux Users & Groups](#3-user-management-linux-users--groups)
4. [SSH Access: Authentication & Security](#4-ssh-access-authentication--security)
5. [Storage: Disk Layout & Permissions](#5-storage-disk-layout--permissions)
6. [Git: Version Control Setup](#6-git-version-control-setup)
7. [Docker: Container Runtime](#7-docker-container-runtime)
8. [MeiliSearch: Search Engine](#8-meilisearch-search-engine)
9. [Knowledge Base: File Structure & Hooks](#9-knowledge-base-file-structure--hooks)
10. [OpenCode & CLI Tools: AI Agent Environment](#10-opencode--cli-tools-ai-agent-environment)
11. [Audit System: auditd Configuration](#11-audit-system-auditd-configuration)
12. [Logging: fluent-bit & GCP Cloud Logging](#12-logging-fluent-bit--gcp-cloud-logging)
13. [Monitoring: Health Checks & Alerts](#13-monitoring-health-checks--alerts)
14. [Backup: Snapshots & Recovery](#14-backup-snapshots--recovery)
15. [Cron Jobs: Scheduled Tasks](#15-cron-jobs-scheduled-tasks)
16. [Firewall: Network Security](#16-firewall-network-security)
17. [Environment Variables: Configuration Management](#17-environment-variables-configuration-management)

---

## 1. Infrastructure: GCP VM Provisioning

### What We Need
A Compute Engine VM in Google Cloud Platform that serves as the central server for all team members.

### Specifications

| Component | Specification | Rationale |
|-----------|---------------|-----------|
| **Machine Type** | e2-standard-4 | 4 vCPU, 16 GB RAM - sufficient for 10 users + MeiliSearch |
| **Region** | europe-west3 (Frankfurt) | GDPR compliance, low latency for EU team |
| **Zone** | europe-west3-a | Single zone is fine for non-critical workload |
| **Boot Disk** | 50 GB SSD | OS, packages, Docker images |
| **Data Disk** | 200 GB SSD | User homes, Knowledge Base, MeiliSearch data |
| **OS Image** | Ubuntu 24.04 LTS | Long-term support, wide compatibility |
| **Network** | VPC with private IP | No public IP, access via IAP or VPN |

### Terraform Resources Needed

```
google_compute_network        - VPC network
google_compute_subnetwork     - Subnet (10.0.0.0/24)
google_compute_firewall       - SSH rules
google_compute_disk           - Data disk (200 GB)
google_compute_instance       - The VM itself
google_service_account        - VM service account
```

### Configuration Details

**Service Account Permissions:**
- `roles/logging.logWriter` - Write logs to Cloud Logging
- `roles/monitoring.metricWriter` - Write metrics to Cloud Monitoring
- `roles/compute.viewer` - Read compute metadata

**Metadata:**
- `enable-oslogin = TRUE` - Optional: Use GCP IAM for SSH (alternative to manual SSH keys)

**Labels:**
```
environment = "production"
team = "it-operations"
project = "teamos"
```

### Files to Create
- `terraform/main.tf` - Main infrastructure
- `terraform/variables.tf` - Variable definitions
- `terraform/outputs.tf` - Output values (IP, instance name)
- `terraform/terraform.tfvars` - Variable values (gitignored)

---

## 2. Operating System: Base Configuration

### What We Need
A properly configured Ubuntu 24.04 LTS system with all necessary packages and security hardening.

### System Packages to Install

**Essential:**
```bash
apt-get install -y \
    git \
    curl \
    wget \
    vim \
    htop \
    tmux \
    jq \
    unzip \
    ca-certificates \
    gnupg \
    lsb-release \
    software-properties-common
```

**Python (for scripts and indexer):**
```bash
apt-get install -y \
    python3 \
    python3-pip \
    python3-venv
```

**Build tools (for some pip packages):**
```bash
apt-get install -y \
    build-essential \
    python3-dev
```

**Audit and logging:**
```bash
apt-get install -y \
    auditd \
    audispd-plugins
```

### System Configuration

**Timezone:**
```bash
timedatectl set-timezone Europe/Berlin
```

**Locale:**
```bash
locale-gen en_US.UTF-8
update-locale LANG=en_US.UTF-8
```

**Hostname:**
```bash
hostnamectl set-hostname teamos-server
```

**Automatic security updates:**
```bash
apt-get install -y unattended-upgrades
dpkg-reconfigure -plow unattended-upgrades
```

### Kernel Parameters

**File: `/etc/sysctl.d/99-teamos.conf`**
```
# Increase inotify watchers for file watching
fs.inotify.max_user_watches = 524288

# Network security
net.ipv4.tcp_syncookies = 1
net.ipv4.conf.all.rp_filter = 1
```

Apply with: `sysctl --system`

### Files to Create
- `/etc/sysctl.d/99-teamos.conf` - Kernel parameters
- `/etc/profile.d/teamos.sh` - Global environment variables

---

## 3. User Management: Linux Users & Groups

### What We Need
Individual Linux user accounts for each team member with appropriate group memberships.

### Groups to Create

| Group | GID | Purpose |
|-------|-----|---------|
| `teamos` | 2000 | All team members |
| `knowledge-admin` | 2001 | Can modify Knowledge Base structure |
| `docker` | (exists) | Can run Docker commands |

```bash
groupadd -g 2000 teamos
groupadd -g 2001 knowledge-admin
```

### User Creation Template

For each user:
```bash
# Create user
useradd -m -s /bin/bash -G teamos,docker USERNAME

# Set up home directory structure
mkdir -p /home/USERNAME/.ssh
mkdir -p /home/USERNAME/.config
mkdir -p /home/USERNAME/workspace

# Set ownership
chown -R USERNAME:USERNAME /home/USERNAME
```

### User List (Initial)

| Username | Email | Groups | Role |
|----------|-------|--------|------|
| admin | admin@company.com | teamos, docker, sudo, knowledge-admin | Admin |
| anna | anna@company.com | teamos, docker, knowledge-admin | Admin |
| max | max@company.com | teamos, docker | Member |
| ... | ... | ... | ... |

### User Environment

**File: `/home/USERNAME/.bashrc.d/teamos.sh`** (sourced from .bashrc)
```bash
# TeamOS Environment
export USER_EMAIL="USERNAME@company.com"
export KNOWLEDGE_DIR="/shared/knowledge"
export MEILI_URL="http://localhost:7700"

# Aliases
alias kb='kb-cli'
alias kbs='kb-cli search'

# PATH additions
export PATH="$PATH:/opt/teamos/bin"
```

**File: `/home/USERNAME/.bashrc`** (append)
```bash
# Source TeamOS configuration
if [ -d ~/.bashrc.d ]; then
    for f in ~/.bashrc.d/*.sh; do
        [ -r "$f" ] && source "$f"
    done
fi
```

### Sudo Configuration

**File: `/etc/sudoers.d/teamos-admins`**
```
# TeamOS Admins
admin ALL=(ALL) NOPASSWD: ALL
anna ALL=(ALL) NOPASSWD: ALL

# Logging
Defaults log_output
Defaults logfile="/var/log/sudo.log"
```

### Scripts to Create
- `/opt/teamos/bin/create-user.sh` - Automated user creation
- `/opt/teamos/bin/delete-user.sh` - User removal with cleanup
- `/opt/teamos/bin/list-users.sh` - List all TeamOS users

---

## 4. SSH Access: Authentication & Security

### What We Need
Secure SSH access using key-based authentication only. No password authentication.

### SSH Server Configuration

**File: `/etc/ssh/sshd_config.d/teamos.conf`**
```
# Authentication
PasswordAuthentication no
PubkeyAuthentication yes
PermitRootLogin no
AuthorizedKeysFile .ssh/authorized_keys

# Security
MaxAuthTries 3
LoginGraceTime 30
ClientAliveInterval 300
ClientAliveCountMax 2

# Logging
LogLevel VERBOSE

# Allow only teamos group
AllowGroups teamos

# Disable unused features
X11Forwarding no
AllowTcpForwarding yes
AllowAgentForwarding yes
```

Restart SSH: `systemctl restart sshd`

### SSH Key Management

**For each user, add their public key:**
```bash
# Add to /home/USERNAME/.ssh/authorized_keys
echo "ssh-ed25519 AAAA... user@laptop" >> /home/USERNAME/.ssh/authorized_keys

# Set permissions
chmod 700 /home/USERNAME/.ssh
chmod 600 /home/USERNAME/.ssh/authorized_keys
chown -R USERNAME:USERNAME /home/USERNAME/.ssh
```

### SSH Key Requirements
- Algorithm: Ed25519 (preferred) or RSA 4096-bit
- Passphrase: Required (enforced by policy, not technically)
- Rotation: Annually or on suspected compromise

### Client SSH Config Template

**For users to add to their `~/.ssh/config`:**
```
Host teamos
    HostName <VM_PRIVATE_IP>
    User <USERNAME>
    IdentityFile ~/.ssh/id_ed25519
    ForwardAgent yes
    ServerAliveInterval 60
    ServerAliveCountMax 3
```

### Alternative: GCP OS Login

If using GCP OS Login instead of manual SSH keys:
```bash
# On VM
gcloud compute os-login ssh-keys add --key-file=/path/to/key.pub

# Users authenticate via:
gcloud compute ssh teamos-server --zone=europe-west3-a
```

Pros: Centralized key management via GCP IAM
Cons: Requires gcloud CLI on client, more complex

### Files to Create
- `/etc/ssh/sshd_config.d/teamos.conf` - SSH hardening
- `/opt/teamos/bin/add-ssh-key.sh` - Add SSH key for user

---

## 5. Storage: Disk Layout & Permissions

### What We Need
Properly mounted data disk with correct directory structure and permissions.

### Disk Layout

```
/                           # Boot Disk (50 GB)
├── /opt/teamos/            # TeamOS scripts and binaries
├── /var/log/               # System logs
└── /etc/                   # Configuration

/data/                      # Data Disk (200 GB) - mounted separately
├── home/                   # User home directories (symlinked from /home)
├── shared/                 # Shared resources
│   └── knowledge/          # Knowledge Base (Git repo)
└── docker/                 # Docker volumes
    └── meilisearch/        # MeiliSearch data
```

### Mount Data Disk

**1. Format disk (first time only):**
```bash
# Find the disk
lsblk

# Format as ext4
mkfs.ext4 -L teamos-data /dev/sdb

# Create mount point
mkdir -p /data
```

**2. Add to fstab:**

**File: `/etc/fstab`** (append)
```
LABEL=teamos-data  /data  ext4  defaults,nofail  0  2
```

**3. Mount:**
```bash
mount -a
```

### Directory Structure Creation

```bash
# Create directories
mkdir -p /data/home
mkdir -p /data/shared/knowledge
mkdir -p /data/docker/meilisearch

# Symlinks
ln -sf /data/home /home
ln -sf /data/shared /shared

# Permissions for shared knowledge
chown root:teamos /data/shared/knowledge
chmod 2775 /data/shared/knowledge  # SGID bit

# Set default ACL so new files inherit group permissions
setfacl -R -m g:teamos:rwx /data/shared/knowledge
setfacl -R -d -m g:teamos:rwx /data/shared/knowledge
```

### Permission Matrix

| Path | Owner | Group | Mode | Notes |
|------|-------|-------|------|-------|
| `/data` | root | root | 755 | Mount point |
| `/data/home` | root | root | 755 | Contains user homes |
| `/data/home/USERNAME` | USERNAME | USERNAME | 750 | Private |
| `/data/shared` | root | teamos | 755 | Shared parent |
| `/data/shared/knowledge` | root | teamos | 2775 | SGID for group inheritance |
| `/data/docker` | root | docker | 755 | Docker volumes |

### Disk Monitoring

Add to monitoring:
- Disk usage alerts at 80% and 90%
- Inode usage alerts

---

## 6. Git: Version Control Setup

### What We Need
Git configured on the server with the Knowledge Base repository cloned and ready.

### Git Installation
```bash
apt-get install -y git
```

### Global Git Configuration

**File: `/etc/gitconfig`**
```ini
[init]
    defaultBranch = main

[core]
    autocrlf = input
    filemode = true

[pull]
    rebase = true

[push]
    default = current
```

### Knowledge Base Repository Setup

**1. Create deploy key for server:**
```bash
# Generate key (no passphrase for automated operations)
ssh-keygen -t ed25519 -f /root/.ssh/github_deploy_key -N ""

# Add to GitHub repo as deploy key (read/write access)
cat /root/.ssh/github_deploy_key.pub
```

**2. Configure SSH for GitHub:**

**File: `/root/.ssh/config`**
```
Host github.com
    HostName github.com
    User git
    IdentityFile /root/.ssh/github_deploy_key
    IdentitiesOnly yes
```

**3. Clone repository:**
```bash
cd /data/shared
git clone git@github.com:company/knowledge-base.git knowledge
chown -R root:teamos knowledge
chmod -R 2775 knowledge
```

**4. Set up auto-pull cron:**
```bash
# /etc/cron.d/knowledge-sync
*/5 * * * * root cd /data/shared/knowledge && git pull --rebase >> /var/log/knowledge-sync.log 2>&1
```

### Git Hooks

**Pre-commit hook for frontmatter validation:**

**File: `/data/shared/knowledge/.git/hooks/pre-commit`**
```bash
#!/bin/bash
# Validate frontmatter in all staged .md files

for file in $(git diff --cached --name-only --diff-filter=ACM | grep '\.md$'); do
    # Check frontmatter exists
    if ! head -1 "$file" | grep -q '^---$'; then
        echo "ERROR: $file is missing frontmatter"
        exit 1
    fi
    
    # Check required fields
    for field in title created created_by; do
        if ! grep -q "^$field:" "$file"; then
            echo "ERROR: $file is missing required field: $field"
            exit 1
        fi
    done
    
    # Auto-update 'updated' fields
    sed -i "s/^updated:.*/updated: $(date +%Y-%m-%d)/" "$file"
    sed -i "s/^updated_by:.*/updated_by: ${GIT_AUTHOR_EMAIL:-unknown}/" "$file"
    git add "$file"
done

exit 0
```

```bash
chmod +x /data/shared/knowledge/.git/hooks/pre-commit
```

### Files to Create
- `/root/.ssh/github_deploy_key` - Deploy key
- `/root/.ssh/config` - SSH config for GitHub
- `/data/shared/knowledge/.git/hooks/pre-commit` - Validation hook
- `/etc/cron.d/knowledge-sync` - Auto-pull cron

---

## 7. Docker: Container Runtime

### What We Need
Docker installed and configured for running MeiliSearch and potentially other services.

### Docker Installation

```bash
# Add Docker's official GPG key
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg

# Add repository
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install
apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
```

### Docker Configuration

**File: `/etc/docker/daemon.json`**
```json
{
    "log-driver": "json-file",
    "log-opts": {
        "max-size": "10m",
        "max-file": "3"
    },
    "storage-driver": "overlay2",
    "data-root": "/data/docker"
}
```

Restart Docker:
```bash
systemctl restart docker
```

### Docker Compose Setup

**File: `/opt/teamos/docker-compose.yml`**
```yaml
version: '3.8'

services:
  meilisearch:
    image: getmeili/meilisearch:v1.6
    container_name: meilisearch
    ports:
      - "127.0.0.1:7700:7700"
    volumes:
      - /data/docker/meilisearch:/meili_data
    environment:
      - MEILI_MASTER_KEY=${MEILI_MASTER_KEY}
      - MEILI_NO_ANALYTICS=true
      - MEILI_ENV=production
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:7700/health"]
      interval: 30s
      timeout: 10s
      retries: 3

networks:
  default:
    name: teamos
```

### Docker Management Commands

```bash
# Start services
cd /opt/teamos && docker compose up -d

# View logs
docker compose logs -f meilisearch

# Restart
docker compose restart meilisearch

# Update image
docker compose pull && docker compose up -d
```

### Files to Create
- `/etc/docker/daemon.json` - Docker configuration
- `/opt/teamos/docker-compose.yml` - Service definitions
- `/opt/teamos/.env` - Environment variables (gitignored)

---

## 8. MeiliSearch: Search Engine

### What We Need
MeiliSearch running as a Docker container, configured for the Knowledge Base.

### Container Configuration
(Defined in docker-compose.yml above)

### Environment Variables

**File: `/opt/teamos/.env`**
```bash
MEILI_MASTER_KEY=your-secure-master-key-here-min-16-chars
```

Generate key:
```bash
openssl rand -base64 32
```

### Index Configuration

After MeiliSearch starts, configure the index:

```bash
# Create index
curl -X POST 'http://localhost:7700/indexes' \
  -H 'Authorization: Bearer YOUR_MASTER_KEY' \
  -H 'Content-Type: application/json' \
  -d '{"uid": "knowledge", "primaryKey": "id"}'

# Configure searchable attributes
curl -X PATCH 'http://localhost:7700/indexes/knowledge/settings' \
  -H 'Authorization: Bearer YOUR_MASTER_KEY' \
  -H 'Content-Type: application/json' \
  -d '{
    "searchableAttributes": ["title", "content", "tags", "category"],
    "filterableAttributes": ["tags", "category", "status", "created_by", "created"],
    "sortableAttributes": ["created", "updated", "title"],
    "rankingRules": ["words", "typo", "proximity", "attribute", "sort", "exactness"]
  }'
```

### Indexer Script

**File: `/opt/teamos/bin/kb-indexer.py`**
```python
#!/usr/bin/env python3
"""
Knowledge Base Indexer
Indexes all Markdown files into MeiliSearch
"""

import meilisearch
import frontmatter
from pathlib import Path
import hashlib
import os
from datetime import datetime

MEILI_URL = os.getenv('MEILI_URL', 'http://localhost:7700')
MEILI_KEY = os.getenv('MEILI_MASTER_KEY')
KNOWLEDGE_DIR = os.getenv('KNOWLEDGE_DIR', '/data/shared/knowledge')

def get_client():
    return meilisearch.Client(MEILI_URL, MEILI_KEY)

def index_file(filepath: Path) -> dict:
    """Index a single file"""
    post = frontmatter.load(filepath)
    relative_path = filepath.relative_to(KNOWLEDGE_DIR)
    doc_id = hashlib.md5(str(relative_path).encode()).hexdigest()
    
    return {
        'id': doc_id,
        'path': str(relative_path),
        'title': post.get('title', filepath.stem),
        'content': post.content,
        'tags': post.get('tags', []),
        'category': post.get('category', 'uncategorized'),
        'status': post.get('status', 'draft'),
        'created': str(post.get('created', '')),
        'created_by': post.get('created_by', 'unknown'),
        'updated': str(post.get('updated', '')),
        'updated_by': post.get('updated_by', 'unknown'),
        'indexed_at': datetime.now().isoformat()
    }

def full_reindex():
    """Reindex all documents"""
    client = get_client()
    index = client.index('knowledge')
    
    docs = []
    for md_file in Path(KNOWLEDGE_DIR).rglob('*.md'):
        if '.git' in str(md_file):
            continue
        try:
            docs.append(index_file(md_file))
        except Exception as e:
            print(f"ERROR indexing {md_file}: {e}")
    
    if docs:
        index.add_documents(docs)
        print(f"Indexed {len(docs)} documents")

def incremental_index(filepath: str):
    """Index a single file"""
    client = get_client()
    index = client.index('knowledge')
    doc = index_file(Path(filepath))
    index.add_documents([doc])
    print(f"Indexed: {filepath}")

if __name__ == '__main__':
    import sys
    if len(sys.argv) > 1 and sys.argv[1] == '--file':
        incremental_index(sys.argv[2])
    else:
        full_reindex()
```

### File Watcher

**File: `/opt/teamos/bin/kb-watcher.py`**
```python
#!/usr/bin/env python3
"""
Watches Knowledge Base for changes and triggers indexing
"""

from watchdog.observers import Observer
from watchdog.events import FileSystemEventHandler
import subprocess
import time
import os

KNOWLEDGE_DIR = os.getenv('KNOWLEDGE_DIR', '/data/shared/knowledge')

class MarkdownHandler(FileSystemEventHandler):
    def on_modified(self, event):
        if event.src_path.endswith('.md') and '.git' not in event.src_path:
            print(f"Modified: {event.src_path}")
            subprocess.run(['/opt/teamos/bin/kb-indexer.py', '--file', event.src_path])
    
    def on_created(self, event):
        if event.src_path.endswith('.md') and '.git' not in event.src_path:
            print(f"Created: {event.src_path}")
            subprocess.run(['/opt/teamos/bin/kb-indexer.py', '--file', event.src_path])

if __name__ == '__main__':
    observer = Observer()
    observer.schedule(MarkdownHandler(), KNOWLEDGE_DIR, recursive=True)
    observer.start()
    print(f"Watching {KNOWLEDGE_DIR} for changes...")
    
    try:
        while True:
            time.sleep(1)
    except KeyboardInterrupt:
        observer.stop()
    observer.join()
```

### Systemd Service for Watcher

**File: `/etc/systemd/system/kb-watcher.service`**
```ini
[Unit]
Description=Knowledge Base File Watcher
After=docker.service
Requires=docker.service

[Service]
Type=simple
User=root
Environment=KNOWLEDGE_DIR=/data/shared/knowledge
Environment=MEILI_URL=http://localhost:7700
EnvironmentFile=/opt/teamos/.env
ExecStart=/opt/teamos/venv/bin/python /opt/teamos/bin/kb-watcher.py
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
```

```bash
systemctl daemon-reload
systemctl enable kb-watcher
systemctl start kb-watcher
```

### Python Virtual Environment

```bash
python3 -m venv /opt/teamos/venv
/opt/teamos/venv/bin/pip install meilisearch python-frontmatter watchdog
```

### Files to Create
- `/opt/teamos/.env` - MeiliSearch master key
- `/opt/teamos/bin/kb-indexer.py` - Indexer script
- `/opt/teamos/bin/kb-watcher.py` - File watcher
- `/etc/systemd/system/kb-watcher.service` - Systemd service

---

## 9. Knowledge Base: File Structure & Hooks

### What We Need
A well-organized directory structure for the Knowledge Base with validation hooks.

### Directory Structure

```
/data/shared/knowledge/
├── .git/                       # Git repository
├── .github/
│   └── CODEOWNERS              # Ownership rules
├── api-docs/                   # API Documentation
│   ├── entra-id/
│   ├── google-workspace/
│   ├── atlassian/
│   └── slack/
├── runbooks/                   # Operational Runbooks
│   ├── incident-response/
│   ├── onboarding/
│   └── maintenance/
├── decisions/                  # Architecture Decision Records
├── guides/                     # How-To Guides
│   ├── developer/
│   └── admin/
├── meeting-notes/              # Meeting Notes
│   └── 2025/
└── templates/                  # Document Templates
    ├── runbook-template.md
    ├── adr-template.md
    └── meeting-template.md
```

### CODEOWNERS File

**File: `/data/shared/knowledge/.github/CODEOWNERS`**
```
# Default owners
* @admin @anna

# API Docs ownership
/api-docs/entra-id/          @admin
/api-docs/google-workspace/  @anna
/api-docs/atlassian/         @max
/api-docs/slack/             @max

# Runbooks
/runbooks/                   @admin @anna

# Decisions require review
/decisions/                  @admin @anna
```

### Document Templates

**File: `/data/shared/knowledge/templates/runbook-template.md`**
```markdown
---
title: "Runbook: [Title]"
created: YYYY-MM-DD
created_by: email@company.com
updated: YYYY-MM-DD
updated_by: email@company.com
tags:
  - runbook
  - [service]
category: runbooks
status: draft
---

# [Title]

## Overview
Brief description of what this runbook covers.

## Prerequisites
- [ ] Prerequisite 1
- [ ] Prerequisite 2

## Procedure

### Step 1: [Step Title]
Description of step.

```bash
# Commands if applicable
```

### Step 2: [Step Title]
...

## Rollback
How to undo if something goes wrong.

## Verification
How to verify the procedure was successful.

## Related Documents
- [Link to related doc](path/to/doc.md)
```

**File: `/data/shared/knowledge/templates/adr-template.md`**
```markdown
---
title: "ADR-XXX: [Title]"
created: YYYY-MM-DD
created_by: email@company.com
updated: YYYY-MM-DD
updated_by: email@company.com
tags:
  - adr
  - [topic]
category: decisions
status: proposed
---

# ADR-XXX: [Title]

## Status
Proposed | Accepted | Deprecated | Superseded

## Context
What is the issue that we're seeing that is motivating this decision?

## Decision
What is the change that we're proposing and/or doing?

## Consequences
What becomes easier or more difficult because of this change?

## Alternatives Considered
What other options were considered?
```

### File Locking Script

**File: `/opt/teamos/bin/kb-lock`**
```bash
#!/bin/bash
# Knowledge Base File Locking

KNOWLEDGE_DIR="/data/shared/knowledge"
LOCK_TIMEOUT=3600  # 1 hour

lock_file() {
    local file="$1"
    local lockfile="${file}.lock"
    local user="${USER_EMAIL:-$USER}"
    local timestamp=$(date +%s)
    
    if [ -f "$lockfile" ]; then
        local lock_info=$(cat "$lockfile")
        local lock_user=$(echo "$lock_info" | cut -d'|' -f1)
        local lock_time=$(echo "$lock_info" | cut -d'|' -f2)
        local current_time=$(date +%s)
        local age=$((current_time - lock_time))
        
        if [ $age -gt $LOCK_TIMEOUT ]; then
            echo "Stale lock removed (was held by $lock_user)"
            rm -f "$lockfile"
        else
            echo "ERROR: File locked by $lock_user (${age}s ago)"
            return 1
        fi
    fi
    
    echo "${user}|${timestamp}" > "$lockfile"
    echo "Lock acquired: $file"
    return 0
}

unlock_file() {
    local file="$1"
    local lockfile="${file}.lock"
    rm -f "$lockfile"
    echo "Lock released: $file"
}

check_lock() {
    local file="$1"
    local lockfile="${file}.lock"
    
    if [ -f "$lockfile" ]; then
        echo "Locked: $(cat "$lockfile")"
        return 1
    else
        echo "Not locked"
        return 0
    fi
}

case "$1" in
    lock)   lock_file "$2" ;;
    unlock) unlock_file "$2" ;;
    check)  check_lock "$2" ;;
    *)
        echo "Usage: kb-lock <lock|unlock|check> <file>"
        exit 1
        ;;
esac
```

```bash
chmod +x /opt/teamos/bin/kb-lock
```

### KB CLI Tool

**File: `/opt/teamos/bin/kb-cli`**
```bash
#!/bin/bash
# Knowledge Base CLI

MEILI_URL="${MEILI_URL:-http://localhost:7700}"
MEILI_KEY="${MEILI_MASTER_KEY}"
KNOWLEDGE_DIR="${KNOWLEDGE_DIR:-/data/shared/knowledge}"

search() {
    local query="$*"
    curl -s "${MEILI_URL}/indexes/knowledge/search" \
        -H "Authorization: Bearer ${MEILI_KEY}" \
        -H "Content-Type: application/json" \
        -d "{\"q\": \"${query}\", \"limit\": 10}" | \
        jq -r '.hits[] | "[\(.category)] \(.title)\n  Path: \(.path)\n  Tags: \(.tags | join(", "))\n"'
}

read_doc() {
    cat "${KNOWLEDGE_DIR}/$1"
}

list_category() {
    find "${KNOWLEDGE_DIR}/$1" -name "*.md" -type f 2>/dev/null | head -20
}

recent() {
    find "${KNOWLEDGE_DIR}" -name "*.md" -mtime -7 -type f | head -20
}

case "$1" in
    search) shift; search "$@" ;;
    read)   read_doc "$2" ;;
    list)   list_category "$2" ;;
    recent) recent ;;
    *)
        echo "Knowledge Base CLI"
        echo ""
        echo "Usage: kb-cli <command> [args]"
        echo ""
        echo "Commands:"
        echo "  search <query>    Search knowledge base"
        echo "  read <path>       Read a document"
        echo "  list <category>   List documents in category"
        echo "  recent            Show recently modified"
        ;;
esac
```

```bash
chmod +x /opt/teamos/bin/kb-cli
ln -sf /opt/teamos/bin/kb-cli /usr/local/bin/kb
```

### Files to Create
- Directory structure (mkdir -p commands)
- `/data/shared/knowledge/.github/CODEOWNERS`
- `/data/shared/knowledge/templates/*.md`
- `/opt/teamos/bin/kb-lock`
- `/opt/teamos/bin/kb-cli`

---

## 10. OpenCode & CLI Tools: AI Agent Environment

### What We Need
OpenCode and other CLI tools installed and configured for each user.

### OpenCode Installation

```bash
# Install OpenCode (check for latest installation method)
curl -fsSL https://opencode.ai/install.sh | bash

# Or via npm if applicable
npm install -g @opencode/cli
```

### OpenCode Configuration

**System-wide AGENTS.md:**

**File: `/data/shared/knowledge/AGENTS.md`**
```markdown
# TeamOS Agent Instructions

## Environment
- Knowledge Base: /data/shared/knowledge
- Search API: http://localhost:7700

## Knowledge Base Access

### Search
```bash
kb search "your query"
# Or direct API:
curl -s "http://localhost:7700/indexes/knowledge/search" \
  -H "Authorization: Bearer $MEILI_MASTER_KEY" \
  -d '{"q": "query", "limit": 5}'
```

### File Locking Protocol
Before editing files in /data/shared/knowledge:
1. Check lock: `kb-lock check <file>`
2. Acquire lock: `kb-lock lock <file>`
3. Edit file
4. Release lock: `kb-lock unlock <file>`
5. Commit: `git add <file> && git commit -m "message" && git push`

### Document Standards
All Markdown files must have frontmatter:
```yaml
---
title: "Document Title"
created: YYYY-MM-DD
created_by: email@company.com
updated: YYYY-MM-DD
updated_by: email@company.com
tags: [tag1, tag2]
category: category-name
status: draft|published
---
```

## Available Tools
- `kb search` - Search knowledge base
- `kb read <path>` - Read document
- `kb-lock` - File locking
- Standard Unix tools
```

### Per-User OpenCode Configuration

**File: `/home/USERNAME/.config/opencode/config.json`** (template)
```json
{
  "user": {
    "email": "USERNAME@company.com"
  },
  "agents": {
    "instructions_file": "/data/shared/knowledge/AGENTS.md"
  }
}
```

### Additional CLI Tools

```bash
# ripgrep for fast searching
apt-get install -y ripgrep

# fzf for fuzzy finding
apt-get install -y fzf

# bat for syntax-highlighted cat
apt-get install -y bat

# tree for directory visualization
apt-get install -y tree
```

### Shell Aliases

**File: `/etc/profile.d/teamos-aliases.sh`**
```bash
# Knowledge Base
alias kb='kb-cli'
alias kbs='kb-cli search'
alias kbr='kb-cli read'

# Git shortcuts for knowledge base
alias kbcommit='cd /data/shared/knowledge && git add -A && git commit'
alias kbpush='cd /data/shared/knowledge && git push'
alias kbpull='cd /data/shared/knowledge && git pull'

# Better defaults
alias cat='batcat --paging=never'
alias grep='grep --color=auto'
```

### Files to Create
- `/data/shared/knowledge/AGENTS.md`
- `/etc/profile.d/teamos-aliases.sh`
- User config templates

---

## 11. Audit System: auditd Configuration

### What We Need
Comprehensive audit logging of all security-relevant actions.

### auditd Installation
```bash
apt-get install -y auditd audispd-plugins
```

### Audit Rules

**File: `/etc/audit/rules.d/teamos.rules`**
```bash
# Delete all existing rules
-D

# Buffer size
-b 8192

# Failure mode (1 = printk, 2 = panic)
-f 1

# ============================================
# KNOWLEDGE BASE MONITORING
# ============================================

# All changes to knowledge base
-w /data/shared/knowledge -p wa -k knowledge_changes

# ============================================
# USER AUTHENTICATION
# ============================================

# Login/logout events
-w /var/log/lastlog -p wa -k logins
-w /var/run/faillock -p wa -k logins

# SSH authorized keys
-w /home -p wa -k ssh_keys

# ============================================
# PRIVILEGE ESCALATION
# ============================================

# Sudo usage
-w /etc/sudoers -p wa -k sudoers
-w /etc/sudoers.d -p wa -k sudoers

# Su command
-w /bin/su -p x -k su_execution

# ============================================
# USER MANAGEMENT
# ============================================

# User/group changes
-w /etc/passwd -p wa -k user_changes
-w /etc/group -p wa -k group_changes
-w /etc/shadow -p wa -k password_changes

# ============================================
# SYSTEM CONFIGURATION
# ============================================

# SSH configuration
-w /etc/ssh/sshd_config -p wa -k ssh_config
-w /etc/ssh/sshd_config.d -p wa -k ssh_config

# Cron
-w /etc/crontab -p wa -k cron
-w /etc/cron.d -p wa -k cron
-w /var/spool/cron -p wa -k cron

# ============================================
# PRIVILEGED COMMANDS
# ============================================

# All commands run as root
-a always,exit -F arch=b64 -S execve -F euid=0 -k privileged_commands

# ============================================
# FILE DELETIONS
# ============================================

# Track file deletions
-a always,exit -F arch=b64 -S unlink -S unlinkat -S rename -S renameat -F dir=/data/shared/knowledge -k file_deletion

# ============================================
# MAKE RULES IMMUTABLE (must be last)
# ============================================
-e 2
```

Load rules:
```bash
augenrules --load
systemctl restart auditd
```

### Audit Log Queries

```bash
# All knowledge base changes today
ausearch -k knowledge_changes -ts today --interpret

# Who modified a specific file
ausearch -k knowledge_changes -f /data/shared/knowledge/api-docs/entra-id/auth.md --interpret

# All sudo usage
ausearch -k privileged_commands -ts today --interpret

# Failed access attempts
ausearch --failed -ts today --interpret
```

### Audit Report Script

**File: `/opt/teamos/bin/audit-report.sh`**
```bash
#!/bin/bash
# Daily Audit Report

echo "========================================"
echo "TeamOS Daily Audit Report"
echo "Date: $(date)"
echo "========================================"

echo ""
echo "=== Knowledge Base Changes ==="
ausearch -k knowledge_changes -ts today --interpret 2>/dev/null | \
    grep -E "(name=|uid=|auid=|comm=)" | head -50

echo ""
echo "=== Sudo Usage ==="
ausearch -k privileged_commands -ts today --interpret 2>/dev/null | \
    grep -E "(comm=|uid=|auid=)" | head -30

echo ""
echo "=== User Logins ==="
last -20

echo ""
echo "=== Failed Access Attempts ==="
ausearch --failed -ts today --interpret 2>/dev/null | head -20

echo ""
echo "========================================"
echo "End of Report"
echo "========================================"
```

```bash
chmod +x /opt/teamos/bin/audit-report.sh
```

### Files to Create
- `/etc/audit/rules.d/teamos.rules`
- `/opt/teamos/bin/audit-report.sh`

---

## 12. Logging: fluent-bit & GCP Cloud Logging

### What We Need
Centralized logging with logs forwarded to GCP Cloud Logging for immutable storage.

### fluent-bit Installation

```bash
# Add repository
curl https://raw.githubusercontent.com/fluent/fluent-bit/master/install.sh | sh
```

### fluent-bit Configuration

**File: `/etc/fluent-bit/fluent-bit.conf`**
```ini
[SERVICE]
    Flush         5
    Daemon        Off
    Log_Level     info
    Parsers_File  parsers.conf
    HTTP_Server   On
    HTTP_Listen   0.0.0.0
    HTTP_Port     2020

# ============================================
# INPUTS
# ============================================

# System logs via systemd
[INPUT]
    Name              systemd
    Tag               system.*
    Systemd_Filter    _SYSTEMD_UNIT=sshd.service
    Systemd_Filter    _SYSTEMD_UNIT=docker.service
    Read_From_Tail    On

# Audit logs
[INPUT]
    Name              tail
    Tag               audit
    Path              /var/log/audit/audit.log
    Parser            audit
    Refresh_Interval  5

# Knowledge sync logs
[INPUT]
    Name              tail
    Tag               knowledge.sync
    Path              /var/log/knowledge-sync.log
    Refresh_Interval  10

# Docker container logs
[INPUT]
    Name              forward
    Listen            0.0.0.0
    Port              24224

# ============================================
# FILTERS
# ============================================

[FILTER]
    Name              record_modifier
    Match             *
    Record            hostname ${HOSTNAME}
    Record            environment production

# ============================================
# OUTPUTS
# ============================================

# GCP Cloud Logging
[OUTPUT]
    Name              stackdriver
    Match             *
    google_service_credentials /etc/fluent-bit/gcp-credentials.json
    resource          gce_instance

# Local backup (last 7 days)
[OUTPUT]
    Name              file
    Match             *
    Path              /var/log/fluent-bit/
    Format            json_lines
```

**File: `/etc/fluent-bit/parsers.conf`**
```ini
[PARSER]
    Name        audit
    Format      regex
    Regex       ^type=(?<type>[^ ]+) msg=audit\((?<timestamp>[^:]+):[^)]+\): (?<message>.*)$
    Time_Key    timestamp
    Time_Format %s.%L
```

### GCP Service Account

```bash
# Create service account
gcloud iam service-accounts create fluent-bit-logger \
    --display-name="Fluent Bit Logger"

# Grant permissions
gcloud projects add-iam-policy-binding PROJECT_ID \
    --member="serviceAccount:fluent-bit-logger@PROJECT_ID.iam.gserviceaccount.com" \
    --role="roles/logging.logWriter"

# Create key
gcloud iam service-accounts keys create /etc/fluent-bit/gcp-credentials.json \
    --iam-account=fluent-bit-logger@PROJECT_ID.iam.gserviceaccount.com

# Secure the key
chmod 600 /etc/fluent-bit/gcp-credentials.json
```

### Systemd Service

**File: `/etc/systemd/system/fluent-bit.service`**
```ini
[Unit]
Description=Fluent Bit Log Processor
After=network.target

[Service]
Type=simple
ExecStart=/opt/fluent-bit/bin/fluent-bit -c /etc/fluent-bit/fluent-bit.conf
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
```

```bash
systemctl daemon-reload
systemctl enable fluent-bit
systemctl start fluent-bit
```

### Log Rotation

**File: `/etc/logrotate.d/fluent-bit`**
```
/var/log/fluent-bit/*.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
    create 640 root root
}
```

### Files to Create
- `/etc/fluent-bit/fluent-bit.conf`
- `/etc/fluent-bit/parsers.conf`
- `/etc/fluent-bit/gcp-credentials.json`
- `/etc/systemd/system/fluent-bit.service`
- `/etc/logrotate.d/fluent-bit`

---

## 13. Monitoring: Health Checks & Alerts

### What We Need
Proactive monitoring with alerts for critical issues.

### Health Check Script

**File: `/opt/teamos/bin/health-check.sh`**
```bash
#!/bin/bash
# TeamOS Health Check

SLACK_WEBHOOK="${SLACK_WEBHOOK_URL}"
ALERT_EMAIL="admin@company.com"

send_alert() {
    local level="$1"
    local message="$2"
    
    # Slack
    if [ -n "$SLACK_WEBHOOK" ]; then
        curl -s -X POST -H 'Content-type: application/json' \
            --data "{\"text\":\"[$level] TeamOS: $message\"}" \
            "$SLACK_WEBHOOK"
    fi
    
    # Log
    logger -t teamos-health "[$level] $message"
}

check_service() {
    local service="$1"
    if ! systemctl is-active --quiet "$service"; then
        send_alert "CRITICAL" "$service is not running"
        return 1
    fi
    return 0
}

check_docker_container() {
    local container="$1"
    if ! docker ps --format '{{.Names}}' | grep -q "^${container}$"; then
        send_alert "CRITICAL" "Docker container $container is not running"
        return 1
    fi
    return 0
}

check_disk_usage() {
    local mount="$1"
    local threshold="$2"
    local usage=$(df "$mount" | tail -1 | awk '{print $5}' | tr -d '%')
    
    if [ "$usage" -gt "$threshold" ]; then
        send_alert "WARNING" "Disk usage on $mount is ${usage}%"
        return 1
    fi
    return 0
}

check_meilisearch() {
    if ! curl -sf http://localhost:7700/health > /dev/null; then
        send_alert "CRITICAL" "MeiliSearch is not responding"
        return 1
    fi
    return 0
}

# Run checks
echo "$(date): Running health checks..."

check_service "sshd"
check_service "docker"
check_service "auditd"
check_service "fluent-bit"
check_service "kb-watcher"

check_docker_container "meilisearch"

check_disk_usage "/" 80
check_disk_usage "/data" 80

check_meilisearch

echo "$(date): Health checks complete"
```

```bash
chmod +x /opt/teamos/bin/health-check.sh
```

### Cron for Health Checks

**File: `/etc/cron.d/teamos-health`**
```
# Health check every 5 minutes
*/5 * * * * root /opt/teamos/bin/health-check.sh >> /var/log/health-check.log 2>&1
```

### GCP Monitoring Alerts

Create via gcloud or Terraform:

```bash
# CPU alert
gcloud alpha monitoring policies create \
    --display-name="TeamOS High CPU" \
    --condition-display-name="CPU > 80%" \
    --condition-filter='resource.type="gce_instance" AND metric.type="compute.googleapis.com/instance/cpu/utilization"' \
    --condition-threshold-value=0.8 \
    --condition-threshold-comparison=COMPARISON_GT \
    --condition-threshold-duration=300s \
    --notification-channels=CHANNEL_ID
```

### Metrics to Monitor

| Metric | Threshold | Alert Level |
|--------|-----------|-------------|
| CPU Usage | >80% for 5min | Warning |
| Memory Usage | >85% | Warning |
| Disk Usage (/) | >80% | Warning |
| Disk Usage (/data) | >80% | Warning |
| MeiliSearch Health | Unhealthy | Critical |
| SSH Service | Down | Critical |
| Docker Service | Down | Critical |
| Failed SSH Logins | >5 in 10min | Warning |

### Files to Create
- `/opt/teamos/bin/health-check.sh`
- `/etc/cron.d/teamos-health`

---

## 14. Backup: Snapshots & Recovery

### What We Need
Regular backups with ability to restore quickly.

### Backup Strategy

| What | Method | Frequency | Retention |
|------|--------|-----------|-----------|
| Knowledge Base | Git push | Every commit | Forever |
| Data Disk | GCP Snapshot | Daily | 7 days |
| MeiliSearch | Dump + GCS | Daily | 7 days |
| Configuration | Git repo | On change | Forever |

### Backup Script

**File: `/opt/teamos/bin/backup.sh`**
```bash
#!/bin/bash
# TeamOS Backup Script

set -e

DATE=$(date +%Y%m%d)
BACKUP_BUCKET="gs://company-backups/teamos"
LOG_FILE="/var/log/backup.log"

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

log "Starting backup..."

# 1. Git push (Knowledge Base)
log "Pushing Knowledge Base to GitHub..."
cd /data/shared/knowledge
git add -A
git diff-index --quiet HEAD || git commit -m "Auto-backup $DATE"
git push origin main || true

# 2. MeiliSearch dump
log "Creating MeiliSearch dump..."
DUMP_RESPONSE=$(curl -s -X POST "http://localhost:7700/dumps" \
    -H "Authorization: Bearer ${MEILI_MASTER_KEY}")
DUMP_UID=$(echo "$DUMP_RESPONSE" | jq -r '.taskUid')
log "Dump task: $DUMP_UID"

# Wait for dump
sleep 30

# Copy dump to GCS
log "Uploading MeiliSearch dump to GCS..."
gsutil cp /data/docker/meilisearch/dumps/*.dump "$BACKUP_BUCKET/meilisearch/" || true

# 3. Disk snapshot
log "Creating disk snapshot..."
gcloud compute disks snapshot teamos-data-disk \
    --snapshot-names="teamos-data-$DATE" \
    --zone=europe-west3-a \
    --storage-location=eu

# 4. Cleanup old snapshots (older than 7 days)
log "Cleaning up old snapshots..."
OLD_SNAPSHOTS=$(gcloud compute snapshots list \
    --filter="name~'^teamos-data-' AND creationTimestamp<-P7D" \
    --format="value(name)")

for snapshot in $OLD_SNAPSHOTS; do
    log "Deleting old snapshot: $snapshot"
    gcloud compute snapshots delete "$snapshot" --quiet
done

log "Backup complete!"
```

```bash
chmod +x /opt/teamos/bin/backup.sh
```

### Backup Cron

**File: `/etc/cron.d/teamos-backup`**
```
# Daily backup at 2 AM
0 2 * * * root /opt/teamos/bin/backup.sh >> /var/log/backup.log 2>&1
```

### Recovery Procedures

**Restore Knowledge Base:**
```bash
cd /data/shared/knowledge
git fetch origin
git reset --hard origin/main
```

**Restore from Disk Snapshot:**
```bash
# Create disk from snapshot
gcloud compute disks create teamos-data-restored \
    --source-snapshot=teamos-data-YYYYMMDD \
    --zone=europe-west3-a

# Attach to VM (requires VM stop)
gcloud compute instances detach-disk teamos-server --disk=teamos-data-disk
gcloud compute instances attach-disk teamos-server --disk=teamos-data-restored
```

**Restore MeiliSearch:**
```bash
# Download dump
gsutil cp gs://company-backups/teamos/meilisearch/DUMP_FILE.dump /tmp/

# Import (requires MeiliSearch restart with dump)
docker stop meilisearch
# Copy dump to meili_data/dumps/
docker start meilisearch
# MeiliSearch auto-imports on start
```

### Files to Create
- `/opt/teamos/bin/backup.sh`
- `/etc/cron.d/teamos-backup`

---

## 15. Cron Jobs: Scheduled Tasks

### What We Need
All scheduled tasks organized and documented.

### Cron Jobs Summary

**File: `/etc/cron.d/teamos`**
```bash
# TeamOS Scheduled Tasks
# 
# Format: minute hour day month weekday user command

SHELL=/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
MAILTO=admin@company.com

# Knowledge Base sync (every 5 minutes)
*/5 * * * * root cd /data/shared/knowledge && git pull --rebase >> /var/log/knowledge-sync.log 2>&1

# Health check (every 5 minutes)
*/5 * * * * root /opt/teamos/bin/health-check.sh >> /var/log/health-check.log 2>&1

# Daily backup (2 AM)
0 2 * * * root /opt/teamos/bin/backup.sh >> /var/log/backup.log 2>&1

# Daily audit report (8 AM)
0 8 * * * root /opt/teamos/bin/audit-report.sh | mail -s "TeamOS Daily Audit Report" admin@company.com

# Weekly full reindex (Sunday 3 AM)
0 3 * * 0 root /opt/teamos/venv/bin/python /opt/teamos/bin/kb-indexer.py >> /var/log/indexer.log 2>&1

# Cleanup old logs (daily at 1 AM)
0 1 * * * root find /var/log/fluent-bit -name "*.log" -mtime +7 -delete

# Docker cleanup (weekly, Sunday 4 AM)
0 4 * * 0 root docker system prune -f >> /var/log/docker-cleanup.log 2>&1
```

### Files to Create
- `/etc/cron.d/teamos`

---

## 16. Firewall: Network Security

### What We Need
GCP firewall rules that restrict access to authorized sources only.

### Firewall Rules

| Rule Name | Direction | Action | Source | Target | Ports | Purpose |
|-----------|-----------|--------|--------|--------|-------|---------|
| allow-ssh-office | Ingress | Allow | Office IPs | teamos-server | TCP 22 | SSH access |
| allow-ssh-vpn | Ingress | Allow | VPN IP range | teamos-server | TCP 22 | VPN SSH access |
| allow-iap | Ingress | Allow | 35.235.240.0/20 | teamos-server | TCP 22 | IAP tunnel |
| deny-all-ingress | Ingress | Deny | 0.0.0.0/0 | all | all | Default deny |

### Terraform Configuration

```hcl
resource "google_compute_firewall" "allow_ssh_office" {
  name    = "teamos-allow-ssh-office"
  network = google_compute_network.vpc.self_link

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = var.office_ip_ranges
  target_tags   = ["teamos-server"]
}

resource "google_compute_firewall" "allow_iap" {
  name    = "teamos-allow-iap"
  network = google_compute_network.vpc.self_link

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  # IAP's IP range
  source_ranges = ["35.235.240.0/20"]
  target_tags   = ["teamos-server"]
}

resource "google_compute_firewall" "deny_all" {
  name    = "teamos-deny-all"
  network = google_compute_network.vpc.self_link
  priority = 65534

  deny {
    protocol = "all"
  }

  source_ranges = ["0.0.0.0/0"]
}
```

### Local Firewall (UFW)

```bash
# Install UFW
apt-get install -y ufw

# Default policies
ufw default deny incoming
ufw default allow outgoing

# Allow SSH
ufw allow 22/tcp

# Allow localhost (for MeiliSearch)
ufw allow from 127.0.0.1

# Enable
ufw enable
```

---

## 17. Environment Variables: Configuration Management

### What We Need
Centralized environment variable management for all services.

### System-wide Variables

**File: `/etc/environment`**
```bash
KNOWLEDGE_DIR="/data/shared/knowledge"
MEILI_URL="http://localhost:7700"
```

**File: `/etc/profile.d/teamos.sh`**
```bash
# TeamOS Environment Variables
export KNOWLEDGE_DIR="/data/shared/knowledge"
export MEILI_URL="http://localhost:7700"
export PATH="$PATH:/opt/teamos/bin"
```

### Service-specific Variables

**File: `/opt/teamos/.env`** (for Docker Compose and scripts)
```bash
# MeiliSearch
MEILI_MASTER_KEY=your-secure-key-here

# Slack Webhook (for alerts)
SLACK_WEBHOOK_URL=https://hooks.slack.com/services/XXX/YYY/ZZZ

# GCP Project
GCP_PROJECT_ID=your-project-id
```

### Loading in Scripts

```bash
#!/bin/bash
# Load environment
set -a
source /opt/teamos/.env
set +a

# Now use $MEILI_MASTER_KEY, etc.
```

### Loading in Systemd Services

```ini
[Service]
EnvironmentFile=/opt/teamos/.env
```

### Security

```bash
# Restrict access to .env file
chmod 600 /opt/teamos/.env
chown root:root /opt/teamos/.env
```

---

## Implementation Checklist

Use this checklist to track progress:

### Phase 1: Infrastructure
- [ ] Create GCP project and enable APIs
- [ ] Create Terraform configuration
- [ ] Provision VM and disks
- [ ] Configure networking and firewall

### Phase 2: Base System
- [ ] Mount data disk
- [ ] Install system packages
- [ ] Configure timezone and locale
- [ ] Set up kernel parameters

### Phase 3: Users & Access
- [ ] Create groups
- [ ] Create user accounts
- [ ] Configure SSH
- [ ] Set up sudo

### Phase 4: Storage & Git
- [ ] Create directory structure
- [ ] Set permissions
- [ ] Clone Knowledge Base repo
- [ ] Configure Git hooks

### Phase 5: Docker & MeiliSearch
- [ ] Install Docker
- [ ] Configure Docker
- [ ] Deploy MeiliSearch
- [ ] Configure index

### Phase 6: Knowledge Base Tools
- [ ] Install Python dependencies
- [ ] Deploy indexer
- [ ] Deploy file watcher
- [ ] Deploy CLI tools

### Phase 7: Audit & Logging
- [ ] Configure auditd
- [ ] Install fluent-bit
- [ ] Configure GCP logging
- [ ] Test log flow

### Phase 8: Monitoring & Backup
- [ ] Deploy health checks
- [ ] Configure alerts
- [ ] Set up backup script
- [ ] Test recovery

### Phase 9: Final
- [ ] Create cron jobs
- [ ] Document everything
- [ ] Test full workflow
- [ ] Onboard first users

---

## Quick Reference

### Important Paths
```
/data/shared/knowledge     - Knowledge Base
/opt/teamos/bin            - TeamOS scripts
/opt/teamos/.env           - Environment variables
/etc/fluent-bit            - Logging configuration
/etc/audit/rules.d         - Audit rules
```

### Important Commands
```bash
# Knowledge Base
kb search "query"          - Search
kb-lock lock <file>        - Lock file
kb-lock unlock <file>      - Unlock file

# Services
systemctl status kb-watcher
docker compose -f /opt/teamos/docker-compose.yml logs

# Monitoring
/opt/teamos/bin/health-check.sh
/opt/teamos/bin/audit-report.sh

# Backup
/opt/teamos/bin/backup.sh
```

### Important Ports
```
22    - SSH
7700  - MeiliSearch (localhost only)
2020  - fluent-bit metrics (localhost only)
```
