# Concept 10: Multi-Client Architecture

**Version:** 1.0  
**Date:** 2025-01-11  
**Status:** Proposal  
**Author:** TeamOS

---

## Executive Summary

TeamOS supports multiple entry points for accessing the AI assistant: **iOS App (VibeRemote)**, **Web UI**, and **CLI**. All clients connect to the same backend, sharing AI sessions, knowledge base, and tool integrations. This document defines the architecture for unified multi-client access.

---

## The Two "Sessions" Problem

Before diving in, we must distinguish between two different concepts both called "session":

| Concept | What It Is | Where It Lives | Lifecycle |
|---------|------------|----------------|-----------|
| **Transport Session** | WebSocket/HTTP connection + UI state | Client ↔ Server | Ephemeral (tab close = gone) |
| **AI Session** (`session_*`) | Conversation history, todos, tool calls | `~/.opencode/sessions/` | Persistent (survives restarts) |

**Key insight**: The transport is disposable; the AI session is the valuable state.

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                                                                             │
│   Client A (iOS)          Client B (Web)          Client C (CLI)           │
│   Transport Session 1     Transport Session 2     Transport Session 3      │
│         │                       │                       │                  │
│         └───────────────────────┼───────────────────────┘                  │
│                                 │                                           │
│                                 ▼                                           │
│                        ┌───────────────┐                                   │
│                        │ OpenCode API  │                                   │
│                        └───────┬───────┘                                   │
│                                │                                           │
│                                ▼                                           │
│                    ┌───────────────────────┐                               │
│                    │   AI Sessions Store   │                               │
│                    │   ~/.opencode/sessions│                               │
│                    │                       │                               │
│                    │   session_abc123      │  ← Same session, any client   │
│                    │   session_def456      │                               │
│                    │   session_ghi789      │                               │
│                    └───────────────────────┘                               │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Entry Points

### 1. iOS App (VibeRemote)

**Repository:** `~/Repos/VibeRemote`  
**Status:** In Development  
**Target:** Native iOS experience for on-the-go access

```
┌─────────────────────────────────────────────────────────────────┐
│                                                                 │
│   VibeRemote (iOS)                                             │
│                                                                 │
│   ┌─────────────────────────────────────────────────────────┐  │
│   │                                                         │  │
│   │   Features:                                             │  │
│   │   • Native iOS UI (SwiftUI)                            │  │
│   │   • Push notifications for proactive alerts            │  │
│   │   • Voice input (Siri integration potential)           │  │
│   │   • Offline queue for poor connectivity                │  │
│   │   • Face ID / Touch ID authentication                  │  │
│   │   • Widget for quick actions                           │  │
│   │                                                         │  │
│   │   Connection:                                           │  │
│   │   • HTTPS to OpenCode Server API                       │  │
│   │   • WebSocket for real-time streaming                  │  │
│   │   • OAuth token stored in Keychain                     │  │
│   │                                                         │  │
│   └─────────────────────────────────────────────────────────┘  │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

**Use Cases:**
- Quick questions while away from desk
- Voice-first interaction
- Notifications for important updates
- Approve/reject actions on the go

### 2. Web UI

**Status:** Planned (Phase 1 uses OpenCode Server built-in UI)  
**Target:** Full-featured browser experience

```
┌─────────────────────────────────────────────────────────────────┐
│                                                                 │
│   Web UI                                                        │
│                                                                 │
│   ┌─────────────────────────────────────────────────────────┐  │
│   │                                                         │  │
│   │   Features:                                             │  │
│   │   • Full conversation interface                        │  │
│   │   • Session management (list, switch, rename)          │  │
│   │   • File upload / attachment support                   │  │
│   │   • Rich markdown rendering                            │  │
│   │   • Code syntax highlighting                           │  │
│   │   • Tool execution visualization                       │  │
│   │                                                         │  │
│   │   Authentication:                                       │  │
│   │   • Pomerium (Google Workspace SSO)                    │  │
│   │   • Session cookie (14-day expiry)                     │  │
│   │                                                         │  │
│   │   URL: https://assistant.teamos.example.com            │  │
│   │                                                         │  │
│   └─────────────────────────────────────────────────────────┘  │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

**Use Cases:**
- Primary workstation access
- Complex multi-step workflows
- Document review and editing
- Extended conversations

### 3. CLI (opencode)

**Status:** Available  
**Target:** Developer/power-user terminal access

```
┌─────────────────────────────────────────────────────────────────┐
│                                                                 │
│   CLI (opencode)                                               │
│                                                                 │
│   ┌─────────────────────────────────────────────────────────┐  │
│   │                                                         │  │
│   │   Features:                                             │  │
│   │   • Full terminal UI (TUI)                             │  │
│   │   • Direct file system access                          │  │
│   │   • Git integration                                    │  │
│   │   • Script automation                                  │  │
│   │   • SSH access to remote servers                       │  │
│   │                                                         │  │
│   │   Authentication:                                       │  │
│   │   • Local: ~/.opencode/config                          │  │
│   │   • Remote: SSH + API token                            │  │
│   │                                                         │  │
│   │   Commands:                                             │  │
│   │   $ opencode                    # Interactive TUI      │  │
│   │   $ opencode "question"         # One-shot query       │  │
│   │   $ opencode --session abc123   # Resume session       │  │
│   │                                                         │  │
│   └─────────────────────────────────────────────────────────┘  │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

**Use Cases:**
- Development workflows
- Server administration
- Automation scripts
- Power users who live in terminal

---

## Unified Backend Architecture

All clients connect to the same backend services:

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                                                                             │
│                              CLIENTS                                        │
│                                                                             │
│   ┌───────────┐         ┌───────────┐         ┌───────────┐               │
│   │    iOS    │         │   Web     │         │    CLI    │               │
│   │VibeRemote │         │    UI     │         │ opencode  │               │
│   └─────┬─────┘         └─────┬─────┘         └─────┬─────┘               │
│         │                     │                     │                      │
│         │ HTTPS               │ HTTPS               │ Local/SSH            │
│         │                     │                     │                      │
└─────────┼─────────────────────┼─────────────────────┼──────────────────────┘
          │                     │                     │
          ▼                     ▼                     ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                                                                             │
│                           AUTHENTICATION                                    │
│                                                                             │
│   ┌─────────────────────────────────────────────────────────────────────┐  │
│   │                         Pomerium                                     │  │
│   │                                                                      │  │
│   │   • Google Workspace SSO                                            │  │
│   │   • Domain restriction (@company.com)                               │  │
│   │   • Identity headers (X-Pomerium-Claim-Email)                       │  │
│   │   • Audit logging                                                   │  │
│   │                                                                      │  │
│   └─────────────────────────────────────────────────────────────────────┘  │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                                                                             │
│                           OPENCODE SERVER                                   │
│                                                                             │
│   ┌─────────────────────────────────────────────────────────────────────┐  │
│   │                                                                      │  │
│   │   API Endpoints:                                                     │  │
│   │                                                                      │  │
│   │   POST   /session              Create new AI session                │  │
│   │   GET    /session              List user's sessions                 │  │
│   │   GET    /session/:id          Get session details                  │  │
│   │   DELETE /session/:id          Delete session                       │  │
│   │   POST   /session/:id/message  Send message, get response           │  │
│   │   GET    /session/:id/message  Get conversation history             │  │
│   │   GET    /event                SSE stream for real-time updates     │  │
│   │                                                                      │  │
│   └─────────────────────────────────────────────────────────────────────┘  │
│                                                                             │
│   ┌─────────────────────────────────────────────────────────────────────┐  │
│   │                                                                      │  │
│   │   Session Storage:                                                   │  │
│   │                                                                      │  │
│   │   ~/.opencode/sessions/                                             │  │
│   │   ├── session_abc123/                                               │  │
│   │   │   ├── messages.json       # Conversation history                │  │
│   │   │   ├── todos.json          # Task list                           │  │
│   │   │   └── metadata.json       # User, created, updated              │  │
│   │   └── session_def456/                                               │  │
│   │                                                                      │  │
│   └─────────────────────────────────────────────────────────────────────┘  │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                                                                             │
│                              MCP SERVERS                                    │
│                                                                             │
│   ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐      │
│   │ Knowledge   │  │   Google    │  │    Jira     │  │   Slack     │      │
│   │    Base     │  │  Workspace  │  │             │  │             │      │
│   │             │  │             │  │             │  │             │      │
│   │ kb_search   │  │ gmail_*     │  │ jira_*      │  │ slack_*     │      │
│   │ kb_read     │  │ calendar_*  │  │             │  │             │      │
│   │ kb_list     │  │ drive_*     │  │             │  │             │      │
│   └─────────────┘  └─────────────┘  └─────────────┘  └─────────────┘      │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Session Management

### Session Lifecycle

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                                                                             │
│   SESSION LIFECYCLE                                                         │
│                                                                             │
│   ┌─────────┐     ┌─────────┐     ┌─────────┐     ┌─────────┐             │
│   │ Create  │────►│ Active  │────►│ Idle    │────►│ Archived│             │
│   └─────────┘     └─────────┘     └─────────┘     └─────────┘             │
│                        │               │               │                   │
│                        │               │               │                   │
│                   User sends      No activity      After 30 days          │
│                   messages        for 24h          of idle                 │
│                        │               │               │                   │
│                        ▼               ▼               ▼                   │
│                   Messages        Session          Moved to               │
│                   stored          marked           cold storage            │
│                                   inactive                                 │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Session Ownership

Sessions are owned by users, identified by email from Pomerium headers:

```json
{
  "session_id": "session_abc123",
  "owner": "alice@company.com",
  "created": "2025-01-11T10:30:00Z",
  "updated": "2025-01-11T14:45:00Z",
  "title": "Q4 Planning Discussion",
  "message_count": 42,
  "status": "active"
}
```

### Cross-Client Session Access

Users can access their sessions from any client:

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                                                                             │
│   SCENARIO: User starts on Web, continues on iOS                           │
│                                                                             │
│   10:00 AM - Web UI                                                         │
│   ┌─────────────────────────────────────────────────────────────────────┐  │
│   │ User: "Help me plan the Q4 roadmap"                                 │  │
│   │ Assistant: "I'll help you plan. Let me check the current backlog..." │  │
│   │ [Session created: session_abc123]                                    │  │
│   └─────────────────────────────────────────────────────────────────────┘  │
│                                                                             │
│   12:30 PM - iOS (VibeRemote) - at lunch                                   │
│   ┌─────────────────────────────────────────────────────────────────────┐  │
│   │ [User opens app, sees session list]                                  │  │
│   │ [Taps "Q4 Planning Discussion"]                                      │  │
│   │ User: "Add the security audit to the roadmap"                        │  │
│   │ Assistant: "Added. The roadmap now includes..."                      │  │
│   └─────────────────────────────────────────────────────────────────────┘  │
│                                                                             │
│   3:00 PM - CLI - back at desk                                             │
│   ┌─────────────────────────────────────────────────────────────────────┐  │
│   │ $ opencode --session session_abc123                                  │  │
│   │ [Conversation history loaded]                                        │  │
│   │ User: "Generate the Jira tickets for this roadmap"                   │  │
│   │ Assistant: "Creating 12 tickets..."                                  │  │
│   └─────────────────────────────────────────────────────────────────────┘  │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Session Models

### Option A: Ephemeral (Simplest)

New session each visit. No persistence.

```
Pros:
  + Simplest to implement
  + No state management
  + Clean slate each time

Cons:
  - No continuity
  - Context lost between visits
  - Must re-explain context each time
```

### Option B: Tab-Based (Current Default)

Each browser tab / app instance = new session. Sessions persist while open.

```
Pros:
  + Parallel workflows (multiple tabs)
  + Natural mental model
  + Sessions accumulate for reference

Cons:
  - Sessions proliferate
  - No explicit naming
  - Hard to find old sessions
```

### Option C: Resumable (Recommended)

Sessions persist. User sees list on login. Can resume or start new.

```
Pros:
  + Continuity across devices
  + Context preserved
  + Can organize by project

Cons:
  + More UI complexity
  + Storage management needed
  + Session cleanup required
```

### Option D: Project-Based (Future)

Sessions explicitly tied to projects/topics. User creates and names them.

```
Pros:
  + Clear organization
  + Shareable (team sessions)
  + Project context automatic

Cons:
  + Highest complexity
  + Requires project management
  + Overhead for quick questions
```

**Recommendation:** Start with **Option C (Resumable)** for Phase 1, evolve to **Option D (Project-Based)** in Phase 2.

---

## Client-Specific Considerations

### iOS (VibeRemote)

| Consideration | Approach |
|---------------|----------|
| **Offline mode** | Queue messages, sync when online |
| **Push notifications** | Server-sent events → APNs |
| **Authentication** | OAuth flow → Keychain storage |
| **Session sync** | Pull session list on app open |
| **Voice input** | Speech-to-text before sending |

### Web UI

| Consideration | Approach |
|---------------|----------|
| **Real-time updates** | Server-Sent Events (SSE) |
| **Authentication** | Pomerium cookie (transparent) |
| **Session management** | Sidebar with session list |
| **File handling** | Drag-and-drop upload |
| **Markdown** | Rich rendering with syntax highlighting |

### CLI

| Consideration | Approach |
|---------------|----------|
| **Session selection** | `--session` flag or interactive picker |
| **Authentication** | API token in config or SSH |
| **Output format** | Markdown in terminal, optional JSON |
| **Automation** | Pipe-friendly, exit codes |
| **File context** | Automatic working directory awareness |

---

## API Design

### Session Endpoints

```yaml
# Create session
POST /api/session
Request:
  title: "Optional session title"
Response:
  session_id: "session_abc123"
  created: "2025-01-11T10:30:00Z"

# List sessions
GET /api/session
Query:
  status: active|archived|all
  limit: 20
  offset: 0
Response:
  sessions:
    - session_id: "session_abc123"
      title: "Q4 Planning"
      updated: "2025-01-11T14:45:00Z"
      message_count: 42

# Get session
GET /api/session/:id
Response:
  session_id: "session_abc123"
  title: "Q4 Planning"
  messages: [...]
  todos: [...]

# Send message
POST /api/session/:id/message
Request:
  content: "User message"
  attachments: [...]
Response:
  message_id: "msg_xyz789"
  # Response streams via SSE

# Delete session
DELETE /api/session/:id
Response:
  deleted: true
```

### Real-Time Streaming

```yaml
# SSE endpoint for real-time updates
GET /api/event
Headers:
  Accept: text/event-stream
  X-Session-ID: session_abc123

Events:
  - event: message
    data: {"role": "assistant", "content": "..."}
  
  - event: tool_call
    data: {"tool": "kb_search", "args": {...}}
  
  - event: tool_result
    data: {"tool": "kb_search", "result": {...}}
  
  - event: done
    data: {"message_id": "msg_xyz789"}
```

---

## Security Model

### Authentication Flow by Client

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                                                                             │
│   iOS (VibeRemote)                                                          │
│   ┌─────────────────────────────────────────────────────────────────────┐  │
│   │ 1. User opens app                                                    │  │
│   │ 2. App checks Keychain for OAuth token                              │  │
│   │ 3. If missing/expired → OAuth flow via ASWebAuthenticationSession   │  │
│   │ 4. Token stored in Keychain                                         │  │
│   │ 5. Token sent in Authorization header                               │  │
│   └─────────────────────────────────────────────────────────────────────┘  │
│                                                                             │
│   Web UI                                                                    │
│   ┌─────────────────────────────────────────────────────────────────────┐  │
│   │ 1. User visits URL                                                   │  │
│   │ 2. Pomerium checks session cookie                                   │  │
│   │ 3. If missing/expired → Redirect to Google OAuth                    │  │
│   │ 4. Cookie set by Pomerium                                           │  │
│   │ 5. Identity passed via X-Pomerium-Claim-* headers                   │  │
│   └─────────────────────────────────────────────────────────────────────┘  │
│                                                                             │
│   CLI                                                                       │
│   ┌─────────────────────────────────────────────────────────────────────┐  │
│   │ Local:                                                               │  │
│   │   • Uses local config (~/.opencode/config)                          │  │
│   │   • No additional auth needed                                       │  │
│   │                                                                      │  │
│   │ Remote (SSH):                                                        │  │
│   │   • SSH key authentication                                          │  │
│   │   • User identity from OS Login                                     │  │
│   └─────────────────────────────────────────────────────────────────────┘  │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Session Isolation

| Rule | Implementation |
|------|----------------|
| Users can only see their sessions | Filter by `owner` field matching authenticated email |
| Sessions cannot be shared (Phase 1) | No sharing endpoints |
| Admin can view all sessions | Special role check |
| Audit all session access | Log every API call with user identity |

---

## Implementation Phases

### Phase 1: Foundation

- [ ] OpenCode Server API deployed
- [ ] Pomerium authentication working
- [ ] Session CRUD endpoints
- [ ] Basic Web UI (OpenCode built-in)
- [ ] CLI session selection

### Phase 2: iOS Integration

- [ ] VibeRemote connects to API
- [ ] OAuth flow implemented
- [ ] Session list and resume
- [ ] Push notification infrastructure

### Phase 3: Enhanced UX

- [ ] Custom Web UI with session management
- [ ] Session naming and organization
- [ ] Cross-device sync indicators
- [ ] Offline support for iOS

### Phase 4: Team Features

- [ ] Shared sessions (optional)
- [ ] Project-based organization
- [ ] Team activity feed
- [ ] Admin dashboard

---

## Related Documents

- [[00-vision]] - TeamOS vision
- [[09-opencode-server-pomerium]] - Web access architecture
- [[05-overall-architecture]] - System architecture overview

---

## Open Questions

- [ ] How should session titles be auto-generated?
- [ ] What's the session retention policy?
- [ ] Should sessions be exportable?
- [ ] How do we handle session conflicts (same session, two clients)?

---

## Summary

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                                                                             │
│   THREE ENTRY POINTS, ONE EXPERIENCE                                        │
│                                                                             │
│   ┌───────────┐     ┌───────────┐     ┌───────────┐                        │
│   │    iOS    │     │    Web    │     │    CLI    │                        │
│   │VibeRemote │     │    UI     │     │ opencode  │                        │
│   └─────┬─────┘     └─────┬─────┘     └─────┬─────┘                        │
│         │                 │                 │                              │
│         └─────────────────┼─────────────────┘                              │
│                           │                                                 │
│                           ▼                                                 │
│                  ┌─────────────────┐                                       │
│                  │  Unified API    │                                       │
│                  │  + AI Sessions  │                                       │
│                  │  + MCP Tools    │                                       │
│                  └─────────────────┘                                       │
│                                                                             │
│   • Same sessions accessible from any client                               │
│   • Same AI capabilities everywhere                                        │
│   • Same tools and integrations                                            │
│   • Seamless context handoff                                               │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

*"Start anywhere. Continue everywhere."*
