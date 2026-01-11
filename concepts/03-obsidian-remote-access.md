# Konzeptpapier: Obsidian & Remote Server Access

**Version:** 1.0  
**Datum:** 2025-01-10  
**Status:** Entwurf  
**Autor:** IT Architecture Team

---

## 1. Executive Summary

Dieses Dokument beschreibt, wie Teammitglieder von ihren lokalen Computern auf den zentralen Knowledge-Server zugreifen können. Es werden verschiedene Methoden für den Zugang evaluiert, mit besonderem Fokus auf die Integration von Obsidian als GUI-basiertem Markdown-Editor neben den CLI-Tools (OpenCode, Gemini CLI).

---

## 2. Anforderungen

### 2.1 Funktionale Anforderungen

| Anforderung | Beschreibung |
|-------------|--------------|
| CLI-Zugang | SSH-basierter Zugang für OpenCode/Gemini CLI |
| GUI-Zugang | Obsidian für visuelles Navigieren und Bearbeiten |
| Offline-Fähigkeit | Arbeiten auch ohne Netzwerkverbindung |
| Synchronisation | Änderungen werden zwischen lokal und Server synchronisiert |
| Multi-Device | Zugang von Laptop, Desktop, ggf. Tablet |

### 2.2 Nicht-funktionale Anforderungen

| Anforderung | Beschreibung |
|-------------|--------------|
| Latenz | <100ms für Dateioperationen |
| Zuverlässigkeit | Keine Datenverluste bei Verbindungsabbruch |
| Sicherheit | Verschlüsselte Übertragung, Authentifizierung |
| Einfachheit | Minimaler Setup-Aufwand für neue Teammitglieder |

---

## 3. Zugangsoptionen im Überblick

```
┌─────────────────────────────────────────────────────────────────┐
│                    Zugangsoptionen                              │
│                                                                 │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐ │
│  │   Option A      │  │   Option B      │  │   Option C      │ │
│  │   SSH + CLI     │  │   SSHFS Mount   │  │   Git Sync      │ │
│  │                 │  │                 │  │                 │ │
│  │  Terminal-only  │  │  Filesystem     │  │  Offline-first  │ │
│  │  Server-side    │  │  Remote Mount   │  │  Bidirektional  │ │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘ │
│                                                                 │
│  ┌─────────────────┐  ┌─────────────────┐                      │
│  │   Option D      │  │   Option E      │                      │
│  │   Syncthing     │  │   Obsidian      │                      │
│  │                 │  │   Livesync      │                      │
│  │  P2P Sync       │  │  Real-time      │                      │
│  │  Dezentral      │  │  CouchDB-based  │                      │
│  └─────────────────┘  └─────────────────┘                      │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## 4. Option A: SSH + CLI (Basis)

### 4.1 Beschreibung

Direkter SSH-Zugang zum Server. Alle Arbeit findet auf dem Server statt.

```
┌──────────────┐         SSH          ┌──────────────┐
│   Laptop     │◄────────────────────►│   Server     │
│              │                       │              │
│  Terminal    │                       │  /shared/    │
│  (lokal)     │                       │  knowledge/  │
└──────────────┘                       └──────────────┘
```

### 4.2 Setup

```bash
# ~/.ssh/config auf dem Laptop
Host team-server
    HostName team-server.company.internal
    User admin
    IdentityFile ~/.ssh/id_ed25519
    ForwardAgent yes
    
# Verbinden
ssh team-server

# OpenCode auf dem Server nutzen
opencode
```

### 4.3 Bewertung

| Kriterium | Bewertung | Kommentar |
|-----------|-----------|-----------|
| Setup-Aufwand | ⭐⭐⭐⭐⭐ | Minimal |
| Offline-Fähigkeit | ⭐ | Keine |
| Latenz | ⭐⭐⭐ | Abhängig von Netzwerk |
| Obsidian-Integration | ⭐ | Nicht möglich |
| Konflikt-Risiko | ⭐⭐⭐⭐⭐ | Keins (alles auf Server) |

**Empfehlung**: Basis-Zugang für CLI-Arbeit, aber nicht ausreichend für Obsidian.

---

## 5. Option B: SSHFS Mount

### 5.1 Beschreibung

Der Server-Ordner wird als lokales Dateisystem gemountet. Obsidian kann direkt darauf zugreifen.

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
# macFUSE installieren (einmalig)
brew install --cask macfuse
brew install gromgit/fuse/sshfs-mac

# Mount-Punkt erstellen
mkdir -p ~/knowledge

# Mounten
sshfs admin@team-server:/shared/knowledge ~/knowledge \
    -o reconnect \
    -o ServerAliveInterval=15 \
    -o ServerAliveCountMax=3 \
    -o volname=TeamKnowledge

# Unmounten
umount ~/knowledge
```

### 5.3 Automatisches Mounten (macOS)

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

### 5.4 Bewertung

| Kriterium | Bewertung | Kommentar |
|-----------|-----------|-----------|
| Setup-Aufwand | ⭐⭐⭐ | macFUSE Installation nötig |
| Offline-Fähigkeit | ⭐ | Keine |
| Latenz | ⭐⭐ | Spürbar bei großen Vaults |
| Obsidian-Integration | ⭐⭐⭐⭐ | Funktioniert, aber langsam |
| Konflikt-Risiko | ⭐⭐ | Last-Write-Wins |

**Empfehlung**: Funktioniert, aber Latenz kann bei großen Vaults störend sein.

---

## 6. Option C: Git Sync (Empfohlen)

### 6.1 Beschreibung

Lokale Kopie des Vaults, synchronisiert via Git. Obsidian Git Plugin für automatische Sync.

```
┌──────────────────────────────────────────────────────────────┐
│                         Laptop                                │
│                                                               │
│  ┌─────────────────┐                ┌─────────────────┐      │
│  │    Obsidian     │◄──────────────►│  ~/knowledge/   │      │
│  │  + Git Plugin   │                │  (lokale Kopie) │      │
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

#### Server-Seite

```bash
# Auf dem Server
cd /shared/knowledge
git init
git remote add origin git@github.com:company/knowledge-base.git
git add -A
git commit -m "Initial commit"
git push -u origin main

# Auto-Pull via Cron (alle 5 Minuten)
echo "*/5 * * * * cd /shared/knowledge && git pull --rebase" | crontab -
```

#### Client-Seite (Laptop)

```bash
# Repository klonen
git clone git@github.com:company/knowledge-base.git ~/knowledge

# Obsidian öffnen mit diesem Vault
open -a Obsidian ~/knowledge
```

#### Obsidian Git Plugin

1. Community Plugins aktivieren
2. "Obsidian Git" Plugin installieren
3. Konfiguration:

```
Vault backup interval: 5 (Minuten)
Auto pull interval: 5 (Minuten)
Commit message: {{date}} - {{hostname}}
Pull updates on startup: true
Push on backup: true
```

### 6.3 Bewertung

| Kriterium | Bewertung | Kommentar |
|-----------|-----------|-----------|
| Setup-Aufwand | ⭐⭐⭐⭐ | Git + Plugin |
| Offline-Fähigkeit | ⭐⭐⭐⭐⭐ | Vollständig |
| Latenz | ⭐⭐⭐⭐⭐ | Lokal = instant |
| Obsidian-Integration | ⭐⭐⭐⭐⭐ | Perfekt |
| Konflikt-Risiko | ⭐⭐⭐ | Merge-Konflikte möglich |

**Empfehlung**: Beste Option für die meisten Use Cases.

---

## 7. Option D: Syncthing

### 7.1 Beschreibung

Peer-to-Peer Synchronisation ohne zentralen Server. Alle Geräte synchronisieren direkt miteinander.

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
# Auf Server
sudo apt install syncthing
sudo systemctl enable syncthing@root
sudo systemctl start syncthing@root

# Web UI: http://localhost:8384

# Auf Laptop (macOS)
brew install syncthing
brew services start syncthing

# Web UI: http://localhost:8384
```

### 7.3 Syncthing Konfiguration

```xml
<!-- ~/.config/syncthing/config.xml -->
<folder id="knowledge" label="Knowledge Base" path="/shared/knowledge">
    <device id="LAPTOP-A-ID" introducedBy=""/>
    <device id="LAPTOP-B-ID" introducedBy=""/>
    <device id="SERVER-ID" introducedBy=""/>
    
    <!-- Konflikt-Handling -->
    <maxConflicts>10</maxConflicts>
</folder>
```

### 7.4 Bewertung

| Kriterium | Bewertung | Kommentar |
|-----------|-----------|-----------|
| Setup-Aufwand | ⭐⭐⭐ | Syncthing auf allen Geräten |
| Offline-Fähigkeit | ⭐⭐⭐⭐⭐ | Vollständig |
| Latenz | ⭐⭐⭐⭐⭐ | Lokal = instant |
| Obsidian-Integration | ⭐⭐⭐⭐⭐ | Perfekt |
| Konflikt-Risiko | ⭐⭐⭐ | Erstellt .sync-conflict Files |

**Empfehlung**: Gute Alternative zu Git, aber weniger Version Control.

---

## 8. Option E: Obsidian Livesync

### 8.1 Beschreibung

Real-time Synchronisation via CouchDB. Änderungen werden sofort synchronisiert.

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
# docker-compose.yml auf Server
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

### 8.3 Obsidian Plugin Konfiguration

1. "Self-hosted LiveSync" Plugin installieren
2. Remote Database URI: `http://server:5984/obsidian`
3. Username/Password eingeben
4. "Setup" → "Rebuild everything"

### 8.4 Bewertung

| Kriterium | Bewertung | Kommentar |
|-----------|-----------|-----------|
| Setup-Aufwand | ⭐⭐ | CouchDB + Plugin |
| Offline-Fähigkeit | ⭐⭐⭐⭐ | Ja, mit Sync bei Reconnect |
| Latenz | ⭐⭐⭐⭐⭐ | Real-time |
| Obsidian-Integration | ⭐⭐⭐⭐⭐ | Native |
| Konflikt-Risiko | ⭐⭐⭐⭐ | CRDT-basiert (automatisch) |

**Empfehlung**: Beste Real-time Experience, aber zusätzliche Infrastruktur (CouchDB).

---

## 9. Empfohlene Lösung: Hybrid-Ansatz

### 9.1 Architektur

```
┌─────────────────────────────────────────────────────────────────┐
│                    Hybrid-Lösung                                │
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
│  │   OpenCode / Gemini CLI arbeiten hier direkt            │   │
│  │                                                          │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### 9.2 Workflow

1. **Obsidian-Nutzer**: Arbeiten lokal, Git Plugin synct automatisch
2. **CLI-Nutzer**: SSH auf Server, arbeiten direkt in `/shared/knowledge`
3. **Synchronisation**: Git als Single Source of Truth
4. **Konflikt-Handling**: Git Merge (siehe Konzeptpapier 04)

### 9.3 Vorteile

- ✅ Offline-Fähigkeit für Obsidian-Nutzer
- ✅ Keine Latenz bei lokaler Arbeit
- ✅ Vollständige Version History
- ✅ CLI und GUI können parallel genutzt werden
- ✅ Keine zusätzliche Infrastruktur (nur GitHub)

---

## 10. Onboarding-Prozess

### 10.1 Für neue Teammitglieder

```bash
#!/bin/bash
# onboard-user.sh

echo "=== Team Knowledge Base Onboarding ==="

# 1. SSH Key generieren (falls nicht vorhanden)
if [ ! -f ~/.ssh/id_ed25519 ]; then
    ssh-keygen -t ed25519 -C "$USER@company.com"
fi

# 2. Public Key anzeigen (für Server-Admin)
echo ""
echo "Bitte sende diesen Public Key an den Admin:"
cat ~/.ssh/id_ed25519.pub
echo ""

# 3. Repository klonen
read -p "GitHub-Zugang eingerichtet? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    git clone git@github.com:company/knowledge-base.git ~/knowledge
fi

# 4. Obsidian konfigurieren
echo ""
echo "Obsidian Setup:"
echo "1. Öffne Obsidian"
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

echo "Setup complete! Du kannst jetzt:"
echo "  - Obsidian nutzen für GUI-Zugang"
echo "  - 'ssh team-server' für CLI-Zugang"
```

### 10.2 Checkliste

- [ ] SSH Key generiert
- [ ] SSH Key auf Server hinterlegt
- [ ] GitHub-Zugang eingerichtet
- [ ] Repository geklont
- [ ] Obsidian installiert
- [ ] Obsidian Git Plugin konfiguriert
- [ ] SSH Config eingerichtet
- [ ] Test: Datei erstellen, pushen, auf Server prüfen

---

## 11. Troubleshooting

### 11.1 Häufige Probleme

| Problem | Ursache | Lösung |
|---------|---------|--------|
| SSHFS mount hängt | Netzwerk-Timeout | `umount -f ~/knowledge` |
| Git Push rejected | Remote hat neuere Änderungen | `git pull --rebase` |
| Obsidian Git Plugin synct nicht | Plugin deaktiviert | Plugin neu aktivieren |
| Merge-Konflikt | Gleichzeitige Bearbeitung | Siehe Konzeptpapier 04 |
| SSH Permission denied | Falscher Key | `ssh -v team-server` für Debug |

### 11.2 Debug-Befehle

```bash
# SSH Verbindung testen
ssh -v team-server

# Git Remote prüfen
git remote -v

# Git Status
git status

# Obsidian Git Plugin Logs
# In Obsidian: Ctrl+Shift+I → Console

# SSHFS Debug
sshfs -o debug admin@team-server:/shared/knowledge ~/knowledge
```

---

## 12. Sicherheitsaspekte

### 12.1 SSH Key Management

```bash
# Ed25519 Keys verwenden (sicherer als RSA)
ssh-keygen -t ed25519 -C "user@company.com"

# Key mit Passphrase schützen
# (wird beim Generieren abgefragt)

# SSH Agent für Passphrase-Caching
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_ed25519
```

### 12.2 GitHub Repository Sicherheit

- Private Repository
- Branch Protection für `main`
- Require Pull Request Reviews (optional)
- Signed Commits (optional)

### 12.3 Lokale Sicherheit

```bash
# Vault-Ordner verschlüsseln (macOS)
# FileVault aktivieren (System Preferences → Security)

# Oder: Encrypted Sparse Bundle
hdiutil create -size 10g -type SPARSEBUNDLE -encryption AES-256 \
    -fs APFS -volname "Knowledge" ~/knowledge.sparsebundle
```

---

## 13. Zusammenfassung

### Empfohlene Konfiguration

| Komponente | Lösung |
|------------|--------|
| **Primärer Zugang** | Git Sync + Obsidian Git Plugin |
| **CLI-Zugang** | SSH direkt auf Server |
| **Backup-Zugang** | SSHFS (bei Git-Problemen) |
| **Version Control** | GitHub Private Repository |

### Entscheidungsmatrix

| Wenn... | Dann... |
|---------|---------|
| Nur CLI-Arbeit | SSH auf Server |
| Obsidian + Offline | Git Sync |
| Real-time Collaboration | Obsidian Livesync (+ CouchDB) |
| Einfachster Setup | SSHFS |
| Maximale Kontrolle | Git Sync |

---

## Anhang A: Referenzen

- [Obsidian Git Plugin](https://github.com/denolehov/obsidian-git)
- [Obsidian Livesync](https://github.com/vrtmrz/obsidian-livesync)
- [SSHFS](https://github.com/libfuse/sshfs)
- [Syncthing](https://syncthing.net/)
- [macFUSE](https://osxfuse.github.io/)
