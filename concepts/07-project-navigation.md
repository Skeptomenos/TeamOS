# TeamOS Project Navigation

**Version:** 1.0  
**Date:** 2025-01-10  
**Purpose:** High-level overview for project navigation  
**Audience:** You - for orientation and decision-making

---

## What Is TeamOS?

A team knowledge platform that evolves into a conversational IT interface. Start with documentation, end with self-service IT for the entire company.

**The journey:** Knowledge Base → Enterprise Tool Integration → Self-Service IT

---

## The VM: What Lives There

A single GCP virtual machine hosts everything. Think of it as the team's shared brain.

### Core Components

| Component | What It Does | Why It Matters |
|-----------|--------------|----------------|
| **Knowledge Store** | Markdown files in a Git repo | Single source of truth for all documentation |
| **Search Engine** | MeiliSearch indexes all documents | Find anything in milliseconds, works for humans and AI agents |
| **User Workspaces** | Each team member has their own Linux account | Personal space + shared resources |
| **Audit System** | Logs every action to immutable storage | Know who did what, when, and why |

### How They Connect

```
Team Members (10 people)
        │
        ├── GUI Path: Obsidian → Git → GitHub → Server
        │   (Offline-capable, visual, familiar)
        │
        └── CLI Path: SSH → Server directly
            (Real-time, AI agents, power users)
                    │
                    ▼
            ┌───────────────────────────────────┐
            │           THE VM                  │
            │                                   │
            │   Knowledge Store ←→ Search       │
            │         │                         │
            │         ▼                         │
            │   Audit System → Cloud Logging    │
            └───────────────────────────────────┘
```

---

## Implementation Phases

### Phase 1: Foundation (You Are Here)

**Goal:** Working knowledge base for your 10-person team.

**What gets built:**
- GCP VM with proper security
- User accounts for each team member
- Git-based knowledge repository
- MeiliSearch for fast search
- Audit logging to GCP Cloud Logging
- Two access paths: CLI (SSH) and GUI (Obsidian + Git)

**Success looks like:** Everyone on the team can find documentation in under 30 seconds.

---

### Phase 2: Enterprise Integration (Future)

**Goal:** Connect to the tools you manage (Entra ID, Google Workspace, Atlassian, Slack).

**What gets built:**
- MCP servers for each enterprise tool
- Identity layer (OAuth token propagation)
- Policy checks before critical actions

**Success looks like:** AI agents can query and modify enterprise systems on behalf of authenticated users.

---

### Phase 3: Self-Service IT (Vision)

**Goal:** Employees talk to IT systems directly. No tickets, no UI navigation.

**What gets built:**
- Company-wide access
- Comprehensive policy engine
- Natural language interface for IT requests

**Success looks like:** "I need a Google Group for Project Alpha" → Done in seconds, not days.

---

## The 17 Technical Components

Everything on the VM breaks down into these building blocks. Each has a dedicated section in the VM Setup Guide.

### Infrastructure Layer

| # | Component | One-Line Summary |
|---|-----------|------------------|
| 1 | **GCP VM Provisioning** | The machine itself - 4 vCPU, 16GB RAM, Frankfurt region |
| 2 | **Operating System** | Ubuntu 24.04 with security hardening |
| 3 | **Storage** | Boot disk (50GB) + Data disk (200GB) with proper permissions |
| 4 | **Firewall** | SSH only from known IPs, everything else blocked |

### Access Layer

| # | Component | One-Line Summary |
|---|-----------|------------------|
| 5 | **User Management** | Linux accounts for each team member with group-based permissions |
| 6 | **SSH Access** | Key-based authentication only, no passwords |

### Knowledge Layer

| # | Component | One-Line Summary |
|---|-----------|------------------|
| 7 | **Git Setup** | Version control with GitHub, auto-sync every 5 minutes |
| 8 | **Knowledge Base Structure** | Organized folders: api-docs, runbooks, decisions, guides |
| 9 | **MeiliSearch** | Docker container providing sub-50ms search |
| 10 | **File Watcher** | Automatically re-indexes when files change |

### AI/CLI Layer

| # | Component | One-Line Summary |
|---|-----------|------------------|
| 11 | **OpenCode & CLI Tools** | AI agent environment with AGENTS.md instructions |
| 12 | **KB CLI** | Command-line tool for searching and reading docs |
| 13 | **File Locking** | Prevents conflicts when multiple people edit |

### Observability Layer

| # | Component | One-Line Summary |
|---|-----------|------------------|
| 14 | **Audit System (auditd)** | Kernel-level logging of all security-relevant actions |
| 15 | **Log Forwarding (fluent-bit)** | Ships logs to GCP Cloud Logging for immutable storage |
| 16 | **Health Monitoring** | Checks services every 5 minutes, alerts on failures |

### Operations Layer

| # | Component | One-Line Summary |
|---|-----------|------------------|
| 17 | **Backup & Recovery** | Daily snapshots, Git push, MeiliSearch dumps |

---

## Key Design Decisions

These choices shape everything else:

| Decision | What We Chose | Why |
|----------|---------------|-----|
| **Version Control** | Git + GitHub | Industry standard, works offline, familiar to everyone |
| **Search** | MeiliSearch | Fast, typo-tolerant, simple to run, good for AI agents |
| **User Isolation** | Linux accounts | Simple, proven, proper permissions without container overhead |
| **Access Model** | Hybrid (CLI + GUI) | CLI for power users and AI, GUI for visual thinkers |
| **Audit Storage** | GCP Cloud Logging | Immutable, searchable, 30+ day retention |
| **Concurrency** | File locking + Git | Prevents conflicts, maintains single source of truth |

---

## Document Map

Where to find detailed information:

| Document | What It Covers |
|----------|----------------|
| `00-vision.md` | Strategic phases, business case, long-term goals |
| `01-knowledge-base-document-search.md` | MeiliSearch setup, frontmatter schema, indexer scripts |
| `02-server-setup-audit-monitoring.md` | GCP VM, Terraform, auditd, fluent-bit, Cloud Logging |
| `03-obsidian-remote-access.md` | 5 access options analyzed, hybrid recommendation |
| `04-conflict-handling.md` | File locking, optimistic locking, ownership model |
| `05-overall-architecture.md` | Architecture diagrams, security layers, cost estimate, roadmap |
| `06-vm-setup-guide.md` | **Implementation reference** - all 17 components in detail |
| `07-project-navigation.md` | This document - high-level orientation |

---

## What's Next

The concept phase is complete. Implementation means:

1. **Terraform** - Provision the GCP infrastructure
2. **Configuration Scripts** - Set up everything on the VM
3. **Testing** - Verify it all works
4. **Onboarding** - Get the team using it

---

## Quick Reference

**VM Specs:** e2-standard-4, Ubuntu 24.04, europe-west3 (Frankfurt)

**Estimated Cost:** ~$15-20 per person per month

**Team Size:** 10 people

**Timeline:** 6 weeks to full deployment (per roadmap in 05-overall-architecture.md)

**Access Methods:**
- CLI: `ssh username@teamos-server`
- GUI: Obsidian with Git sync plugin

**Key Paths on Server:**
- Knowledge Base: `/data/shared/knowledge/`
- Scripts: `/opt/teamos/bin/`
- Logs: `/var/log/` + GCP Cloud Logging

---

*This document is your map. The VM Setup Guide (06) is your implementation manual.*
