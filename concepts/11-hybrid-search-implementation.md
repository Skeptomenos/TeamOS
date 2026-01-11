# Concept Paper: Hybrid Search Implementation & MCP Server Access

**Version:** 1.0  
**Date:** 2026-01-11  
**Status:** Planning  
**Author:** TeamOS  
**Prerequisites:** concepts/08-hybrid-search-vector-database.md, concepts/09-opencode-server-pomerium.md

---

## 1. Executive Summary

This document details the implementation plan for completing the hybrid search system and exposing the MCP server for external AI agent access. These components are currently deployed but not integrated, leaving significant functionality unrealized.

**Current State:**
- Qdrant container running but empty (no vectors)
- MeiliSearch working (keyword search only)
- MCP server script exists but not externally accessible
- Vertex AI permissions configured but not used

**Target State:**
- Hybrid search combining keyword + semantic search
- External MCP access for AI agents via Pomerium
- Automatic vector indexing on document changes

---

## 2. Architecture Gap Analysis

### 2.1 Current vs Target Architecture

```
CURRENT STATE:
==============

  User/Agent Query
        |
        v
  +-------------+
  | MeiliSearch |  <-- Keyword search only
  +-------------+
        |
        v
  Results (exact matches only)


TARGET STATE:
=============

  User/Agent Query
        |
        v
  +------------------+
  |  Query Router    |
  +--------+---------+
           |
     +-----+-----+
     |           |
     v           v
+----------+ +----------+
|MeiliSearch| |  Qdrant  |
| (keyword) | |(semantic)|
+-----+----+ +-----+----+
      |            |
      v            v
  [Results]    [Results]
      |            |
      +-----+------+
            |
            v
    +---------------+
    |  RRF Fusion   |
    +---------------+
            |
            v
    Ranked Results (best of both)
```

### 2.2 Missing Components

| Component | Location | Status | Blocker |
|-----------|----------|--------|---------|
| Vertex AI Client | hybrid_indexer.py | Not deployed | None |
| Vector Indexing | kb-watcher.py | Not integrated | Needs hybrid_indexer.py |
| Qdrant Vectors | Qdrant DB | Empty | No indexing running |
| Hybrid Search | kb-mcp-server.py | Not implemented | Needs Qdrant vectors |
| MCP External Access | Pomerium config | Not configured | Security design needed |

---

## 3. Component Specifications

### 3.1 Vertex AI Embedding Service

**Purpose:** Convert document text into 768-dimensional vectors for semantic search.

**Configuration:**
```yaml
Model: text-embedding-005
Dimensions: 768
Max tokens per request: 2048
Rate limit: 600 requests/minute
Project: it-services-automations
Region: europe-west1
```

**Python Implementation:**
```python
from google.cloud import aiplatform
from google.cloud.aiplatform import TextEmbeddingModel

def get_embeddings(texts: list[str]) -> list[list[float]]:
    """Generate embeddings using Vertex AI."""
    model = TextEmbeddingModel.from_pretrained("text-embedding-005")
    embeddings = model.get_embeddings(texts)
    return [e.values for e in embeddings]
```

**Chunking Strategy:**
```
Document (e.g., 5000 words)
        |
        v
+------------------+
| Chunk by section |
| (## headings)    |
+------------------+
        |
        v
[Chunk 1: 500 words] [Chunk 2: 800 words] [Chunk 3: 600 words]
        |                    |                    |
        v                    v                    v
   [Vector 1]           [Vector 2]           [Vector 3]
        |                    |                    |
        +--------------------+--------------------+
                             |
                             v
                    Store in Qdrant with metadata:
                    - document_id
                    - chunk_index
                    - file_path
                    - title
```

### 3.2 Hybrid Indexer (hybrid_indexer.py)

**Purpose:** Index documents to both MeiliSearch (full text) and Qdrant (vectors).

**Data Flow:**
```
Markdown File
      |
      v
+------------------+
| Parse Frontmatter|
| Extract Content  |
+------------------+
      |
      +------------------+------------------+
      |                                     |
      v                                     v
+------------------+               +------------------+
| MeiliSearch      |               | Chunk Document   |
| (full document)  |               | (by sections)    |
+------------------+               +------------------+
                                            |
                                            v
                                   +------------------+
                                   | Vertex AI        |
                                   | Embeddings       |
                                   +------------------+
                                            |
                                            v
                                   +------------------+
                                   | Qdrant           |
                                   | (vectors + meta) |
                                   +------------------+
```

**Qdrant Collection Schema:**
```json
{
  "collection_name": "knowledge",
  "vectors": {
    "size": 768,
    "distance": "Cosine"
  },
  "payload_schema": {
    "document_id": "keyword",
    "chunk_index": "integer",
    "file_path": "keyword",
    "title": "text",
    "category": "keyword",
    "tags": "keyword[]",
    "content": "text",
    "created": "datetime",
    "updated": "datetime"
  }
}
```

### 3.3 Hybrid Search with RRF Fusion

**Purpose:** Combine keyword and semantic search results for optimal relevance.

**Algorithm: Reciprocal Rank Fusion (RRF)**
```
RRF Score = Σ (1 / (k + rank_i))

Where:
- k = 60 (constant, standard value)
- rank_i = position in result list from search engine i
```

**Example:**
```
Query: "configure SSO for Atlassian"

MeiliSearch Results:          Qdrant Results:
1. atlassian-sso-setup.md     1. google-workspace-sso.md
2. sso-troubleshooting.md     2. atlassian-sso-setup.md
3. atlassian-api-docs.md      3. entra-id-saml.md

RRF Calculation:
- atlassian-sso-setup.md: 1/(60+1) + 1/(60+2) = 0.0164 + 0.0161 = 0.0325
- google-workspace-sso.md: 0 + 1/(60+1) = 0.0164
- sso-troubleshooting.md: 1/(60+2) + 0 = 0.0161
- entra-id-saml.md: 0 + 1/(60+3) = 0.0159
- atlassian-api-docs.md: 1/(60+3) + 0 = 0.0159

Final Ranking:
1. atlassian-sso-setup.md (0.0325) <- Best of both!
2. google-workspace-sso.md (0.0164)
3. sso-troubleshooting.md (0.0161)
4. entra-id-saml.md (0.0159)
5. atlassian-api-docs.md (0.0159)
```

**Implementation:**
```python
def hybrid_search(query: str, limit: int = 10) -> list[dict]:
    """Perform hybrid search with RRF fusion."""
    
    # 1. Keyword search (MeiliSearch)
    meili_results = meili_client.index('knowledge').search(
        query, 
        {'limit': limit * 2}
    )['hits']
    
    # 2. Semantic search (Qdrant)
    query_vector = get_embeddings([query])[0]
    qdrant_results = qdrant_client.search(
        collection_name='knowledge',
        query_vector=query_vector,
        limit=limit * 2
    )
    
    # 3. RRF Fusion
    scores = defaultdict(float)
    k = 60
    
    for rank, hit in enumerate(meili_results, 1):
        doc_id = hit['id']
        scores[doc_id] += 1 / (k + rank)
    
    for rank, hit in enumerate(qdrant_results, 1):
        doc_id = hit.payload['document_id']
        scores[doc_id] += 1 / (k + rank)
    
    # 4. Sort by combined score
    ranked = sorted(scores.items(), key=lambda x: x[1], reverse=True)
    
    return ranked[:limit]
```

---

## 4. MCP Server External Access

### 4.1 Current State

```
CURRENT:
========
External AI Agent
      |
      X  (No access)
      
Internal (SSH):
      |
      v
  kb-mcp-server.py (localhost only)
```

### 4.2 Target Architecture

```
TARGET:
=======
External AI Agent (Claude, GPT, etc.)
      |
      | HTTPS
      v
+------------------+
|    Pomerium      |
| (Google OAuth)   |
+------------------+
      |
      | Authenticated
      v
+------------------+
|  MCP Gateway     |
|  (new service)   |
+------------------+
      |
      | stdio/HTTP
      v
+------------------+
| kb-mcp-server.py |
+------------------+
      |
      v
+--------+--------+
|        |        |
v        v        v
Meili  Qdrant  Files
```

### 4.3 MCP Gateway Options

**Option A: HTTP-to-MCP Bridge (Recommended)**
```
Pros:
- Standard REST API for any client
- Easy to integrate with existing tools
- Can add rate limiting, caching

Cons:
- Not native MCP protocol
- Requires translation layer

Implementation:
- FastAPI service wrapping kb-mcp-server.py
- Endpoints: /search, /read, /list, /recent
- Returns JSON responses
```

**Option B: WebSocket MCP Proxy**
```
Pros:
- Native MCP protocol over WebSocket
- Real-time bidirectional communication
- Standard for MCP clients

Cons:
- More complex to implement
- Requires WebSocket support in Pomerium

Implementation:
- WebSocket server wrapping stdio MCP
- Pomerium WebSocket passthrough
```

**Option C: Server-Sent Events (SSE)**
```
Pros:
- Simpler than WebSocket
- Works with standard HTTP
- Good for streaming responses

Cons:
- One-way communication
- May not suit all MCP patterns
```

### 4.4 Recommended Implementation: HTTP Gateway

**New Service: kb-api-gateway**

```python
#!/usr/bin/env python3
"""
Knowledge Base API Gateway
Exposes MCP tools as REST endpoints for external access.
"""

from fastapi import FastAPI, HTTPException, Depends
from fastapi.security import HTTPBearer
from pydantic import BaseModel
import meilisearch
from qdrant_client import QdrantClient

app = FastAPI(title="TeamOS Knowledge API")
security = HTTPBearer()

class SearchRequest(BaseModel):
    query: str
    category: str | None = None
    limit: int = 10
    hybrid: bool = True  # Use hybrid search by default

class SearchResult(BaseModel):
    id: str
    title: str
    path: str
    category: str
    score: float
    snippet: str

@app.post("/api/v1/search", response_model=list[SearchResult])
async def search(request: SearchRequest, token: str = Depends(security)):
    """Search the knowledge base."""
    # Pomerium validates token, we trust the request
    if request.hybrid:
        results = hybrid_search(request.query, request.limit)
    else:
        results = keyword_search(request.query, request.limit)
    return results

@app.get("/api/v1/documents/{path:path}")
async def read_document(path: str, token: str = Depends(security)):
    """Read a specific document."""
    # Implementation
    pass

@app.get("/api/v1/documents")
async def list_documents(
    category: str | None = None,
    limit: int = 50,
    token: str = Depends(security)
):
    """List documents with optional filtering."""
    pass
```

**Pomerium Route Configuration:**
```yaml
policy:
  - from: https://api.IP.nip.io
    to: http://172.17.0.1:8000
    allowed_domains:
      - example.com
    pass_identity_headers: true
    cors_allow_preflight: true
    set_request_headers:
      X-Pomerium-Claim-Email: ${pomerium.claim.email}
```

### 4.5 Security Considerations

| Concern | Mitigation |
|---------|------------|
| Unauthorized access | Pomerium OAuth (domain-restricted) |
| Rate limiting | FastAPI middleware (100 req/min) |
| Data exfiltration | Audit logging of all queries |
| Injection attacks | Input validation, parameterized queries |
| Token replay | Short-lived Pomerium sessions |

---

## 5. Implementation Plan

### Phase 1: Vector Indexing (Week 1)

```
Day 1-2: Deploy hybrid_indexer.py
├── Create /opt/teamos/bin/hybrid_indexer.py
├── Install google-cloud-aiplatform in venv
├── Create Qdrant collection with schema
└── Test single document indexing

Day 3-4: Integrate with kb-watcher
├── Update kb-watcher.py to call hybrid_indexer
├── Handle chunking for large documents
├── Add error handling and retries
└── Test file change detection

Day 5: Full reindex
├── Run full reindex of all documents
├── Verify vector count in Qdrant
├── Compare MeiliSearch vs Qdrant doc counts
└── Document any indexing failures
```

### Phase 2: Hybrid Search (Week 2)

```
Day 1-2: Update kb-mcp-server.py
├── Add Qdrant client
├── Implement RRF fusion
├── Add hybrid search toggle
└── Test search quality

Day 3: Update kb CLI
├── Add --hybrid flag to search command
├── Update output formatting
└── Test CLI search

Day 4-5: Testing and tuning
├── Compare keyword vs hybrid results
├── Tune RRF k parameter if needed
├── Document search quality improvements
└── Performance benchmarking
```

### Phase 3: External API (Week 3)

```
Day 1-2: Create kb-api-gateway
├── FastAPI application
├── Endpoint implementations
├── Pomerium integration
└── Local testing

Day 3: Deploy and configure
├── Systemd service
├── Pomerium route
├── SSL/TLS verification
└── End-to-end testing

Day 4-5: Documentation and clients
├── API documentation (OpenAPI)
├── Example client code
├── Integration guide for AI agents
└── Rate limiting configuration
```

---

## 6. File Changes Required

### 6.1 New Files

| File | Purpose |
|------|---------|
| /opt/teamos/bin/hybrid_indexer.py | Dual indexing to MeiliSearch + Qdrant |
| /opt/teamos/bin/kb-api-gateway.py | REST API for external access |
| /etc/systemd/system/kb-api-gateway.service | Systemd service |

### 6.2 Modified Files

| File | Changes |
|------|---------|
| /opt/teamos/bin/kb-watcher.py | Call hybrid_indexer instead of indexer |
| /opt/teamos/bin/kb-mcp-server.py | Add hybrid search with RRF |
| /opt/teamos/bin/kb | Add --hybrid flag |
| /opt/teamos/pomerium/config.yaml | Add API gateway route |
| /opt/teamos/docker-compose.yml | No changes (Qdrant already running) |

### 6.3 Terraform Changes

| File | Changes |
|------|---------|
| terraform/scripts/startup.sh | Add hybrid_indexer.py, kb-api-gateway |
| terraform/main.tf | Add firewall rule for API port (if needed) |

---

## 7. Testing Strategy

### 7.1 Unit Tests

```python
# test_hybrid_search.py

def test_rrf_fusion():
    """Test RRF score calculation."""
    meili_results = [{'id': 'a'}, {'id': 'b'}, {'id': 'c'}]
    qdrant_results = [{'id': 'c'}, {'id': 'a'}, {'id': 'd'}]
    
    result = rrf_fusion(meili_results, qdrant_results, k=60)
    
    # 'a' should be first (appears in both, ranks 1 and 2)
    assert result[0]['id'] == 'a'

def test_chunking():
    """Test document chunking by sections."""
    content = "# Title\n\nIntro\n\n## Section 1\n\nContent 1\n\n## Section 2\n\nContent 2"
    chunks = chunk_document(content)
    
    assert len(chunks) == 3  # Intro + 2 sections
```

### 7.2 Integration Tests

```bash
# Test hybrid indexing
echo "# Test Doc" > /data/shared/knowledge/test.md
sleep 5  # Wait for indexer

# Verify in MeiliSearch
curl -s localhost:7700/indexes/knowledge/search -d '{"q":"Test Doc"}' | jq '.hits | length'
# Expected: 1

# Verify in Qdrant
curl -s localhost:6333/collections/knowledge/points/count | jq '.result.count'
# Expected: >= 1

# Cleanup
rm /data/shared/knowledge/test.md
```

### 7.3 Search Quality Tests

| Query | Expected Top Result | Keyword Only | Hybrid |
|-------|---------------------|--------------|--------|
| "how to log in" | authentication-guide.md | ? | ? |
| "Entra ID API" | entra-id/api-reference.md | ? | ? |
| "troubleshoot SSO" | sso-troubleshooting.md | ? | ? |

---

## 8. Rollback Plan

If hybrid search causes issues:

1. **Immediate:** Disable hybrid in kb-mcp-server.py (set `hybrid=False`)
2. **Short-term:** Revert kb-watcher.py to use indexer.py only
3. **Full rollback:** Remove hybrid_indexer.py, restart services

Qdrant data can be safely ignored - MeiliSearch continues to work independently.

---

## 9. Success Metrics

| Metric | Current | Target |
|--------|---------|--------|
| Search relevance (manual eval) | ~60% | >85% |
| Synonym matching | 0% | >80% |
| Query latency (p95) | <50ms | <100ms |
| External API availability | 0% | 99.9% |
| Documents indexed (Qdrant) | 0 | 100% |

---

## 10. Dependencies

### 10.1 Python Packages

```
google-cloud-aiplatform>=1.38.0
qdrant-client>=1.7.0
tiktoken>=0.5.0  # For token counting
fastapi>=0.109.0
uvicorn>=0.27.0
```

### 10.2 GCP APIs

- Vertex AI API (aiplatform.googleapis.com) - Must be enabled
- Service account needs `roles/aiplatform.user`

### 10.3 Network

- Qdrant: localhost:6333 (already available)
- API Gateway: 0.0.0.0:8000 (new)
- Pomerium route for api.*.nip.io

---

## 11. References

- [MeiliSearch Documentation](https://docs.meilisearch.com/)
- [Qdrant Documentation](https://qdrant.tech/documentation/)
- [Vertex AI Embeddings](https://cloud.google.com/vertex-ai/docs/generative-ai/embeddings/get-text-embeddings)
- [Reciprocal Rank Fusion Paper](https://plg.uwaterloo.ca/~gvcormac/cormacksigir09-rrf.pdf)
- [MCP Protocol Specification](https://modelcontextprotocol.io/)
- concepts/08-hybrid-search-vector-database.md
- concepts/09-opencode-server-pomerium.md
- concepts/10-multi-client-architecture.md
