# Konzeptpapier: Gesamtarchitektur - TeamOS Knowledge Platform

**Version:** 1.0  
**Datum:** 2025-01-10  
**Status:** Entwurf  
**Autor:** IT Architecture Team

---

## 1. Executive Summary

Dieses Dokument beschreibt die Gesamtarchitektur der TeamOS Knowledge Platform - einer integrierten Lösung für team-weites Wissensmanagement, optimiert für die Nutzung mit AI-gestützten CLI-Tools (OpenCode, Gemini CLI) und traditionellen GUI-Tools (Obsidian). Die Architektur verbindet alle Komponenten aus den vorherigen Konzeptpapieren zu einem kohärenten System.

---

## 2. Vision

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                                                                             │
│                         "Knowledge at Your Fingertips"                      │
│                                                                             │
│   Ein Team von 10 IT-Spezialisten, die Tier 0/1 Enterprise Tools           │
│   (Entra ID, Google Workspace, Atlassian, Slack) verwalten, teilt          │
│   Wissen nahtlos über CLI und GUI, unterstützt von AI-Agenten.             │
│                                                                             │
│   Jedes Teammitglied kann:                                                  │
│   ✓ Wissen in Sekunden finden (nicht Minuten)                              │
│   ✓ Dokumentation erstellen, die AI-Agenten verstehen                      │
│   ✓ Offline arbeiten und später synchronisieren                            │
│   ✓ Nachvollziehen, wer was wann geändert hat                              │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 3. Architektur-Übersicht

### 3.1 High-Level Architektur

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

## 4. Komponenten-Übersicht

### 4.1 Komponenten-Matrix

| Komponente | Purpose | Technologie | Standort |
|------------|---------|-------------|----------|
| **Knowledge Store** | Markdown-Dateien speichern | Git + Filesystem | Server + GitHub |
| **Search Engine** | Volltextsuche | MeiliSearch | Server (Docker) |
| **Version Control** | Änderungshistorie | Git + GitHub | Dezentral |
| **Audit System** | Sicherheits-Logging | auditd | Server |
| **Log Aggregation** | Zentrale Logs | fluent-bit → GCP | Server → Cloud |
| **Monitoring** | Metriken & Alerts | GCP Monitoring | Cloud |
| **Client Access** | GUI-Zugang | Obsidian + Git | Laptops |
| **CLI Access** | Terminal-Zugang | SSH | Laptops → Server |

### 4.2 Komponenten-Diagramm

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         KOMPONENTEN & DATENFLUSS                            │
│                                                                             │
│                                                                             │
│   ┌─────────────┐                                                          │
│   │   MENSCH    │                                                          │
│   │  (Editor)   │                                                          │
│   └──────┬──────┘                                                          │
│          │                                                                  │
│          │ schreibt/liest                                                  │
│          ▼                                                                  │
│   ┌─────────────┐         ┌─────────────┐         ┌─────────────┐         │
│   │  Obsidian   │◄───────►│    Git      │◄───────►│   GitHub    │         │
│   │  (lokal)    │  sync   │  (lokal)    │  push   │  (remote)   │         │
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
│          │ indexiert             │ loggt                 │ forwarded       │
│          ▼                       ▼                       ▼                 │
│   ┌─────────────┐         ┌─────────────┐         ┌─────────────┐         │
│   │   Search    │         │   Audit     │         │ GCP Cloud   │         │
│   │   Index     │         │   Trail     │         │  Logging    │         │
│   └─────────────┘         └─────────────┘         └─────────────┘         │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 5. Detaillierte Komponenten-Beschreibung

### 5.1 Knowledge Store

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           KNOWLEDGE STORE                                   │
│                                                                             │
│  PURPOSE:                                                                   │
│  Zentrale Speicherung aller Dokumentation in Markdown-Format               │
│                                                                             │
│  TECHNOLOGIE:                                                               │
│  - Filesystem: ext4 auf GCP Persistent Disk                                │
│  - Version Control: Git                                                     │
│  - Remote: GitHub Private Repository                                        │
│                                                                             │
│  STRUKTUR:                                                                  │
│  /shared/knowledge/                                                         │
│  ├── .git/                    # Git Repository                             │
│  ├── .github/                                                              │
│  │   └── CODEOWNERS           # Ownership-Regeln                           │
│  ├── api-docs/                # API-Dokumentation                          │
│  │   ├── entra-id/                                                         │
│  │   ├── google-workspace/                                                 │
│  │   ├── atlassian/                                                        │
│  │   └── slack/                                                            │
│  ├── runbooks/                # Operative Runbooks                         │
│  ├── decisions/               # ADRs                                       │
│  ├── guides/                  # How-To Guides                              │
│  └── templates/               # Dokumentvorlagen                           │
│                                                                             │
│  INTEGRATION:                                                               │
│  - MeiliSearch indexiert alle .md Dateien                                  │
│  - Pre-commit Hooks validieren Frontmatter                                 │
│  - File Watcher triggert Re-Indexierung                                    │
│                                                                             │
│  DATENFLUSS:                                                                │
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
│  Schnelle Volltextsuche über alle Dokumente für Menschen und LLMs          │
│                                                                             │
│  TECHNOLOGIE:                                                               │
│  - MeiliSearch v1.6 (Docker Container)                                     │
│  - REST API auf Port 7700                                                  │
│  - ~500MB RAM für 10.000 Dokumente                                         │
│                                                                             │
│  FEATURES:                                                                  │
│  - Typo-tolerante Suche                                                    │
│  - Faceted Search (Tags, Kategorie, Autor)                                 │
│  - Sub-50ms Latenz                                                         │
│  - Real-time Indexierung via File Watcher                                  │
│                                                                             │
│  DATENFLUSS:                                                                │
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
│  API BEISPIEL:                                                              │
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
│  Nachvollziehbarkeit aller Aktionen für Compliance und Debugging           │
│                                                                             │
│  TECHNOLOGIE:                                                               │
│  - auditd (Linux Kernel Audit)                                             │
│  - fluent-bit (Log Forwarding)                                             │
│  - GCP Cloud Logging (Immutable Storage)                                   │
│                                                                             │
│  WAS WIRD GELOGGT:                                                          │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  - Alle Dateiänderungen in /shared/knowledge                        │   │
│  │  - SSH-Logins und -Logouts                                          │   │
│  │  - Sudo-Nutzung                                                     │   │
│  │  - User-Management (useradd, userdel, passwd)                       │   │
│  │  - Privilegierte Befehle                                            │   │
│  │  - Fehlgeschlagene Zugriffsversuche                                 │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  DATENFLUSS:                                                                │
│                                                                             │
│  ┌─────────────┐    syscall    ┌─────────────┐    log     ┌─────────────┐ │
│  │   Kernel    │──────────────►│   auditd    │───────────►│ /var/log/   │ │
│  │  (Aktionen) │               │             │            │ audit/      │ │
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
│  │  30+ Tage   │                                                          │
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
│  Zugang zur Knowledge Base von Mitarbeiter-Laptops                         │
│                                                                             │
│  ZWEI ZUGANGSARTEN:                                                         │
│                                                                             │
│  ┌─────────────────────────────────┐  ┌─────────────────────────────────┐  │
│  │         GUI ACCESS              │  │         CLI ACCESS              │  │
│  │                                 │  │                                 │  │
│  │  ┌─────────────┐               │  │  ┌─────────────┐               │  │
│  │  │  Obsidian   │               │  │  │  Terminal   │               │  │
│  │  │             │               │  │  │             │               │  │
│  │  └──────┬──────┘               │  │  └──────┬──────┘               │  │
│  │         │                       │  │         │                       │  │
│  │         │ liest/schreibt        │  │         │ SSH                   │  │
│  │         ▼                       │  │         ▼                       │  │
│  │  ┌─────────────┐               │  │  ┌─────────────┐               │  │
│  │  │ ~/knowledge │               │  │  │   Server    │               │  │
│  │  │ (Git Clone) │               │  │  │             │               │  │
│  │  └──────┬──────┘               │  │  └──────┬──────┘               │  │
│  │         │                       │  │         │                       │  │
│  │         │ Git Sync              │  │         │ direkt                │  │
│  │         ▼                       │  │         ▼                       │  │
│  │  ┌─────────────┐               │  │  ┌─────────────┐               │  │
│  │  │   GitHub    │               │  │  │  /shared/   │               │  │
│  │  │             │               │  │  │  knowledge/ │               │  │
│  │  └─────────────┘               │  │  └─────────────┘               │  │
│  │                                 │  │                                 │  │
│  │  VORTEILE:                      │  │  VORTEILE:                      │  │
│  │  - Offline-fähig                │  │  - Kein lokaler Clone nötig    │  │
│  │  - Schnelle Navigation          │  │  - Direkter Zugriff            │  │
│  │  - Graph View                   │  │  - OpenCode/Gemini CLI         │  │
│  │                                 │  │  - Immer aktuell               │  │
│  └─────────────────────────────────┘  └─────────────────────────────────┘  │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 6. Datenfluss-Diagramme

### 6.1 Dokument erstellen (GUI)

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    WORKFLOW: Dokument erstellen (Obsidian)                  │
│                                                                             │
│  1. User erstellt Datei in Obsidian                                        │
│     ┌─────────────┐                                                        │
│     │  Obsidian   │ → new-doc.md                                           │
│     └──────┬──────┘                                                        │
│            │                                                                │
│  2. Obsidian Git Plugin committed automatisch (alle 5 Min)                 │
│            │                                                                │
│            ▼                                                                │
│     ┌─────────────┐                                                        │
│     │  git add    │                                                        │
│     │  git commit │                                                        │
│     │  git push   │                                                        │
│     └──────┬──────┘                                                        │
│            │                                                                │
│  3. GitHub empfängt Push                                                   │
│            │                                                                │
│            ▼                                                                │
│     ┌─────────────┐                                                        │
│     │   GitHub    │                                                        │
│     │  (remote)   │                                                        │
│     └──────┬──────┘                                                        │
│            │                                                                │
│  4. Server pullt Änderungen (Cron alle 5 Min)                              │
│            │                                                                │
│            ▼                                                                │
│     ┌─────────────┐                                                        │
│     │   Server    │                                                        │
│     │  git pull   │                                                        │
│     └──────┬──────┘                                                        │
│            │                                                                │
│  5. File Watcher erkennt neue Datei                                        │
│            │                                                                │
│            ▼                                                                │
│     ┌─────────────┐                                                        │
│     │ MeiliSearch │ → Dokument indexiert                                   │
│     │   Indexer   │                                                        │
│     └─────────────┘                                                        │
│                                                                             │
│  LATENZ: ~5-10 Minuten bis Dokument auf Server und in Suche                │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 6.2 Dokument erstellen (CLI/LLM)

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    WORKFLOW: Dokument erstellen (CLI/LLM)                   │
│                                                                             │
│  1. User/LLM verbindet via SSH                                             │
│     ┌─────────────┐                                                        │
│     │  Terminal   │ → ssh team-server                                      │
│     └──────┬──────┘                                                        │
│            │                                                                │
│  2. Datei wird direkt auf Server erstellt                                  │
│            │                                                                │
│            ▼                                                                │
│     ┌─────────────┐                                                        │
│     │  OpenCode   │ → /shared/knowledge/new-doc.md                         │
│     │  (Server)   │                                                        │
│     └──────┬──────┘                                                        │
│            │                                                                │
│  3. File Watcher erkennt sofort                                            │
│            │                                                                │
│            ▼                                                                │
│     ┌─────────────┐                                                        │
│     │ MeiliSearch │ → Dokument indexiert                                   │
│     │   Indexer   │                                                        │
│     └──────┬──────┘                                                        │
│            │                                                                │
│  4. Git Commit (manuell oder via Hook)                                     │
│            │                                                                │
│            ▼                                                                │
│     ┌─────────────┐                                                        │
│     │  git add    │                                                        │
│     │  git commit │                                                        │
│     │  git push   │                                                        │
│     └──────┬──────┘                                                        │
│            │                                                                │
│  5. GitHub empfängt Push                                                   │
│            │                                                                │
│            ▼                                                                │
│     ┌─────────────┐                                                        │
│     │   GitHub    │                                                        │
│     └─────────────┘                                                        │
│                                                                             │
│  LATENZ: Sekunden bis Dokument in Suche, Minuten bis auf anderen Clients   │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 6.3 Dokument suchen

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    WORKFLOW: Dokument suchen                                │
│                                                                             │
│  OPTION A: CLI                                                              │
│  ┌─────────────┐                                                           │
│  │  Terminal   │ → kb search "Entra ID API"                                │
│  └──────┬──────┘                                                           │
│         │                                                                   │
│         │ REST API                                                          │
│         ▼                                                                   │
│  ┌─────────────┐                                                           │
│  │ MeiliSearch │ → Ergebnisse                                              │
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
│  │ MeiliSearch │ → JSON Response → LLM verarbeitet                         │
│  └─────────────┘                                                           │
│                                                                             │
│  OPTION C: Obsidian                                                         │
│  ┌─────────────┐                                                           │
│  │  Obsidian   │ → Lokale Suche (Ctrl+Shift+F)                             │
│  │  (lokal)    │ → Oder: Graph View Navigation                             │
│  └─────────────┘                                                           │
│                                                                             │
│  LATENZ: <50ms für MeiliSearch, instant für lokale Obsidian-Suche          │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 7. Sicherheitsarchitektur

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           SECURITY LAYERS                                   │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  LAYER 1: NETWORK                                                    │   │
│  │                                                                      │   │
│  │  - VPC mit Private IP                                               │   │
│  │  - Firewall: SSH nur von Office IP / VPN                            │   │
│  │  - Kein direkter Internet-Zugang für Services                       │   │
│  │  - IAP (Identity-Aware Proxy) optional                              │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                     │                                       │
│                                     ▼                                       │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  LAYER 2: AUTHENTICATION                                            │   │
│  │                                                                      │   │
│  │  - SSH Key-basiert (Ed25519)                                        │   │
│  │  - Keine Passwort-Authentifizierung                                 │   │
│  │  - Optional: SSO via Entra ID (OS Login)                            │   │
│  │  - GitHub: SSH Keys oder Personal Access Tokens                     │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                     │                                       │
│                                     ▼                                       │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  LAYER 3: AUTHORIZATION                                             │   │
│  │                                                                      │   │
│  │  - Linux Groups (users, docker, sudo)                               │   │
│  │  - File Permissions (SGID auf /shared)                              │   │
│  │  - CODEOWNERS für GitHub PRs                                        │   │
│  │  - Least Privilege Prinzip                                          │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                     │                                       │
│                                     ▼                                       │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  LAYER 4: AUDIT & MONITORING                                        │   │
│  │                                                                      │   │
│  │  - auditd für alle Dateioperationen                                 │   │
│  │  - Session Recording                                                │   │
│  │  - Immutable Logs in GCP Cloud Logging                              │   │
│  │  - Alerting bei verdächtigen Aktivitäten                            │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                     │                                       │
│                                     ▼                                       │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  LAYER 5: DATA PROTECTION                                           │   │
│  │                                                                      │   │
│  │  - Encryption at Rest (GCP Disk Encryption)                         │   │
│  │  - Encryption in Transit (SSH, HTTPS)                               │   │
│  │  - Git History für Datenwiederherstellung                           │   │
│  │  - Daily Backups (Snapshots + Git)                                  │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 8. Deployment-Architektur

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

## 9. Kosten-Schätzung

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           MONATLICHE KOSTEN (geschätzt)                     │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  COMPUTE                                                             │   │
│  │                                                                      │   │
│  │  e2-standard-4 (4 vCPU, 16 GB RAM)                                  │   │
│  │  Region: europe-west3                                                │   │
│  │  24/7 Betrieb                                                        │   │
│  │                                                                      │   │
│  │  Kosten: ~$100/Monat                                                │   │
│  │  (Mit Committed Use: ~$60/Monat)                                    │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  STORAGE                                                             │   │
│  │                                                                      │   │
│  │  Boot Disk: 50 GB SSD = ~$8/Monat                                   │   │
│  │  Data Disk: 200 GB SSD = ~$34/Monat                                 │   │
│  │  Snapshots: ~$5/Monat (geschätzt)                                   │   │
│  │                                                                      │   │
│  │  Kosten: ~$47/Monat                                                 │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  NETWORKING                                                          │   │
│  │                                                                      │   │
│  │  Egress: Minimal (SSH Traffic)                                      │   │
│  │  Keine externe IP = keine NAT-Kosten                                │   │
│  │                                                                      │   │
│  │  Kosten: ~$5/Monat                                                  │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  LOGGING & MONITORING                                                │   │
│  │                                                                      │   │
│  │  Cloud Logging: 50 GB/Monat kostenlos                               │   │
│  │  Cloud Monitoring: Basis kostenlos                                  │   │
│  │                                                                      │   │
│  │  Kosten: ~$0/Monat (unter Free Tier)                                │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  GITHUB                                                              │   │
│  │                                                                      │   │
│  │  GitHub Team: $4/User/Monat × 10 User                               │   │
│  │                                                                      │   │
│  │  Kosten: ~$40/Monat                                                 │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  ═══════════════════════════════════════════════════════════════════════   │
│                                                                             │
│  GESAMT: ~$190-200/Monat                                                   │
│  (Mit Committed Use Discounts: ~$150/Monat)                                │
│                                                                             │
│  PRO PERSON: ~$15-20/Monat                                                 │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 10. Implementierungs-Roadmap

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           IMPLEMENTIERUNGS-ROADMAP                          │
│                                                                             │
│  PHASE 1: FOUNDATION (Woche 1-2)                                           │
│  ════════════════════════════════                                          │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  □ GCP Projekt einrichten                                           │   │
│  │  □ VPC und Firewall konfigurieren                                   │   │
│  │  □ VM provisionieren (Terraform)                                    │   │
│  │  □ Basis-OS konfigurieren                                           │   │
│  │  □ Docker installieren                                              │   │
│  │  □ GitHub Repository erstellen                                      │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  PHASE 2: CORE SERVICES (Woche 2-3)                                        │
│  ═══════════════════════════════════                                       │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  □ MeiliSearch Container deployen                                   │   │
│  │  □ Indexer-Script implementieren                                    │   │
│  │  □ File Watcher einrichten                                          │   │
│  │  □ auditd konfigurieren                                             │   │
│  │  □ fluent-bit → GCP Logging                                         │   │
│  │  □ Backup-Skripte erstellen                                         │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  PHASE 3: USER SETUP (Woche 3-4)                                           │
│  ════════════════════════════════                                          │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  □ Linux User für alle Teammitglieder                               │   │
│  │  □ SSH Keys konfigurieren                                           │   │
│  │  □ Gruppen und Berechtigungen                                       │   │
│  │  □ CODEOWNERS Datei erstellen                                       │   │
│  │  □ Pre-commit Hooks implementieren                                  │   │
│  │  □ File Locking Script                                              │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  PHASE 4: CLIENT SETUP (Woche 4)                                           │
│  ═══════════════════════════════                                           │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  □ Onboarding-Skript erstellen                                      │   │
│  │  □ Obsidian Git Plugin Anleitung                                    │   │
│  │  □ SSH Config Templates                                             │   │
│  │  □ CLI Tools (kb search, etc.)                                      │   │
│  │  □ AGENTS.md für LLM-Integration                                    │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  PHASE 5: MONITORING & DOCS (Woche 5)                                      │
│  ═════════════════════════════════════                                     │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  □ GCP Monitoring Dashboards                                        │   │
│  │  □ Alerting (Slack Integration)                                     │   │
│  │  □ Health Check Skripte                                             │   │
│  │  □ Runbooks für Incidents                                           │   │
│  │  □ Team-Schulung                                                    │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  PHASE 6: MIGRATION & GO-LIVE (Woche 6)                                    │
│  ═══════════════════════════════════════                                   │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  □ Bestehende Docs migrieren                                        │   │
│  │  □ Frontmatter zu allen Docs hinzufügen                             │   │
│  │  □ Vollständige Indexierung                                         │   │
│  │  □ Go-Live Announcement                                             │   │
│  │  □ Feedback sammeln                                                 │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 11. Risiken und Mitigationen

| Risiko | Wahrscheinlichkeit | Auswirkung | Mitigation |
|--------|-------------------|------------|------------|
| Datenverlust | Niedrig | Hoch | Git + Daily Snapshots + GitHub |
| Server-Ausfall | Niedrig | Mittel | GCP SLA, lokale Git-Kopien |
| Merge-Konflikte | Mittel | Niedrig | Ownership-Modell, File Locking |
| Performance-Probleme | Niedrig | Mittel | Monitoring, Skalierung möglich |
| Sicherheitsvorfall | Niedrig | Hoch | Audit, Immutable Logs, Alerting |
| Adoption-Probleme | Mittel | Mittel | Schulung, einfaches Onboarding |

---

## 12. Erfolgskriterien

| Metrik | Ziel | Messung |
|--------|------|---------|
| Suchlatenz | <100ms | MeiliSearch Metriken |
| Dokument-Auffindbarkeit | >90% in <30s | User-Feedback |
| Sync-Latenz | <10 Min | Git Push → Server Pull |
| Uptime | >99.5% | GCP Monitoring |
| Adoption | 100% Team | Nutzungsstatistiken |
| Konflikte pro Woche | <3 | Git Merge-Statistiken |

---

## 13. Zusammenfassung

Die TeamOS Knowledge Platform bietet:

- **Unified Knowledge Store**: Markdown-basiert, Git-versioniert
- **Schnelle Suche**: MeiliSearch mit <50ms Latenz
- **Flexible Zugänge**: CLI (SSH) und GUI (Obsidian)
- **Vollständiges Audit**: Alle Aktionen nachvollziehbar
- **Konflikt-Management**: Ownership + Locking + Git
- **Kosteneffizient**: ~$15-20 pro Person/Monat

Die Architektur ist modular aufgebaut und kann bei Bedarf erweitert werden (z.B. Semantic Search, CouchDB für Real-time Sync).

---

## Anhang A: Referenzen zu anderen Konzeptpapieren

| Dokument | Thema |
|----------|-------|
| 01-knowledge-base-document-search.md | Knowledge Base & Suche |
| 02-server-setup-audit-monitoring.md | Server, Audit, Monitoring |
| 03-obsidian-remote-access.md | Client-Zugang |
| 04-conflict-handling.md | Konflikt-Management |

---

## Anhang B: Technologie-Stack Zusammenfassung

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           TECHNOLOGIE-STACK                                 │
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
