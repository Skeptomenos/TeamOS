# Konzeptpapier: Knowledge Base - Dokumentenverwaltung und Suche

**Version:** 1.0  
**Datum:** 2025-01-10  
**Status:** Entwurf  
**Autor:** IT Architecture Team

---

## 1. Executive Summary

Dieses Dokument beschreibt das Konzept für eine team-weite Knowledge Base, die auf Markdown-Dateien basiert und durch moderne Suchtechnologien für LLM-basierte CLI-Tools (OpenCode, Gemini CLI) optimiert ist. Das Ziel ist eine zentrale, durchsuchbare Wissensdatenbank, die sowohl von Menschen als auch von AI-Agenten effizient genutzt werden kann.

---

## 2. Problemstellung

### 2.1 Aktuelle Herausforderungen

| Problem | Auswirkung |
|---------|------------|
| Wissen in Silos (Confluence, lokale Notizen, Slack) | Informationen schwer auffindbar |
| Keine einheitliche Struktur | Inkonsistente Dokumentation |
| Keine AI-Optimierung | LLMs können Wissen nicht effizient nutzen |
| Fehlende Versionierung | Änderungen nicht nachvollziehbar |
| Keine Metadaten | Autor, Erstelldatum, Kontext fehlen |

### 2.2 Anforderungen

- **Unified Search**: Eine Suche für alle Dokumente
- **AI-Ready**: Optimiert für LLM-Kontext-Fenster
- **Versioniert**: Vollständige Änderungshistorie
- **Metadaten-reich**: Frontmatter mit Autor, Datum, Tags
- **Schnell**: Sub-Sekunden Suche bei 10.000+ Dokumenten

---

## 3. Lösungsarchitektur

### 3.1 Technologie-Stack

```
┌─────────────────────────────────────────────────────────────────┐
│                    Knowledge Base Stack                         │
│                                                                 │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │                   Markdown Files                         │   │
│  │   - Frontmatter (YAML) für Metadaten                    │   │
│  │   - Standardisierte Ordnerstruktur                      │   │
│  │   - Git-versioniert                                     │   │
│  └─────────────────────────────────────────────────────────┘   │
│                            │                                    │
│                            ▼                                    │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │                   MeiliSearch                            │   │
│  │   - Volltextsuche mit Typo-Toleranz                     │   │
│  │   - Faceted Search (nach Tags, Autor, Datum)            │   │
│  │   - REST API für CLI-Integration                        │   │
│  │   - ~500MB RAM für 10k Dokumente                        │   │
│  └─────────────────────────────────────────────────────────┘   │
│                            │                                    │
│                            ▼                                    │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │                   CLI Interface                          │   │
│  │   - `kb search "API documentation"`                     │   │
│  │   - `kb add runbooks/new-runbook.md`                    │   │
│  │   - Integration in OpenCode/Gemini CLI                  │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### 3.2 Warum MeiliSearch?

| Kriterium | MeiliSearch | Typesense | Elasticsearch |
|-----------|-------------|-----------|---------------|
| **RAM-Verbrauch** | ~500MB | ~300MB | 2GB+ |
| **Setup-Komplexität** | Einfach | Mittel | Komplex |
| **Typo-Toleranz** | Exzellent | Gut | Konfigurierbar |
| **Latenz** | <50ms | <50ms | <100ms |
| **Docker Image** | 50MB | 30MB | 500MB+ |
| **Ops-Overhead** | Minimal | Minimal | Hoch |

**Entscheidung**: MeiliSearch bietet das beste Verhältnis aus Einfachheit, Performance und Features für unseren Use Case.

---

## 4. Dokumentenstruktur

### 4.1 Ordnerstruktur

```
/shared/knowledge/
├── api-docs/                 # API-Dokumentation
│   ├── entra-id/
│   ├── google-workspace/
│   ├── atlassian/
│   └── slack/
├── runbooks/                 # Operative Runbooks
│   ├── incident-response/
│   ├── onboarding/
│   └── maintenance/
├── decisions/                # Architecture Decision Records (ADRs)
│   ├── 001-knowledge-base-stack.md
│   └── 002-search-engine-choice.md
├── guides/                   # How-To Guides
│   ├── developer/
│   └── admin/
├── meeting-notes/            # Meeting-Protokolle
│   └── 2025/
└── templates/                # Dokumentvorlagen
    ├── runbook-template.md
    ├── adr-template.md
    └── meeting-template.md
```

### 4.2 Frontmatter-Schema

Jedes Markdown-Dokument MUSS folgendes Frontmatter enthalten:

```yaml
---
title: "API-Dokumentation: Entra ID Graph API"
created: 2025-01-10
created_by: admin@company.com
updated: 2025-01-10
updated_by: admin@company.com
tags:
  - api
  - entra-id
  - authentication
category: api-docs
status: published  # draft | review | published | deprecated
---
```

### 4.3 Automatische Frontmatter-Validierung

Pre-commit Hook zur Validierung:

```bash
#!/bin/bash
# .git/hooks/pre-commit

for file in $(git diff --cached --name-only --diff-filter=ACM | grep '\.md$'); do
    # Prüfe ob Frontmatter existiert
    if ! head -1 "$file" | grep -q '^---$'; then
        echo "ERROR: $file hat kein Frontmatter"
        exit 1
    fi
    
    # Prüfe Pflichtfelder
    for field in title created created_by; do
        if ! grep -q "^$field:" "$file"; then
            echo "ERROR: $file fehlt Pflichtfeld '$field'"
            exit 1
        fi
    done
    
    # Update 'updated' und 'updated_by' automatisch
    sed -i '' "s/^updated:.*/updated: $(date +%Y-%m-%d)/" "$file"
    sed -i '' "s/^updated_by:.*/updated_by: $GIT_AUTHOR_EMAIL/" "$file"
    git add "$file"
done
```

---

## 5. Suchsystem

### 5.1 MeiliSearch Konfiguration

```yaml
# docker-compose.yml
version: '3.8'
services:
  meilisearch:
    image: getmeili/meilisearch:v1.6
    container_name: knowledge-search
    ports:
      - "7700:7700"
    volumes:
      - ./meili_data:/meili_data
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
```

### 5.2 Index-Schema

```json
{
  "uid": "knowledge",
  "primaryKey": "id",
  "searchableAttributes": [
    "title",
    "content",
    "tags",
    "category"
  ],
  "filterableAttributes": [
    "tags",
    "category",
    "status",
    "created_by",
    "created"
  ],
  "sortableAttributes": [
    "created",
    "updated",
    "title"
  ],
  "rankingRules": [
    "words",
    "typo",
    "proximity",
    "attribute",
    "sort",
    "exactness"
  ]
}
```

### 5.3 Indexer-Script

```python
#!/usr/bin/env python3
"""
Knowledge Base Indexer
Indexiert alle Markdown-Dateien in MeiliSearch
"""

import meilisearch
import frontmatter
from pathlib import Path
import hashlib
import os
from datetime import datetime

MEILI_URL = os.getenv('MEILI_URL', 'http://localhost:7700')
MEILI_KEY = os.getenv('MEILI_MASTER_KEY')
KNOWLEDGE_DIR = os.getenv('KNOWLEDGE_DIR', '/shared/knowledge')

client = meilisearch.Client(MEILI_URL, MEILI_KEY)

def get_or_create_index():
    """Index erstellen falls nicht vorhanden"""
    try:
        return client.get_index('knowledge')
    except:
        client.create_index('knowledge', {'primaryKey': 'id'})
        index = client.get_index('knowledge')
        
        # Konfiguration setzen
        index.update_searchable_attributes([
            'title', 'content', 'tags', 'category'
        ])
        index.update_filterable_attributes([
            'tags', 'category', 'status', 'created_by', 'created'
        ])
        index.update_sortable_attributes([
            'created', 'updated', 'title'
        ])
        
        return index

def index_file(filepath: Path) -> dict:
    """Einzelne Datei indexieren"""
    post = frontmatter.load(filepath)
    
    # ID aus Dateipfad generieren
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
    """Vollständige Neuindexierung"""
    index = get_or_create_index()
    
    docs = []
    for md_file in Path(KNOWLEDGE_DIR).rglob('*.md'):
        try:
            docs.append(index_file(md_file))
        except Exception as e:
            print(f"ERROR indexing {md_file}: {e}")
    
    if docs:
        index.add_documents(docs)
        print(f"Indexed {len(docs)} documents")

def incremental_index(filepath: str):
    """Einzelne Datei (neu-)indexieren"""
    index = get_or_create_index()
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

### 5.4 File-Watcher für Real-Time Indexing

```python
#!/usr/bin/env python3
"""
Watches for file changes and triggers incremental indexing
"""

from watchdog.observers import Observer
from watchdog.events import FileSystemEventHandler
import subprocess
import time

class MarkdownHandler(FileSystemEventHandler):
    def on_modified(self, event):
        if event.src_path.endswith('.md'):
            subprocess.run(['python3', 'indexer.py', '--file', event.src_path])
    
    def on_created(self, event):
        if event.src_path.endswith('.md'):
            subprocess.run(['python3', 'indexer.py', '--file', event.src_path])

if __name__ == '__main__':
    observer = Observer()
    observer.schedule(MarkdownHandler(), '/shared/knowledge', recursive=True)
    observer.start()
    
    try:
        while True:
            time.sleep(1)
    except KeyboardInterrupt:
        observer.stop()
    observer.join()
```

---

## 6. CLI-Integration

### 6.1 Knowledge Base CLI Tool

```bash
#!/bin/bash
# /usr/local/bin/kb - Knowledge Base CLI

MEILI_URL="${MEILI_URL:-http://localhost:7700}"
MEILI_KEY="${MEILI_MASTER_KEY}"

case "$1" in
    search)
        shift
        query="$*"
        curl -s "${MEILI_URL}/indexes/knowledge/search" \
            -H "Authorization: Bearer ${MEILI_KEY}" \
            -H "Content-Type: application/json" \
            -d "{\"q\": \"${query}\", \"limit\": 10}" | \
            jq -r '.hits[] | "[\(.category)] \(.title)\n  Path: \(.path)\n  Tags: \(.tags | join(", "))\n"'
        ;;
    
    read)
        # Datei anzeigen
        cat "/shared/knowledge/$2"
        ;;
    
    list)
        # Dateien in Kategorie auflisten
        find "/shared/knowledge/$2" -name "*.md" -type f | head -20
        ;;
    
    recent)
        # Kürzlich geänderte Dateien
        find /shared/knowledge -name "*.md" -mtime -7 -type f | head -20
        ;;
    
    *)
        echo "Usage: kb <command> [args]"
        echo "Commands:"
        echo "  search <query>    - Search knowledge base"
        echo "  read <path>       - Read a document"
        echo "  list <category>   - List documents in category"
        echo "  recent            - Show recently modified"
        ;;
esac
```

### 6.2 Integration in AGENTS.md

```markdown
## Knowledge Base Access

The team knowledge base is available at `/shared/knowledge/`.

### Search Commands
- `kb search "query"` - Full-text search across all documents
- `kb read path/to/doc.md` - Read specific document
- `kb list api-docs` - List documents in category
- `kb recent` - Show recently modified documents

### Direct MeiliSearch API
```bash
curl -s "http://localhost:7700/indexes/knowledge/search" \
  -H "Authorization: Bearer $MEILI_KEY" \
  -d '{"q": "your query", "limit": 5}'
```

### Document Structure
All documents use frontmatter with: title, created, created_by, tags, category, status
```

---

## 7. LLM-Optimierung

### 7.1 Kontext-Fenster-Optimierung

Für LLMs ist es wichtig, relevante Dokumente kompakt zu liefern:

```python
def get_context_for_llm(query: str, max_tokens: int = 4000) -> str:
    """
    Holt relevante Dokumente und formatiert sie für LLM-Kontext
    """
    results = search(query, limit=10)
    
    context_parts = []
    current_tokens = 0
    
    for hit in results['hits']:
        # Geschätzte Token-Zahl (grob: 4 chars = 1 token)
        doc_tokens = len(hit['content']) // 4
        
        if current_tokens + doc_tokens > max_tokens:
            break
        
        context_parts.append(f"""
## {hit['title']}
**Path:** {hit['path']}
**Tags:** {', '.join(hit['tags'])}

{hit['content'][:2000]}...
""")
        current_tokens += doc_tokens
    
    return "\n---\n".join(context_parts)
```

### 7.2 Semantic Search (Optional, Phase 2)

Für bessere Suchergebnisse kann später Embedding-basierte Suche hinzugefügt werden:

```python
# Mit sentence-transformers
from sentence_transformers import SentenceTransformer

model = SentenceTransformer('all-MiniLM-L6-v2')

def embed_document(content: str) -> list:
    return model.encode(content).tolist()

# Speicherung in pgvector oder Qdrant
```

---

## 8. Backup & Recovery

### 8.1 Backup-Strategie

```bash
#!/bin/bash
# /etc/cron.daily/knowledge-backup

# Git-basiertes Backup (bereits durch Git abgedeckt)
cd /shared/knowledge
git push origin main

# MeiliSearch Dump
curl -X POST "http://localhost:7700/dumps" \
    -H "Authorization: Bearer ${MEILI_KEY}"

# Dump nach GCS kopieren
gsutil cp /meili_data/dumps/*.dump gs://company-backups/knowledge/
```

### 8.2 Recovery

```bash
# Bei Datenverlust: Git restore
cd /shared/knowledge
git checkout main

# MeiliSearch neu indexieren
python3 indexer.py
```

---

## 9. Metriken & Monitoring

### 9.1 Zu überwachende Metriken

| Metrik | Schwellwert | Aktion |
|--------|-------------|--------|
| Suchlatenz | >200ms | Index optimieren |
| Index-Größe | >5GB | Alte Dokumente archivieren |
| Dokumente ohne Frontmatter | >0 | Pre-commit Hook prüfen |
| Verwaiste Dokumente | >30 Tage unverändert | Review-Prozess |

### 9.2 Health Check

```bash
#!/bin/bash
# health-check.sh

# MeiliSearch erreichbar?
if ! curl -sf http://localhost:7700/health > /dev/null; then
    echo "CRITICAL: MeiliSearch not responding"
    exit 2
fi

# Index vorhanden?
doc_count=$(curl -s http://localhost:7700/indexes/knowledge/stats \
    -H "Authorization: Bearer ${MEILI_KEY}" | jq '.numberOfDocuments')

if [ "$doc_count" -lt 10 ]; then
    echo "WARNING: Only $doc_count documents indexed"
    exit 1
fi

echo "OK: $doc_count documents indexed"
exit 0
```

---

## 10. Rollout-Plan

| Phase | Zeitraum | Aktivitäten |
|-------|----------|-------------|
| **Phase 1** | Woche 1 | MeiliSearch aufsetzen, Indexer implementieren |
| **Phase 2** | Woche 2 | Bestehende Docs migrieren, Frontmatter hinzufügen |
| **Phase 3** | Woche 3 | CLI-Tool deployen, Team-Schulung |
| **Phase 4** | Woche 4 | Monitoring einrichten, Feedback sammeln |
| **Phase 5** | Monat 2+ | Semantic Search evaluieren |

---

## 11. Offene Fragen

- [ ] Sollen alte Confluence-Seiten migriert werden?
- [ ] Wie lange sollen deprecated Dokumente aufbewahrt werden?
- [ ] Brauchen wir Zugriffsrechte pro Kategorie?
- [ ] Integration mit Slack für Benachrichtigungen bei neuen Docs?

---

## Anhang A: Referenzen

- [MeiliSearch Dokumentation](https://docs.meilisearch.com/)
- [Python Frontmatter Library](https://python-frontmatter.readthedocs.io/)
- [Watchdog File System Events](https://pythonhosted.org/watchdog/)
