# Concept 08: Hybrid Search with Vector Database

**Status:** Proposal  
**Created:** 2025-01-11  
**Author:** TeamOS  
**Depends on:** [01-knowledge-base-document-search.md](01-knowledge-base-document-search.md)

---

## Executive Summary

Add semantic vector search alongside the existing MeiliSearch keyword search to create a hybrid retrieval system. This reduces LLM token consumption by 4-10x while improving search quality for natural language queries.

**Key Benefits:**
- **Token efficiency**: Retrieve relevant chunks instead of whole documents
- **Semantic understanding**: Find conceptually related content, not just keyword matches
- **Faster responses**: Smaller context = faster LLM processing
- **Better AI experience**: More precise context = better answers

---

## Problem Statement

### Current Limitations

The existing MeiliSearch-based search has three limitations for AI agents:

#### 1. Document-Level Granularity

MeiliSearch returns **whole documents**. A 3000-token document is returned even if only one paragraph is relevant.

```
Query: "What port does MeiliSearch run on?"

Current: Returns entire vm-setup.md (3000 tokens)
Ideal:   Returns one paragraph (200 tokens)
```

#### 2. Keyword Dependency

MeiliSearch requires keyword overlap. Semantic equivalents don't match.

```
Query: "How do I add a new team member?"

MeiliSearch: Searches for "add", "new", "team", "member"
             Misses: "onboarding", "user provisioning", "employee setup"

Vector:      Understands semantic meaning
             Finds: onboarding docs, user creation runbooks
```

#### 3. Token Waste

AI agents consume tokens proportional to retrieved content:

| Scenario | Documents | Avg Size | Total Tokens | Cost (GPT-4) |
|----------|-----------|----------|--------------|--------------|
| Current  | 5 docs    | 2000     | 10,000       | ~$0.30       |
| Proposed | 5 chunks  | 400      | 2,000        | ~$0.06       |

**5x reduction in token consumption per query.**

---

## Proposed Solution

### Hybrid Search Architecture

Run MeiliSearch and Qdrant (vector database) in parallel, combining results:

```
┌─────────────────────────────────────────────────────────────────────┐
│                           User Query                                 │
│                  "How do I configure SSO?"                          │
└─────────────────────────────┬───────────────────────────────────────┘
                              │
                              ▼
                    ┌───────────────────┐
                    │   Query Router    │
                    │                   │
                    │ • Embed query     │
                    │ • Fan out search  │
                    └─────────┬─────────┘
                              │
              ┌───────────────┴───────────────┐
              ▼                               ▼
    ┌───────────────────┐           ┌───────────────────┐
    │    MeiliSearch    │           │      Qdrant       │
    │                   │           │                   │
    │ • Keyword match   │           │ • Vector similarity│
    │ • Fuzzy search    │           │ • Semantic match  │
    │ • Exact phrases   │           │ • Concept finding │
    │                   │           │                   │
    │ Returns: doc IDs  │           │ Returns: chunk IDs│
    │ + relevance score │           │ + similarity score│
    └─────────┬─────────┘           └─────────┬─────────┘
              │                               │
              └───────────────┬───────────────┘
                              ▼
                    ┌───────────────────┐
                    │  Result Merger    │
                    │                   │
                    │ • Normalize scores│
                    │ • Deduplicate     │
                    │ • Re-rank (RRF)   │
                    │ • Top-K selection │
                    └─────────┬─────────┘
                              │
                              ▼
                    ┌───────────────────┐
                    │  Context Builder  │
                    │                   │
                    │ • Fetch chunks    │
                    │ • Add metadata    │
                    │ • Format for LLM  │
                    └─────────┬─────────┘
                              │
                              ▼
                    ┌───────────────────┐
                    │   LLM Context     │
                    │   (2-3K tokens)   │
                    └───────────────────┘
```

### Why Hybrid?

Neither approach alone is sufficient:

| Query Type | MeiliSearch | Vector | Winner |
|------------|-------------|--------|--------|
| "error code AUTH-403" | ✅ Exact match | ❌ May miss | Keyword |
| "how to add users" | ⚠️ Needs exact words | ✅ Semantic | Vector |
| "MeiliSearch port 7700" | ✅ Both terms | ✅ Concept | Tie |
| "authentication problems" | ⚠️ Partial | ✅ Finds SSO, OAuth | Vector |

**Hybrid catches both exact matches AND semantic relationships.**

---

## Technical Design

### Component Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│                         TeamOS Server                                │
│                                                                      │
│  ┌──────────────────────────────────────────────────────────────┐   │
│  │                    Knowledge Base                             │   │
│  │                 /data/shared/knowledge/                       │   │
│  └──────────────────────────┬───────────────────────────────────┘   │
│                             │                                        │
│                             ▼                                        │
│  ┌──────────────────────────────────────────────────────────────┐   │
│  │                    File Watcher                               │   │
│  │                  (kb-watcher.py)                              │   │
│  │                                                               │   │
│  │  On file change:                                              │   │
│  │  1. Parse markdown + frontmatter                              │   │
│  │  2. Update MeiliSearch (full doc)                             │   │
│  │  3. Chunk document                                            │   │
│  │  4. Generate embeddings                                       │   │
│  │  5. Upsert to Qdrant                                          │   │
│  └──────────────────────────┬───────────────────────────────────┘   │
│                             │                                        │
│              ┌──────────────┴──────────────┐                        │
│              ▼                             ▼                         │
│  ┌─────────────────────┐       ┌─────────────────────┐              │
│  │     MeiliSearch     │       │       Qdrant        │              │
│  │                     │       │                     │              │
│  │  Port: 7700         │       │  Port: 6333         │              │
│  │  Index: knowledge   │       │  Collection: kb     │              │
│  │                     │       │                     │              │
│  │  Stores:            │       │  Stores:            │              │
│  │  • Full documents   │       │  • Chunk vectors    │              │
│  │  • Metadata         │       │  • Chunk text       │              │
│  │  • Searchable text  │       │  • Source metadata  │              │
│  └─────────────────────┘       └─────────────────────┘              │
│              │                             │                         │
│              └──────────────┬──────────────┘                        │
│                             ▼                                        │
│  ┌──────────────────────────────────────────────────────────────┐   │
│  │                    MCP Server                                 │   │
│  │                (kb-mcp-server.py)                             │   │
│  │                                                               │   │
│  │  Tools:                                                       │   │
│  │  • kb_search  → Hybrid search (vector + keyword)              │   │
│  │  • kb_read    → Full document retrieval                       │   │
│  │  • kb_list    → Document listing                              │   │
│  │  • kb_recent  → Recent changes                                │   │
│  └──────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────┘
```

### 1. Document Chunking Strategy

Chunks must be:
- **Self-contained**: Understandable without surrounding context
- **Appropriately sized**: 200-500 tokens (balance between precision and context)
- **Semantically coherent**: Don't split mid-thought

#### Chunking Algorithm

```python
def chunk_document(filepath: str, content: str) -> list[Chunk]:
    """
    Chunk a markdown document by headings, with size limits.
    
    Strategy:
    1. Split by ## headings (sections)
    2. If section > 500 tokens, split by paragraphs
    3. If paragraph > 500 tokens, split by sentences
    4. Preserve heading context in each chunk
    """
    chunks = []
    frontmatter, body = parse_frontmatter(content)
    
    # Split by level-2 headings
    sections = split_by_headings(body, level=2)
    
    for section in sections:
        heading = section.heading  # e.g., "## SSH Access"
        text = section.content
        
        if count_tokens(text) <= 500:
            # Section fits in one chunk
            chunks.append(Chunk(
                text=f"{heading}\n\n{text}",
                source=filepath,
                heading=heading,
                metadata=frontmatter
            ))
        else:
            # Split large sections by paragraph
            paragraphs = split_by_paragraphs(text)
            for i, para in enumerate(paragraphs):
                if count_tokens(para) <= 500:
                    chunks.append(Chunk(
                        text=f"{heading}\n\n{para}",
                        source=filepath,
                        heading=heading,
                        chunk_index=i,
                        metadata=frontmatter
                    ))
                else:
                    # Split very large paragraphs by sentence
                    sentences = split_by_sentences(para)
                    current_chunk = []
                    current_tokens = 0
                    
                    for sentence in sentences:
                        sent_tokens = count_tokens(sentence)
                        if current_tokens + sent_tokens > 500:
                            chunks.append(Chunk(
                                text=f"{heading}\n\n" + " ".join(current_chunk),
                                source=filepath,
                                heading=heading,
                                metadata=frontmatter
                            ))
                            current_chunk = [sentence]
                            current_tokens = sent_tokens
                        else:
                            current_chunk.append(sentence)
                            current_tokens += sent_tokens
                    
                    if current_chunk:
                        chunks.append(Chunk(
                            text=f"{heading}\n\n" + " ".join(current_chunk),
                            source=filepath,
                            heading=heading,
                            metadata=frontmatter
                        ))
    
    return chunks
```

#### Chunk Metadata

Each chunk stores:

```python
@dataclass
class Chunk:
    id: str              # "{filepath}#chunk{n}"
    text: str            # The actual chunk content
    source: str          # Original file path
    heading: str         # Section heading for context
    chunk_index: int     # Position in document
    metadata: dict       # Frontmatter (title, category, tags, etc.)
    token_count: int     # For context budget management
```

### 2. Embedding Strategy

#### Model Selection

| Model | Dimensions | Speed | Quality | Cost |
|-------|------------|-------|---------|------|
| **Google text-embedding-005** | 768 | Fast | Best | $0.00002/1K chars |
| Google text-embedding-004 | 768 | Fast | Good | $0.00002/1K chars |
| OpenAI text-embedding-3-small | 1536 | Fast | Good | $0.02/1M tokens |
| Ollama nomic-embed-text | 768 | Local | Good | Free |

**Decision:** Use **Google Vertex AI `text-embedding-005`** (textembedding-gecko).

Rationale:
- Company runs on GCP with full control (no permission needed)
- Vertex AI already available in `it-services-automations` project
- Native GCP integration, same billing
- Excellent quality, competitive pricing
- 768 dimensions = smaller vectors = faster search

#### Embedding Pipeline

```python
from google.cloud import aiplatform
from vertexai.language_models import TextEmbeddingModel
from qdrant_client import QdrantClient
from qdrant_client.models import PointStruct, VectorParams, Distance

# Initialize clients
aiplatform.init(project="it-services-automations", location="europe-west1")
embedding_model = TextEmbeddingModel.from_pretrained("text-embedding-005")
qdrant = QdrantClient(host="localhost", port=6333)

# Create collection (once)
qdrant.create_collection(
    collection_name="knowledge",
    vectors_config=VectorParams(
        size=768,  # text-embedding-005 dimensions
        distance=Distance.COSINE
    )
)

def embed_chunks(chunks: list[Chunk]) -> list[PointStruct]:
    """Generate embeddings using Vertex AI and prepare for Qdrant upsert."""
    
    # Batch embed for efficiency (max 250 texts per batch)
    texts = [chunk.text for chunk in chunks]
    embeddings = embedding_model.get_embeddings(texts)
    
    points = []
    for chunk, embedding in zip(chunks, embeddings):
        points.append(PointStruct(
            id=hash(chunk.id) % (2**63),  # Qdrant needs int IDs
            vector=embedding.values,
            payload={
                "chunk_id": chunk.id,
                "text": chunk.text,
                "source": chunk.source,
                "heading": chunk.heading,
                "chunk_index": chunk.chunk_index,
                "title": chunk.metadata.get("title"),
                "category": chunk.metadata.get("category"),
                "tags": chunk.metadata.get("tags", []),
                "token_count": chunk.token_count
            }
        ))
    
    return points

def index_document(filepath: str, content: str):
    """Full indexing pipeline for a single document."""
    
    # 1. Chunk the document
    chunks = chunk_document(filepath, content)
    
    # 2. Delete old chunks for this file
    qdrant.delete(
        collection_name="knowledge",
        points_selector=models.FilterSelector(
            filter=models.Filter(
                must=[
                    models.FieldCondition(
                        key="source",
                        match=models.MatchValue(value=filepath)
                    )
                ]
            )
        )
    )
    
    # 3. Generate embeddings and upsert
    points = embed_chunks(chunks)
    qdrant.upsert(collection_name="knowledge", points=points)
    
    print(f"Indexed {len(chunks)} chunks from {filepath}")
```

### 3. Hybrid Search Implementation

#### Reciprocal Rank Fusion (RRF)

Combine results from both search engines using RRF:

```python
def reciprocal_rank_fusion(
    results_lists: list[list[dict]],
    k: int = 60
) -> list[dict]:
    """
    Combine multiple ranked lists using Reciprocal Rank Fusion.
    
    RRF score = Σ 1 / (k + rank)
    
    This gives higher weight to items ranked highly in multiple lists.
    """
    scores = {}
    
    for results in results_lists:
        for rank, result in enumerate(results):
            doc_id = result["id"]
            if doc_id not in scores:
                scores[doc_id] = {"score": 0, "data": result}
            scores[doc_id]["score"] += 1 / (k + rank + 1)
    
    # Sort by combined score
    sorted_results = sorted(
        scores.values(),
        key=lambda x: x["score"],
        reverse=True
    )
    
    return [item["data"] for item in sorted_results]
```

#### Hybrid Search Function

```python
async def hybrid_search(
    query: str,
    limit: int = 5,
    category: str = None,
    keyword_weight: float = 0.3,
    vector_weight: float = 0.7
) -> list[SearchResult]:
    """
    Perform hybrid search combining MeiliSearch and Qdrant.
    
    Args:
        query: Natural language search query
        limit: Maximum results to return
        category: Optional category filter
        keyword_weight: Weight for keyword results (0-1)
        vector_weight: Weight for vector results (0-1)
    
    Returns:
        List of SearchResult with chunks and metadata
    """
    
    # 1. Embed the query using Vertex AI
    query_embeddings = embedding_model.get_embeddings([query])
    query_embedding = query_embeddings[0].values
    
    # 2. Search both engines in parallel
    keyword_task = search_meilisearch(query, limit=limit*2, category=category)
    vector_task = search_qdrant(query_embedding, limit=limit*2, category=category)
    
    keyword_results, vector_results = await asyncio.gather(
        keyword_task, vector_task
    )
    
    # 3. Normalize and weight scores
    keyword_results = normalize_scores(keyword_results, weight=keyword_weight)
    vector_results = normalize_scores(vector_results, weight=vector_weight)
    
    # 4. Combine using RRF
    combined = reciprocal_rank_fusion([keyword_results, vector_results])
    
    # 5. Deduplicate (same source file, overlapping chunks)
    deduplicated = deduplicate_chunks(combined)
    
    # 6. Return top results
    return deduplicated[:limit]


async def search_meilisearch(
    query: str,
    limit: int,
    category: str = None
) -> list[dict]:
    """Keyword search via MeiliSearch."""
    
    filters = []
    if category:
        filters.append(f"category = '{category}'")
    
    results = meili_client.index("knowledge").search(
        query,
        {
            "limit": limit,
            "filter": " AND ".join(filters) if filters else None,
            "attributesToRetrieve": ["id", "title", "content", "category"]
        }
    )
    
    return [
        {
            "id": hit["id"],
            "text": hit["content"][:2000],  # Truncate for context
            "source": hit["id"],
            "score": hit.get("_rankingScore", 0),
            "type": "keyword"
        }
        for hit in results["hits"]
    ]


async def search_qdrant(
    query_embedding: list[float],
    limit: int,
    category: str = None
) -> list[dict]:
    """Vector search via Qdrant."""
    
    filters = None
    if category:
        filters = models.Filter(
            must=[
                models.FieldCondition(
                    key="category",
                    match=models.MatchValue(value=category)
                )
            ]
        )
    
    results = qdrant.search(
        collection_name="knowledge",
        query_vector=query_embedding,
        limit=limit,
        query_filter=filters
    )
    
    return [
        {
            "id": hit.payload["chunk_id"],
            "text": hit.payload["text"],
            "source": hit.payload["source"],
            "heading": hit.payload["heading"],
            "score": hit.score,
            "type": "vector"
        }
        for hit in results
    ]
```

### 4. Updated MCP Server

```python
# kb-mcp-server.py additions

@server.tool("kb_search")
async def kb_search(
    query: str,
    category: str = None,
    limit: int = 5,
    mode: str = "hybrid"  # "hybrid", "keyword", "vector"
) -> str:
    """
    Search the knowledge base.
    
    Args:
        query: Natural language search query
        category: Filter by category (api-docs, runbooks, decisions, guides)
        limit: Maximum number of results (default: 5)
        mode: Search mode - "hybrid" (default), "keyword", or "vector"
    
    Returns:
        Relevant chunks from the knowledge base with source references.
    """
    
    if mode == "hybrid":
        results = await hybrid_search(query, limit=limit, category=category)
    elif mode == "keyword":
        results = await search_meilisearch(query, limit=limit, category=category)
    elif mode == "vector":
        embedding = embed_query(query)
        results = await search_qdrant(embedding, limit=limit, category=category)
    else:
        return f"Unknown mode: {mode}. Use 'hybrid', 'keyword', or 'vector'."
    
    if not results:
        return "No results found."
    
    # Format results for LLM consumption
    output = []
    total_tokens = 0
    
    for i, result in enumerate(results, 1):
        chunk_text = result["text"]
        source = result["source"]
        heading = result.get("heading", "")
        search_type = result.get("type", "hybrid")
        
        # Track token budget
        chunk_tokens = count_tokens(chunk_text)
        if total_tokens + chunk_tokens > 8000:
            output.append(f"\n[Truncated: {len(results) - i + 1} more results available]")
            break
        
        total_tokens += chunk_tokens
        
        output.append(f"""
---
**Result {i}** ({search_type}) | Source: `{source}`
{f"Section: {heading}" if heading else ""}

{chunk_text}
""")
    
    return "\n".join(output)
```

### 5. Updated File Watcher

```python
# kb-watcher.py additions

from hybrid_indexer import index_document_meilisearch, index_document_qdrant

class KnowledgeBaseHandler(FileSystemEventHandler):
    
    def on_modified(self, event):
        if event.is_directory:
            return
        if not event.src_path.endswith('.md'):
            return
        
        filepath = event.src_path
        
        try:
            with open(filepath, 'r') as f:
                content = f.read()
            
            # Index in both systems
            index_document_meilisearch(filepath, content)  # Existing
            index_document_qdrant(filepath, content)       # New
            
            logger.info(f"Indexed (hybrid): {filepath}")
            
        except Exception as e:
            logger.error(f"Failed to index {filepath}: {e}")
    
    def on_deleted(self, event):
        if event.is_directory:
            return
        if not event.src_path.endswith('.md'):
            return
        
        filepath = event.src_path
        
        # Remove from both systems
        delete_from_meilisearch(filepath)
        delete_from_qdrant(filepath)
        
        logger.info(f"Removed from index: {filepath}")
```

---

## Infrastructure Changes

### Docker Compose Addition

```yaml
# docker-compose.yml

services:
  meilisearch:
    image: getmeili/meilisearch:v1.6
    container_name: meilisearch
    ports:
      - "127.0.0.1:7700:7700"
    volumes:
      - /data/docker/meilisearch:/meili_data
    environment:
      - MEILI_MASTER_KEY=${MEILI_MASTER_KEY}
      - MEILI_ENV=production
    restart: unless-stopped

  qdrant:
    image: qdrant/qdrant:v1.7.4
    container_name: qdrant
    ports:
      - "127.0.0.1:6333:6333"
      - "127.0.0.1:6334:6334"  # gRPC
    volumes:
      - /data/docker/qdrant:/qdrant/storage
    environment:
      - QDRANT__SERVICE__GRPC_PORT=6334
    restart: unless-stopped

  # ... other services
```

### Resource Requirements

| Service | RAM | Disk | CPU |
|---------|-----|------|-----|
| MeiliSearch | 512MB | 1GB | 0.5 |
| Qdrant | 512MB | 2GB | 0.5 |
| Embeddings (API) | - | - | - |
| **Total Additional** | **1GB** | **3GB** | **1 core** |

For local embeddings (Ollama), add:
- RAM: +4GB
- Disk: +4GB (model storage)
- GPU: Optional but recommended

---

## Migration Plan

### Phase 1: Deploy Qdrant (Day 1)

1. Add Qdrant to docker-compose.yml
2. Start Qdrant container
3. Verify connectivity

```bash
# Test Qdrant
curl http://localhost:6333/collections
```

### Phase 2: Implement Indexer (Day 1-2)

1. Create `hybrid_indexer.py` with chunking + embedding
2. Run full re-index of existing documents
3. Verify chunk count and quality

```bash
# Full re-index
python3 /opt/teamos/bin/hybrid_indexer.py --full
```

### Phase 3: Update Watcher (Day 2)

1. Modify `kb-watcher.py` to index both systems
2. Test with file modifications
3. Verify real-time sync

### Phase 4: Update MCP Server (Day 2-3)

1. Add hybrid search to `kb-mcp-server.py`
2. Update `kb_search` tool with mode parameter
3. Test with various queries

### Phase 5: Validation (Day 3)

1. Compare search quality: keyword vs vector vs hybrid
2. Measure token consumption reduction
3. Test edge cases (exact matches, semantic queries)

### Phase 6: Documentation (Day 3)

1. Update AGENTS.md with new search capabilities
2. Document hybrid search in vm-setup.md
3. Add troubleshooting section

---

## Cost Analysis

### Embedding Costs (OpenAI)

| Metric | Value |
|--------|-------|
| Documents | ~50 |
| Avg chunks per doc | ~10 |
| Total chunks | ~500 |
| Avg tokens per chunk | ~300 |
| Total tokens | ~150,000 |
| Initial index cost | ~$0.003 |
| Monthly updates (est.) | ~$0.01 |

**Embedding cost is negligible.**

### Token Savings

| Metric | Before | After | Savings |
|--------|--------|-------|---------|
| Tokens per search | 10,000 | 2,000 | 8,000 |
| Searches per day | 50 | 50 | - |
| Daily tokens | 500,000 | 100,000 | 400,000 |
| Monthly tokens | 15M | 3M | 12M |
| Monthly cost (GPT-4) | $450 | $90 | **$360** |

**ROI: Embedding costs ($0.01/mo) vs token savings ($360/mo) = 36,000x return.**

---

## Success Metrics

| Metric | Current | Target | Measurement |
|--------|---------|--------|-------------|
| Tokens per search | ~10,000 | <3,000 | Log analysis |
| Search latency | ~200ms | <300ms | P95 timing |
| Semantic recall | N/A | >80% | Manual evaluation |
| Exact match recall | ~90% | >90% | Automated tests |
| Index freshness | <5s | <10s | Watcher logs |

---

## Risks and Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Bad chunking splits context | Medium | Medium | Include heading in every chunk |
| Embedding API downtime | High | Low | Queue failed embeds, retry |
| Qdrant data loss | High | Low | Regular backups to GCS |
| Increased complexity | Medium | High | Clear separation of concerns |
| Cost overrun (embeddings) | Low | Low | Monitor usage, switch to local if needed |

---

## Future Enhancements

### Short-term (1-3 months)

1. **Query classification**: Auto-detect if query needs keyword vs semantic
2. **Re-ranking**: Add cross-encoder for final result ordering
3. **Caching**: Cache frequent query embeddings

### Medium-term (3-6 months)

1. **Local embeddings**: Migrate to Ollama for zero-cost embeddings
2. **Multi-modal**: Embed images and diagrams
3. **Personalization**: Weight results by user's team/role

### Long-term (6-12 months)

1. **Knowledge graph**: Extract entities and relationships
2. **Auto-summarization**: Generate chunk summaries for faster scanning
3. **Feedback loop**: Learn from which results users actually use

---

## Appendix A: Qdrant Collection Schema

```json
{
  "collection_name": "knowledge",
  "vectors": {
    "size": 768,
    "distance": "Cosine"
  },
  "payload_schema": {
    "chunk_id": "keyword",
    "text": "text",
    "source": "keyword",
    "heading": "keyword",
    "chunk_index": "integer",
    "title": "keyword",
    "category": "keyword",
    "tags": "keyword[]",
    "token_count": "integer",
    "created": "datetime",
    "updated": "datetime"
  }
}
```

---

## Appendix B: Example Queries and Expected Behavior

### Query 1: Exact Match (Keyword Wins)

```
Query: "error AUTH-403"

MeiliSearch: Finds exact string in troubleshooting.md
Qdrant: May not find (no semantic meaning to error code)

Result: Keyword result ranked first
```

### Query 2: Semantic Match (Vector Wins)

```
Query: "how do I add a new team member"

MeiliSearch: Searches for "add", "new", "team", "member"
             Partial matches in various docs

Qdrant: Understands intent = onboarding
        Finds: onboarding-checklist.md, user-provisioning.md

Result: Vector results ranked first
```

### Query 3: Hybrid (Both Contribute)

```
Query: "configure MeiliSearch for production"

MeiliSearch: Finds "MeiliSearch" and "production" keywords
Qdrant: Finds search engine setup, deployment configs

Result: Combined results from both, deduplicated
```

---

## Appendix C: File Structure After Implementation

```
/opt/teamos/
├── bin/
│   ├── kb                      # CLI tool (unchanged)
│   ├── kb-mcp-server.py        # Updated with hybrid search
│   ├── kb-watcher.py           # Updated for dual indexing
│   ├── indexer.py              # MeiliSearch indexer (existing)
│   └── hybrid_indexer.py       # New: Qdrant chunking + embedding
├── lib/
│   ├── chunker.py              # Document chunking logic
│   ├── embedder.py             # Embedding generation
│   └── hybrid_search.py        # RRF and result merging
├── venv/                       # Python environment
└── docker-compose.yml          # Updated with Qdrant

/data/docker/
├── meilisearch/                # MeiliSearch data
└── qdrant/                     # Qdrant vector storage
```

---

## Decision

**Recommended:** Proceed with hybrid search implementation.

The token savings alone justify the effort, and the improved search quality will significantly enhance the AI agent experience.

**Next Steps:**
1. Review and approve this design
2. Create implementation tasks
3. Begin Phase 1 (Deploy Qdrant)
