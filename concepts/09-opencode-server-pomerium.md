# Concept 09: OpenCode Server with Pomerium Authentication

**Version:** 1.0  
**Date:** 2025-01-11  
**Status:** Proposal  
**Author:** TeamOS

---

## Executive Summary

Deploy OpenCode Server as the AI backend for TeamOS, secured by Pomerium zero-trust proxy with Google Workspace SSO. This enables team members to access their personal AI assistant via web browser, authenticated with their Google account.

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                                                                             │
│   User's Browser                                                            │
│   https://assistant.teamos.example.com                                     │
│                                                                             │
└───────────────────────────────┬─────────────────────────────────────────────┘
                                │
                                │ HTTPS
                                ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                           POMERIUM                                          │
│                                                                             │
│   • Google OAuth authentication                                            │
│   • Verify user is in allowed domain (@example.com)                        │
│   • Check Google Group membership (optional)                               │
│   • Pass user identity to upstream                                         │
│   • Audit log all requests                                                 │
│                                                                             │
│   Headers added:                                                            │
│   • X-Pomerium-Jwt-Assertion: <signed JWT with user info>                  │
│   • X-Pomerium-Claim-Email: alice@example.com                              │
│   • X-Pomerium-Claim-Groups: team-it, team-admins                          │
│                                                                             │
└───────────────────────────────┬─────────────────────────────────────────────┘
                                │
                                │ HTTP (internal)
                                ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                      SESSION ROUTER                                         │
│                      (Optional - Phase 2)                                   │
│                                                                             │
│   Maps user email → their OpenCode Server port                             │
│   alice@example.com → localhost:4101                                       │
│   bob@example.com   → localhost:4102                                       │
│                                                                             │
└───────────────────────────────┬─────────────────────────────────────────────┘
                                │
                    ┌───────────┴───────────┐
                    ▼                       ▼
┌─────────────────────────────┐ ┌─────────────────────────────┐
│   Alice's OpenCode Server   │ │   Bob's OpenCode Server     │
│   localhost:4101            │ │   localhost:4102            │
│                             │ │                             │
│   • Runs as Linux user      │ │   • Runs as Linux user      │
│   • Alice's sessions        │ │   • Bob's sessions          │
│   • Alice's MCP tools       │ │   • Bob's MCP tools         │
│   • Alice's OAuth tokens    │ │   • Bob's OAuth tokens      │
│                             │ │                             │
│   MCP Servers:              │ │   MCP Servers:              │
│   • Knowledge Base          │ │   • Knowledge Base          │
│   • Google Workspace        │ │   • Google Workspace        │
│   • Jira (future)           │ │   • Jira (future)           │
└─────────────────────────────┘ └─────────────────────────────┘
```

---

## User Experience

### First-Time Access

```
1. User visits: https://assistant.teamos.example.com

2. Pomerium redirects to Google OAuth:
   "Sign in with your example.com Google account"

3. User authenticates with Google (+ 2FA if configured)

4. Pomerium verifies:
   ✓ Email ends with @example.com
   ✓ User is in "teamos-users" Google Group (optional)

5. User lands on TeamOS Assistant interface

6. User's OpenCode Server starts (if not running)

7. Ready to chat:
   "Show me my open Jira tickets and summarize the Q4 roadmap"
```

### Subsequent Access

```
1. User visits: https://assistant.teamos.example.com

2. Pomerium checks session cookie:
   ✓ Valid session, not expired

3. Immediate access (no login prompt)
```

---

## Components

### 1. Pomerium

Single container handling authentication, authorization, and proxying.

```yaml
# /opt/teamos/pomerium/config.yaml
# NOTE: Update URLs when migrating from nip.io to production domain

authenticate_service_url: https://auth.34-22-146-168.nip.io
identity_provider: google
identity_provider_client_id: ${GOOGLE_CLIENT_ID}
identity_provider_client_secret: ${GOOGLE_CLIENT_SECRET}

# Restrict to your Google Workspace domain
# TODO: Replace with your actual domain
allowed_domains:
  - yourcompany.com

# Optional: Restrict to specific Google Group
# allowed_groups:
#   - teamos-users@yourcompany.com

routes:
  # Main assistant UI
  - from: https://assistant.34-22-146-168.nip.io
    to: http://localhost:4096
    policy:
      - allow:
          or:
            - domain:
                is: yourcompany.com
    pass_identity_headers: true
    
  # API endpoint
  - from: https://assistant.34-22-146-168.nip.io
    prefix: /api
    to: http://localhost:4096
    policy:
      - allow:
          or:
            - domain:
                is: yourcompany.com
    pass_identity_headers: true
```

### 2. OpenCode Server

Headless AI backend exposing HTTP API.

```bash
# Start OpenCode Server (per-user or shared)
opencode serve --hostname 127.0.0.1 --port 4096
```

**Key Endpoints Used:**

| Endpoint | Purpose |
|----------|---------|
| `POST /session` | Create new conversation |
| `GET /session` | List user's sessions |
| `POST /session/:id/message` | Send message, get response |
| `GET /session/:id/message` | Get conversation history |
| `GET /event` | SSE stream for real-time updates |

### 3. Frontend (Phase 2)

Simple web UI that talks to OpenCode Server API.

```
┌─────────────────────────────────────────────────────────────────┐
│  TeamOS Assistant                              alice@example.com │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │ Sessions          │  Conversation                       │   │
│  │                   │                                     │   │
│  │ > Q4 Planning     │  You: Show me the Q4 roadmap       │   │
│  │   Jira Tickets    │                                     │   │
│  │   KB Search       │  Assistant: Here's the Q4 roadmap  │   │
│  │                   │  from the knowledge base:           │   │
│  │                   │                                     │   │
│  │                   │  ## Q4 Priorities                   │   │
│  │                   │  1. Launch TeamOS Phase 2           │   │
│  │                   │  2. Migrate to new auth system      │   │
│  │                   │  ...                                │   │
│  │                   │                                     │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                 │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │ Ask anything...                                    Send │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## Implementation Phases

### Phase 1: Shared Server (Week 1)

Single OpenCode Server for all users. Simple, validates the concept.

```
┌─────────────────────────────────────────────────────────────────┐
│                                                                 │
│   Pomerium → Single OpenCode Server (shared)                   │
│                                                                 │
│   • All users share same server                                │
│   • Sessions tagged by user email                              │
│   • Good for: testing, small team                              │
│   • Limitation: shared OAuth context                           │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

**Deliverables:**
- [ ] Pomerium deployed with Google OAuth
- [ ] OpenCode Server running as systemd service
- [ ] Basic web UI (or use API directly)
- [ ] Team can access via browser

### Phase 2: Per-User Servers (Week 2-3)

Each user gets their own OpenCode Server instance.

```
┌─────────────────────────────────────────────────────────────────┐
│                                                                 │
│   Pomerium → Session Router → Per-User OpenCode Servers       │
│                                                                 │
│   • Each user has isolated server                              │
│   • User's OAuth tokens stay with their process                │
│   • Full identity propagation for MCP tools                    │
│   • Scales to team size                                        │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

**Deliverables:**
- [ ] Session router service
- [ ] Systemd user services for OpenCode
- [ ] On-demand server spawning
- [ ] Idle timeout and cleanup

### Phase 3: Full Assistant Experience (Week 4+)

Polished UI with proactive features.

**Deliverables:**
- [ ] React/Next.js frontend
- [ ] Session persistence
- [ ] Proactive notifications
- [ ] Mobile-friendly design

---

## Security Model

### Authentication Flow

```
┌────────┐     ┌──────────┐     ┌────────┐     ┌──────────┐
│ User   │────►│ Pomerium │────►│ Google │────►│ Pomerium │
│        │     │          │     │ OAuth  │     │          │
└────────┘     └──────────┘     └────────┘     └──────────┘
                                                     │
                                                     ▼
                                              ┌──────────┐
                                              │ Verify:  │
                                              │ • Domain │
                                              │ • Groups │
                                              │ • Policy │
                                              └──────────┘
                                                     │
                                                     ▼
                                              ┌──────────┐
                                              │ OpenCode │
                                              │ Server   │
                                              └──────────┘
```

### Access Control

| Control | Implementation |
|---------|----------------|
| **Domain restriction** | `allowed_domains: [example.com]` |
| **Group-based access** | Google Groups via Pomerium |
| **Session timeout** | Pomerium cookie expiry (default 14 days) |
| **Audit logging** | Pomerium access logs + OpenCode session logs |
| **Network isolation** | OpenCode binds to 127.0.0.1 only |

### Identity Headers

Pomerium passes user identity to OpenCode Server:

```http
X-Pomerium-Jwt-Assertion: eyJhbGciOiJFUzI1NiIsInR5cCI6IkpXVCJ9...
X-Pomerium-Claim-Email: alice@example.com
X-Pomerium-Claim-Groups: team-it,team-admins
X-Pomerium-Claim-User: alice
```

---

## Infrastructure

### DNS Records

**Current (Development):** Using nip.io for zero-DNS setup:
```
assistant.34-22-146-168.nip.io  → 34.22.146.168 (auto-resolved)
auth.34-22-146-168.nip.io       → 34.22.146.168 (auto-resolved)
```

**Future (Production):** Migrate to proper domain when ready:
```
assistant.teamos.company.com  → TeamOS Server IP
auth.teamos.company.com       → TeamOS Server IP
```

> **TODO:** Set up proper DNS records before production rollout. nip.io is for development/testing only - it has no SLA and should not be used for production workloads.

### Ports

| Service | Port | Binding |
|---------|------|---------|
| Pomerium (HTTPS) | 443 | 0.0.0.0 |
| Pomerium (HTTP redirect) | 80 | 0.0.0.0 |
| OpenCode Server | 4096 | 127.0.0.1 |
| Per-user servers | 4101-4199 | 127.0.0.1 |

### Docker Compose

```yaml
# /opt/teamos/docker-compose.yml

services:
  pomerium:
    image: pomerium/pomerium:latest
    container_name: pomerium
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./pomerium/config.yaml:/pomerium/config.yaml:ro
      - ./pomerium/certs:/pomerium/certs:ro
    environment:
      - POMERIUM_DEBUG=false
    restart: unless-stopped

  # Other services (MeiliSearch, Qdrant, etc.)
```

### Systemd Service (OpenCode)

```ini
# /etc/systemd/system/opencode-server.service

[Unit]
Description=OpenCode Server
After=network.target

[Service]
Type=simple
User=teamos
ExecStart=/usr/local/bin/opencode serve --hostname 127.0.0.1 --port 4096
Restart=always
RestartSec=5
Environment=HOME=/home/teamos

[Install]
WantedBy=multi-user.target
```

---

## Google OAuth Setup

### 1. Create OAuth Credentials

**GCP Project:** `it-services-automations`

```
Google Cloud Console
→ Project: it-services-automations
→ APIs & Services
→ Credentials
→ Create Credentials
→ OAuth Client ID

Application type: Web application
Name: TeamOS Assistant

Authorized redirect URIs:
  https://auth.34-22-146-168.nip.io/oauth2/callback

# Future (when proper domain is set up):
# https://auth.teamos.company.com/oauth2/callback
```

> **Note:** Update redirect URI when migrating from nip.io to production domain.

### 2. Configure Consent Screen

```
OAuth consent screen
→ User type: Internal (for Workspace)
→ App name: TeamOS Assistant
→ Support email: admin@example.com
→ Authorized domains: example.com
```

### 3. Enable Required APIs

```
APIs & Services → Enable APIs:
  • Google+ API (for profile info)
  • Admin SDK API (for group membership, optional)
```

---

## Team Usage Guide

### For Team Members

**Accessing the Assistant:**

1. Open browser: `https://assistant.teamos.example.com`
2. Sign in with your `@example.com` Google account
3. Start chatting with your AI assistant

**What You Can Do:**

| Action | Example |
|--------|---------|
| Search knowledge base | "Find docs about Entra ID SSO" |
| Read documents | "Show me the onboarding runbook" |
| Ask questions | "How do I reset a user's MFA?" |
| Get summaries | "Summarize the Q4 roadmap" |

**Coming Soon (Phase 2+):**

| Action | Example |
|--------|---------|
| Check calendar | "What meetings do I have today?" |
| Search email | "Find emails from Alice about the project" |
| Create tickets | "Create a Jira ticket for the auth bug" |
| Schedule meetings | "Schedule a 30min with Bob this week" |

### For Admins

**Managing Access:**

- Add/remove users via Google Workspace
- Control access via Google Groups (if configured)
- View audit logs in Pomerium dashboard

**Monitoring:**

```bash
# Check Pomerium status
docker logs pomerium

# Check OpenCode Server status
sudo systemctl status opencode-server

# View active sessions
curl -s http://localhost:4096/session | jq
```

---

## Cost Estimate

| Component | Cost |
|-----------|------|
| Pomerium (open source) | Free |
| OpenCode Server | Free |
| GCP VM (existing) | Already provisioned |
| LLM API tokens | Per usage (existing) |
| **Total Additional** | **$0** |

---

## Risks and Mitigations

| Risk | Mitigation |
|------|------------|
| Pomerium misconfiguration | Test with single user first |
| OpenCode Server crashes | Systemd auto-restart |
| Session data loss | SQLite DB on persistent disk |
| OAuth token expiry | Pomerium handles refresh |
| Unauthorized access | Domain + group restrictions |

---

## Success Criteria

| Metric | Target |
|--------|--------|
| Team members with access | 100% |
| Login success rate | >99% |
| Response latency (P95) | <5s |
| Uptime | >99% |
| User satisfaction | Positive feedback |

---

## Related Documents

- [[00-vision]] - TeamOS vision
- [[01-knowledge-base-document-search]] - Knowledge Base architecture
- [[08-hybrid-search-vector-database]] - Hybrid search design
- [[10-multi-client-architecture]] - Multi-client (iOS, Web, CLI) architecture

---

## Next Steps

1. **Create Google OAuth credentials**
2. **Deploy Pomerium** on TeamOS server
3. **Configure OpenCode Server** as systemd service
4. **Test with single user**
5. **Roll out to team**

---

## Appendix: Quick Reference

### URLs

**Development (nip.io):**

| Purpose | URL |
|---------|-----|
| Assistant | `https://assistant.34-22-146-168.nip.io` |
| Auth | `https://auth.34-22-146-168.nip.io` |

**Production (future):**

| Purpose | URL |
|---------|-----|
| Assistant | `https://assistant.teamos.company.com` |
| Auth | `https://auth.teamos.company.com` |

### Commands

```bash
# Start Pomerium
docker compose up -d pomerium

# Start OpenCode Server
sudo systemctl start opencode-server

# View logs
docker logs -f pomerium
journalctl -u opencode-server -f

# Test API
curl -H "Authorization: Bearer $TOKEN" \
  https://assistant.teamos.example.com/api/session
```
