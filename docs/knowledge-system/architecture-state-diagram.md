# TeamOS Architecture State Machine Diagram

**Version:** 1.0  
**Date:** 2026-01-11  
**Status:** Current Production State

---

## 1. System Overview

```
+===========================================================================+
|                         TEAMOS KNOWLEDGE PLATFORM                          |
|                        (GCP: it-services-automations)                      |
+===========================================================================+
|                                                                            |
|   INTERNET                                                                 |
|       |                                                                    |
|       | HTTPS (443) / HTTP (80)                                            |
|       v                                                                    |
|   +-----------------------------------------------------------------------+|
|   |                     POMERIUM REVERSE PROXY                            ||
|   |                   (pomerium/pomerium:latest)                          ||
|   |                                                                       ||
|   |   Routes:                                                             ||
|   |   - assistant.IP.nip.io --> OpenCode Server (172.17.0.1:4096)        ||
|   |   - git.IP.nip.io ---------> Gitea (gitea:3000)                      ||
|   |   - auth.IP.nip.io --------> Pomerium Auth Dashboard                 ||
|   |                                                                       ||
|   |   Authentication: Google OAuth (example.com domain)               ||
|   +-----------------------------------------------------------------------+|
|       |                           |                                        |
|       v                           v                                        |
|   +-------------------+   +-------------------+                            |
|   | OPENCODE SERVER   |   |      GITEA        |                            |
|   | (systemd service) |   | (Docker container)|                            |
|   |                   |   |                   |                            |
|   | Port: 4096        |   | Port: 3000 (HTTP) |                            |
|   | Host: 0.0.0.0     |   | Port: 2222 (SSH)  |                            |
|   |                   |   |                   |                            |
|   | AI Assistant UI   |   | Git Hosting       |                            |
|   +-------------------+   | OAuth Login       |                            |
|                           +-------------------+                            |
|                                   |                                        |
|                                   | Git Clone/Push                         |
|                                   v                                        |
|   +-----------------------------------------------------------------------+|
|   |                    KNOWLEDGE BASE                                     ||
|   |              /data/shared/knowledge/                                  ||
|   |                                                                       ||
|   |   +-- api-docs/          (API documentation)                         ||
|   |   +-- runbooks/          (Operational procedures)                    ||
|   |   +-- decisions/         (Architecture Decision Records)             ||
|   |   +-- guides/            (How-to guides)                             ||
|   |   +-- AGENTS.md          (AI agent instructions)                     ||
|   |                                                                       ||
|   |   Format: Markdown with YAML frontmatter                             ||
|   |   Version Control: Git                                                ||
|   +-----------------------------------------------------------------------+|
|       |                                                                    |
|       | File System Events (inotify)                                       |
|       v                                                                    |
|   +-------------------+                                                    |
|   |   KB-WATCHER      |                                                    |
|   | (systemd service) |                                                    |
|   |                   |                                                    |
|   | Watches: *.md     |                                                    |
|   | Debounce: 2s      |                                                    |
|   +--------+----------+                                                    |
|            |                                                               |
|            | Triggers indexer.py                                           |
|            v                                                               |
|   +-------------------+       +-------------------+                        |
|   |   MEILISEARCH     |       |      QDRANT       |                        |
|   | (Docker container)|       | (Docker container)|                        |
|   |                   |       |                   |                        |
|   | Port: 7700        |       | Port: 6333 (HTTP) |                        |
|   | Index: knowledge  |       | Port: 6334 (gRPC) |                        |
|   |                   |       |                   |                        |
|   | Full-text search  |       | Vector search     |                        |
|   | Typo-tolerant     |       | (NOT YET ACTIVE)  |                        |
|   +-------------------+       +-------------------+                        |
|                                                                            |
+============================================================================+
```

---

## 2. Component State Machine

### 2.1 Request Flow State Machine

```
                                    +-------------+
                                    |   START     |
                                    +------+------+
                                           |
                                           v
                              +------------------------+
                              | User accesses URL      |
                              | (assistant/git/auth)   |
                              +------------------------+
                                           |
                                           v
                              +------------------------+
                              | Pomerium receives      |
                              | request on :80/:443    |
                              +------------------------+
                                           |
                                           v
                              +------------------------+
                              | Check authentication   |
                              | cookie                 |
                              +------------------------+
                                    |           |
                          (no cookie)           (valid cookie)
                                    |           |
                                    v           |
                              +------------+    |
                              | Redirect   |    |
                              | to Google  |    |
                              | OAuth      |    |
                              +-----+------+    |
                                    |           |
                                    v           |
                              +------------+    |
                              | User signs |    |
                              | in with    |    |
                              | Google     |    |
                              +-----+------+    |
                                    |           |
                                    v           |
                              +------------+    |
                              | Verify     |    |
                              | domain is  |    |
                              | allowed    |    |
                              +-----+------+    |
                                    |           |
                          (example.com)      |
                                    |           |
                                    v           |
                              +------------+    |
                              | Set auth   |    |
                              | cookie     |    |
                              +-----+------+    |
                                    |           |
                                    +-----------+
                                           |
                                           v
                              +------------------------+
                              | Route to upstream      |
                              | based on hostname      |
                              +------------------------+
                                    |           |
                    (assistant.*)   |           | (git.*)
                                    v           v
                              +---------+  +---------+
                              |OpenCode |  | Gitea   |
                              | :4096   |  | :3000   |
                              +---------+  +---------+
                                    |           |
                                    v           v
                              +------------------------+
                              | Return response to     |
                              | user via Pomerium      |
                              +------------------------+
                                           |
                                           v
                                    +------+------+
                                    |    END      |
                                    +-------------+
```

### 2.2 Document Indexing State Machine

```
                                    +-------------+
                                    |   START     |
                                    +------+------+
                                           |
                                           v
                              +------------------------+
                              | File change detected   |
                              | by kb-watcher          |
                              | (inotify event)        |
                              +------------------------+
                                           |
                                           v
                              +------------------------+
                              | Is file *.md?          |
                              +------------------------+
                                    |           |
                                  (no)        (yes)
                                    |           |
                                    v           v
                              +--------+  +------------+
                              | IGNORE |  | Is in      |
                              +--------+  | .git/ or   |
                                          | hidden?    |
                                          +------------+
                                               |    |
                                            (yes)  (no)
                                               |    |
                                               v    v
                                         +------+ +------------+
                                         |IGNORE| | Debounce   |
                                         +------+ | check (2s) |
                                                  +------------+
                                                       |    |
                                              (too soon)    (ok)
                                                       |    |
                                                       v    v
                                                 +------+ +------------+
                                                 |IGNORE| | Determine  |
                                                 +------+ | event type |
                                                          +------------+
                                                          |     |     |
                                              (created/   |     |     | (deleted)
                                               modified)  |     |     |
                                                          v     |     v
                                                    +-------+   |  +--------+
                                                    | Parse |   |  | Delete |
                                                    | front |   |  | from   |
                                                    | matter|   |  | index  |
                                                    +---+---+   |  +--------+
                                                        |       |
                                                        v       |
                                                    +-------+   |
                                                    | Build |   |
                                                    | doc   |   |
                                                    | object|   |
                                                    +---+---+   |
                                                        |       |
                                                        v       |
                                                    +-------+   |
                                                    | Index |   |
                                                    | to    |   |
                                                    | Meili |   |
                                                    +---+---+   |
                                                        |       |
                                                        +-------+
                                                              |
                                                              v
                                                    +-------------+
                                                    |    END      |
                                                    +-------------+
```

### 2.3 Search Query State Machine

```
                                    +-------------+
                                    |   START     |
                                    +------+------+
                                           |
                                           v
                              +------------------------+
                              | Search request via     |
                              | - kb CLI               |
                              | - MCP Server           |
                              | - Direct API           |
                              +------------------------+
                                           |
                                           v
                              +------------------------+
                              | Build MeiliSearch      |
                              | query with filters     |
                              +------------------------+
                                           |
                                           v
                              +------------------------+
                              | POST /indexes/         |
                              | knowledge/search       |
                              +------------------------+
                                           |
                                           v
                              +------------------------+
                              | MeiliSearch processes  |
                              | - Typo tolerance       |
                              | - Ranking              |
                              | - Facet filtering      |
                              +------------------------+
                                           |
                                           v
                              +------------------------+
                              | Return results with    |
                              | - title, path          |
                              | - category, tags       |
                              | - content snippet      |
                              +------------------------+
                                           |
                                           v
                                    +------+------+
                                    |    END      |
                                    +-------------+
```

---

## 3. Component Inventory (Current Production)

### 3.1 Docker Containers

| Container   | Image                     | Ports                          | Purpose              |
|-------------|---------------------------|--------------------------------|----------------------|
| pomerium    | pomerium/pomerium:latest  | 0.0.0.0:80, 0.0.0.0:443       | Reverse proxy + Auth |
| gitea       | gitea/gitea:latest        | 127.0.0.1:3000, 0.0.0.0:2222  | Git hosting          |
| meilisearch | getmeili/meilisearch:v1.6 | 127.0.0.1:7700                | Full-text search     |
| qdrant      | qdrant/qdrant:v1.7.4      | 127.0.0.1:6333, 6334          | Vector DB (inactive) |

### 3.2 Systemd Services

| Service         | Binary/Script                        | Purpose                    |
|-----------------|--------------------------------------|----------------------------|
| opencode-server | /usr/bin/opencode serve              | AI Assistant Web UI        |
| kb-watcher      | /opt/teamos/bin/kb-watcher.py        | File change detection      |
| docker          | Docker daemon                        | Container runtime          |

### 3.3 Scripts in /opt/teamos/bin/

| Script            | Purpose                                      |
|-------------------|----------------------------------------------|
| kb                | CLI for knowledge base operations            |
| indexer.py        | Index documents to MeiliSearch               |
| kb-watcher.py     | Watch for file changes, trigger indexing     |
| kb-mcp-server.py  | MCP server for AI agent access               |
| health-check.sh   | System health verification                   |
| audit-report.sh   | Generate audit reports                       |
| create-user.sh    | Provision new users                          |
| sync-users.py     | Sync users from external source              |

---

## 4. Network Topology

```
+===========================================================================+
|                           NETWORK DIAGRAM                                  |
+===========================================================================+
|                                                                            |
|   INTERNET                                                                 |
|       |                                                                    |
|       | External IP: 104.155.82.179                                        |
|       |                                                                    |
|   +---+-------------------------------------------------------------------+|
|   |   GCP FIREWALL                                                        ||
|   |   - teamos-allow-ssh (22)                                             ||
|   |   - teamos-allow-https (80, 443)                                      ||
|   |   - teamos-allow-gitea (2222)                                         ||
|   +-----------------------------------------------------------------------+|
|       |                                                                    |
|       v                                                                    |
|   +-----------------------------------------------------------------------+|
|   |   VM: teamos-server (e2-standard-4)                                   ||
|   |   Zone: europe-west1-b                                                ||
|   |   OS: Ubuntu 24.04 LTS                                                ||
|   |                                                                       ||
|   |   +-------------------+                                               ||
|   |   | eth0              |                                               ||
|   |   | 10.132.0.x        |                                               ||
|   |   +--------+----------+                                               ||
|   |            |                                                          ||
|   |            |                                                          ||
|   |   +--------+----------+                                               ||
|   |   | docker0 bridge    |                                               ||
|   |   | 172.17.0.1        |                                               ||
|   |   +--------+----------+                                               ||
|   |            |                                                          ||
|   |   +--------+----------+----------+----------+                         ||
|   |   |        |          |          |          |                         ||
|   |   v        v          v          v          v                         ||
|   | +------+ +------+ +--------+ +-------+ +----------+                   ||
|   | |pomer | |gitea | |meili   | |qdrant | |opencode  |                   ||
|   | |ium   | |      | |search  | |       | |(host)    |                   ||
|   | |      | |      | |        | |       | |          |                   ||
|   | |:80   | |:3000 | |:7700   | |:6333  | |:4096     |                   ||
|   | |:443  | |      | |        | |:6334  | |          |                   ||
|   | +------+ +------+ +--------+ +-------+ +----------+                   ||
|   |                                                                       ||
|   +-----------------------------------------------------------------------+|
|                                                                            |
+============================================================================+
```

---

## 5. Data Flow Diagram

```
+===========================================================================+
|                           DATA FLOW                                        |
+===========================================================================+
|                                                                            |
|   +-------------+                                                          |
|   | User/Agent  |                                                          |
|   +------+------+                                                          |
|          |                                                                 |
|          | 1. HTTPS Request                                                |
|          v                                                                 |
|   +-------------+     2. OAuth      +-------------+                        |
|   |  Pomerium   |<----------------->|   Google    |                        |
|   +------+------+                   |   OAuth     |                        |
|          |                          +-------------+                        |
|          | 3. Proxy to upstream                                            |
|          |                                                                 |
|     +----+----+                                                            |
|     |         |                                                            |
|     v         v                                                            |
|   +-----+  +-----+                                                         |
|   |Open |  |Gitea|                                                         |
|   |Code |  |     |                                                         |
|   +--+--+  +--+--+                                                         |
|      |        |                                                            |
|      |        | 4. Git operations                                          |
|      |        v                                                            |
|      |     +------------------+                                            |
|      |     | Knowledge Base   |                                            |
|      |     | /data/shared/    |                                            |
|      |     | knowledge/       |                                            |
|      |     +--------+---------+                                            |
|      |              |                                                      |
|      |              | 5. File events                                       |
|      |              v                                                      |
|      |     +------------------+                                            |
|      |     |   kb-watcher     |                                            |
|      |     +--------+---------+                                            |
|      |              |                                                      |
|      |              | 6. Index                                             |
|      |              v                                                      |
|      |     +------------------+                                            |
|      |     |   MeiliSearch    |                                            |
|      |     +--------+---------+                                            |
|      |              ^                                                      |
|      |              |                                                      |
|      | 7. Search    |                                                      |
|      +------------->+                                                      |
|                                                                            |
+============================================================================+
```

---

## 6. Authentication Flow

```
+===========================================================================+
|                     GOOGLE OAUTH AUTHENTICATION FLOW                       |
+===========================================================================+
|                                                                            |
|   +--------+          +----------+          +---------+          +-------+ |
|   | User   |          | Pomerium |          | Google  |          | Up-   | |
|   | Browser|          |          |          | OAuth   |          | stream| |
|   +---+----+          +----+-----+          +----+----+          +---+---+ |
|       |                    |                     |                    |    |
|       | 1. GET /           |                     |                    |    |
|       +------------------->|                     |                    |    |
|       |                    |                     |                    |    |
|       |    2. No cookie    |                     |                    |    |
|       |    302 Redirect    |                     |                    |    |
|       |<-------------------+                     |                    |    |
|       |                    |                     |                    |    |
|       | 3. GET /authorize  |                     |                    |    |
|       +-------------------------------------------->                  |    |
|       |                    |                     |                    |    |
|       |    4. Login page   |                     |                    |    |
|       |<--------------------------------------------                  |    |
|       |                    |                     |                    |    |
|       | 5. User credentials|                     |                    |    |
|       +-------------------------------------------->                  |    |
|       |                    |                     |                    |    |
|       |    6. Auth code    |                     |                    |    |
|       |    302 to callback |                     |                    |    |
|       |<--------------------------------------------                  |    |
|       |                    |                     |                    |    |
|       | 7. GET /callback   |                     |                    |    |
|       +------------------->|                     |                    |    |
|       |                    |                     |                    |    |
|       |                    | 8. Exchange code    |                    |    |
|       |                    +-------------------->|                    |    |
|       |                    |                     |                    |    |
|       |                    | 9. ID token         |                    |    |
|       |                    |<--------------------+                    |    |
|       |                    |                     |                    |    |
|       |                    | 10. Verify domain   |                    |    |
|       |                    |     (example.com)|                    |    |
|       |                    |                     |                    |    |
|       | 11. Set cookie     |                     |                    |    |
|       |     302 to origin  |                     |                    |    |
|       |<-------------------+                     |                    |    |
|       |                    |                     |                    |    |
|       | 12. GET / (cookie) |                     |                    |    |
|       +------------------->|                     |                    |    |
|       |                    |                     |                    |    |
|       |                    | 13. Proxy request   |                    |    |
|       |                    +----------------------------------------->|    |
|       |                    |                     |                    |    |
|       |                    | 14. Response        |                    |    |
|       |                    |<-----------------------------------------+    |
|       |                    |                     |                    |    |
|       | 15. Response       |                     |                    |    |
|       |<-------------------+                     |                    |    |
|       |                    |                     |                    |    |
+===========================================================================+
```

---

## 7. Storage Layout

```
+===========================================================================+
|                           STORAGE LAYOUT                                   |
+===========================================================================+
|                                                                            |
|   BOOT DISK (50GB SSD)                                                     |
|   /                                                                        |
|   +-- /opt/teamos/                                                         |
|   |   +-- bin/                    Scripts and binaries                     |
|   |   +-- venv/                   Python virtual environment               |
|   |   +-- pomerium/               Pomerium configuration                   |
|   |   +-- docker-compose.yml      Docker service definitions               |
|   |                                                                        |
|   +-- /etc/systemd/system/                                                 |
|       +-- opencode-server.service                                          |
|       +-- kb-watcher.service                                               |
|                                                                            |
|   DATA DISK (100GB SSD) - /data                                            |
|   /data                                                                    |
|   +-- /data/shared/knowledge/     Knowledge base (Git repo)                |
|   |   +-- .git/                                                            |
|   |   +-- api-docs/                                                        |
|   |   +-- runbooks/                                                        |
|   |   +-- decisions/                                                       |
|   |   +-- guides/                                                          |
|   |                                                                        |
|   +-- /data/docker/                                                        |
|       +-- meilisearch/            MeiliSearch data                         |
|       +-- qdrant/                 Qdrant vector data                       |
|       +-- gitea/                  Gitea repositories and config            |
|                                                                            |
+============================================================================+
```

---

## 8. Service Dependencies

```
+===========================================================================+
|                        SERVICE DEPENDENCY GRAPH                            |
+===========================================================================+
|                                                                            |
|                           +-------------+                                  |
|                           |   docker    |                                  |
|                           +------+------+                                  |
|                                  |                                         |
|                 +----------------+----------------+                        |
|                 |                |                |                        |
|                 v                v                v                        |
|          +------+------+  +------+------+  +------+------+                |
|          | meilisearch |  |    gitea    |  |   qdrant    |                |
|          +------+------+  +------+------+  +-------------+                |
|                 |                |                                         |
|                 |                |                                         |
|                 v                v                                         |
|          +------+------+  +------+------+                                 |
|          | kb-watcher  |  |  pomerium   |                                 |
|          +-------------+  +------+------+                                 |
|                                  |                                         |
|                                  | depends_on: gitea                       |
|                                  |                                         |
|                                  v                                         |
|                           +------+------+                                  |
|                           |   network   |                                  |
|                           +------+------+                                  |
|                                  |                                         |
|                                  v                                         |
|                           +------+------+                                  |
|                           |opencode-srv |                                  |
|                           +-------------+                                  |
|                                                                            |
+============================================================================+
```

---

## 9. Current URLs

| Service   | URL                                     | Auth Required |
|-----------|-----------------------------------------|---------------|
| Assistant | https://assistant.104-155-82-179.nip.io | Yes (Google)  |
| Git       | https://git.104-155-82-179.nip.io       | Yes (Google)  |
| Auth      | https://auth.104-155-82-179.nip.io      | Yes (Google)  |
| SSH       | ssh -p 2222 git@104.155.82.179          | SSH Key       |

---

## 10. What's NOT Active Yet

| Component        | Status      | Notes                                    |
|------------------|-------------|------------------------------------------|
| Qdrant           | Running     | Container up, but not integrated         |
| Hybrid Search    | Not Active  | Only MeiliSearch is used                 |
| Vertex AI        | Not Active  | Embeddings not configured                |
| MCP Server       | Available   | Script exists, not exposed externally    |
| fluent-bit       | Not Running | Audit log forwarding not configured      |

---

## 11. Terraform State

Resources managed by Terraform:

| Resource                                    | Status    |
|---------------------------------------------|-----------|
| google_compute_network.teamos_vpc           | Imported  |
| google_compute_disk.data_disk               | Imported  |
| google_compute_instance.teamos_server       | Imported  |
| google_compute_firewall.allow_ssh           | Imported  |
| google_compute_firewall.allow_gitea         | Imported  |
| google_compute_firewall.allow_https         | Created   |
| google_service_account.teamos_opencode      | Imported  |
| google_service_account.teamos_fluentbit     | Imported  |
| google_project_iam_member.opencode_vertex   | Created   |
| google_project_iam_member.fluentbit_logging | Created   |
| random_password.meili_master_key            | Created   |
| random_password.pomerium_shared_secret      | Created   |
| random_password.pomerium_cookie_secret      | Created   |
