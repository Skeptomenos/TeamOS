# TeamOS Agent Operational Guide

**Project**: TeamOS Knowledge Platform  
**Type**: Infrastructure-as-Code + Documentation  
**Stack**: Terraform (GCP), Shell, Python, Docker, Markdown

---

## Project Overview

TeamOS is an infrastructure project for a team-wide knowledge management platform. It provisions a shared GCP VM with:
- MeiliSearch for full-text search
- Git-based knowledge base (Markdown with YAML frontmatter)
- Audit logging (auditd + fluent-bit)
- Multi-user SSH access with OS Login
- Gitea for Git hosting with Google OAuth
- MCP Server for AI agent access

**This is NOT a typical application codebase** - it's infrastructure, scripts, and documentation.

---

## Directory Structure

```
TeamOS/
├── concepts/               # Architecture concept papers
│   ├── 00-vision.md
│   ├── 01-knowledge-base-document-search.md
│   ├── 02-server-setup-audit-monitoring.md
│   └── ...
├── docs/                   # Operational documentation
│   └── vm-setup.md         # Complete VM setup guide
└── terraform/              # Infrastructure as Code (One-Click Deploy)
    ├── main.tf
    ├── variables.tf
    ├── outputs.tf
    └── scripts/
        └── startup.sh      # Automated setup script
```

### Server Directory Structure (after deployment)

```
/data/shared/knowledge/     # Git-versioned knowledge base
├── AGENTS.md               # AI agent guide
├── api-docs/               # API documentation
├── decisions/              # Architecture Decision Records
├── guides/                 # How-to guides
├── runbooks/               # Operational procedures
└── templates/              # Document templates

/opt/teamos/
├── bin/
│   ├── kb                  # Knowledge base CLI
│   ├── indexer.py          # MeiliSearch indexer
│   ├── kb-watcher.py       # File watcher service
│   └── kb-mcp-server.py    # MCP server for AI agents
├── venv/                   # Python virtual environment
└── docker-compose.yml      # Docker services
```

---

## Build, Lint & Test Commands

### Terraform

```bash
# Initialize Terraform
cd terraform && terraform init

# Validate configuration
terraform validate

# Plan changes
terraform plan -var-file="production.tfvars"

# Apply changes
terraform apply -var-file="production.tfvars"

# Format check
terraform fmt -check -recursive
```

### Shell Scripts

```bash
# Lint shell scripts with shellcheck
shellcheck scripts/*.sh bin/*

# Run a specific script (dry-run pattern if supported)
./scripts/script-name.sh --dry-run
```

### Python (MeiliSearch Indexer)

```bash
# Install dependencies
pip install meilisearch python-frontmatter watchdog

# Run indexer
python3 scripts/indexer.py

# Run single file indexing
python3 scripts/indexer.py --file path/to/doc.md
```

### Markdown Validation

```bash
# Validate frontmatter in markdown files
# (Custom pre-commit hook - see concepts/01-knowledge-base-document-search.md)

# Check for required frontmatter fields
for file in $(find . -name "*.md"); do
    head -1 "$file" | grep -q '^---$' || echo "Missing frontmatter: $file"
done
```

---

## Code Style Guidelines

### Terraform (.tf files)

- **Formatting**: Use `terraform fmt` - 2-space indentation
- **Naming**: `snake_case` for resources, variables, outputs
- **Variables**: Always include `description` and `type`
- **Defaults**: Provide sensible defaults where appropriate
- **Comments**: Use `#` for inline comments

```hcl
variable "machine_type" {
  description = "GCE machine type"
  type        = string
  default     = "e2-standard-4"
}
```

### Shell Scripts (.sh files)

- **Shebang**: Always start with `#!/bin/bash` or `#!/usr/bin/env bash`
- **Error handling**: Use `set -e` (exit on error), `set -u` (undefined vars)
- **Quoting**: Always quote variables: `"$VAR"` not `$VAR`
- **Functions**: Use `snake_case` for function names
- **Comments**: Document purpose at top of script

```bash
#!/bin/bash
set -euo pipefail

# Description: Creates a new user with standard configuration
# Usage: ./create-user.sh <username> "<ssh-public-key>"

main() {
    local username="$1"
    local ssh_key="$2"
    # ...
}

main "$@"
```

### Python Scripts

- **Style**: PEP 8 compliant
- **Imports**: Standard lib > Third party > Local (blank line between groups)
- **Type hints**: Use type hints for function signatures
- **Docstrings**: Triple-quoted docstrings for modules and functions
- **Naming**: `snake_case` for functions/variables, `PascalCase` for classes

```python
#!/usr/bin/env python3
"""
Knowledge Base Indexer
Indexes all Markdown files into MeiliSearch
"""

import os
from pathlib import Path
from typing import Optional

import meilisearch
import frontmatter


def index_file(filepath: Path) -> dict:
    """Index a single markdown file."""
    pass
```

### Markdown Documentation

- **Frontmatter**: REQUIRED for all docs in `/shared/knowledge/`
  ```yaml
  ---
  title: "Document Title"
  created: 2025-01-10
  created_by: email@company.com
  updated: 2025-01-10
  updated_by: email@company.com
  tags: [tag1, tag2]
  category: api-docs | runbooks | decisions | guides
  status: draft | review | published | deprecated
  ---
  ```
- **Headings**: Use ATX-style (`#`, `##`, `###`)
- **Code blocks**: Always specify language for syntax highlighting
- **Tables**: Use for structured data, align columns
- **ASCII diagrams**: Use box-drawing characters for architecture diagrams

### Configuration Files

- **YAML**: 2-space indentation, no tabs
- **JSON**: 2-space indentation, trailing commas NOT allowed
- **INI**: Use `[SECTION]` headers, `key = value` format

---

## Error Handling

### Terraform

- Use `lifecycle` blocks for critical resources
- Implement `prevent_destroy` for data disks
- Use `depends_on` explicitly when order matters

### Shell Scripts

```bash
# Always check command success
if ! command -v docker &> /dev/null; then
    echo "ERROR: docker is not installed" >&2
    exit 1
fi

# Use trap for cleanup
trap cleanup EXIT

cleanup() {
    rm -f "$TEMP_FILE"
}
```

### Python

```python
try:
    result = client.get_index('knowledge')
except meilisearch.errors.MeiliSearchApiError as e:
    logger.error(f"MeiliSearch error: {e}")
    raise
```

---

## GCP-Specific Guidelines

### Resource Naming

- Pattern: `teamos-<resource-type>-<environment>`
- Examples: `teamos-vpc`, `teamos-server`, `teamos-data-disk`

### Labels

All resources MUST have these labels:
```hcl
labels = {
  team        = "it-operations"
  project     = "teamos"
  environment = "production"
}
```

### Regions

- Primary: `europe-west3` (Frankfurt) or `europe-west1` (Belgium)
- Use variables for region/zone, never hardcode

### Service Accounts

- Principle of least privilege
- Separate service accounts per function
- Document required IAM roles

---

## Security Requirements

### SSH Access

- Key-based authentication ONLY (no passwords)
- Ed25519 keys preferred
- OS Login enabled for Google Workspace integration

### Secrets Management

- NEVER commit secrets to git
- Use environment variables or GCP Secret Manager
- Sensitive Terraform variables: mark with `sensitive = true`

### Audit Logging

- All file changes in `/shared/knowledge` are logged
- All sudo usage is logged
- Logs forwarded to GCP Cloud Logging (immutable)

---

## Common Operations

### Connecting to TeamOS Server

```bash
# Recommended (uses Google Workspace identity)
gcloud compute ssh teamos-server --zone=europe-west1-b --project=it-services-automations

# Or use alias
alias teamos="gcloud compute ssh teamos-server --zone=europe-west1-b --project=it-services-automations"
```

### Managing Docker Services

```bash
# View status
docker ps

# Restart services
cd /opt/teamos && docker compose restart

# View logs
docker logs -f meilisearch
```

### Knowledge Base Search

```bash
# CLI search
kb search "Entra ID API"

# Read a document
kb read runbooks/onboarding/new-hire-checklist.md

# List by category
kb list api-docs

# Recent changes
kb recent 7

# Direct API
curl -s "http://localhost:7700/indexes/knowledge/search" \
  -H "Authorization: Bearer $MEILI_KEY" \
  -d '{"q": "your query", "limit": 5}'
```

### AI Agent Access (MCP Server)

The knowledge base exposes an MCP server at `/opt/teamos/bin/kb-mcp-server.py` with these tools:

| Tool | Purpose |
|------|---------|
| `kb_search` | Search documents by query, category, or project |
| `kb_read` | Read full content of a specific document |
| `kb_list` | List documents with optional filters |
| `kb_recent` | Get recently modified documents |

---

## File Locations on Server

| Path | Purpose |
|------|---------|
| `/data/shared/knowledge/` | Git-versioned knowledge base |
| `/data/docker/` | Docker data volumes |
| `/opt/teamos/` | Scripts and docker-compose |
| `/home/template/` | Template user for provisioning |
| `/var/log/audit/` | Audit logs |

---

## Pre-Commit Checklist

Before committing changes:

1. [ ] Terraform: `terraform fmt` and `terraform validate`
2. [ ] Shell: `shellcheck` passes
3. [ ] Markdown: Frontmatter present and valid
4. [ ] No secrets or credentials in code
5. [ ] Documentation updated if behavior changed

---

## Concept Documents Reference

| Document | Purpose |
|----------|---------|
| `00-vision.md` | Strategic vision and phases |
| `01-knowledge-base-document-search.md` | MeiliSearch setup, indexing |
| `02-server-setup-audit-monitoring.md` | VM setup, audit, logging |
| `03-obsidian-remote-access.md` | GUI access via Obsidian |
| `04-conflict-handling.md` | Git conflict resolution |
| `05-overall-architecture.md` | System architecture overview |
| `06-vm-setup-guide.md` | Step-by-step VM setup |
| `07-project-navigation.md` | Project navigation patterns |

---

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Terraform state lock | `terraform force-unlock <LOCK_ID>` |
| MeiliSearch not responding | `docker restart meilisearch` |
| SSH permission denied | Verify Google Workspace group membership |
| Disk space low | Check `/data` usage, clean Docker images |

---

## Contact & Ownership

- **Owner**: Your Name
- **Team**: IT Operations (identity-n-productivity@example.com)
- **GCP Project**: `it-services-automations`
