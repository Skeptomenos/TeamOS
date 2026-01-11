# TeamOS

> **"One window. Every tool. Your personal assistant."**

---

## The Vision

Every employee juggles dozens of tools. Google Workspace. Jira. Confluence. Slack. HR systems. Finance portals. Each with its own login, its own interface, its own learning curve.

**What if there was just one window?**

TeamOS is building the unified entry point for every employee—a single interface where you can access any tool, take any action, find any information. And standing beside you: a personal AI assistant that knows your context, your permissions, and your work.

```
┌─────────────────────────────────────────────────────────────────┐
│                                                                 │
│   TODAY                           TOMORROW                      │
│                                                                 │
│   ┌─────┐ ┌─────┐ ┌─────┐        ┌─────────────────────────┐   │
│   │Gmail│ │Jira │ │Slack│        │                         │   │
│   └──┬──┘ └──┬──┘ └──┬──┘        │      "Show me my        │   │
│      │       │       │           │       open tickets,     │   │
│   ┌──┴──┐ ┌──┴──┐ ┌──┴──┐        │       schedule a        │   │
│   │Conf.│ │ HR  │ │Docs │        │       meeting with      │   │
│   └──┬──┘ └──┬──┘ └──┬──┘        │       the team, and     │   │
│      │       │       │           │       draft a status    │   │
│   ┌──┴──┐ ┌──┴──┐ ┌──┴──┐        │       update."          │   │
│   │Drive│ │Okta │ │More │        │                         │   │
│   └─────┘ └─────┘ └─────┘        └───────────┬─────────────┘   │
│                                              │                  │
│   🔀 Context switching                       ▼                  │
│   🧠 Cognitive overload            ┌─────────────────┐         │
│   ⏰ Time wasted                   │    TeamOS       │         │
│                                    │  ┌───────────┐  │         │
│                                    │  │ Assistant │  │         │
│                                    │  └─────┬─────┘  │         │
│                                    │        │        │         │
│                                    │   ┌────┴────┐   │         │
│                                    │   ▼    ▼    ▼   │         │
│                                    │  All  Your Tools│         │
│                                    └─────────────────┘         │
│                                                                 │
│                                    ⚡ One window. Done.         │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## What We're Building

### Phase 1: Knowledge Base *(Current)*

The foundation: a team-wide knowledge platform that AI agents can search and learn from.

- **Git-versioned Markdown** with structured metadata
- **Sub-second search** via MeiliSearch
- **AI-native access** via MCP Server
- **Complete audit trail** for every change

### Phase 2: Enterprise Integration *(Next)*

Connect the tools your team uses every day into a unified layer.

- Google Workspace (Gmail, Calendar, Drive, Docs)
- Atlassian (Jira, Confluence)
- Slack
- Entra ID / Azure AD
- HR & Finance systems

### Phase 3: Personal Assistant *(Vision)*

Every employee gets an AI assistant that:
- Knows what tools you have access to
- Understands your current projects and context
- Can take actions on your behalf (with your permission)
- Learns your preferences over time

---

## The Promise

**No more tab hell.** Stop switching between 15 browser tabs to do one task.

**No more "where is that?"** Ask your assistant. It knows where everything is.

**No more repetitive tasks.** "Schedule my weekly 1:1s for the quarter" — done.

**No more onboarding friction.** New employees talk to their assistant from day one.

---

## Quick Start

```bash
# One-click deploy to GCP
cd terraform
cp terraform.tfvars.example terraform.tfvars
terraform init && terraform apply

# SSH to your new server
gcloud compute ssh teamos-server --zone=europe-west1-b

# Search the knowledge base
kb search "onboarding"
```

See [terraform/README.md](terraform/README.md) for full deployment guide.

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         TeamOS Server                           │
│                                                                 │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────────┐ │
│  │   Gitea     │  │ MeiliSearch │  │    Knowledge Base       │ │
│  │  (Git Host) │  │  (Search)   │  │  /data/shared/knowledge │ │
│  └─────────────┘  └─────────────┘  └─────────────────────────┘ │
│                                                                 │
│  ┌─────────────────────────────────────────────────────────────┐│
│  │                     AI Access Layer                         ││
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐   ││
│  │  │ MCP      │  │ kb CLI   │  │ Indexer  │  │ Watcher  │   ││
│  │  │ Server   │  │          │  │          │  │ Service  │   ││
│  │  └──────────┘  └──────────┘  └──────────┘  └──────────┘   ││
│  └─────────────────────────────────────────────────────────────┘│
│                                                                 │
│  ┌─────────────────────────────────────────────────────────────┐│
│  │                   Security & Audit                          ││
│  │  • Google Workspace SSO (OS Login)                          ││
│  │  • auditd → fluent-bit → GCP Cloud Logging                 ││
│  │  • Session recording                                        ││
│  └─────────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────────┘
```

---

## For AI Agents

TeamOS is built AI-first. The knowledge base exposes an MCP server with these tools:

| Tool | Purpose |
|------|---------|
| `kb_search` | Search documents by query, category, or project |
| `kb_read` | Read full content of a specific document |
| `kb_list` | List documents with optional filters |
| `kb_recent` | Get recently modified documents |

```bash
# MCP Server location
/opt/teamos/bin/kb-mcp-server.py

# Or use the CLI
kb search "authentication API"
kb read runbooks/onboarding/new-hire.md
```

---

## Why This Matters

**For Employees:**
- One place for everything — no more hunting across tools
- Personal AI assistant that actually knows your context
- Get things done in seconds, not minutes

**For Teams:**
- Shared knowledge that's actually findable
- Onboard new members in hours, not weeks
- AI agents that understand your team's work

**For Organizations:**
- Reduce tool fatigue and context-switching costs
- Complete audit trail for compliance
- Foundation for the AI-augmented workplace

---

## Project Structure

```
TeamOS/
├── concepts/           # Vision and architecture documents
├── docs/               # Operational documentation
└── terraform/          # One-click infrastructure deployment
    ├── main.tf         # GCP resources
    ├── scripts/
    │   └── startup.sh  # Automated server setup
    └── README.md       # Deployment guide
```

---

## Current Status

| Component | Status |
|-----------|--------|
| GCP Infrastructure | ✅ Production |
| Knowledge Base | ✅ Live |
| MeiliSearch Indexing | ✅ Real-time |
| MCP Server | ✅ Available |
| Google OAuth | ✅ Configured |
| Audit Logging | ✅ 180-day retention |

---

## Contributing

TeamOS is currently an internal project. 

If you're interested in the vision of unified employee experience, check out the [concepts/](concepts/) folder for our thinking.

---

## License

MIT

---

<p align="center">
  <strong>TeamOS</strong><br>
  <em>One Window. Every Tool. Your Assistant.</em>
</p>
