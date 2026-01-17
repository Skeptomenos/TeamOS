# Cognitive Knowledge Architecture for AI Agents

**Version:** 1.0  
**Date:** 2026-01-11  
**Status:** Concept Paper  
**Authors:** TeamOS + Thoth Project  

---

## Executive Summary

This paper presents a **Cognitive Knowledge Architecture** — a framework for how AI agents should think about, navigate, maintain, and reason over persistent knowledge bases. 

The key insight is that modern RAG (Retrieval-Augmented Generation) infrastructure has largely solved the *how* of knowledge retrieval — chunking, embedding, hybrid search, and ranking are well-understood problems with commodity solutions. What remains unsolved is the *cognitive layer* — the behavioral guidance that tells an AI agent how to approach knowledge systematically, avoid context explosion, maintain knowledge integrity over time, and operate with appropriate autonomy.

**Our contribution is not another RAG system. It is the librarian's mind that sits atop the library's catalog.**

---

## Part I: The Cognitive Layer (Our Contribution)

### 1. Progressive Context Disclosure

#### The Problem

AI agents with access to large knowledge bases face a fundamental tension:
- **Too little context** → Hallucination, missed connections, incomplete answers
- **Too much context** → Token explosion, confusion, degraded reasoning, high cost

Current RAG systems address this with relevance ranking — return the top-K most relevant chunks. But relevance ranking alone doesn't solve the cognitive problem: the AI doesn't know *what it doesn't know*. It may dive deep into a specific document without understanding the broader landscape, missing critical context that would change its interpretation.

#### The Solution: The Circle Model

We propose a **progressive disclosure discipline** that mirrors how expert humans approach unfamiliar knowledge domains:

```
┌─────────────────────────────────────────────────────────────────────┐
│                     PROGRESSIVE CONTEXT DISCLOSURE                   │
│                                                                      │
│   CIRCLE 1: MAP                                                      │
│   ┌─────────────────────────────────────────────────────────────┐   │
│   │  "What exists? How is it organized?"                         │   │
│   │                                                              │   │
│   │  • Index files, registries, dashboards                       │   │
│   │  • High-level summaries and overviews                        │   │
│   │  • Structural understanding before content                   │   │
│   │                                                              │   │
│   │  ALWAYS ACCESS FIRST. Orientation before exploration.        │   │
│   └─────────────────────────────────────────────────────────────┘   │
│                              │                                       │
│                              ▼                                       │
│   CIRCLE 2: TERRITORY                                                │
│   ┌─────────────────────────────────────────────────────────────┐   │
│   │  "What specifically addresses my query?"                     │   │
│   │                                                              │   │
│   │  • Entity files (people, projects, decisions)                │   │
│   │  • Targeted documents matching clear intent                  │   │
│   │  • Specific context for identified needs                     │   │
│   │                                                              │   │
│   │  ACCESS WHEN INTENT IS CLEAR. Targeted retrieval.            │   │
│   └─────────────────────────────────────────────────────────────┘   │
│                              │                                       │
│                              ▼                                       │
│   CIRCLE 3: DEEP DIVE                                                │
│   ┌─────────────────────────────────────────────────────────────┐   │
│   │  "What are all the details?"                                 │   │
│   │                                                              │   │
│   │  • Full document content, historical logs                    │   │
│   │  • Exhaustive search across knowledge base                   │   │
│   │  • Deep exploration of specific topics                       │   │
│   │                                                              │   │
│   │  ACCESS ONLY WHEN CIRCLES 1-2 INSUFFICIENT.                  │   │
│   │  Never deep-dive without orientation.                        │   │
│   └─────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────┘
```

#### Why This Matters

The Circle Model is **cognitive discipline**, not just an algorithm. RAPTOR and similar hierarchical retrieval systems build tree structures algorithmically — they create summaries at different levels. But they don't tell the AI *how to use* that hierarchy. An AI with RAPTOR might still retrieve leaf nodes directly, bypassing the orientation that higher-level summaries provide.

The Circle Model instructs the AI:
- **Resist the urge to deep-dive immediately**
- **Orient before exploring**
- **Understand structure before content**

This is behavioral guidance that complements infrastructure, not a replacement for it.

#### Enforcement Mechanism

The Circle Model can be enforced at multiple layers:
- **Prompt layer**: Instructions to check Circle 1 before Circle 3
- **Hook layer**: Track reads by circle, warn if deep-diving without orientation
- **Infrastructure layer**: Boost Circle 1 content in search rankings

---

### 2. The Smart Merge Protocol

#### The Problem

Knowledge bases decay. Information becomes outdated, contradictory, or duplicated. Traditional systems treat knowledge as append-only — new information is added, but old information persists. Over time, the knowledge base becomes a palimpsest of outdated facts, conflicting statements, and redundant entries.

RAG systems don't address this. They retrieve information but don't maintain it. The assumption is that humans will curate the knowledge base. But when AI agents are the primary writers (as in AI-assisted knowledge management), there's no human in the loop to catch decay.

#### The Solution: Smart Merge as Cognitive Protocol

We propose a **Smart Merge Protocol** — a set of behavioral rules for how AI agents should update existing knowledge:

```
┌─────────────────────────────────────────────────────────────────────┐
│                        SMART MERGE PROTOCOL                          │
│                                                                      │
│   STEP 1: READ BEFORE WRITE                                          │
│   ┌─────────────────────────────────────────────────────────────┐   │
│   │  Before modifying any document, read its current content.    │   │
│   │  Understand the existing narrative, structure, and facts.    │   │
│   │  Never write blind.                                          │   │
│   └─────────────────────────────────────────────────────────────┘   │
│                              │                                       │
│                              ▼                                       │
│   STEP 2: INTEGRATE, DON'T APPEND                                    │
│   ┌─────────────────────────────────────────────────────────────┐   │
│   │  New information merges INTO existing sections.              │   │
│   │  The document body represents CURRENT STATE.                 │   │
│   │  A reader should understand the present without archaeology. │   │
│   │                                                              │   │
│   │  WRONG: "Update: As of Jan 2026, the status is now X"        │   │
│   │  RIGHT: Change "Status: Y" to "Status: X"                    │   │
│   └─────────────────────────────────────────────────────────────┘   │
│                              │                                       │
│                              ▼                                       │
│   STEP 3: COMPARE CONFIDENCE                                         │
│   ┌─────────────────────────────────────────────────────────────┐   │
│   │  When new information conflicts with existing:               │   │
│   │                                                              │   │
│   │  • New confidence > Existing → Update                        │   │
│   │  • New confidence < Existing → Don't change                  │   │
│   │  • Confidence unclear → Ask human                            │   │
│   │                                                              │   │
│   │  Sources of confidence: recency, authority, specificity      │   │
│   └─────────────────────────────────────────────────────────────┘   │
│                              │                                       │
│                              ▼                                       │
│   STEP 4: DEDUPLICATE                                                │
│   ┌─────────────────────────────────────────────────────────────┐   │
│   │  One source of truth per fact.                               │   │
│   │  Before creating new content, check if it exists elsewhere.  │   │
│   │  If similar content exists, update it rather than duplicate. │   │
│   └─────────────────────────────────────────────────────────────┘   │
│                              │                                       │
│                              ▼                                       │
│   STEP 5: LOG SIGNIFICANT CHANGES                                    │
│   ┌─────────────────────────────────────────────────────────────┐   │
│   │  Maintain audit trail at document bottom (Progress Log).     │   │
│   │  Format: YYYY-MM-DD: [Change description] (source)           │   │
│   │                                                              │   │
│   │  The log is for history. The body is for current truth.      │   │
│   └─────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────┘
```

#### Why This Matters

No existing RAG or memory system addresses knowledge maintenance at the cognitive level. Systems like Mem0 extract and store facts, but they don't provide guidance on *how to update* when facts change. The Smart Merge Protocol fills this gap.

#### Enforcement Mechanism

- **Prompt layer**: Instructions for merge behavior
- **Hook layer**: Detect potential conflicts, inject warnings before writes
- **Infrastructure layer**: Deduplication detection via semantic similarity

---

### 3. The Trust Gradient

#### The Problem

AI agents need varying levels of autonomy for different actions. A fully autonomous agent is dangerous (it might send embarrassing emails). A fully supervised agent is useless (every action requires approval). Current systems offer binary permissions — allowed or not allowed — without nuance.

#### The Solution: Graduated Trust Levels

We propose a **Trust Gradient** — a progressive autonomy model where trust is earned and actions are gated by trust level:

```
┌─────────────────────────────────────────────────────────────────────┐
│                          TRUST GRADIENT                              │
│                                                                      │
│   LEVEL 1: NEW                                                       │
│   ┌─────────────────────────────────────────────────────────────┐   │
│   │  Autonomous: Read, search, internal reasoning                │   │
│   │  Requires Approval: All writes, all external actions         │   │
│   │                                                              │   │
│   │  "I can look, but I need permission to touch."               │   │
│   └─────────────────────────────────────────────────────────────┘   │
│                              │                                       │
│                              ▼ (trust earned over time)              │
│   LEVEL 2: ESTABLISHED                                               │
│   ┌─────────────────────────────────────────────────────────────┐   │
│   │  Autonomous: Knowledge updates, code changes with evidence   │   │
│   │  Requires Approval: External communications, deletions       │   │
│   │                                                              │   │
│   │  "I can maintain the knowledge base and write code."         │   │
│   └─────────────────────────────────────────────────────────────┘   │
│                              │                                       │
│                              ▼ (trust earned over time)              │
│   LEVEL 3: TRUSTED                                                   │
│   ┌─────────────────────────────────────────────────────────────┐   │
│   │  Autonomous: Routine communications, calendar changes        │   │
│   │  Requires Approval: High-stakes external actions             │   │
│   │                                                              │   │
│   │  "I can handle routine tasks independently."                 │   │
│   └─────────────────────────────────────────────────────────────┘   │
│                                                                      │
│   ALWAYS REQUIRE APPROVAL (any trust level):                         │
│   • Sending to external parties (outside organization)               │
│   • Permanent deletions                                              │
│   • Financial transactions                                           │
│   • Modifying permission/trust configuration                         │
└─────────────────────────────────────────────────────────────────────┘
```

#### Why This Matters

The Trust Gradient enables **safe progressive delegation**. As the AI demonstrates reliability, it earns more autonomy. This mirrors how human organizations work — new employees have limited authority that expands with demonstrated competence.

Critically, trust is stored as **knowledge** (in a trust state file), not hardcoded. It can be adjusted, audited, and reasoned about. The AI can even request trust elevation with justification.

#### Enforcement Mechanism

- **Prompt layer**: Awareness of current trust level and its implications
- **Hook layer**: Block actions that exceed current trust level
- **Infrastructure layer**: Audit logging of all actions for trust evaluation

---

### 4. The Hemisphere Model

#### The Problem

Knowledge naturally clusters into domains with different characteristics. Professional knowledge has different confidentiality, tone, and relevance patterns than personal knowledge. Technical knowledge requires different expertise than operational knowledge. Treating all knowledge uniformly leads to inappropriate context mixing and tone mismatches.

#### The Solution: Cognitive Domain Separation

We propose a **Hemisphere Model** — explicit separation of knowledge into domains with distinct cognitive contexts:

```
┌─────────────────────────────────────────────────────────────────────┐
│                         HEMISPHERE MODEL                             │
│                                                                      │
│   ┌───────────────┐  ┌───────────────┐  ┌───────────────┐           │
│   │     WORK      │  │     LIFE      │  │    CODING     │           │
│   │               │  │               │  │               │           │
│   │ Professional  │  │   Personal    │  │   Technical   │           │
│   │ Collaborative │  │   Private     │  │ Project-based │           │
│   │ Team-relevant │  │  Individual   │  │  Code-focused │           │
│   │               │  │               │  │               │           │
│   │ Tone: Formal  │  │ Tone: Casual  │  │ Tone: Precise │           │
│   │ Share: Team   │  │ Share: Never  │  │ Share: Project│           │
│   └───────────────┘  └───────────────┘  └───────────────┘           │
│                              │                                       │
│                              ▼                                       │
│   ┌─────────────────────────────────────────────────────────────┐   │
│   │                        KERNEL                                │   │
│   │                                                              │   │
│   │  System configuration, meta-knowledge, templates, state      │   │
│   │  Rarely accessed directly, supports all other hemispheres    │   │
│   └─────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────┘
```

#### Hemisphere Characteristics

| Hemisphere | Nature | Default Sharing | Tone | Cross-Reference |
|------------|--------|-----------------|------|-----------------|
| **Work** | Professional, collaborative | Team-wide | Formal, clear | Frequent with Coding |
| **Life** | Personal, private | Never | Casual, supportive | Rare |
| **Coding** | Technical, project-specific | Within project | Precise, technical | Frequent with Work |
| **Kernel** | System, meta-knowledge | Internal only | Neutral | Supports all |

#### Why This Matters

The Hemisphere Model provides **cognitive context switching**. When operating in the Work hemisphere, the AI should think and communicate as a professional assistant. In Life, it should be more personal and supportive. In Coding, it should be technically precise.

This isn't just folder organization — it's behavioral guidance that changes how the AI approaches queries, what context it considers relevant, and how it communicates responses.

#### Enforcement Mechanism

- **Prompt layer**: Hemisphere-aware persona and tone guidance
- **Hook layer**: Warn on cross-hemisphere data leakage (especially Life → Work)
- **Infrastructure layer**: Hemisphere as metadata field for filtering

---

### 5. Depth Specialization

#### The Problem

An AI operating at the root of a knowledge base should behave differently than one focused on a specific project. The generalist coordinator needs broad awareness; the project specialist needs deep context. Current systems don't adapt behavior based on scope.

#### The Solution: Depth-Aware Behavior

We propose a **Depth Model** — behavior adaptation based on how deep in the knowledge hierarchy the AI is operating:

```
┌─────────────────────────────────────────────────────────────────────┐
│                         DEPTH MODEL                                  │
│                                                                      │
│   DEPTH 0: ROOT                                                      │
│   ┌─────────────────────────────────────────────────────────────┐   │
│   │  Scope: Entire knowledge base                                │   │
│   │  Role: Generalist coordinator, orchestrator                  │   │
│   │  Context: Minimal — just top-level registries                │   │
│   │  Behavior: Route queries, coordinate across domains          │   │
│   └─────────────────────────────────────────────────────────────┘   │
│                              │                                       │
│                              ▼                                       │
│   DEPTH 1: HEMISPHERE                                                │
│   ┌─────────────────────────────────────────────────────────────┐   │
│   │  Scope: Single domain (Work, Life, Coding)                   │   │
│   │  Role: Domain expert                                         │   │
│   │  Context: Hemisphere overview, dashboard, key entities       │   │
│   │  Behavior: Deep domain knowledge, appropriate tone           │   │
│   └─────────────────────────────────────────────────────────────┘   │
│                              │                                       │
│                              ▼                                       │
│   DEPTH 2: CATEGORY                                                  │
│   ┌─────────────────────────────────────────────────────────────┐   │
│   │  Scope: Category within domain (Projects, People, Runbooks) │   │
│   │  Role: Category specialist                                   │   │
│   │  Context: Category index, related entities                   │   │
│   │  Behavior: Focused expertise, cross-entity awareness         │   │
│   └─────────────────────────────────────────────────────────────┘   │
│                              │                                       │
│                              ▼                                       │
│   DEPTH 3: ENTITY                                                    │
│   ┌─────────────────────────────────────────────────────────────┐   │
│   │  Scope: Specific entity (Project X, Person Y)                │   │
│   │  Role: Deep expert on this entity                            │   │
│   │  Context: Full entity context pre-loaded                     │   │
│   │  Behavior: Authoritative on entity, may lack broader view    │   │
│   └─────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────┘
```

#### Why This Matters

Depth specialization enables **appropriate context loading**. A depth-3 session focused on "Project Alpha" should have Project Alpha's full context pre-loaded — its overview, decisions, stakeholders, history. It shouldn't waste tokens on unrelated projects.

Conversely, a depth-0 session should have minimal pre-loaded context but broad routing capability. It's the coordinator, not the specialist.

#### Enforcement Mechanism

- **Prompt layer**: Depth-appropriate persona and scope awareness
- **Hook layer**: Boot sequence selection based on depth
- **Infrastructure layer**: Pre-load context files based on depth

---

### 6. Layered Enforcement

#### The Problem

Behavioral guidance exists on a spectrum of reliability:
- Some behaviors must be guaranteed (security, audit trails)
- Some behaviors should be encouraged but can be context-dependent
- Some behaviors are infrastructure properties, not agent choices

Current systems conflate these, leading to either over-rigid systems (everything in code) or unreliable systems (everything in prompts).

#### The Solution: Explicit Enforcement Layers

We propose a **Layered Enforcement Model** — explicit separation of behavioral guidance by reliability requirement:

```
┌─────────────────────────────────────────────────────────────────────┐
│                      LAYERED ENFORCEMENT                             │
│                                                                      │
│   ┌─────────────────────────────────────────────────────────────┐   │
│   │                    PROMPT LAYER                              │   │
│   │                    (Soft Guidance ~80%)                      │   │
│   │                                                              │   │
│   │  • Smart Merge Protocol                                      │   │
│   │  • Circle progression discipline                             │   │
│   │  • Source citation practices                                 │   │
│   │  • Tone and communication style                              │   │
│   │  • Index-first retrieval preference                          │   │
│   │                                                              │   │
│   │  Mechanism: System prompt instructions                       │   │
│   │  Reliability: Agent usually follows, may deviate with reason │   │
│   └─────────────────────────────────────────────────────────────┘   │
│                              │                                       │
│                              ▼                                       │
│   ┌─────────────────────────────────────────────────────────────┐   │
│   │                    HOOK LAYER                                │   │
│   │                    (Hard Enforcement 100%)                   │   │
│   │                                                              │   │
│   │  • Frontmatter date injection (created/updated)              │   │
│   │  • Permission blocking (trust level gates)                   │   │
│   │  • Context aperture tracking (circle warnings)               │   │
│   │  • Write confirmation and audit trail                        │   │
│   │  • Deduplication warnings                                    │   │
│   │                                                              │   │
│   │  Mechanism: Code that intercepts tool calls                  │   │
│   │  Reliability: Deterministic, cannot be bypassed              │   │
│   └─────────────────────────────────────────────────────────────┘   │
│                              │                                       │
│                              ▼                                       │
│   ┌─────────────────────────────────────────────────────────────┐   │
│   │                 INFRASTRUCTURE LAYER                         │   │
│   │                 (Always-On Guarantees 100%)                  │   │
│   │                                                              │   │
│   │  • Automatic indexing on file changes                        │   │
│   │  • Search availability and ranking                           │   │
│   │  • Audit logging to immutable store                          │   │
│   │  • Backup and recovery                                       │   │
│   │  • API availability and authentication                       │   │
│   │                                                              │   │
│   │  Mechanism: Background services, infrastructure              │   │
│   │  Reliability: System property, independent of agent          │   │
│   └─────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────┘
```

#### Why This Matters

Layered enforcement provides **reliability where needed and flexibility where appropriate**. Critical behaviors (permissions, audit trails) are guaranteed by hooks and infrastructure. Nuanced behaviors (merge strategies, tone) are guided by prompts but can adapt to context.

This is the key insight: **not everything needs to be in code, and not everything can be in prompts**. The art is knowing which layer each behavior belongs to.

---

### 7. Dual Retrieval Paradigm

#### The Problem

Knowledge access has two fundamentally different modes:
- **Navigation**: "I know the structure, show me what's in Projects"
- **Discovery**: "I don't know where this is, find anything about SSO"

Current systems typically support one mode well. Search-first systems (most RAG) are poor at navigation. Navigation-first systems (file browsers) are poor at discovery. AI agents need both.

#### The Solution: Explicit Dual-Mode Retrieval

We propose a **Dual Retrieval Paradigm** — explicit support for both navigation and discovery, with the AI choosing based on query type:

```
┌─────────────────────────────────────────────────────────────────────┐
│                     DUAL RETRIEVAL PARADIGM                          │
│                                                                      │
│                         ┌─────────────┐                              │
│                         │    QUERY    │                              │
│                         └──────┬──────┘                              │
│                                │                                     │
│                                ▼                                     │
│                    ┌───────────────────────┐                         │
│                    │   QUERY CLASSIFIER    │                         │
│                    │                       │                         │
│                    │  • Structure known?   │                         │
│                    │  • Location clear?    │                         │
│                    │  • Browsing intent?   │                         │
│                    └───────────┬───────────┘                         │
│                                │                                     │
│              ┌─────────────────┴─────────────────┐                   │
│              │                                   │                   │
│              ▼                                   ▼                   │
│   ┌─────────────────────┐             ┌─────────────────────┐       │
│   │   NAVIGATION MODE   │             │   DISCOVERY MODE    │       │
│   │   (Index-First)     │             │   (Search-First)    │       │
│   │                     │             │                     │       │
│   │ 1. Read _index.md   │             │ 1. Hybrid search    │       │
│   │ 2. Identify target  │             │ 2. Rank by RRF      │       │
│   │ 3. Navigate to file │             │ 3. Return chunks    │       │
│   │ 4. Read if needed   │             │ 4. Include context  │       │
│   │                     │             │                     │       │
│   │ Best for:           │             │ Best for:           │       │
│   │ • Known structure   │             │ • Unknown location  │       │
│   │ • Browsing intent   │             │ • Conceptual query  │       │
│   │ • "What's in X?"    │             │ • "Find Y"          │       │
│   └─────────────────────┘             └─────────────────────┘       │
│                                                                      │
│   HYBRID QUERIES: Use both modes                                     │
│   "Find SSO docs in the runbooks folder"                             │
│   → Navigate to runbooks, then search within                         │
└─────────────────────────────────────────────────────────────────────┘
```

#### Why This Matters

The Dual Retrieval Paradigm acknowledges that **different queries need different strategies**. A lookup query ("What's Sarah's email?") shouldn't trigger a full semantic search. A discovery query ("How do we handle authentication?") shouldn't require knowing the file structure.

By making both modes explicit and teaching the AI to choose, we get efficient retrieval for all query types.

---

## Part II: Infrastructure Integration (Adopting Existing Solutions)

The cognitive layer described above sits on top of infrastructure. We don't reinvent infrastructure — we adopt proven solutions and integrate them with our cognitive architecture.

### 1. Hybrid Search (Adopted)

**What it is**: Combining keyword search (BM25/MeiliSearch) with semantic search (vector embeddings/Qdrant) using Reciprocal Rank Fusion (RRF).

**Why we adopt it**: This is a solved problem. Hybrid search consistently outperforms either approach alone.

**Integration with cognitive layer**:
- Circle 1 content (indexes, registries) gets ranking boost
- Search results include structural context (hemisphere, category)
- Query classifier routes to search mode when appropriate

**Recommended implementation**:
- MeiliSearch for keyword search
- Qdrant for vector search
- RRF fusion with k=60
- Vertex AI or OpenAI for embeddings

### 2. Hierarchical Retrieval — RAPTOR (Adopted)

**What it is**: Building a tree of summaries where leaf nodes are original chunks and higher nodes are summaries of clusters. Queries can retrieve at any level.

**Why we adopt it**: RAPTOR (2024) provides the algorithmic foundation for hierarchical retrieval that complements our Circle Model.

**Integration with cognitive layer**:
- RAPTOR tree levels map to Circle levels
- Root/high-level summaries = Circle 1
- Mid-level summaries = Circle 2
- Leaf chunks = Circle 3
- Circle discipline tells the AI *how to use* the hierarchy

**Recommended implementation**:
- Build RAPTOR tree during indexing
- Store summaries at each level
- Query can specify level preference
- Circle tracking monitors level access patterns

### 3. Automatic Indexing (Adopted)

**What it is**: File watcher that triggers indexing on file changes, maintaining search indexes automatically.

**Why we adopt it**: Manual index maintenance doesn't scale. Automatic indexing is standard practice.

**Integration with cognitive layer**:
- File watcher triggers dual indexing (keyword + vector)
- Also updates `_index.md` files automatically (navigation substrate)
- Frontmatter enforcer hook runs during indexing
- Smart Merge warnings generated during indexing

**Recommended implementation**:
- inotify/fswatch for file change detection
- Debounced indexing (avoid thrashing)
- Dual write to MeiliSearch and Qdrant
- Auto-generate `_index.md` from frontmatter

### 4. Chunk-Level Retrieval (Adopted)

**What it is**: Returning relevant paragraphs/sections rather than whole documents.

**Why we adopt it**: Token efficiency. Returning 300-token chunks instead of 3000-token documents reduces cost and improves focus.

**Integration with cognitive layer**:
- Chunks carry structural metadata (source file, section heading)
- Circle 3 retrieval returns chunks, not full documents
- Smart Merge operates at document level, informed by chunk retrieval

**Recommended implementation**:
- Chunk by semantic boundaries (headings, paragraphs)
- Target 200-500 tokens per chunk
- Store chunk metadata (source, position, heading)
- Overlap chunks slightly for context continuity

### 5. Frontmatter Schema (Adopted + Extended)

**What it is**: YAML metadata at the top of markdown files enabling structured queries.

**Why we adopt it**: Standard practice in static site generators, knowledge bases, and documentation systems.

**Integration with cognitive layer**:
- Core fields: title, type, created, updated, tags, status, summary
- Cognitive fields: hemisphere, category, trust_level
- Hook-enforced: created (set once), updated (auto-updated)
- Prompt-guided: type, hemisphere, tags, summary

**Recommended schema**:
```yaml
---
title: "Document Title"
type: document | person | project | decision | runbook
hemisphere: work | life | coding | kernel
category: projects | people | runbooks | api-docs | decisions
created: 2026-01-11          # Auto-set by hook
updated: 2026-01-11          # Auto-updated by hook
created_by: email@example.com # Multi-user systems
updated_by: email@example.com # Multi-user systems
tags: [tag1, tag2]
status: draft | active | review | deprecated
summary: "One-line description for index display"
trust_level: 1 | 2 | 3       # Minimum trust to access
---
```

### 6. Index Files (Adopted + Auto-Generated)

**What it is**: `_index.md` files in each folder summarizing contents for navigation.

**Why we adopt it**: Enables navigation mode, provides Circle 1 content, human-browsable.

**Integration with cognitive layer**:
- Auto-generated from frontmatter during indexing
- Human-editable for narrative context
- Circle 1 content — always accessible first
- Navigation mode uses these as primary substrate

**Recommended format**:
```markdown
# [Folder Name]

Brief description of this folder's purpose.

| Name | File | Summary | Status | Tags |
|------|------|---------|--------|------|
| Project Alpha | alpha.md | Q1 API redesign | active | api, q1 |
| Project Beta | beta.md | Infrastructure migration | paused | infra |
```

---

## Part III: Reference Architecture

### System Overview

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                    COGNITIVE KNOWLEDGE ARCHITECTURE                              │
│                                                                                  │
│  ┌────────────────────────────────────────────────────────────────────────────┐ │
│  │                         COGNITIVE LAYER                                     │ │
│  │                         (Our Contribution)                                  │ │
│  │                                                                             │ │
│  │  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐ ┌─────────────┐           │ │
│  │  │   Circle    │ │   Smart     │ │   Trust     │ │ Hemisphere  │           │ │
│  │  │   Model     │ │   Merge     │ │  Gradient   │ │   Model     │           │ │
│  │  └─────────────┘ └─────────────┘ └─────────────┘ └─────────────┘           │ │
│  │                                                                             │ │
│  │  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐                           │ │
│  │  │   Depth     │ │   Layered   │ │    Dual     │                           │ │
│  │  │   Model     │ │ Enforcement │ │  Retrieval  │                           │ │
│  │  └─────────────┘ └─────────────┘ └─────────────┘                           │ │
│  └────────────────────────────────────────────────────────────────────────────┘ │
│                                      │                                          │
│                                      ▼                                          │
│  ┌────────────────────────────────────────────────────────────────────────────┐ │
│  │                       ENFORCEMENT LAYER                                     │ │
│  │                                                                             │ │
│  │  PROMPT ENFORCEMENT          HOOK ENFORCEMENT                               │ │
│  │  ┌───────────────────┐       ┌───────────────────┐                         │ │
│  │  │ • Circle discipline│       │ • Frontmatter     │                         │ │
│  │  │ • Smart Merge rules│       │ • Permissions     │                         │ │
│  │  │ • Tone guidance    │       │ • Context tracking│                         │ │
│  │  │ • Citation practice│       │ • Write confirm   │                         │ │
│  │  └───────────────────┘       └───────────────────┘                         │ │
│  └────────────────────────────────────────────────────────────────────────────┘ │
│                                      │                                          │
│                                      ▼                                          │
│  ┌────────────────────────────────────────────────────────────────────────────┐ │
│  │                      INFRASTRUCTURE LAYER                                   │ │
│  │                      (Adopted Solutions)                                    │ │
│  │                                                                             │ │
│  │  ┌───────────────┐ ┌───────────────┐ ┌───────────────┐ ┌───────────────┐   │ │
│  │  │  MeiliSearch  │ │    Qdrant     │ │    RAPTOR     │ │ File Watcher  │   │ │
│  │  │  (keyword)    │ │   (vector)    │ │  (hierarchy)  │ │  (indexing)   │   │ │
│  │  └───────────────┘ └───────────────┘ └───────────────┘ └───────────────┘   │ │
│  │                                                                             │ │
│  │  ┌───────────────┐ ┌───────────────┐ ┌───────────────┐                     │ │
│  │  │  Embeddings   │ │  RRF Fusion   │ │  Audit Log    │                     │ │
│  │  │ (Vertex/OAI)  │ │  (ranking)    │ │  (immutable)  │                     │ │
│  │  └───────────────┘ └───────────────┘ └───────────────┘                     │ │
│  └────────────────────────────────────────────────────────────────────────────┘ │
│                                      │                                          │
│                                      ▼                                          │
│  ┌────────────────────────────────────────────────────────────────────────────┐ │
│  │                        STORAGE LAYER                                        │ │
│  │                                                                             │ │
│  │  ┌─────────────────────────────────────────────────────────────────────┐   │ │
│  │  │                     KNOWLEDGE BASE                                   │   │ │
│  │  │                                                                      │   │ │
│  │  │  /{hemisphere}/                    Domain separation                 │   │ │
│  │  │  /{hemisphere}/{category}/         Category organization             │   │ │
│  │  │  /{hemisphere}/{category}/{entity}/ Entity-level detail              │   │ │
│  │  │                                                                      │   │ │
│  │  │  _index.md files for navigation                                      │   │ │
│  │  │  Frontmatter for structured metadata                                 │   │ │
│  │  │  Markdown content for human + AI readability                         │   │ │
│  │  └─────────────────────────────────────────────────────────────────────┘   │ │
│  └────────────────────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────────────────────┘
```

### Query Flow

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                              QUERY FLOW                                          │
│                                                                                  │
│   USER QUERY                                                                     │
│       │                                                                          │
│       ▼                                                                          │
│   ┌───────────────────────────────────────┐                                      │
│   │           QUERY CLASSIFIER            │                                      │
│   │                                       │                                      │
│   │  Lookup? → Direct file read           │                                      │
│   │  Navigate? → Index-first mode         │                                      │
│   │  Discover? → Hybrid search mode       │                                      │
│   │  Synthesize? → Multi-document mode    │                                      │
│   └───────────────────┬───────────────────┘                                      │
│                       │                                                          │
│       ┌───────────────┼───────────────┐                                          │
│       │               │               │                                          │
│       ▼               ▼               ▼                                          │
│   ┌─────────┐   ┌───────────┐   ┌───────────┐                                    │
│   │ NAVIGATE│   │  SEARCH   │   │  LOOKUP   │                                    │
│   │         │   │           │   │           │                                    │
│   │ _index  │   │ Hybrid    │   │ Direct    │                                    │
│   │ → file  │   │ → chunks  │   │ → file    │                                    │
│   └────┬────┘   └─────┬─────┘   └─────┬─────┘                                    │
│        │              │               │                                          │
│        └──────────────┼───────────────┘                                          │
│                       │                                                          │
│                       ▼                                                          │
│   ┌───────────────────────────────────────┐                                      │
│   │         CIRCLE ENFORCEMENT            │                                      │
│   │                                       │                                      │
│   │  Track: Which circles accessed?       │                                      │
│   │  Warn: Deep dive without orientation? │                                      │
│   │  Boost: Circle 1 content in ranking   │                                      │
│   └───────────────────┬───────────────────┘                                      │
│                       │                                                          │
│                       ▼                                                          │
│   ┌───────────────────────────────────────┐                                      │
│   │         CONTEXT ASSEMBLY              │                                      │
│   │                                       │                                      │
│   │  • Retrieved content                  │                                      │
│   │  • Structural context (hemisphere,    │                                      │
│   │    category, source file)             │                                      │
│   │  • Trust level awareness              │                                      │
│   │  • Depth-appropriate persona          │                                      │
│   └───────────────────┬───────────────────┘                                      │
│                       │                                                          │
│                       ▼                                                          │
│                   RESPONSE                                                       │
└─────────────────────────────────────────────────────────────────────────────────┘
```

### Write Flow

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                              WRITE FLOW                                          │
│                                                                                  │
│   NEW INFORMATION                                                                │
│       │                                                                          │
│       ▼                                                                          │
│   ┌───────────────────────────────────────┐                                      │
│   │        DEDUPLICATION CHECK            │                                      │
│   │                                       │                                      │
│   │  Does this entity already exist?      │                                      │
│   │  Is there similar content elsewhere?  │                                      │
│   └───────────────────┬───────────────────┘                                      │
│                       │                                                          │
│       ┌───────────────┴───────────────┐                                          │
│       │                               │                                          │
│   EXISTS                          NEW                                            │
│       │                               │                                          │
│       ▼                               ▼                                          │
│   ┌─────────────┐             ┌─────────────┐                                    │
│   │ SMART MERGE │             │   CREATE    │                                    │
│   │             │             │             │                                    │
│   │ 1. Read     │             │ 1. Template │                                    │
│   │ 2. Integrate│             │ 2. Content  │                                    │
│   │ 3. Compare  │             │ 3. Write    │                                    │
│   │ 4. Dedup    │             │             │                                    │
│   │ 5. Log      │             │             │                                    │
│   └──────┬──────┘             └──────┬──────┘                                    │
│          │                           │                                           │
│          └───────────────────────────┘                                           │
│                       │                                                          │
│                       ▼                                                          │
│   ┌───────────────────────────────────────┐                                      │
│   │       FRONTMATTER ENFORCEMENT         │                                      │
│   │                                       │                                      │
│   │  • Inject/update created date         │                                      │
│   │  • Update updated date                │                                      │
│   │  • Validate required fields           │                                      │
│   └───────────────────┬───────────────────┘                                      │
│                       │                                                          │
│                       ▼                                                          │
│   ┌───────────────────────────────────────┐                                      │
│   │        PERMISSION CHECK               │                                      │
│   │                                       │                                      │
│   │  Trust level sufficient for write?    │                                      │
│   │  Block or allow based on trust        │                                      │
│   └───────────────────┬───────────────────┘                                      │
│                       │                                                          │
│                       ▼                                                          │
│   ┌───────────────────────────────────────┐                                      │
│   │          WRITE EXECUTION              │                                      │
│   │                                       │                                      │
│   │  • Write file                         │                                      │
│   │  • Trigger indexing                   │                                      │
│   │  • Update _index.md                   │                                      │
│   │  • Audit log                          │                                      │
│   └───────────────────┬───────────────────┘                                      │
│                       │                                                          │
│                       ▼                                                          │
│   ┌───────────────────────────────────────┐                                      │
│   │        WRITE CONFIRMATION             │                                      │
│   │                                       │                                      │
│   │  • Confirm write completed            │                                      │
│   │  • Remind about bidirectional links   │                                      │
│   │  • Remind about _index.md update      │                                      │
│   └───────────────────────────────────────┘                                      │
└─────────────────────────────────────────────────────────────────────────────────┘
```

---

## Part IV: Comparison with Existing Approaches

### What We Add Beyond Standard RAG

| Aspect | Standard RAG | Cognitive Knowledge Architecture |
|--------|--------------|----------------------------------|
| **Retrieval** | Search → Return chunks | Classify query → Choose mode → Apply circle discipline |
| **Context** | Top-K relevant chunks | Progressive disclosure with orientation requirement |
| **Maintenance** | Human curation | Smart Merge protocol for AI-driven maintenance |
| **Permissions** | Binary (allowed/not) | Graduated trust with earned autonomy |
| **Organization** | Flat or simple hierarchy | Hemisphere + depth model with cognitive context |
| **Behavior** | Implicit in model | Explicit layered enforcement |

### What We Add Beyond RAPTOR

| Aspect | RAPTOR | Cognitive Knowledge Architecture |
|--------|--------|----------------------------------|
| **Hierarchy** | Algorithmic tree of summaries | Tree + cognitive discipline for traversal |
| **Usage** | Query retrieves at any level | Circle model guides level selection |
| **Maintenance** | Static after indexing | Smart Merge for ongoing updates |
| **Behavior** | None (infrastructure only) | Full cognitive layer |

### What We Add Beyond Context Engineering

| Aspect | Context Engineering | Cognitive Knowledge Architecture |
|--------|---------------------|----------------------------------|
| **Focus** | What to put in context | How AI should think about knowledge |
| **Scope** | Single query/session | Persistent knowledge base |
| **Maintenance** | Not addressed | Smart Merge protocol |
| **Structure** | Ad-hoc | Hemisphere + depth model |
| **Enforcement** | Primarily prompt | Explicit layered enforcement |

---

## Part V: Implementation Guidance

### For Personal Knowledge Systems (Thoth-style)

**Emphasis**: Cognitive layer, light infrastructure

- Local filesystem storage
- Prompt-heavy enforcement
- Hooks for critical behaviors (frontmatter, permissions)
- Optional: local MeiliSearch + Qdrant for search
- Primary access: local AI agent

### For Team Knowledge Systems (TeamOS-style)

**Emphasis**: Infrastructure layer, cognitive layer as enhancement

- Shared server storage
- Full hybrid search infrastructure
- Hooks for enforcement + audit
- External API access with OAuth
- Multi-user with audit logging

### For Hybrid Systems

**Emphasis**: Both layers, with sync boundaries

- Personal layer: local, private, fast iteration
- Team layer: shared, governed, audited
- Selective sync: personal → team (intentional), team → personal (automatic)
- Unified query: federated search across both

---

## Conclusion

The Cognitive Knowledge Architecture addresses a gap in current AI knowledge management: the cognitive layer that tells AI agents *how to think* about knowledge, not just *how to retrieve* it.

Our contributions:
1. **Progressive Context Disclosure (Circle Model)** — Orientation before exploration
2. **Smart Merge Protocol** — Maintain knowledge integrity over time
3. **Trust Gradient** — Safe progressive delegation
4. **Hemisphere Model** — Cognitive domain separation
5. **Depth Specialization** — Behavior adaptation by scope
6. **Layered Enforcement** — Reliability where needed, flexibility where appropriate
7. **Dual Retrieval Paradigm** — Navigation and discovery as explicit modes

These cognitive concepts sit atop proven infrastructure: hybrid search, hierarchical retrieval (RAPTOR), automatic indexing, and chunk-level retrieval. We don't reinvent infrastructure — we add the librarian's mind to the library's catalog.

The result is an AI that doesn't just find information, but understands how to approach knowledge systematically, maintain it responsibly, and operate with appropriate autonomy.

---

## References

- RAPTOR: Recursive Abstractive Processing for Tree-Organized Retrieval (Sarthi et al., 2024)
- Context Engineering for AI Agents (Anthropic, 2025)
- Mem0: Building Production-Ready AI Agents with Scalable Long-Term Memory (2025)
- A Survey of RAG-Reasoning Systems in LLMs (EMNLP 2025)
- Thoth Knowledge Base State Machine Analysis (TeamOS, 2026)
- TeamOS Hybrid Search Implementation (TeamOS, 2026)

---

*Document created: 2026-01-11*
*Status: Concept Paper*
