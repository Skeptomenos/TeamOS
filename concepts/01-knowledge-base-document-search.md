# Concept Paper: Knowledge Base - Document Management and Search

**Version:** 1.1  
**Date:** 2025-01-11  
**Status:** Implemented  
**Author:** TeamOS

---

## 1. Executive Summary

This document describes the concept for a team-wide Knowledge Base built on Markdown files and optimized through modern search technologies for LLM-based CLI tools (OpenCode, Gemini CLI). The goal is a central, searchable knowledge database that can be efficiently used by both humans and AI agents.

> **Future Enhancement:** For improved semantic search and token efficiency, see [[08-hybrid-search-vector-database]] which adds vector-based search alongside the keyword search described here.

---

## 2. Problem Statement

### 2.1 Current Challenges

| Problem | Impact |
|---------|--------|
| Knowledge in silos (Confluence, local notes, Slack) | Information hard to find |
| No unified structure | Inconsistent documentation |
| No AI optimization | LLMs cannot efficiently use knowledge |
| Missing version control | Changes not traceable |
| No metadata | Author, creation date, context missing |

### 2.2 Requirements

- **Unified Search**: One search for all documents
- **AI-Ready**: Optimized for LLM context windows
- **Versioned**: Complete change history
- **Metadata-rich**: Frontmatter with author, date, tags
- **Fast**: Sub-second search for 10,000+ documents

---

## 3. Solution Architecture

### 3.1 Technology Stack

```
┌─────────────────────────────────────────────────────────────────┐
│                    Knowledge Base Stack                         │
│                                                                 │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │                   Markdown Files                         │   │
│  │   - Frontmatter (YAML) for metadata                     │   │
│  │   - Standardized folder structure                       │   │
│  │   - Git-versioned                                       │   │
│  └─────────────────────────────────────────────────────────┘   │
│                            │                                    │
│                            ▼                                    │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │                   MeiliSearch                            │   │
│  │   - Full-text search with typo tolerance                │   │
│  │   - Faceted search (by tags, author, date)              │   │
│  │   - REST API for CLI integration                        │   │
│  │   - ~500MB RAM for 10k documents                        │   │
│  └─────────────────────────────────────────────────────────┘   │
│                            │                                    │
│                            ▼                                    │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │                   CLI Interface                          │   │
│  │   - `kb search "API documentation"`                     │   │
│  │   - `kb add runbooks/new-runbook.md`                    │   │
│  │   - Integration with OpenCode/Gemini CLI                │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### 3.2 Why MeiliSearch?

| Criterion | MeiliSearch | Typesense | Elasticsearch |
|-----------|-------------|-----------|---------------|
| **RAM Usage** | ~500MB | ~300MB | 2GB+ |
| **Setup Complexity** | Simple | Medium | Complex |
| **Typo Tolerance** | Excellent | Good | Configurable |
| **Latency** | <50ms | <50ms | <100ms |
| **Docker Image** | 50MB | 30MB | 500MB+ |
| **Ops Overhead** | Minimal | Minimal | High |

**Decision**: MeiliSearch offers the best balance of simplicity, performance, and features for our use case.

---

## 4. Document Structure

### 4.1 Folder Structure

```
/data/shared/knowledge/
├── api-docs/                 # API documentation
│   ├── entra-id/
│   ├── google-workspace/
│   ├── atlassian/
│   └── slack/
├── runbooks/                 # Operational runbooks
│   ├── incident-response/
│   ├── onboarding/
│   └── maintenance/
├── decisions/                # Architecture Decision Records (ADRs)
│   ├── 001-knowledge-base-stack.md
│   └── 002-search-engine-choice.md
├── guides/                   # How-to guides
│   ├── developer/
│   └── admin/
├── meeting-notes/            # Meeting notes
│   └── 2025/
└── templates/                # Document templates
    ├── runbook-template.md
    ├── adr-template.md
    └── meeting-template.md
```

### 4.2 Frontmatter Schema

Every Markdown document MUST contain the following frontmatter:

```yaml
---
title: "API Documentation: Entra ID Graph API"
created: 2025-01-10
created_by: admin@example.com
updated: 2025-01-10
updated_by: admin@example.com
tags:
  - api
  - entra-id
  - authentication
category: api-docs
status: published  # draft | review | published | deprecated
---
```

### 4.3 Automatic Frontmatter Validation

Pre-commit hook for validation:

```bash
#!/bin/bash
# .git/hooks/pre-commit

for file in $(git diff --cached --name-only --diff-filter=ACM | grep '\.md$'); do
    # Check if frontmatter exists
    if ! head -1 "$file" | grep -q '^---$'; then
        echo "ERROR: $file has no frontmatter"
        exit 1
    fi
    
    # Check required fields
    for field in title created created_by; do
        if ! grep -q "^$field:" "$file"; then
            echo "ERROR: $file missing required field '$field'"
            exit 1
        fi
    done
    
    # Auto-update 'updated' and 'updated_by'
    sed -i '' "s/^updated:.*/updated: $(date +%Y-%m-%d)/" "$file"
    sed -i '' "s/^updated_by:.*/updated_by: $GIT_AUTHOR_EMAIL/" "$file"
    git add "$file"
done
```

---

## 5. Search System

### 5.1 MeiliSearch Configuration

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

### 5.2 Index Schema

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

### 5.3 Indexer Script

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

client = meilisearch.Client(MEILI_URL, MEILI_KEY)

def get_or_create_index():
    """Create index if it doesn't exist"""
    try:
        return client.get_index('knowledge')
    except:
        client.create_index('knowledge', {'primaryKey': 'id'})
        index = client.get_index('knowledge')
        
        # Set configuration
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
    """Index a single file"""
    post = frontmatter.load(filepath)
    
    # Generate ID from file path
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
    """Complete reindexing"""
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
    """Index a single file (new or updated)"""
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

### 5.4 File Watcher for Real-Time Indexing

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
    observer.schedule(MarkdownHandler(), '/data/shared/knowledge', recursive=True)
    observer.start()
    
    try:
        while True:
            time.sleep(1)
    except KeyboardInterrupt:
        observer.stop()
    observer.join()
```

---

## 6. CLI Integration

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
        # Display file
        cat "/data/shared/knowledge/$2"
        ;;
    
    list)
        # List files in category
        find "/data/shared/knowledge/$2" -name "*.md" -type f | head -20
        ;;
    
    recent)
        # Recently modified files
        find /data/shared/knowledge -name "*.md" -mtime -7 -type f | head -20
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

The team knowledge base is available at `/data/shared/knowledge/`.

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

## 7. LLM Optimization

### 7.1 Context Window Optimization

For LLMs, it's important to deliver relevant documents compactly:

```python
def get_context_for_llm(query: str, max_tokens: int = 4000) -> str:
    """
    Retrieves relevant documents and formats them for LLM context
    """
    results = search(query, limit=10)
    
    context_parts = []
    current_tokens = 0
    
    for hit in results['hits']:
        # Estimated token count (rough: 4 chars = 1 token)
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

### 7.2 Semantic Search (Enhancement)

For better search results, embedding-based search can be added. See [[08-hybrid-search-vector-database]] for the complete design of hybrid keyword + vector search.

```python
# With sentence-transformers
from sentence_transformers import SentenceTransformer

model = SentenceTransformer('all-MiniLM-L6-v2')

def embed_document(content: str) -> list:
    return model.encode(content).tolist()

# Storage in Qdrant (see concept 08)
```

---

## 8. Backup & Recovery

### 8.1 Backup Strategy

```bash
#!/bin/bash
# /etc/cron.daily/knowledge-backup

# Git-based backup (already covered by Git)
cd /data/shared/knowledge
git push origin main

# MeiliSearch dump
curl -X POST "http://localhost:7700/dumps" \
    -H "Authorization: Bearer ${MEILI_KEY}"

# Copy dump to GCS
gsutil cp /meili_data/dumps/*.dump gs://company-backups/knowledge/
```

### 8.2 Recovery

```bash
# On data loss: Git restore
cd /data/shared/knowledge
git checkout main

# Reindex MeiliSearch
python3 indexer.py
```

---

## 9. Metrics & Monitoring

### 9.1 Metrics to Monitor

| Metric | Threshold | Action |
|--------|-----------|--------|
| Search latency | >200ms | Optimize index |
| Index size | >5GB | Archive old documents |
| Documents without frontmatter | >0 | Check pre-commit hook |
| Orphaned documents | >30 days unchanged | Review process |

### 9.2 Health Check

```bash
#!/bin/bash
# health-check.sh

# MeiliSearch reachable?
if ! curl -sf http://localhost:7700/health > /dev/null; then
    echo "CRITICAL: MeiliSearch not responding"
    exit 2
fi

# Index exists?
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

## 10. Rollout Plan

| Phase | Timeframe | Activities |
|-------|-----------|------------|
| **Phase 1** | Week 1 | Set up MeiliSearch, implement indexer |
| **Phase 2** | Week 2 | Migrate existing docs, add frontmatter |
| **Phase 3** | Week 3 | Deploy CLI tool, team training |
| **Phase 4** | Week 4 | Set up monitoring, collect feedback |
| **Phase 5** | Month 2+ | Evaluate and implement semantic search (see [[08-hybrid-search-vector-database]]) |

---

## 11. Open Questions

- [ ] Should old Confluence pages be migrated?
- [ ] How long should deprecated documents be retained?
- [ ] Do we need access rights per category?
- [ ] Integration with Slack for notifications on new docs?

---

## Related Documents

- [[00-vision]] - TeamOS vision and strategic phases
- [[05-overall-architecture]] - System architecture overview
- [[08-hybrid-search-vector-database]] - Hybrid search with vector database (planned enhancement)

---

## Appendix A: References

- [MeiliSearch Documentation](https://docs.meilisearch.com/)
- [Python Frontmatter Library](https://python-frontmatter.readthedocs.io/)
- [Watchdog File System Events](https://pythonhosted.org/watchdog/)
