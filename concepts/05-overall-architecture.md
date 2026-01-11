# Concept Paper: Overall Architecture - TeamOS Knowledge Platform

**Version:** 1.1  
**Date:** 2025-01-11  
**Status:** Implemented  
**Author:** TeamOS

---

## 1. Executive Summary

This document describes the overall architecture of the TeamOS Knowledge Platform - an integrated solution for team-wide knowledge management, optimized for use with AI-powered CLI tools (OpenCode, Gemini CLI) and traditional GUI tools (Obsidian). The architecture connects all components from the previous concept papers into a coherent system.

---

## 2. Vision

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                                                                             │
│                         "Knowledge at Your Fingertips"                      │
│                                                                             │
│   A team of 10 IT specialists who manage Tier 0/1 Enterprise Tools         │
│   (Entra ID, Google Workspace, Atlassian, Slack) share knowledge           │
│   seamlessly via CLI and GUI, supported by AI agents.                       │
│                                                                             │
│   Each team member can:                                                     │
│   ✓ Find knowledge in seconds (not minutes)                                │
│   ✓ Create documentation that AI agents understand                         │
│   ✓ Work offline and synchronize later                                     │
│   ✓ Track who changed what and when                                        │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 3. Architecture Overview

### 3.1 High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           TEAMOS KNOWLEDGE PLATFORM                         │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                         CLIENT LAYER                                 │   │
│  │                                                                      │   │
│  │   ┌─────────────┐   ┌─────────────┐   ┌─────────────┐              │   │
│  │   │   Laptop    │   │   Laptop    │   │   Laptop    │   ...        │   │
│  │   │   Alice     │   │   Anna      │   │   Max       │              │   │
│  │   │             │   │             │   │             │              │   │
│  │   │ ┌─────────┐ │   │ ┌─────────┐ │   │ ┌─────────┐ │              │   │
│  │   │ │Obsidian │ │   │ │Terminal │ │   │ │Obsidian │ │              │   │
│  │   │ │+ Git    │ │   │ │ (SSH)   │ │   │ │+ Git    │ │              │   │
│  │   │ └─────────┘ │   │ └─────────┘ │   │ └─────────┘ │              │   │
│  │   └──────┬──────┘   └──────┬──────┘   └──────┬──────┘              │   │
│  │          │                 │                 │                      │   │
│  └──────────┼─────────────────┼─────────────────┼──────────────────────┘   │
│             │                 │                 │                          │
│             │    SSH/Git      │    SSH          │    SSH/Git               │
│             │                 │                 │                          │
│  ┌──────────┼─────────────────┼─────────────────┼──────────────────────┐   │
│  │          ▼                 ▼                 ▼                      │   │
│  │                      GITHUB (Private Repo)                          │   │
│  │                      - Version Control                              │   │
│  │                      - Branch Protection                            │   │
│  │                      - CODEOWNERS                                   │   │
│  └──────────────────────────────┬──────────────────────────────────────┘   │
│                                 │                                          │
│                                 │ git pull (cron)                          │
│                                 ▼                                          │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                         SERVER LAYER                                 │   │
│  │                      (GCP Compute Engine)                            │   │
│  │                                                                      │   │
│  │   ┌─────────────────────────────────────────────────────────────┐   │   │
│  │   │                    COMPUTE                                   │   │   │
│  │   │                                                              │   │   │
│  │   │   ┌─────────────┐   ┌─────────────┐   ┌─────────────┐       │   │   │
│  │   │   │  OpenCode   │   │ Gemini CLI  │   │    Bash     │       │   │   │
│  │   │   │  Sessions   │   │  Sessions   │   │  Sessions   │       │   │   │
│  │   │   └─────────────┘   └─────────────┘   └─────────────┘       │   │   │
│  │   │                                                              │   │   │
│  │   └─────────────────────────────────────────────────────────────┘   │   │
│  │                                 │                                    │   │
│  │   ┌─────────────────────────────┼───────────────────────────────┐   │   │
│  │   │                    STORAGE  │                                │   │   │
│  │   │                             ▼                                │   │   │
│  │   │   ┌─────────────────────────────────────────────────────┐   │   │   │
│  │   │   │              /shared/knowledge/                      │   │   │   │
│  │   │   │              (Git Working Copy)                      │   │   │   │
│  │   │   │                                                      │   │   │   │
│  │   │   │   ├── api-docs/                                     │   │   │   │
│  │   │   │   ├── runbooks/                                     │   │   │   │
│  │   │   │   ├── decisions/                                    │   │   │   │
│  │   │   │   └── guides/                                       │   │   │   │
│  │   │   └─────────────────────────────────────────────────────┘   │   │   │
│  │   │                             │                                │   │   │
│  │   │   ┌─────────────────────────┼───────────────────────────┐   │   │   │
│  │   │   │                         ▼                            │   │   │   │
│  │   │   │   ┌─────────────┐   ┌─────────────┐                 │   │   │   │
│  │   │   │   │ MeiliSearch │   │   auditd    │                 │   │   │   │
│  │   │   │   │  (Search)   │   │  (Audit)    │                 │   │   │   │
│  │   │   │   └─────────────┘   └─────────────┘                 │   │   │   │
│  │   │   │                                                      │   │   │   │
│  │   │   └──────────────────────────────────────────────────────┘   │   │   │
│  │   │                                                              │   │   │
│  │   └──────────────────────────────────────────────────────────────┘   │   │
│  │                                 │                                    │   │
│  └─────────────────────────────────┼────────────────────────────────────┘   │
│                                    │                                        │
│                                    │ Logs                                   │
│                                    ▼                                        │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                      OBSERVABILITY LAYER                             │   │
│  │                                                                      │   │
│  │   ┌─────────────┐   ┌─────────────┐   ┌─────────────┐              │   │
│  │   │ GCP Cloud   │   │ GCP Cloud   │   │   Slack     │              │   │
│  │   │  Logging    │   │ Monitoring  │   │  Alerts     │              │   │
│  │   └─────────────┘   └─────────────┘   └─────────────┘              │   │
│  │                                                                      │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 4. Component Overview

### 4.1 Component Matrix

| Component | Purpose | Technology | Location |
|------------|---------|-------------|----------|
| **Knowledge Store** | Store Markdown files | Git + Filesystem | Server + GitHub |
| **Search Engine** | Full-text search | MeiliSearch | Server (Docker) |
| **Version Control** | Change history | Git + GitHub | Decentralized |
| **Audit System** | Security logging | auditd | Server |
| **Log Aggregation** | Centralized logs | fluent-bit → GCP | Server → Cloud |
| **Monitoring** | Metrics & Alerts | GCP Monitoring | Cloud |
| **Client Access** | GUI access | Obsidian + Git | Laptops |
| **CLI Access** | Terminal access | SSH | Laptops → Server |

### 4.2 Component Diagram

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         COMPONENTS & DATA FLOW                              │
│                                                                             │
│                                                                             │
│   ┌─────────────┐                                                          │
│   │   HUMAN     │                                                          │
│   │  (Editor)   │                                                          │
│   └──────┬──────┘                                                          │
│          │                                                                  │
│          │ writes/reads                                                     │
│          ▼                                                                  │
│   ┌─────────────┐         ┌─────────────┐         ┌─────────────┐         │
│   │  Obsidian   │◄───────►│    Git      │◄───────►│   GitHub    │         │
│   │  (local)    │  sync   │  (local)    │  push   │  (remote)   │         │
│   └─────────────┘         └─────────────┘         └──────┬──────┘         │
│                                                          │                 │
│                                                          │ pull            │
│                                                          ▼                 │
│   ┌─────────────┐         ┌─────────────┐         ┌─────────────┐         │
│   │  LLM Agent  │◄───────►│   Server    │◄───────►│  Knowledge  │         │
│   │ (OpenCode)  │  SSH    │  (Compute)  │  r/w    │   Store     │         │
│   └─────────────┘         └──────┬──────┘         └──────┬──────┘         │
│                                  │                       │                 │
│          ┌───────────────────────┼───────────────────────┤                 │
│          │                       │                       │                 │
│          ▼                       ▼                       ▼                 │
│   ┌─────────────┐         ┌─────────────┐         ┌─────────────┐         │
│   │ MeiliSearch │         │   auditd    │         │  fluent-bit │         │
│   │  (Search)   │         │  (Audit)    │         │   (Logs)    │         │
│   └─────────────┘         └─────────────┘         └──────┬──────┘         │
│          │                       │                       │                 │
│          │ indexes               │ logs                  │ forwards        │
│          ▼                       ▼                       ▼                 │
│   ┌─────────────┐         ┌─────────────┐         ┌─────────────┐         │
│   │   Search    │         │   Audit     │         │ GCP Cloud   │         │
│   │   Index     │         │   Trail     │         │  Logging    │         │
│   └─────────────┘         └─────────────┘         └─────────────┘         │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 5. Detailed Component Description

### 5.1 Knowledge Store

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           KNOWLEDGE STORE                                   │
│                                                                             │
│  PURPOSE:                                                                   │
│  Central storage of all documentation in Markdown format                    │
│                                                                             │
│  TECHNOLOGY:                                                                │
│  - Filesystem: ext4 on GCP Persistent Disk                                 │
│  - Version Control: Git                                                     │
│  - Remote: GitHub Private Repository                                        │
│                                                                             │
│  STRUCTURE:                                                                 │
│  /shared/knowledge/                                                         │
│  ├── .git/                    # Git Repository                             │
│  ├── .github/                                                              │
│  │   └── CODEOWNERS           # Ownership rules                            │
│  ├── api-docs/                # API documentation                          │
│  │   ├── entra-id/                                                         │
│  │   ├── google-workspace/                                                 │
│  │   ├── atlassian/                                                        │
│  │   └── slack/                                                            │
│  ├── runbooks/                # Operational runbooks                       │
│  ├── decisions/               # ADRs                                       │
│  ├── guides/                  # How-To Guides                              │
│  └── templates/               # Document templates                         │
│                                                                             │
│  INTEGRATION:                                                               │
│  - MeiliSearch indexes all .md files                                       │
│  - Pre-commit hooks validate frontmatter                                   │
│  - File watcher triggers re-indexing                                       │
│                                                                             │
│  DATA FLOW:                                                                 │
│  ┌────────┐    write    ┌────────┐    push    ┌────────┐                  │
│  │ Editor │────────────►│  Git   │───────────►│ GitHub │                  │
│  └────────┘             └────────┘            └────────┘                  │
│       ▲                      │                     │                       │
│       │                      │ commit hook         │ webhook               │
│       │                      ▼                     ▼                       │
│       │              ┌─────────────┐        ┌─────────────┐               │
│       └──────────────│ Frontmatter │        │   Server    │               │
│         validation   │ Validation  │        │  git pull   │               │
│                      └─────────────┘        └─────────────┘               │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 5.2 Search Engine (MeiliSearch)

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           SEARCH ENGINE                                     │
│                                                                             │
│  PURPOSE:                                                                   │
│  Fast full-text search across all documents for humans and LLMs            │
│                                                                             │
│  TECHNOLOGY:                                                                │
│  - MeiliSearch v1.6 (Docker Container)                                     │
│  - REST API on port 7700                                                   │
│  - ~500MB RAM for 10,000 documents                                         │
│                                                                             │
│  FEATURES:                                                                  │
│  - Typo-tolerant search                                                    │
│  - Faceted search (tags, category, author)                                 │
│  - Sub-50ms latency                                                        │
│  - Real-time indexing via file watcher                                     │
│                                                                             │
│  DATA FLOW:                                                                 │
│                                                                             │
│  ┌─────────────┐    inotify    ┌─────────────┐    index    ┌────────────┐ │
│  │  Knowledge  │──────────────►│ File Watcher│────────────►│ MeiliSearch│ │
│  │   Store     │               │  (Python)   │             │   Index    │ │
│  └─────────────┘               └─────────────┘             └─────┬──────┘ │
│                                                                   │        │
│                                                                   │        │
│  ┌─────────────┐    REST API   ┌─────────────┐    query          │        │
│  │   LLM/CLI   │◄─────────────►│ MeiliSearch │◄──────────────────┘        │
│  │   Client    │   results     │   Server    │                            │
│  └─────────────┘               └─────────────┘                            │
│                                                                             │
│  API EXAMPLE:                                                               │
│  POST /indexes/knowledge/search                                            │
│  {"q": "Entra ID API authentication", "limit": 5}                          │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 5.3 Audit System

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           AUDIT SYSTEM                                      │
│                                                                             │
│  PURPOSE:                                                                   │
│  Traceability of all actions for compliance and debugging                  │
│                                                                             │
│  TECHNOLOGY:                                                                │
│  - auditd (Linux Kernel Audit)                                             │
│  - fluent-bit (Log Forwarding)                                             │
│  - GCP Cloud Logging (Immutable Storage)                                   │
│                                                                             │
│  WHAT IS LOGGED:                                                            │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  - All file changes in /shared/knowledge                            │   │
│  │  - SSH logins and logouts                                           │   │
│  │  - Sudo usage                                                       │   │
│  │  - User management (useradd, userdel, passwd)                       │   │
│  │  - Privileged commands                                              │   │
│  │  - Failed access attempts                                           │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  DATA FLOW:                                                                 │
│                                                                             │
│  ┌─────────────┐    syscall    ┌─────────────┐    log     ┌─────────────┐ │
│  │   Kernel    │──────────────►│   auditd    │───────────►│ /var/log/   │ │
│  │  (Actions)  │               │             │            │ audit/      │ │
│  └─────────────┘               └─────────────┘            └──────┬──────┘ │
│                                                                   │        │
│                                                                   │        │
│  ┌─────────────┐    forward    ┌─────────────┐    store          │        │
│  │ GCP Cloud   │◄──────────────│ fluent-bit  │◄──────────────────┘        │
│  │  Logging    │               │             │                            │
│  └─────────────┘               └─────────────┘                            │
│        │                                                                   │
│        │ immutable                                                         │
│        ▼                                                                   │
│  ┌─────────────┐                                                          │
│  │  30+ Days   │                                                          │
│  │  Retention  │                                                          │
│  └─────────────┘                                                          │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 5.4 Client Access Layer

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           CLIENT ACCESS                                     │
│                                                                             │
│  PURPOSE:                                                                   │
│  Access to the Knowledge Base from employee laptops                        │
│                                                                             │
│  TWO ACCESS TYPES:                                                          │
│                                                                             │
│  ┌─────────────────────────────────┐  ┌─────────────────────────────────┐  │
│  │         GUI ACCESS              │  │         CLI ACCESS              │  │
│  │                                 │  │                                 │  │
│  │  ┌─────────────┐               │  │  ┌─────────────┐               │  │
│  │  │  Obsidian   │               │  │  │  Terminal   │               │  │
│  │  │             │               │  │  │             │               │  │
│  │  └──────┬──────┘               │  │  └──────┬──────┘               │  │
│  │         │                       │  │         │                       │  │
│  │         │ reads/writes          │  │         │ SSH                   │  │
│  │         ▼                       │  │         ▼                       │  │
│  │  ┌─────────────┐               │  │  ┌─────────────┐               │  │
│  │  │ ~/knowledge │               │  │  │   Server    │               │  │
│  │  │ (Git Clone) │               │  │  │             │               │  │
│  │  └──────┬──────┘               │  │  └──────┬──────┘               │  │
│  │         │                       │  │         │                       │  │
│  │         │ Git Sync              │  │         │ direct                │  │
│  │         ▼                       │  │         ▼                       │  │
│  │  ┌─────────────┐               │  │  ┌─────────────┐               │  │
│  │  │   GitHub    │               │  │  │  /shared/   │               │  │
│  │  │             │               │  │  │  knowledge/ │               │  │
│  │  └─────────────┘               │  │  └─────────────┘               │  │
│  │                                 │  │                                 │  │
│  │  ADVANTAGES:                    │  │  ADVANTAGES:                    │  │
│  │  - Offline capable              │  │  - No local clone needed       │  │
│  │  - Fast navigation              │  │  - Direct access               │  │
│  │  - Graph View                   │  │  - OpenCode/Gemini CLI         │  │
│  │                                 │  │  - Always up to date           │  │
│  └─────────────────────────────────┘  └─────────────────────────────────┘  │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 6. Data Flow Diagrams

### 6.1 Create Document (GUI)

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    WORKFLOW: Create Document (Obsidian)                     │
│                                                                             │
│  1. User creates file in Obsidian                                          │
│     ┌─────────────┐                                                        │
│     │  Obsidian   │ → new-doc.md                                           │
│     └──────┬──────┘                                                        │
│            │                                                                │
│  2. Obsidian Git Plugin commits automatically (every 5 min)                │
│            │                                                                │
│            ▼                                                                │
│     ┌─────────────┐                                                        │
│     │  git add    │                                                        │
│     │  git commit │                                                        │
│     │  git push   │                                                        │
│     └──────┬──────┘                                                        │
│            │                                                                │
│  3. GitHub receives push                                                   │
│            │                                                                │
│            ▼                                                                │
│     ┌─────────────┐                                                        │
│     │   GitHub    │                                                        │
│     │  (remote)   │                                                        │
│     └──────┬──────┘                                                        │
│            │                                                                │
│  4. Server pulls changes (Cron every 5 min)                                │
│            │                                                                │
│            ▼                                                                │
│     ┌─────────────┐                                                        │
│     │   Server    │                                                        │
│     │  git pull   │                                                        │
│     └──────┬──────┘                                                        │
│            │                                                                │
│  5. File watcher detects new file                                          │
│            │                                                                │
│            ▼                                                                │
│     ┌─────────────┐                                                        │
│     │ MeiliSearch │ → Document indexed                                     │
│     │   Indexer   │                                                        │
│     └─────────────┘                                                        │
│                                                                             │
│  LATENCY: ~5-10 minutes until document is on server and in search          │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 6.2 Create Document (CLI/LLM)

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    WORKFLOW: Create Document (CLI/LLM)                      │
│                                                                             │
│  1. User/LLM connects via SSH                                              │
│     ┌─────────────┐                                                        │
│     │  Terminal   │ → ssh team-server                                      │
│     └──────┬──────┘                                                        │
│            │                                                                │
│  2. File is created directly on server                                     │
│            │                                                                │
│            ▼                                                                │
│     ┌─────────────┐                                                        │
│     │  OpenCode   │ → /shared/knowledge/new-doc.md                         │
│     │  (Server)   │                                                        │
│     └──────┬──────┘                                                        │
│            │                                                                │
│  3. File watcher detects immediately                                       │
│            │                                                                │
│            ▼                                                                │
│     ┌─────────────┐                                                        │
│     │ MeiliSearch │ → Document indexed                                     │
│     │   Indexer   │                                                        │
│     └──────┬──────┘                                                        │
│            │                                                                │
│  4. Git commit (manual or via hook)                                        │
│            │                                                                │
│            ▼                                                                │
│     ┌─────────────┐                                                        │
│     │  git add    │                                                        │
│     │  git commit │                                                        │
│     │  git push   │                                                        │
│     └──────┬──────┘                                                        │
│            │                                                                │
│  5. GitHub receives push                                                   │
│            │                                                                │
│            ▼                                                                │
│     ┌─────────────┐                                                        │
│     │   GitHub    │                                                        │
│     └─────────────┘                                                        │
│                                                                             │
│  LATENCY: Seconds until document is in search, minutes until on other      │
│           clients                                                           │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 6.3 Search Document

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    WORKFLOW: Search Document                                │
│                                                                             │
│  OPTION A: CLI                                                              │
│  ┌─────────────┐                                                           │
│  │  Terminal   │ → kb search "Entra ID API"                                │
│  └──────┬──────┘                                                           │
│         │                                                                   │
│         │ REST API                                                          │
│         ▼                                                                   │
│  ┌─────────────┐                                                           │
│  │ MeiliSearch │ → Results                                                 │
│  └─────────────┘                                                           │
│                                                                             │
│  OPTION B: LLM Agent                                                        │
│  ┌─────────────┐                                                           │
│  │  OpenCode   │ → curl localhost:7700/indexes/knowledge/search            │
│  └──────┬──────┘                                                           │
│         │                                                                   │
│         │ REST API                                                          │
│         ▼                                                                   │
│  ┌─────────────┐                                                           │
│  │ MeiliSearch │ → JSON Response → LLM processes                           │
│  └─────────────┘                                                           │
│                                                                             │
│  OPTION C: Obsidian                                                         │
│  ┌─────────────┐                                                           │
│  │  Obsidian   │ → Local search (Ctrl+Shift+F)                             │
│  │  (local)    │ → Or: Graph View navigation                               │
│  └─────────────┘                                                           │
│                                                                             │
│  LATENCY: <50ms for MeiliSearch, instant for local Obsidian search         │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 7. Security Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           SECURITY LAYERS                                   │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  LAYER 1: NETWORK                                                    │   │
│  │                                                                      │   │
│  │  - VPC with Private IP                                              │   │
│  │  - Firewall: SSH only from Office IP / VPN                          │   │
│  │  - No direct internet access for services                           │   │
│  │  - IAP (Identity-Aware Proxy) optional                              │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                     │                                       │
│                                     ▼                                       │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  LAYER 2: AUTHENTICATION                                            │   │
│  │                                                                      │   │
│  │  - SSH Key-based (Ed25519)                                          │   │
│  │  - No password authentication                                       │   │
│  │  - Optional: SSO via Entra ID (OS Login)                            │   │
│  │  - GitHub: SSH Keys or Personal Access Tokens                       │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                     │                                       │
│                                     ▼                                       │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  LAYER 3: AUTHORIZATION                                             │   │
│  │                                                                      │   │
│  │  - Linux Groups (users, docker, sudo)                               │   │
│  │  - File Permissions (SGID on /shared)                               │   │
│  │  - CODEOWNERS for GitHub PRs                                        │   │
│  │  - Least Privilege Principle                                        │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                     │                                       │
│                                     ▼                                       │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  LAYER 4: AUDIT & MONITORING                                        │   │
│  │                                                                      │   │
│  │  - auditd for all file operations                                   │   │
│  │  - Session recording                                                │   │
│  │  - Immutable logs in GCP Cloud Logging                              │   │
│  │  - Alerting on suspicious activities                                │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                     │                                       │
│                                     ▼                                       │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  LAYER 5: DATA PROTECTION                                           │   │
│  │                                                                      │   │
│  │  - Encryption at Rest (GCP Disk Encryption)                         │   │
│  │  - Encryption in Transit (SSH, HTTPS)                               │   │
│  │  - Git History for data recovery                                    │   │
│  │  - Daily Backups (Snapshots + Git)                                  │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 8. Deployment Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           DEPLOYMENT ARCHITECTURE                           │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                         GCP PROJECT                                  │   │
│  │                                                                      │   │
│  │   ┌─────────────────────────────────────────────────────────────┐   │   │
│  │   │                    VPC NETWORK                               │   │   │
│  │   │                                                              │   │   │
│  │   │   ┌─────────────────────────────────────────────────────┐   │   │   │
│  │   │   │              SUBNET (10.0.0.0/24)                    │   │   │   │
│  │   │   │                                                      │   │   │   │
│  │   │   │   ┌─────────────────────────────────────────────┐   │   │   │   │
│  │   │   │   │         COMPUTE ENGINE VM                    │   │   │   │   │
│  │   │   │   │         team-knowledge-server                │   │   │   │   │
│  │   │   │   │         e2-standard-4                        │   │   │   │   │
│  │   │   │   │         10.0.0.2                             │   │   │   │   │
│  │   │   │   │                                              │   │   │   │   │
│  │   │   │   │   ┌─────────────┐  ┌─────────────┐          │   │   │   │   │
│  │   │   │   │   │  Boot Disk  │  │  Data Disk  │          │   │   │   │   │
│  │   │   │   │   │   50 GB     │  │   200 GB    │          │   │   │   │   │
│  │   │   │   │   │   (OS)      │  │  (/data)    │          │   │   │   │   │
│  │   │   │   │   └─────────────┘  └─────────────┘          │   │   │   │   │
│  │   │   │   │                                              │   │   │   │   │
│  │   │   │   │   ┌─────────────────────────────────────┐   │   │   │   │   │
│  │   │   │   │   │           DOCKER                     │   │   │   │   │   │
│  │   │   │   │   │                                      │   │   │   │   │   │
│  │   │   │   │   │   ┌─────────────┐                   │   │   │   │   │   │
│  │   │   │   │   │   │ MeiliSearch │ :7700             │   │   │   │   │   │
│  │   │   │   │   │   └─────────────┘                   │   │   │   │   │   │
│  │   │   │   │   │                                      │   │   │   │   │   │
│  │   │   │   │   └─────────────────────────────────────┘   │   │   │   │   │
│  │   │   │   │                                              │   │   │   │   │
│  │   │   │   └──────────────────────────────────────────────┘   │   │   │   │
│  │   │   │                                                      │   │   │   │
│  │   │   └──────────────────────────────────────────────────────┘   │   │   │
│  │   │                                                              │   │   │
│  │   │   ┌─────────────────────────────────────────────────────┐   │   │   │
│  │   │   │              FIREWALL RULES                          │   │   │   │
│  │   │   │                                                      │   │   │   │
│  │   │   │   allow-ssh-office: TCP 22 from [Office IPs]        │   │   │   │
│  │   │   │   deny-all-ingress: * from 0.0.0.0/0                │   │   │   │
│  │   │   │                                                      │   │   │   │
│  │   │   └─────────────────────────────────────────────────────┘   │   │   │
│  │   │                                                              │   │   │
│  │   └──────────────────────────────────────────────────────────────┘   │   │
│  │                                                                      │   │
│  │   ┌─────────────────────────────────────────────────────────────┐   │   │
│  │   │                    CLOUD SERVICES                            │   │   │
│  │   │                                                              │   │   │
│  │   │   ┌─────────────┐  ┌─────────────┐  ┌─────────────┐        │   │   │
│  │   │   │ Cloud       │  │ Cloud       │  │ Cloud       │        │   │   │
│  │   │   │ Logging     │  │ Monitoring  │  │ Storage     │        │   │   │
│  │   │   │             │  │             │  │ (Backups)   │        │   │   │
│  │   │   └─────────────┘  └─────────────┘  └─────────────┘        │   │   │
│  │   │                                                              │   │   │
│  │   └──────────────────────────────────────────────────────────────┘   │   │
│  │                                                                      │   │
│  └──────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 9. Cost Estimate

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           MONTHLY COSTS (estimated)                         │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  COMPUTE                                                             │   │
│  │                                                                      │   │
│  │  e2-standard-4 (4 vCPU, 16 GB RAM)                                  │   │
│  │  Region: europe-west3                                                │   │
│  │  24/7 operation                                                      │   │
│  │                                                                      │   │
│  │  Cost: ~$100/month                                                  │   │
│  │  (With Committed Use: ~$60/month)                                   │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  STORAGE                                                             │   │
│  │                                                                      │   │
│  │  Boot Disk: 50 GB SSD = ~$8/month                                   │   │
│  │  Data Disk: 200 GB SSD = ~$34/month                                 │   │
│  │  Snapshots: ~$5/month (estimated)                                   │   │
│  │                                                                      │   │
│  │  Cost: ~$47/month                                                   │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  NETWORKING                                                          │   │
│  │                                                                      │   │
│  │  Egress: Minimal (SSH traffic)                                      │   │
│  │  No external IP = no NAT costs                                      │   │
│  │                                                                      │   │
│  │  Cost: ~$5/month                                                    │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  LOGGING & MONITORING                                                │   │
│  │                                                                      │   │
│  │  Cloud Logging: 50 GB/month free                                    │   │
│  │  Cloud Monitoring: Basic free                                       │   │
│  │                                                                      │   │
│  │  Cost: ~$0/month (under Free Tier)                                  │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  GITHUB                                                              │   │
│  │                                                                      │   │
│  │  GitHub Team: $4/User/month × 10 Users                              │   │
│  │                                                                      │   │
│  │  Cost: ~$40/month                                                   │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  ═══════════════════════════════════════════════════════════════════════   │
│                                                                             │
│  TOTAL: ~$190-200/month                                                    │
│  (With Committed Use Discounts: ~$150/month)                               │
│                                                                             │
│  PER PERSON: ~$15-20/month                                                 │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 10. Implementation Roadmap

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           IMPLEMENTATION ROADMAP                            │
│                                                                             │
│  PHASE 1: FOUNDATION (Week 1-2)                                            │
│  ════════════════════════════════                                          │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  □ Set up GCP project                                               │   │
│  │  □ Configure VPC and firewall                                       │   │
│  │  □ Provision VM (Terraform)                                         │   │
│  │  □ Configure base OS                                                │   │
│  │  □ Install Docker                                                   │   │
│  │  □ Create GitHub repository                                         │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  PHASE 2: CORE SERVICES (Week 2-3)                                         │
│  ═══════════════════════════════════                                       │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  □ Deploy MeiliSearch container                                     │   │
│  │  □ Implement indexer script                                         │   │
│  │  □ Set up file watcher                                              │   │
│  │  □ Configure auditd                                                 │   │
│  │  □ fluent-bit → GCP Logging                                         │   │
│  │  □ Create backup scripts                                            │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  PHASE 3: USER SETUP (Week 3-4)                                            │
│  ════════════════════════════════                                          │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  □ Linux users for all team members                                 │   │
│  │  □ Configure SSH keys                                               │   │
│  │  □ Groups and permissions                                           │   │
│  │  □ Create CODEOWNERS file                                           │   │
│  │  □ Implement pre-commit hooks                                       │   │
│  │  □ File locking script                                              │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  PHASE 4: CLIENT SETUP (Week 4)                                            │
│  ═══════════════════════════════                                           │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  □ Create onboarding script                                         │   │
│  │  □ Obsidian Git Plugin guide                                        │   │
│  │  □ SSH config templates                                             │   │
│  │  □ CLI tools (kb search, etc.)                                      │   │
│  │  □ AGENTS.md for LLM integration                                    │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  PHASE 5: MONITORING & DOCS (Week 5)                                       │
│  ═════════════════════════════════════                                     │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  □ GCP Monitoring dashboards                                        │   │
│  │  □ Alerting (Slack integration)                                     │   │
│  │  □ Health check scripts                                             │   │
│  │  □ Runbooks for incidents                                           │   │
│  │  □ Team training                                                    │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  PHASE 6: MIGRATION & GO-LIVE (Week 6)                                     │
│  ═══════════════════════════════════════                                   │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  □ Migrate existing docs                                            │   │
│  │  □ Add frontmatter to all docs                                      │   │
│  │  □ Complete indexing                                                │   │
│  │  □ Go-live announcement                                             │   │
│  │  □ Collect feedback                                                 │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 11. Risks and Mitigations

| Risk | Probability | Impact | Mitigation |
|--------|-------------------|------------|------------|
| Data loss | Low | High | Git + Daily Snapshots + GitHub |
| Server outage | Low | Medium | GCP SLA, local Git copies |
| Merge conflicts | Medium | Low | Ownership model, file locking |
| Performance issues | Low | Medium | Monitoring, scaling possible |
| Security incident | Low | High | Audit, immutable logs, alerting |
| Adoption problems | Medium | Medium | Training, simple onboarding |

---

## 12. Success Criteria

| Metric | Target | Measurement |
|--------|------|---------|
| Search latency | <100ms | MeiliSearch metrics |
| Document findability | >90% in <30s | User feedback |
| Sync latency | <10 min | Git Push → Server Pull |
| Uptime | >99.5% | GCP Monitoring |
| Adoption | 100% Team | Usage statistics |
| Conflicts per week | <3 | Git merge statistics |

---

## 13. Summary

The TeamOS Knowledge Platform provides:

- **Unified Knowledge Store**: Markdown-based, Git-versioned
- **Fast Search**: MeiliSearch with <50ms latency
- **Flexible Access**: CLI (SSH) and GUI (Obsidian)
- **Complete Audit**: All actions traceable
- **Conflict Management**: Ownership + Locking + Git
- **Cost Effective**: ~$15-20 per person/month

The architecture is modular and can be extended as needed (e.g., Semantic Search, CouchDB for real-time sync).

---

## Appendix A: References to Other Concept Papers

| Document | Topic |
|----------|-------|
| 01-knowledge-base-document-search.md | Knowledge Base & Search |
| 02-server-setup-audit-monitoring.md | Server, Audit, Monitoring |
| 03-obsidian-remote-access.md | Client Access |
| 04-conflict-handling.md | Conflict Management |

---

## Appendix B: Technology Stack Summary

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           TECHNOLOGY STACK                                  │
│                                                                             │
│  INFRASTRUCTURE                                                             │
│  ├── Cloud: Google Cloud Platform                                          │
│  ├── Compute: Compute Engine (e2-standard-4)                               │
│  ├── Storage: Persistent Disk (SSD)                                        │
│  └── Network: VPC, Firewall, Private IP                                    │
│                                                                             │
│  SERVER                                                                     │
│  ├── OS: Ubuntu 24.04 LTS                                                  │
│  ├── Container: Docker                                                     │
│  ├── Search: MeiliSearch                                                   │
│  ├── Audit: auditd                                                         │
│  └── Logging: fluent-bit                                                   │
│                                                                             │
│  VERSION CONTROL                                                            │
│  ├── VCS: Git                                                              │
│  ├── Remote: GitHub (Private)                                              │
│  └── Hooks: Pre-commit (Frontmatter Validation)                            │
│                                                                             │
│  CLIENT                                                                     │
│  ├── GUI: Obsidian + Git Plugin                                            │
│  ├── CLI: SSH + OpenCode/Gemini CLI                                        │
│  └── Sync: Git Push/Pull                                                   │
│                                                                             │
│  OBSERVABILITY                                                              │
│  ├── Logs: GCP Cloud Logging                                               │
│  ├── Metrics: GCP Cloud Monitoring                                         │
│  └── Alerts: Slack Integration                                             │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Related Documents

- [[00-vision]]
- [[01-knowledge-base-document-search]]
- [[08-hybrid-search-vector-database]]
