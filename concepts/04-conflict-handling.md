# Konzeptpapier: Konflikt-Handling und Lösungsstrategien

**Version:** 1.0  
**Datum:** 2025-01-10  
**Status:** Entwurf  
**Autor:** IT Architecture Team

---

## 1. Executive Summary

Dieses Dokument analysiert die verschiedenen Arten von Konflikten, die bei der gemeinsamen Nutzung einer Knowledge Base auftreten können, und präsentiert Strategien zu deren Vermeidung und Lösung. Der Fokus liegt auf praktikablen Lösungen für ein Team von 10 Personen, die sowohl mit CLI-Tools (OpenCode, Gemini CLI) als auch mit GUI-Tools (Obsidian) arbeiten.

---

## 2. Konflikt-Taxonomie

### 2.1 Arten von Konflikten

```
┌─────────────────────────────────────────────────────────────────┐
│                    Konflikt-Arten                               │
│                                                                 │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  1. WRITE-WRITE KONFLIKT                                 │   │
│  │     Zwei Personen bearbeiten dieselbe Datei gleichzeitig │   │
│  │     → Änderungen überschreiben sich                      │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                 │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  2. READ-WRITE KONFLIKT                                  │   │
│  │     Person A liest Datei, Person B ändert sie           │   │
│  │     → Person A arbeitet mit veralteten Daten            │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                 │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  3. STRUKTURKONFLIKT                                     │   │
│  │     Datei wird verschoben/umbenannt während bearbeitet  │   │
│  │     → Verwaiste Änderungen, doppelte Dateien            │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                 │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  4. SEMANTISCHER KONFLIKT                                │   │
│  │     Änderungen sind syntaktisch kompatibel, aber        │   │
│  │     inhaltlich widersprüchlich                          │   │
│  │     → Inkonsistente Dokumentation                       │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### 2.2 Konflikt-Wahrscheinlichkeit

| Szenario | Wahrscheinlichkeit | Auswirkung |
|----------|-------------------|------------|
| Zwei Personen bearbeiten dieselbe Datei | Mittel | Hoch |
| LLM und Mensch bearbeiten gleichzeitig | Hoch | Mittel |
| Strukturänderungen während Bearbeitung | Niedrig | Hoch |
| Semantische Widersprüche | Mittel | Mittel |

---

## 3. Konflikt-Vermeidungsstrategien

### 3.1 Strategie 1: File Locking (Pessimistisch)

```
┌─────────────────────────────────────────────────────────────────┐
│                    File Locking                                 │
│                                                                 │
│  Zeitpunkt t=0:                                                │
│  ┌─────────────┐                    ┌─────────────┐            │
│  │   User A    │                    │   User B    │            │
│  │  will edit  │                    │  will edit  │            │
│  └──────┬──────┘                    └──────┬──────┘            │
│         │                                  │                    │
│         ▼                                  │                    │
│  ┌─────────────┐                           │                    │
│  │ doc.md.lock │ ← Lock erstellt           │                    │
│  │ "user_a"    │                           │                    │
│  └─────────────┘                           │                    │
│         │                                  ▼                    │
│         │                           ┌─────────────┐            │
│         │                           │   BLOCKED   │            │
│         │                           │ "Locked by  │            │
│         │                           │  User A"    │            │
│         │                           └─────────────┘            │
│         ▼                                                       │
│  ┌─────────────┐                                               │
│  │   EDITING   │                                               │
│  └─────────────┘                                               │
│         │                                                       │
│         ▼                                                       │
│  ┌─────────────┐                                               │
│  │ Lock removed│ → User B kann jetzt bearbeiten               │
│  └─────────────┘                                               │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

#### Implementierung

```bash
#!/bin/bash
# /usr/local/bin/kb-lock

KNOWLEDGE_DIR="/shared/knowledge"
LOCK_TIMEOUT=3600  # 1 Stunde

lock_file() {
    local file="$1"
    local lockfile="${file}.lock"
    local user="${USER_EMAIL:-$USER}"
    local timestamp=$(date +%s)
    
    # Prüfe ob Lock existiert
    if [ -f "$lockfile" ]; then
        local lock_info=$(cat "$lockfile")
        local lock_user=$(echo "$lock_info" | cut -d'|' -f1)
        local lock_time=$(echo "$lock_info" | cut -d'|' -f2)
        local current_time=$(date +%s)
        local age=$((current_time - lock_time))
        
        # Lock abgelaufen?
        if [ $age -gt $LOCK_TIMEOUT ]; then
            echo "Stale lock removed (was held by $lock_user)"
            rm -f "$lockfile"
        else
            echo "ERROR: File locked by $lock_user (${age}s ago)"
            echo "Use 'kb-lock --force $file' to override"
            return 1
        fi
    fi
    
    # Lock erstellen
    echo "${user}|${timestamp}" > "$lockfile"
    echo "Lock acquired for $file"
    return 0
}

unlock_file() {
    local file="$1"
    local lockfile="${file}.lock"
    
    if [ -f "$lockfile" ]; then
        rm -f "$lockfile"
        echo "Lock released for $file"
    fi
}

check_lock() {
    local file="$1"
    local lockfile="${file}.lock"
    
    if [ -f "$lockfile" ]; then
        cat "$lockfile"
        return 1
    fi
    return 0
}

case "$1" in
    lock)   lock_file "$2" ;;
    unlock) unlock_file "$2" ;;
    check)  check_lock "$2" ;;
    --force)
        rm -f "${3}.lock"
        lock_file "$3"
        ;;
    *)
        echo "Usage: kb-lock <lock|unlock|check|--force> <file>"
        ;;
esac
```

#### LLM-Integration (AGENTS.md)

```markdown
## File Locking Protocol for AI Agents

When editing files in /shared/knowledge/:

1. **Before editing**: Check for lock
   ```bash
   kb-lock check /shared/knowledge/path/to/file.md
   ```

2. **If locked**: 
   - Wait 30 seconds
   - Re-read the file (it may have changed)
   - Try again
   - After 3 attempts, notify user

3. **If unlocked**: Acquire lock
   ```bash
   kb-lock lock /shared/knowledge/path/to/file.md
   ```

4. **After editing**: Release lock
   ```bash
   kb-lock unlock /shared/knowledge/path/to/file.md
   ```

5. **On error/crash**: Locks expire after 1 hour automatically
```

#### Bewertung

| Aspekt | Bewertung |
|--------|-----------|
| Konflikt-Vermeidung | ⭐⭐⭐⭐⭐ |
| Benutzerfreundlichkeit | ⭐⭐⭐ |
| Parallelität | ⭐⭐ |
| Implementierungsaufwand | ⭐⭐⭐⭐ |

---

### 3.2 Strategie 2: Optimistic Locking (Git-basiert)

```
┌─────────────────────────────────────────────────────────────────┐
│                    Optimistic Locking                           │
│                                                                 │
│  Zeitpunkt t=0:                                                │
│  ┌─────────────┐                    ┌─────────────┐            │
│  │   User A    │                    │   User B    │            │
│  │  git pull   │                    │  git pull   │            │
│  │  (v1)       │                    │  (v1)       │            │
│  └──────┬──────┘                    └──────┬──────┘            │
│         │                                  │                    │
│         ▼                                  ▼                    │
│  ┌─────────────┐                    ┌─────────────┐            │
│  │   EDITING   │                    │   EDITING   │            │
│  │   (lokal)   │                    │   (lokal)   │            │
│  └──────┬──────┘                    └──────┬──────┘            │
│         │                                  │                    │
│         ▼                                  │                    │
│  ┌─────────────┐                           │                    │
│  │ git commit  │                           │                    │
│  │ git push    │ → v2                      │                    │
│  │ SUCCESS     │                           │                    │
│  └─────────────┘                           │                    │
│                                            ▼                    │
│                                     ┌─────────────┐            │
│                                     │ git commit  │            │
│                                     │ git push    │            │
│                                     │ REJECTED!   │            │
│                                     └──────┬──────┘            │
│                                            │                    │
│                                            ▼                    │
│                                     ┌─────────────┐            │
│                                     │ git pull    │            │
│                                     │ --rebase    │            │
│                                     │ MERGE!      │            │
│                                     └─────────────┘            │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

#### Workflow

```bash
# Vor dem Bearbeiten
git pull --rebase

# Nach dem Bearbeiten
git add -A
git commit -m "Update: description"
git push

# Bei Konflikt
git pull --rebase
# Konflikte lösen
git add -A
git rebase --continue
git push
```

#### Bewertung

| Aspekt | Bewertung |
|--------|-----------|
| Konflikt-Vermeidung | ⭐⭐⭐ |
| Benutzerfreundlichkeit | ⭐⭐⭐⭐ |
| Parallelität | ⭐⭐⭐⭐⭐ |
| Implementierungsaufwand | ⭐⭐⭐⭐⭐ |

---

### 3.3 Strategie 3: Ownership-Modell

```
┌─────────────────────────────────────────────────────────────────┐
│                    Ownership-Modell                             │
│                                                                 │
│  /shared/knowledge/                                            │
│  ├── api-docs/                                                 │
│  │   ├── entra-id/          ← Owner: admin@company.com        │
│  │   ├── google-workspace/  ← Owner: anna@company.com         │
│  │   └── slack/             ← Owner: max@company.com          │
│  ├── runbooks/                                                 │
│  │   └── incident-response/ ← Owner: ops-team                 │
│  └── decisions/             ← Owner: architecture-team        │
│                                                                 │
│  Regeln:                                                       │
│  - Nur Owner darf Dateien in seinem Bereich ÄNDERN            │
│  - Alle dürfen LESEN                                           │
│  - Änderungsvorschläge via Pull Request                        │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

#### Implementierung via CODEOWNERS

```
# /shared/knowledge/.github/CODEOWNERS

# API Docs
/api-docs/entra-id/          @admin
/api-docs/google-workspace/  @anna
/api-docs/slack/             @max

# Runbooks
/runbooks/                   @ops-team

# Decisions
/decisions/                  @architecture-team

# Default: Alle können vorschlagen, Review erforderlich
*                            @knowledge-admins
```

#### Bewertung

| Aspekt | Bewertung |
|--------|-----------|
| Konflikt-Vermeidung | ⭐⭐⭐⭐⭐ |
| Benutzerfreundlichkeit | ⭐⭐⭐ |
| Parallelität | ⭐⭐⭐⭐ |
| Implementierungsaufwand | ⭐⭐⭐ |

---

### 3.4 Strategie 4: CRDT-basierte Synchronisation

```
┌─────────────────────────────────────────────────────────────────┐
│                    CRDT (Conflict-free Replicated Data Types)   │
│                                                                 │
│  Prinzip: Änderungen werden als Operationen gespeichert,       │
│           nicht als Zustände. Operationen sind kommutativ.     │
│                                                                 │
│  User A: "Füge 'Hello' an Position 0 ein"                      │
│  User B: "Füge 'World' an Position 0 ein"                      │
│                                                                 │
│  Ergebnis (deterministisch): "HelloWorld" oder "WorldHello"    │
│  (basierend auf Timestamp/User-ID)                             │
│                                                                 │
│  Implementierung: Obsidian Livesync (CouchDB)                  │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

#### Bewertung

| Aspekt | Bewertung |
|--------|-----------|
| Konflikt-Vermeidung | ⭐⭐⭐⭐⭐ |
| Benutzerfreundlichkeit | ⭐⭐⭐⭐⭐ |
| Parallelität | ⭐⭐⭐⭐⭐ |
| Implementierungsaufwand | ⭐⭐ |

---

## 4. Konflikt-Lösungsstrategien

### 4.1 Git Merge-Konflikte lösen

```
┌─────────────────────────────────────────────────────────────────┐
│                    Git Merge-Konflikt                           │
│                                                                 │
│  <<<<<<< HEAD                                                  │
│  Die API unterstützt OAuth 2.0 mit PKCE.                       │
│  =======                                                        │
│  Die API unterstützt OAuth 2.0 mit Client Credentials.         │
│  >>>>>>> feature-branch                                         │
│                                                                 │
│  Lösungsoptionen:                                              │
│  1. Manuell: Beide Versionen prüfen, beste wählen              │
│  2. Theirs: git checkout --theirs file.md                      │
│  3. Ours: git checkout --ours file.md                          │
│  4. Merge: Beide Informationen kombinieren                     │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

#### Merge-Tool Konfiguration

```bash
# Git Merge-Tool konfigurieren
git config --global merge.tool vscode
git config --global mergetool.vscode.cmd 'code --wait $MERGED'

# Bei Konflikt
git mergetool
```

#### LLM-gestütztes Merge

```python
#!/usr/bin/env python3
"""
AI-assisted merge conflict resolution
"""

import subprocess
import openai

def get_conflict_content(file_path: str) -> tuple:
    """Extrahiert die beiden Versionen aus einem Konflikt"""
    with open(file_path, 'r') as f:
        content = f.read()
    
    # Parse conflict markers
    ours = []
    theirs = []
    in_ours = False
    in_theirs = False
    
    for line in content.split('\n'):
        if line.startswith('<<<<<<<'):
            in_ours = True
        elif line.startswith('======='):
            in_ours = False
            in_theirs = True
        elif line.startswith('>>>>>>>'):
            in_theirs = False
        elif in_ours:
            ours.append(line)
        elif in_theirs:
            theirs.append(line)
    
    return '\n'.join(ours), '\n'.join(theirs)

def resolve_with_llm(ours: str, theirs: str, context: str) -> str:
    """Nutzt LLM um Konflikt zu lösen"""
    prompt = f"""
    Du bist ein technischer Dokumentations-Experte.
    
    Es gibt einen Merge-Konflikt in einer Markdown-Datei.
    
    VERSION A (aktuell):
    {ours}
    
    VERSION B (eingehend):
    {theirs}
    
    KONTEXT:
    {context}
    
    Bitte erstelle eine zusammengeführte Version, die:
    1. Alle korrekten Informationen aus beiden Versionen enthält
    2. Widersprüche auflöst (bevorzuge die aktuellere/korrektere Info)
    3. Gut formatiert ist
    
    Antworte NUR mit dem zusammengeführten Text, keine Erklärungen.
    """
    
    response = openai.chat.completions.create(
        model="gpt-4",
        messages=[{"role": "user", "content": prompt}]
    )
    
    return response.choices[0].message.content

if __name__ == '__main__':
    import sys
    file_path = sys.argv[1]
    
    ours, theirs = get_conflict_content(file_path)
    
    # Kontext aus Dateiname/Pfad
    context = f"Datei: {file_path}"
    
    resolved = resolve_with_llm(ours, theirs, context)
    
    print("Vorgeschlagene Lösung:")
    print("-" * 40)
    print(resolved)
    print("-" * 40)
    
    confirm = input("Übernehmen? (y/n): ")
    if confirm.lower() == 'y':
        with open(file_path, 'w') as f:
            f.write(resolved)
        print(f"Konflikt in {file_path} gelöst")
```

---

### 4.2 Syncthing Konflikt-Dateien

```
┌─────────────────────────────────────────────────────────────────┐
│                    Syncthing Konflikte                          │
│                                                                 │
│  Bei Konflikt erstellt Syncthing:                              │
│                                                                 │
│  document.md                    ← Gewinner (neueste Änderung)  │
│  document.sync-conflict-20250110-143022-ABCDEF.md  ← Verlierer │
│                                                                 │
│  Lösung:                                                       │
│  1. Beide Dateien vergleichen                                  │
│  2. Manuell zusammenführen                                     │
│  3. Konflikt-Datei löschen                                     │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

#### Konflikt-Finder Script

```bash
#!/bin/bash
# find-conflicts.sh

KNOWLEDGE_DIR="/shared/knowledge"

echo "=== Syncthing Konflikte ==="
find "$KNOWLEDGE_DIR" -name "*.sync-conflict-*" -type f

echo ""
echo "=== Git Konflikte ==="
cd "$KNOWLEDGE_DIR"
git diff --name-only --diff-filter=U

echo ""
echo "=== Stale Locks ==="
find "$KNOWLEDGE_DIR" -name "*.lock" -mmin +60 -type f
```

---

### 4.3 Last-Write-Wins (SSHFS)

```
┌─────────────────────────────────────────────────────────────────┐
│                    Last-Write-Wins Problem                      │
│                                                                 │
│  t=0: User A öffnet doc.md (Version 1)                         │
│  t=1: User B öffnet doc.md (Version 1)                         │
│  t=2: User A speichert (Version 2)                             │
│  t=3: User B speichert (Version 3) ← User A's Änderungen WEG!  │
│                                                                 │
│  SSHFS hat KEIN Konflikt-Handling!                             │
│                                                                 │
│  Mitigation:                                                   │
│  - File Locking verwenden                                      │
│  - Oder: SSHFS nur für Read-Only Zugang                        │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## 5. Empfohlene Strategie

### 5.1 Hybrid-Ansatz

```
┌─────────────────────────────────────────────────────────────────┐
│                    Empfohlener Hybrid-Ansatz                    │
│                                                                 │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  EBENE 1: Ownership (Vermeidung)                        │   │
│  │  - Klare Zuständigkeiten pro Bereich                    │   │
│  │  - Reduziert Konflikt-Wahrscheinlichkeit um 80%         │   │
│  └─────────────────────────────────────────────────────────┘   │
│                            │                                    │
│                            ▼                                    │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  EBENE 2: Git-basiertes Optimistic Locking              │   │
│  │  - Paralleles Arbeiten möglich                          │   │
│  │  - Konflikte werden beim Push erkannt                   │   │
│  └─────────────────────────────────────────────────────────┘   │
│                            │                                    │
│                            ▼                                    │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  EBENE 3: File Locking für kritische Dokumente          │   │
│  │  - Nur für häufig bearbeitete Shared-Dokumente          │   │
│  │  - LLM-Agents nutzen immer Locking                      │   │
│  └─────────────────────────────────────────────────────────┘   │
│                            │                                    │
│                            ▼                                    │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  EBENE 4: LLM-gestütztes Merge bei Konflikten           │   │
│  │  - Automatische Vorschläge                              │   │
│  │  - Menschliche Bestätigung                              │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### 5.2 Implementierungs-Checkliste

| Komponente | Priorität | Status |
|------------|-----------|--------|
| Git-basierter Workflow | Hoch | [ ] |
| CODEOWNERS für Ownership | Hoch | [ ] |
| File Locking Script | Mittel | [ ] |
| LLM-Merge-Tool | Niedrig | [ ] |
| Konflikt-Finder Script | Mittel | [ ] |
| Team-Schulung | Hoch | [ ] |

---

## 6. Spezialfall: LLM-Agent Konflikte

### 6.1 Problem

LLM-Agents (OpenCode, Gemini CLI) können sehr schnell viele Dateien bearbeiten, was zu Konflikten führt.

### 6.2 Lösung: Agent-Protokoll

```markdown
## LLM Agent File Access Protocol

### Vor jeder Dateiänderung:

1. **Lock prüfen**
   ```bash
   if kb-lock check "$FILE"; then
       # Datei ist frei
   else
       # Warten und erneut versuchen
       sleep 30
       # Datei neu lesen (könnte sich geändert haben)
   fi
   ```

2. **Lock erwerben**
   ```bash
   kb-lock lock "$FILE"
   ```

3. **Datei lesen** (immer aktuellste Version)
   ```bash
   cat "$FILE"
   ```

4. **Änderungen durchführen**

5. **Lock freigeben**
   ```bash
   kb-lock unlock "$FILE"
   ```

6. **Git Commit**
   ```bash
   git add "$FILE"
   git commit -m "Update: $FILE - $DESCRIPTION"
   git push || git pull --rebase && git push
   ```

### Bei Konflikt:

1. Änderungen NICHT überschreiben
2. Konflikt-Datei erstellen: `$FILE.conflict.$TIMESTAMP`
3. User benachrichtigen
4. Auf manuelle Lösung warten
```

### 6.3 Konflikt-Benachrichtigung

```bash
#!/bin/bash
# notify-conflict.sh

FILE="$1"
USER="$2"
CONFLICT_TYPE="$3"

# Slack Notification
curl -X POST -H 'Content-type: application/json' \
    --data "{
        \"text\": \"⚠️ Konflikt in Knowledge Base\",
        \"blocks\": [
            {
                \"type\": \"section\",
                \"text\": {
                    \"type\": \"mrkdwn\",
                    \"text\": \"*Datei:* $FILE\n*Benutzer:* $USER\n*Typ:* $CONFLICT_TYPE\"
                }
            }
        ]
    }" \
    "$SLACK_WEBHOOK_URL"
```

---

## 7. Monitoring & Metriken

### 7.1 Zu überwachende Metriken

| Metrik | Schwellwert | Aktion |
|--------|-------------|--------|
| Konflikte pro Tag | >5 | Ownership-Struktur prüfen |
| Stale Locks | >0 (älter als 1h) | Automatisch entfernen |
| Merge-Konflikte | >3 pro Woche | Team-Kommunikation verbessern |
| Konflikt-Dateien | >0 | Sofort lösen |

### 7.2 Dashboard-Script

```bash
#!/bin/bash
# conflict-dashboard.sh

echo "=== Knowledge Base Conflict Dashboard ==="
echo "Date: $(date)"
echo ""

echo "=== Active Locks ==="
find /shared/knowledge -name "*.lock" -type f -exec ls -la {} \;

echo ""
echo "=== Conflict Files ==="
find /shared/knowledge -name "*.conflict.*" -o -name "*.sync-conflict-*" | wc -l

echo ""
echo "=== Git Status ==="
cd /shared/knowledge
git status --short

echo ""
echo "=== Recent Conflicts (Git Log) ==="
git log --oneline --grep="conflict" --since="7 days ago"
```

---

## 8. Schulungsmaterial

### 8.1 Quick Reference Card

```
┌─────────────────────────────────────────────────────────────────┐
│                    KONFLIKT-HANDLING QUICK REFERENCE            │
│                                                                 │
│  VOR DEM BEARBEITEN:                                           │
│  1. git pull                                                   │
│  2. kb-lock check <datei>                                      │
│  3. kb-lock lock <datei>                                       │
│                                                                 │
│  NACH DEM BEARBEITEN:                                          │
│  1. kb-lock unlock <datei>                                     │
│  2. git add -A                                                 │
│  3. git commit -m "Beschreibung"                               │
│  4. git push                                                   │
│                                                                 │
│  BEI KONFLIKT:                                                 │
│  1. git pull --rebase                                          │
│  2. Konflikte in Editor lösen                                  │
│  3. git add <datei>                                            │
│  4. git rebase --continue                                      │
│  5. git push                                                   │
│                                                                 │
│  HILFE:                                                        │
│  - find-conflicts.sh                                           │
│  - conflict-dashboard.sh                                       │
│  - #knowledge-base Slack Channel                               │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## 9. Zusammenfassung

### Empfohlene Strategie

| Situation | Strategie |
|-----------|-----------|
| Normale Bearbeitung | Git + Optimistic Locking |
| Kritische Dokumente | File Locking |
| LLM-Agents | Immer File Locking |
| Konflikt aufgetreten | LLM-gestütztes Merge |
| Häufige Konflikte | Ownership-Modell einführen |

### Nächste Schritte

1. [ ] File Locking Script implementieren
2. [ ] CODEOWNERS Datei erstellen
3. [ ] Team über Workflow schulen
4. [ ] Monitoring einrichten
5. [ ] LLM-Merge-Tool evaluieren

---

## Anhang A: Referenzen

- [Git Merge Strategies](https://git-scm.com/docs/merge-strategies)
- [CRDT Explained](https://crdt.tech/)
- [Obsidian Livesync](https://github.com/vrtmrz/obsidian-livesync)
- [Syncthing Conflict Handling](https://docs.syncthing.net/users/syncing.html#conflicting-changes)
