# Concept Paper: Obsidian & Remote Server Access

**Version:** 1.1  
**Date:** 2025-01-11  
**Status:** Implemented  
**Author:** TeamOS

---

## 1. Executive Summary

This document describes how team members can access the central knowledge server from their local computers. Various access methods are evaluated, with a special focus on integrating Obsidian as a GUI-based Markdown editor alongside CLI tools (OpenCode, Gemini CLI).

---

## 2. Requirements

### 2.1 Functional Requirements

| Requirement | Description |
|-------------|-------------|
| CLI Access | SSH-based access for OpenCode/Gemini CLI |
| GUI Access | Obsidian for visual navigation and editing |
| Offline Capability | Work even without network connection |
| Synchronization | Changes are synchronized between local and server |
| Multi-Device | Access from laptop, desktop, optionally tablet |

### 2.2 Non-Functional Requirements

| Requirement | Description |
|-------------|-------------|
| Latency | <100ms for file operations |
| Reliability | No data loss on connection interruption |
| Security | Encrypted transmission, authentication |
| Simplicity | Minimal setup effort for new team members |

---

## 3. Access Options Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                    Access Options                               │
│                                                                 │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐ │
│  │   Option A      │  │   Option B      │  │   Option C      │ │
│  │   SSH + CLI     │  │   SSHFS Mount   │  │   Git Sync      │ │
│  │                 │  │                 │  │                 │ │
│  │  Terminal-only  │  │  Filesystem     │  │  Offline-first  │ │
│  │  Server-side    │  │  Remote Mount   │  │  Bidirectional  │ │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘ │
│                                                                 │
│  ┌─────────────────┐  ┌─────────────────┐                      │
│  │   Option D      │  │   Option E      │                      │
│  │   Syncthing     │  │   Obsidian      │                      │
│  │                 │  │   Livesync      │                      │
│  │  P2P Sync       │  │  Real-time      │                      │
│  │  Decentralized  │  │  CouchDB-based  │                      │
│  └─────────────────┘  └─────────────────┘                      │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## 4. Option A: SSH + CLI (Baseline)

### 4.1 Description

Direct SSH access to the server. All work takes place on the server.

```
┌──────────────┐         SSH          ┌──────────────┐
│   Laptop     │◄────────────────────►│   Server     │
│              │                       │              │
│  Terminal    │                       │  /shared/    │
│  (local)     │                       │  knowledge/  │
└──────────────┘                       └──────────────┘
```

### 4.2 Setup

```bash
# ~/.ssh/config on the laptop
Host team-server
    HostName team-server.company.internal
    User admin
    IdentityFile ~/.ssh/id_ed25519
    ForwardAgent yes
    
# Connect
ssh team-server

# Use OpenCode on the server
opencode
```

### 4.3 Evaluation

| Criterion | Rating | Comment |
|-----------|--------|---------|
| Setup Effort | ⭐⭐⭐⭐⭐ | Minimal |
| Offline Capability | ⭐ | None |
| Latency | ⭐⭐⭐ | Depends on network |
| Obsidian Integration | ⭐ | Not possible |
| Conflict Risk | ⭐⭐⭐⭐⭐ | None (everything on server) |

**Recommendation**: Baseline access for CLI work, but not sufficient for Obsidian.

---

## 5. Option B: SSHFS Mount

### 5.1 Description

The server folder is mounted as a local filesystem. Obsidian can access it directly.

```
┌──────────────────────────────────────────────────────────────┐
│                         Laptop                                │
│                                                               │
│  ┌─────────────────┐      SSHFS      ┌─────────────────┐     │
│  │    Obsidian     │◄───────────────►│  ~/knowledge/   │     │
│  │                 │                  │  (mount point)  │     │
│  └─────────────────┘                  └────────┬────────┘     │
│                                                │              │
└────────────────────────────────────────────────┼──────────────┘
                                                 │ SSH/SFTP
                                                 ▼
┌──────────────────────────────────────────────────────────────┐
│                         Server                                │
│                                                               │
│                    /shared/knowledge/                         │
│                                                               │
└──────────────────────────────────────────────────────────────┘
```

### 5.2 Setup (macOS)

```bash
# Install macFUSE (one-time)
brew install --cask macfuse
brew install gromgit/fuse/sshfs-mac

# Create mount point
mkdir -p ~/knowledge

# Mount
sshfs admin@team-server:/shared/knowledge ~/knowledge \
    -o reconnect \
    -o ServerAliveInterval=15 \
    -o ServerAliveCountMax=3 \
    -o volname=TeamKnowledge

# Unmount
umount ~/knowledge
```

### 5.3 Automatic Mounting (macOS)

```bash
# ~/Library/LaunchAgents/com.company.sshfs-knowledge.plist
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.org/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.company.sshfs-knowledge</string>
    <key>ProgramArguments</key>
    <array>
        <string>/usr/local/bin/sshfs</string>
        <string>admin@team-server:/shared/knowledge</string>
        <string>/Users/admin/knowledge</string>
        <string>-o</string>
        <string>reconnect,ServerAliveInterval=15</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
</dict>
</plist>
```

### 5.4 Evaluation

| Criterion | Rating | Comment |
|-----------|--------|---------|
| Setup Effort | ⭐⭐⭐ | macFUSE installation required |
| Offline Capability | ⭐ | None |
| Latency | ⭐⭐ | Noticeable with large vaults |
| Obsidian Integration | ⭐⭐⭐⭐ | Works, but slow |
| Conflict Risk | ⭐⭐ | Last-Write-Wins |

**Recommendation**: Works, but latency can be disruptive with large vaults.

---

## 6. Option C: Git Sync (Recommended)

### 6.1 Description

Local copy of the vault, synchronized via Git. Obsidian Git Plugin for automatic sync.

```
┌──────────────────────────────────────────────────────────────┐
│                         Laptop                                │
│                                                               │
│  ┌─────────────────┐                ┌─────────────────┐      │
│  │    Obsidian     │◄──────────────►│  ~/knowledge/   │      │
│  │  + Git Plugin   │                │  (local copy)   │      │
│  └─────────────────┘                └────────┬────────┘      │
│                                              │               │
└──────────────────────────────────────────────┼───────────────┘
                                               │ git push/pull
                                               ▼
┌──────────────────────────────────────────────────────────────┐
│                    GitHub / GitLab                            │
│                    (Private Repo)                             │
└──────────────────────────────────────────────────────────────┘
                                               │
                                               │ git push/pull
                                               ▼
┌──────────────────────────────────────────────────────────────┐
│                         Server                                │
│                                                               │
│                    /shared/knowledge/                         │
│                    (Git Working Copy)                         │
│                                                               │
└──────────────────────────────────────────────────────────────┘
```

### 6.2 Setup

#### Server-Side

```bash
# On the server
cd /shared/knowledge
git init
git remote add origin git@github.com:company/knowledge-base.git
git add -A
git commit -m "Initial commit"
git push -u origin main

# Auto-Pull via Cron (every 5 minutes)
echo "*/5 * * * * cd /shared/knowledge && git pull --rebase" | crontab -
```

#### Client-Side (Laptop)

```bash
# Clone repository
git clone git@github.com:company/knowledge-base.git ~/knowledge

# Open Obsidian with this vault
open -a Obsidian ~/knowledge
```

#### Obsidian Git Plugin

1. Enable Community Plugins
2. Install "Obsidian Git" Plugin
3. Configuration:

```
Vault backup interval: 5 (minutes)
Auto pull interval: 5 (minutes)
Commit message: {{date}} - {{hostname}}
Pull updates on startup: true
Push on backup: true
```

### 6.3 Evaluation

| Criterion | Rating | Comment |
|-----------|--------|---------|
| Setup Effort | ⭐⭐⭐⭐ | Git + Plugin |
| Offline Capability | ⭐⭐⭐⭐⭐ | Full |
| Latency | ⭐⭐⭐⭐⭐ | Local = instant |
| Obsidian Integration | ⭐⭐⭐⭐⭐ | Perfect |
| Conflict Risk | ⭐⭐⭐ | Merge conflicts possible |

**Recommendation**: Best option for most use cases.

---

## 7. Option D: Syncthing

### 7.1 Description

Peer-to-peer synchronization without a central server. All devices synchronize directly with each other.

```
┌──────────────┐         Syncthing         ┌──────────────┐
│   Laptop A   │◄─────────────────────────►│   Laptop B   │
│              │                           │              │
└──────┬───────┘                           └──────┬───────┘
       │                                          │
       │              Syncthing                   │
       └──────────────────┬───────────────────────┘
                          │
                          ▼
                   ┌──────────────┐
                   │    Server    │
                   │              │
                   └──────────────┘
```

### 7.2 Setup

```bash
# On Server
sudo apt install syncthing
sudo systemctl enable syncthing@root
sudo systemctl start syncthing@root

# Web UI: http://localhost:8384

# On Laptop (macOS)
brew install syncthing
brew services start syncthing

# Web UI: http://localhost:8384
```

### 7.3 Syncthing Configuration

```xml
<!-- ~/.config/syncthing/config.xml -->
<folder id="knowledge" label="Knowledge Base" path="/shared/knowledge">
    <device id="LAPTOP-A-ID" introducedBy=""/>
    <device id="LAPTOP-B-ID" introducedBy=""/>
    <device id="SERVER-ID" introducedBy=""/>
    
    <!-- Conflict Handling -->
    <maxConflicts>10</maxConflicts>
</folder>
```

### 7.4 Evaluation

| Criterion | Rating | Comment |
|-----------|--------|---------|
| Setup Effort | ⭐⭐⭐ | Syncthing on all devices |
| Offline Capability | ⭐⭐⭐⭐⭐ | Full |
| Latency | ⭐⭐⭐⭐⭐ | Local = instant |
| Obsidian Integration | ⭐⭐⭐⭐⭐ | Perfect |
| Conflict Risk | ⭐⭐⭐ | Creates .sync-conflict files |

**Recommendation**: Good alternative to Git, but less version control.

---

## 8. Option E: Obsidian Livesync

### 8.1 Description

Real-time synchronization via CouchDB. Changes are synchronized immediately.

```
┌──────────────┐                           ┌──────────────┐
│   Laptop A   │                           │   Laptop B   │
│   Obsidian   │                           │   Obsidian   │
│  + Livesync  │                           │  + Livesync  │
└──────┬───────┘                           └──────┬───────┘
       │                                          │
       │              CouchDB                     │
       └──────────────────┬───────────────────────┘
                          │
                          ▼
                   ┌──────────────┐
                   │   CouchDB    │
                   │   Server     │
                   └──────────────┘
```

### 8.2 Setup

```yaml
# docker-compose.yml on Server
version: '3.8'
services:
  couchdb:
    image: couchdb:3
    ports:
      - "5984:5984"
    environment:
      - COUCHDB_USER=admin
      - COUCHDB_PASSWORD=secure_password
    volumes:
      - ./couchdb_data:/opt/couchdb/data
```

### 8.3 Obsidian Plugin Configuration

1. Install "Self-hosted LiveSync" Plugin
2. Remote Database URI: `http://server:5984/obsidian`
3. Enter Username/Password
4. "Setup" → "Rebuild everything"

### 8.4 Evaluation

| Criterion | Rating | Comment |
|-----------|--------|---------|
| Setup Effort | ⭐⭐ | CouchDB + Plugin |
| Offline Capability | ⭐⭐⭐⭐ | Yes, with sync on reconnect |
| Latency | ⭐⭐⭐⭐⭐ | Real-time |
| Obsidian Integration | ⭐⭐⭐⭐⭐ | Native |
| Conflict Risk | ⭐⭐⭐⭐ | CRDT-based (automatic) |

**Recommendation**: Best real-time experience, but requires additional infrastructure (CouchDB).

---

## 9. Recommended Solution: Hybrid Approach

### 9.1 Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    Hybrid Solution                              │
│                                                                 │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │                    Laptop                                │   │
│  │                                                          │   │
│  │   ┌─────────────┐         ┌─────────────┐               │   │
│  │   │  Obsidian   │◄───────►│ ~/knowledge │               │   │
│  │   │ + Git Plugin│         │ (Git Clone) │               │   │
│  │   └─────────────┘         └──────┬──────┘               │   │
│  │                                  │                       │   │
│  │   ┌─────────────┐                │ git push/pull        │   │
│  │   │  Terminal   │────────────────┼──────────────────┐   │   │
│  │   │  (SSH)      │                │                  │   │   │
│  │   └─────────────┘                │                  │   │   │
│  │                                  │                  │   │   │
│  └──────────────────────────────────┼──────────────────┼───┘   │
│                                     │                  │       │
│                                     ▼                  ▼       │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │                    GitHub                                │   │
│  │                 (Private Repo)                           │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                     │                          │
│                                     │ git pull (cron)          │
│                                     ▼                          │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │                    Server                                │   │
│  │                                                          │   │
│  │   /shared/knowledge/  ◄── Git Working Copy              │   │
│  │                                                          │   │
│  │   OpenCode / Gemini CLI work directly here              │   │
│  │                                                          │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### 9.2 Workflow

1. **Obsidian Users**: Work locally, Git Plugin syncs automatically
2. **CLI Users**: SSH to server, work directly in `/shared/knowledge`
3. **Synchronization**: Git as Single Source of Truth
4. **Conflict Handling**: Git Merge (see Concept Paper 04)

### 9.3 Advantages

- Offline capability for Obsidian users
- No latency during local work
- Complete version history
- CLI and GUI can be used in parallel
- No additional infrastructure required (only GitHub)

---

## 10. Onboarding Process

### 10.1 For New Team Members

```bash
#!/bin/bash
# onboard-user.sh

echo "=== Team Knowledge Base Onboarding ==="

# 1. Generate SSH Key (if not present)
if [ ! -f ~/.ssh/id_ed25519 ]; then
    ssh-keygen -t ed25519 -C "$USER@company.com"
fi

# 2. Display Public Key (for Server Admin)
echo ""
echo "Please send this public key to the admin:"
cat ~/.ssh/id_ed25519.pub
echo ""

# 3. Clone Repository
read -p "GitHub access configured? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    git clone git@github.com:company/knowledge-base.git ~/knowledge
fi

# 4. Configure Obsidian
echo ""
echo "Obsidian Setup:"
echo "1. Open Obsidian"
echo "2. 'Open folder as vault' → ~/knowledge"
echo "3. Settings → Community Plugins → Enable"
echo "4. Browse → 'Obsidian Git' → Install → Enable"
echo "5. Obsidian Git Settings:"
echo "   - Vault backup interval: 5"
echo "   - Auto pull interval: 5"
echo "   - Pull updates on startup: ON"
echo ""

# 5. SSH Config
cat << EOF >> ~/.ssh/config

Host team-server
    HostName team-server.company.internal
    User $USER
    IdentityFile ~/.ssh/id_ed25519
    ForwardAgent yes
EOF

echo "Setup complete! You can now:"
echo "  - Use Obsidian for GUI access"
echo "  - 'ssh team-server' for CLI access"
```

### 10.2 Checklist

- [ ] SSH Key generated
- [ ] SSH Key added to server
- [ ] GitHub access configured
- [ ] Repository cloned
- [ ] Obsidian installed
- [ ] Obsidian Git Plugin configured
- [ ] SSH Config set up
- [ ] Test: Create file, push, verify on server

---

## 11. Troubleshooting

### 11.1 Common Problems

| Problem | Cause | Solution |
|---------|-------|----------|
| SSHFS mount hangs | Network timeout | `umount -f ~/knowledge` |
| Git Push rejected | Remote has newer changes | `git pull --rebase` |
| Obsidian Git Plugin not syncing | Plugin disabled | Re-enable plugin |
| Merge conflict | Simultaneous editing | See Concept Paper 04 |
| SSH Permission denied | Wrong key | `ssh -v team-server` for debug |

### 11.2 Debug Commands

```bash
# Test SSH connection
ssh -v team-server

# Check Git Remote
git remote -v

# Git Status
git status

# Obsidian Git Plugin Logs
# In Obsidian: Ctrl+Shift+I → Console

# SSHFS Debug
sshfs -o debug admin@team-server:/shared/knowledge ~/knowledge
```

---

## 12. Security Aspects

### 12.1 SSH Key Management

```bash
# Use Ed25519 Keys (more secure than RSA)
ssh-keygen -t ed25519 -C "user@company.com"

# Protect key with passphrase
# (prompted during generation)

# SSH Agent for passphrase caching
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_ed25519
```

### 12.2 GitHub Repository Security

- Private Repository
- Branch Protection for `main`
- Require Pull Request Reviews (optional)
- Signed Commits (optional)

### 12.3 Local Security

```bash
# Encrypt vault folder (macOS)
# Enable FileVault (System Preferences → Security)

# Or: Encrypted Sparse Bundle
hdiutil create -size 10g -type SPARSEBUNDLE -encryption AES-256 \
    -fs APFS -volname "Knowledge" ~/knowledge.sparsebundle
```

---

## 13. Summary

### Recommended Configuration

| Component | Solution |
|-----------|----------|
| **Primary Access** | Git Sync + Obsidian Git Plugin |
| **CLI Access** | SSH directly to server |
| **Backup Access** | SSHFS (for Git issues) |
| **Version Control** | GitHub Private Repository |

### Decision Matrix

| If... | Then... |
|-------|---------|
| CLI work only | SSH to server |
| Obsidian + Offline | Git Sync |
| Real-time Collaboration | Obsidian Livesync (+ CouchDB) |
| Simplest Setup | SSHFS |
| Maximum Control | Git Sync |

---

## Appendix A: References

- [Obsidian Git Plugin](https://github.com/denolehov/obsidian-git)
- [Obsidian Livesync](https://github.com/vrtmrz/obsidian-livesync)
- [SSHFS](https://github.com/libfuse/sshfs)
- [Syncthing](https://syncthing.net/)
- [macFUSE](https://osxfuse.github.io/)

---

## Related Documents

- [[00-vision]]
- [[01-knowledge-base-document-search]]
- [[05-overall-architecture]]
