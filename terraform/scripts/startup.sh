#!/bin/bash
set -e

LOG_FILE="/var/log/teamos-setup.log"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "=== TeamOS Server Setup Started: $(date) ==="

export DEBIAN_FRONTEND=noninteractive

METADATA_URL="http://metadata.google.internal/computeMetadata/v1/instance/attributes"
METADATA_HEADER="Metadata-Flavor: Google"

get_metadata() {
    curl -sf -H "$METADATA_HEADER" "$METADATA_URL/$1" 2>/dev/null || echo ""
}

EXTERNAL_IP=$(curl -sf -H "$METADATA_HEADER" "http://metadata.google.internal/computeMetadata/v1/instance/network-interfaces/0/access-configs/0/external-ip")
IP_DASHED=$(echo "$EXTERNAL_IP" | tr '.' '-')

OAUTH_CLIENT_ID=$(get_metadata "teamos-oauth-client-id")
OAUTH_CLIENT_SECRET=$(get_metadata "teamos-oauth-client-secret")
ALLOWED_DOMAIN=$(get_metadata "teamos-allowed-domain")
MEILI_MASTER_KEY=$(get_metadata "teamos-meili-master-key")
POMERIUM_SHARED_SECRET=$(get_metadata "teamos-pomerium-shared")
POMERIUM_COOKIE_SECRET=$(get_metadata "teamos-pomerium-cookie")

if [ -z "$MEILI_MASTER_KEY" ]; then
    MEILI_MASTER_KEY=$(openssl rand -hex 16)
fi
if [ -z "$POMERIUM_SHARED_SECRET" ]; then
    POMERIUM_SHARED_SECRET=$(openssl rand -hex 16)
fi
if [ -z "$POMERIUM_COOKIE_SECRET" ]; then
    POMERIUM_COOKIE_SECRET=$(openssl rand -hex 16)
fi

echo "External IP: $EXTERNAL_IP"
echo "IP Dashed: $IP_DASHED"
echo "Allowed Domain: $ALLOWED_DOMAIN"

apt-get update -qq
apt-get install -y \
    git curl wget vim htop tmux jq unzip \
    ca-certificates gnupg lsb-release \
    python3 python3-pip python3-venv \
    zsh auditd audispd-plugins

DATA_DISK="/dev/disk/by-id/google-teamos-data"
if [ -e "$DATA_DISK" ] && ! mount | grep -q "/data"; then
    if ! blkid "$DATA_DISK" | grep -q "ext4"; then
        mkfs.ext4 -L teamos-data "$DATA_DISK"
    fi
    mkdir -p /data
    mount "$DATA_DISK" /data
    echo "LABEL=teamos-data /data ext4 defaults,nofail 0 2" >> /etc/fstab
fi

mkdir -p /data/shared/knowledge
mkdir -p /data/docker
mkdir -p /opt/teamos/bin

install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo $VERSION_CODENAME) stable" > /etc/apt/sources.list.d/docker.list
apt-get update -qq
apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

mkdir -p /etc/docker
cat > /etc/docker/daemon.json << 'EOF'
{
    "data-root": "/data/docker",
    "log-driver": "json-file",
    "log-opts": {
        "max-size": "10m",
        "max-file": "3"
    }
}
EOF
systemctl restart docker

curl -fsSL https://deb.nodesource.com/setup_22.x | bash -
apt-get install -y nodejs
npm install -g opencode-ai

cat > /opt/teamos/docker-compose.yml << EOF
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
      - MEILI_NO_ANALYTICS=true
      - MEILI_ENV=production
    restart: unless-stopped

  qdrant:
    image: qdrant/qdrant:v1.7.4
    container_name: qdrant
    ports:
      - "127.0.0.1:6333:6333"
      - "127.0.0.1:6334:6334"
    volumes:
      - /data/docker/qdrant:/qdrant/storage
    restart: unless-stopped

  gitea:
    image: gitea/gitea:latest
    container_name: gitea
    ports:
      - "127.0.0.1:3000:3000"
      - "2222:22"
    volumes:
      - /data/docker/gitea:/data
      - /etc/timezone:/etc/timezone:ro
      - /etc/localtime:/etc/localtime:ro
    environment:
      - USER_UID=1000
      - USER_GID=1000
    restart: unless-stopped

  pomerium:
    image: pomerium/pomerium:latest
    container_name: pomerium
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - /opt/teamos/pomerium:/pomerium:ro
    environment:
      - POMERIUM_DEBUG=false
    restart: unless-stopped
    depends_on:
      - gitea
EOF

mkdir -p /data/docker/meilisearch /data/docker/gitea /data/docker/qdrant /opt/teamos/pomerium
cd /opt/teamos && docker compose up -d meilisearch qdrant gitea

sleep 10

GITEA_DOMAIN="${IP_DASHED}.nip.io"

mkdir -p /data/docker/gitea/gitea/conf
cat > /data/docker/gitea/gitea/conf/app.ini << EOF
APP_NAME = TeamOS Git
RUN_MODE = prod
RUN_USER = git

[repository]
ROOT = /data/git/repositories

[server]
APP_DATA_PATH = /data/gitea
DOMAIN = ${GITEA_DOMAIN}
SSH_DOMAIN = ${GITEA_DOMAIN}
HTTP_PORT = 3000
ROOT_URL = http://${GITEA_DOMAIN}:3000/
DISABLE_SSH = false
SSH_PORT = 22
LFS_START_SERVER = true

[database]
DB_TYPE = sqlite3
PATH = /data/gitea/gitea.db

[session]
PROVIDER = file
PROVIDER_CONFIG = /data/gitea/sessions

[log]
MODE = console
LEVEL = info

[security]
INSTALL_LOCK = true
PASSWORD_HASH_ALGO = pbkdf2

[service]
DISABLE_REGISTRATION = false
REQUIRE_SIGNIN_VIEW = true
ALLOW_ONLY_EXTERNAL_REGISTRATION = true
ENABLE_CAPTCHA = false
DEFAULT_KEEP_EMAIL_PRIVATE = true
DEFAULT_ALLOW_CREATE_ORGANIZATION = false

[oauth2_client]
ENABLE_AUTO_REGISTRATION = true
ACCOUNT_LINKING = auto
USERNAME = email

[oauth2]
ENABLED = true
EOF

chown -R 1000:1000 /data/docker/gitea/gitea
cd /opt/teamos && docker compose restart gitea
sleep 5

docker exec -u git gitea gitea admin user create \
  --username admin \
  --password 'TeamOS-Admin-2025!' \
  --email admin@teamos.local \
  --admin \
  --must-change-password=false 2>/dev/null || true

echo "Gitea configured."

if [ -n "$OAUTH_CLIENT_ID" ] && [ -n "$OAUTH_CLIENT_SECRET" ]; then
    echo "Configuring Gitea OAuth..."
    sleep 5
    docker exec -u git gitea gitea admin auth add-oauth \
        --name 'Google' \
        --provider openidConnect \
        --key "$OAUTH_CLIENT_ID" \
        --secret "$OAUTH_CLIENT_SECRET" \
        --auto-discover-url 'https://accounts.google.com/.well-known/openid-configuration' \
        --scopes 'openid' \
        --scopes 'email' \
        --scopes 'profile' \
        --skip-local-2fa 2>/dev/null || echo "OAuth already configured or failed"
fi

cat > /opt/teamos/pomerium/config.yaml << EOF
authenticate_service_url: https://auth.${IP_DASHED}.nip.io
idp_provider: google
idp_client_id: ${OAUTH_CLIENT_ID}
idp_client_secret: ${OAUTH_CLIENT_SECRET}
shared_secret: ${POMERIUM_SHARED_SECRET}
cookie_secret: ${POMERIUM_COOKIE_SECRET}

policy:
  - from: https://assistant.${IP_DASHED}.nip.io
    to: http://host.docker.internal:4096
    allowed_domains:
      - ${ALLOWED_DOMAIN}
    pass_identity_headers: true

  - from: https://git.${IP_DASHED}.nip.io
    to: http://gitea:3000
    allowed_domains:
      - ${ALLOWED_DOMAIN}
    pass_identity_headers: true
    preserve_host_header: true
EOF

if [ -n "$OAUTH_CLIENT_ID" ] && [ -n "$OAUTH_CLIENT_SECRET" ]; then
    echo "Starting Pomerium..."
    cd /opt/teamos && docker compose up -d pomerium
else
    echo "OAuth credentials not provided. Pomerium not started."
    echo "To start Pomerium later, provide OAuth credentials and run:"
    echo "  cd /opt/teamos && docker compose up -d pomerium"
fi

echo "Gitea URL: http://${IP_DASHED}.nip.io:3000"
echo "Assistant URL: https://assistant.${IP_DASHED}.nip.io (requires Pomerium)"

cat > /etc/audit/rules.d/teamos.rules << 'EOF'
-D
-b 8192
-f 1
-w /data/shared/knowledge -p wa -k knowledge_changes
-w /etc/passwd -p wa -k user_changes
-w /etc/group -p wa -k group_changes
-w /etc/shadow -p wa -k password_changes
-w /etc/sudoers -p wa -k sudoers_changes
-w /etc/sudoers.d -p wa -k sudoers_changes
-w /etc/ssh/sshd_config -p wa -k ssh_config
-w /etc/profile.d -p wa -k profile_changes
-a always,exit -F arch=b64 -S execve -F euid=0 -F auid>=1000 -F auid!=4294967295 -k privileged_commands
-a always,exit -F arch=b64 -S unlink -S unlinkat -S rename -S renameat -F auid>=1000 -F auid!=4294967295 -k file_deletion
-e 2
EOF
augenrules --load
systemctl enable auditd
systemctl restart auditd

curl -fsSL https://packages.fluentbit.io/fluentbit.key | gpg --dearmor -o /usr/share/keyrings/fluentbit-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/fluentbit-keyring.gpg] https://packages.fluentbit.io/ubuntu/noble noble main" > /etc/apt/sources.list.d/fluent-bit.list
apt-get update -qq
apt-get install -y fluent-bit

cat > /etc/fluent-bit/fluent-bit.conf << 'EOF'
[SERVICE]
    Flush         5
    Daemon        Off
    Log_Level     info
    HTTP_Server   On
    HTTP_Listen   127.0.0.1
    HTTP_Port     2020

[INPUT]
    Name              systemd
    Tag               system.*
    Read_From_Tail    On

[INPUT]
    Name              tail
    Tag               audit
    Path              /var/log/audit/audit.log
    Refresh_Interval  5

[INPUT]
    Name              tail
    Tag               auth
    Path              /var/log/auth.log
    Refresh_Interval  5

[FILTER]
    Name              record_modifier
    Match             *
    Record            hostname teamos-server

[OUTPUT]
    Name              stackdriver
    Match             *
    resource          gce_instance
EOF

systemctl enable fluent-bit
systemctl restart fluent-bit

mkdir -p /var/log/sessions
chmod 1733 /var/log/sessions

cat > /etc/profile.d/teamos-first-login.sh << 'HOOK'
#!/bin/bash
if [[ "$USER" != *"_"* ]]; then return 0; fi
if [[ -d "$HOME/.oh-my-zsh" ]]; then return 0; fi

echo "Welcome to TeamOS! Setting up your environment..."

if [[ -d /home/template/.oh-my-zsh ]]; then
    cp -r /home/template/.oh-my-zsh "$HOME/"
    cp -r /home/template/.bun "$HOME/" 2>/dev/null || true
    cp -r /home/template/.config "$HOME/" 2>/dev/null || true
    cp /home/template/.zshrc "$HOME/" 2>/dev/null || true
    sudo usermod -aG docker,teamos "$USER" 2>/dev/null || true
    echo "Setup complete! Run: exec zsh"
fi

if [[ -x /usr/bin/zsh ]] && [[ -z "$ZSH_VERSION" ]]; then
    export SHELL=/usr/bin/zsh
    exec /usr/bin/zsh -l
fi
HOOK
chmod +x /etc/profile.d/teamos-first-login.sh

cat > /etc/profile.d/session-recording.sh << 'SCRIPT'
#!/bin/bash
if [ -z "$SSH_CONNECTION" ]; then return 0; fi
if [ -n "$SESSION_RECORDING" ]; then return 0; fi
if [ -n "$SCRIPT" ]; then return 0; fi
export SESSION_RECORDING=1
SESSION_FILE="/var/log/sessions/${USER}_$(date +%Y%m%d_%H%M%S)_$$.log"
exec script -q -f "$SESSION_FILE"
SCRIPT
chmod +x /etc/profile.d/session-recording.sh

cat > /opt/teamos/bin/health-check.sh << 'SCRIPT'
#!/bin/bash
LOG_FILE="/var/log/teamos-health.log"
log() { echo "$(date +"%Y-%m-%d %H:%M:%S") - $1" >> "$LOG_FILE"; }
log "Starting health check"
for svc in auditd fluent-bit docker; do
    systemctl is-active --quiet "$svc" || log "ALERT: $svc not running"
done
for container in meilisearch gitea; do
    docker ps --format "{{.Names}}" | grep -q "^$container$" || log "ALERT: $container not running"
done
DISK_USAGE=$(df /data | tail -1 | awk '{print $5}' | tr -d '%')
[ "$DISK_USAGE" -gt 80 ] && log "ALERT: Disk at ${DISK_USAGE}%"
log "Health check completed"
SCRIPT
chmod +x /opt/teamos/bin/health-check.sh

cat > /etc/cron.d/teamos << 'CRON'
*/5 * * * * root /opt/teamos/bin/health-check.sh
0 8 * * * root /opt/teamos/bin/audit-report.sh >> /var/log/teamos-audit-report.log 2>&1
CRON
chmod 644 /etc/cron.d/teamos

groupadd -f teamos

# =============================================================================
# KNOWLEDGE BASE SETUP
# =============================================================================

echo "Setting up Knowledge Base infrastructure..."

# Create Python virtual environment
python3 -m venv /opt/teamos/venv
/opt/teamos/venv/bin/pip install --upgrade pip
/opt/teamos/venv/bin/pip install \
    meilisearch \
    python-frontmatter \
    watchdog \
    mcp \
    qdrant-client \
    google-cloud-aiplatform \
    tiktoken

# Create kb CLI tool
cat > /opt/teamos/bin/kb << 'KBCLI'
#!/bin/bash
set -e

MEILI_URL="\${MEILI_URL:-http://localhost:7700}"
MEILI_KEY="\${MEILI_MASTER_KEY}"
KNOWLEDGE_DIR="${KNOWLEDGE_DIR:-/data/shared/knowledge}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

usage() {
    echo -e "${BOLD}Knowledge Base CLI${NC}"
    echo ""
    echo "Usage: kb <command> [arguments]"
    echo ""
    echo "Commands:"
    echo "  search <query>      Search the knowledge base"
    echo "  read <path>         Read a document"
    echo "  list [category]     List documents"
    echo "  recent [days]       Recently modified (default: 7)"
    echo "  categories          List categories"
    echo "  reindex             Full reindex"
    echo "  stats               Index statistics"
}

case "${1:-}" in
    search)
        shift
        query="$*"
        [ -z "$query" ] && { echo "Usage: kb search <query>"; exit 1; }
        curl -s "${MEILI_URL}/indexes/knowledge/search" \
            -H "Authorization: Bearer ${MEILI_KEY}" \
            -H "Content-Type: application/json" \
            -d "{\"q\": \"${query}\", \"limit\": 10}" | \
            jq -r '.hits[] | "\u001b[1;34m[\(.category)]\u001b[0m \u001b[1m\(.title)\u001b[0m\n  Path: \(.path)\n"'
        ;;
    read)
        [ -z "$2" ] && { echo "Usage: kb read <path>"; exit 1; }
        cat "${KNOWLEDGE_DIR}/$2"
        ;;
    list)
        find "${KNOWLEDGE_DIR}/${2:-.}" -name '*.md' -type f ! -path '*/.git/*' | while read f; do
            echo "  ${f#$KNOWLEDGE_DIR/}"
        done
        ;;
    recent)
        find "${KNOWLEDGE_DIR}" -name '*.md' -type f -mtime -"${2:-7}" ! -path '*/.git/*' -printf '%T+ %p\n' | sort -r | head -20
        ;;
    categories)
        find "${KNOWLEDGE_DIR}" -maxdepth 1 -type d ! -name '.git' ! -name '.' -printf '%f\n'
        ;;
    reindex)
        export MEILI_MASTER_KEY="${MEILI_KEY}"
        /opt/teamos/venv/bin/python3 /opt/teamos/bin/indexer.py
        ;;
    stats)
        curl -s "${MEILI_URL}/indexes/knowledge/stats" -H "Authorization: Bearer ${MEILI_KEY}" | jq .
        ;;
    *) usage ;;
esac
KBCLI
chmod +x /opt/teamos/bin/kb

# Create MeiliSearch indexer
cat > /opt/teamos/bin/indexer.py << 'INDEXER'
#!/usr/bin/env python3
import os, sys, hashlib, logging
from pathlib import Path
from datetime import datetime
from typing import Optional, Dict, Any, List
import meilisearch
import frontmatter

MEILI_URL = os.getenv('MEILI_URL', 'http://localhost:7700')
MEILI_KEY = os.getenv('MEILI_MASTER_KEY', 'teamos-dev-key-change-in-prod')
KNOWLEDGE_DIR = os.getenv('KNOWLEDGE_DIR', '/data/shared/knowledge')
INDEX_NAME = 'knowledge'

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

def get_client(): return meilisearch.Client(MEILI_URL, MEILI_KEY)

def normalize_list(value):
    if value is None: return []
    if isinstance(value, str): return [v.strip() for v in value.split(',')]
    if isinstance(value, list): return [str(v) for v in value]
    return [str(value)]

def get_or_create_index(client):
    try:
        return client.get_index(INDEX_NAME)
    except:
        task = client.create_index(INDEX_NAME, {'primaryKey': 'id'})
        client.wait_for_task(task.task_uid)
        index = client.get_index(INDEX_NAME)
        index.update_searchable_attributes(['title', 'summary', 'content', 'tags', 'project'])
        index.update_filterable_attributes(['category', 'status', 'project', 'assignee', 'tags', 'priority'])
        index.update_sortable_attributes(['created', 'updated', 'title'])
        return index

def parse_document(filepath: Path) -> Optional[Dict[str, Any]]:
    try:
        post = frontmatter.load(filepath)
        rel = filepath.relative_to(KNOWLEDGE_DIR)
        return {
            'id': hashlib.md5(str(rel).encode()).hexdigest(),
            'path': str(rel), 'filename': filepath.name,
            'title': post.get('title', filepath.stem),
            'created': str(post.get('created', '')),
            'created_by': post.get('created_by', ''),
            'category': post.get('category', 'guide'),
            'updated': str(post.get('updated', '')),
            'status': post.get('status', 'draft'),
            'tags': normalize_list(post.get('tags')),
            'summary': post.get('summary', ''),
            'content': post.content,
            'project': post.get('project', ''),
            'assignee': post.get('assignee', ''),
            'priority': post.get('priority', ''),
            'indexed_at': datetime.now().isoformat()
        }
    except Exception as e:
        logger.error(f'Error parsing {filepath}: {e}')
        return None

def full_reindex():
    client = get_client()
    try:
        task = client.delete_index(INDEX_NAME)
        client.wait_for_task(task.task_uid)
    except: pass
    index = get_or_create_index(client)
    docs = [d for f in Path(KNOWLEDGE_DIR).rglob('*.md') 
            if not any(p.startswith('.') for p in f.parts) 
            for d in [parse_document(f)] if d]
    if docs:
        task = index.add_documents(docs)
        client.wait_for_task(task.task_uid)
    logger.info(f'Indexed {len(docs)} documents')
    return len(docs)

if __name__ == '__main__':
    if len(sys.argv) > 2 and sys.argv[1] == '--file':
        doc = parse_document(Path(sys.argv[2]))
        if doc:
            idx = get_or_create_index(get_client())
            idx.add_documents([doc])
            logger.info(f'Indexed: {doc["path"]}')
    elif len(sys.argv) > 2 and sys.argv[1] == '--delete':
        rel = Path(sys.argv[2]).relative_to(KNOWLEDGE_DIR) if KNOWLEDGE_DIR in sys.argv[2] else Path(sys.argv[2])
        doc_id = hashlib.md5(str(rel).encode()).hexdigest()
        get_client().get_index(INDEX_NAME).delete_document(doc_id)
    else:
        full_reindex()
INDEXER
chmod +x /opt/teamos/bin/indexer.py

cat > /opt/teamos/bin/hybrid_indexer.py << 'HYBRID_INDEXER'
#!/usr/bin/env python3
import os, sys, hashlib, logging, re
from pathlib import Path
from dataclasses import dataclass
from typing import List, Dict, Any, Optional
import frontmatter
from qdrant_client import QdrantClient
from qdrant_client.models import PointStruct, VectorParams, Distance, Filter, FieldCondition, MatchValue
import tiktoken

QDRANT_URL = os.getenv('QDRANT_URL', 'http://localhost:6333')
KNOWLEDGE_DIR = os.getenv('KNOWLEDGE_DIR', '/data/shared/knowledge')
COLLECTION_NAME = 'knowledge'
EMBEDDING_DIM = 768
MAX_CHUNK_TOKENS = 400

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

try:
    from google.cloud import aiplatform
    from vertexai.language_models import TextEmbeddingModel
    aiplatform.init(project=os.getenv('GCP_PROJECT', 'it-services-automations'), location='europe-west1')
    embedding_model = TextEmbeddingModel.from_pretrained("text-embedding-005")
    USE_VERTEX = True
except Exception as e:
    logger.warning(f"Vertex AI not available: {e}. Using mock embeddings.")
    USE_VERTEX = False

tokenizer = tiktoken.get_encoding("cl100k_base")

@dataclass
class Chunk:
    id: str
    text: str
    source: str
    heading: str
    chunk_index: int
    metadata: Dict[str, Any]
    token_count: int

def count_tokens(text: str) -> int:
    return len(tokenizer.encode(text))

def split_by_headings(content: str) -> List[tuple]:
    pattern = r'^(#{1,3}\s+.+)$'
    parts = re.split(pattern, content, flags=re.MULTILINE)
    sections = []
    current_heading = ""
    current_content = []
    for part in parts:
        if re.match(pattern, part):
            if current_content:
                sections.append((current_heading, '\n'.join(current_content).strip()))
            current_heading = part.strip()
            current_content = []
        else:
            current_content.append(part)
    if current_content:
        sections.append((current_heading, '\n'.join(current_content).strip()))
    return sections

def chunk_document(filepath: Path, content: str) -> List[Chunk]:
    chunks = []
    try:
        post = frontmatter.loads(content)
        body = post.content
        metadata = dict(post.metadata)
    except:
        body = content
        metadata = {}
    
    sections = split_by_headings(body)
    rel_path = str(filepath.relative_to(KNOWLEDGE_DIR)) if KNOWLEDGE_DIR in str(filepath) else str(filepath)
    
    chunk_idx = 0
    for heading, text in sections:
        if not text.strip():
            continue
        full_text = f"{heading}\n\n{text}" if heading else text
        tokens = count_tokens(full_text)
        
        if tokens <= MAX_CHUNK_TOKENS:
            chunks.append(Chunk(
                id=f"{rel_path}#chunk{chunk_idx}",
                text=full_text,
                source=rel_path,
                heading=heading,
                chunk_index=chunk_idx,
                metadata=metadata,
                token_count=tokens
            ))
            chunk_idx += 1
        else:
            paragraphs = text.split('\n\n')
            current_chunk = []
            current_tokens = count_tokens(heading) if heading else 0
            
            for para in paragraphs:
                para_tokens = count_tokens(para)
                if current_tokens + para_tokens > MAX_CHUNK_TOKENS and current_chunk:
                    chunk_text = f"{heading}\n\n" + '\n\n'.join(current_chunk) if heading else '\n\n'.join(current_chunk)
                    chunks.append(Chunk(
                        id=f"{rel_path}#chunk{chunk_idx}",
                        text=chunk_text,
                        source=rel_path,
                        heading=heading,
                        chunk_index=chunk_idx,
                        metadata=metadata,
                        token_count=count_tokens(chunk_text)
                    ))
                    chunk_idx += 1
                    current_chunk = [para]
                    current_tokens = count_tokens(heading) + para_tokens if heading else para_tokens
                else:
                    current_chunk.append(para)
                    current_tokens += para_tokens
            
            if current_chunk:
                chunk_text = f"{heading}\n\n" + '\n\n'.join(current_chunk) if heading else '\n\n'.join(current_chunk)
                chunks.append(Chunk(
                    id=f"{rel_path}#chunk{chunk_idx}",
                    text=chunk_text,
                    source=rel_path,
                    heading=heading,
                    chunk_index=chunk_idx,
                    metadata=metadata,
                    token_count=count_tokens(chunk_text)
                ))
                chunk_idx += 1
    
    return chunks

def get_embeddings(texts: List[str]) -> List[List[float]]:
    if USE_VERTEX:
        embeddings = embedding_model.get_embeddings(texts)
        return [e.values for e in embeddings]
    else:
        import random
        return [[random.random() for _ in range(EMBEDDING_DIM)] for _ in texts]

def get_qdrant_client() -> QdrantClient:
    return QdrantClient(url=QDRANT_URL)

def ensure_collection(client: QdrantClient):
    collections = [c.name for c in client.get_collections().collections]
    if COLLECTION_NAME not in collections:
        client.create_collection(
            collection_name=COLLECTION_NAME,
            vectors_config=VectorParams(size=EMBEDDING_DIM, distance=Distance.COSINE)
        )
        logger.info(f"Created collection: {COLLECTION_NAME}")

def index_document(filepath: str, content: str):
    client = get_qdrant_client()
    ensure_collection(client)
    
    path = Path(filepath)
    rel_path = str(path.relative_to(KNOWLEDGE_DIR)) if KNOWLEDGE_DIR in filepath else filepath
    
    client.delete(
        collection_name=COLLECTION_NAME,
        points_selector=Filter(must=[FieldCondition(key="source", match=MatchValue(value=rel_path))])
    )
    
    chunks = chunk_document(path, content)
    if not chunks:
        logger.warning(f"No chunks generated for {filepath}")
        return
    
    texts = [c.text for c in chunks]
    embeddings = get_embeddings(texts)
    
    points = []
    for chunk, embedding in zip(chunks, embeddings):
        points.append(PointStruct(
            id=abs(hash(chunk.id)) % (2**63),
            vector=embedding,
            payload={
                "chunk_id": chunk.id,
                "text": chunk.text,
                "source": chunk.source,
                "heading": chunk.heading,
                "chunk_index": chunk.chunk_index,
                "title": chunk.metadata.get("title", ""),
                "category": chunk.metadata.get("category", ""),
                "tags": chunk.metadata.get("tags", []),
                "token_count": chunk.token_count
            }
        ))
    
    client.upsert(collection_name=COLLECTION_NAME, points=points)
    logger.info(f"Indexed {len(chunks)} chunks from {rel_path}")

def delete_document(filepath: str):
    client = get_qdrant_client()
    rel_path = str(Path(filepath).relative_to(KNOWLEDGE_DIR)) if KNOWLEDGE_DIR in filepath else filepath
    client.delete(
        collection_name=COLLECTION_NAME,
        points_selector=Filter(must=[FieldCondition(key="source", match=MatchValue(value=rel_path))])
    )
    logger.info(f"Deleted chunks for {rel_path}")

def full_reindex():
    client = get_qdrant_client()
    try:
        client.delete_collection(COLLECTION_NAME)
    except: pass
    ensure_collection(client)
    
    total_chunks = 0
    for filepath in Path(KNOWLEDGE_DIR).rglob('*.md'):
        if any(p.startswith('.') for p in filepath.parts):
            continue
        try:
            content = filepath.read_text()
            index_document(str(filepath), content)
            total_chunks += 1
        except Exception as e:
            logger.error(f"Error indexing {filepath}: {e}")
    
    logger.info(f"Full reindex complete: {total_chunks} documents")

if __name__ == '__main__':
    if len(sys.argv) > 2 and sys.argv[1] == '--file':
        content = Path(sys.argv[2]).read_text()
        index_document(sys.argv[2], content)
    elif len(sys.argv) > 2 and sys.argv[1] == '--delete':
        delete_document(sys.argv[2])
    else:
        full_reindex()
HYBRID_INDEXER
chmod +x /opt/teamos/bin/hybrid_indexer.py

# Create file watcher (indexes to both MeiliSearch and Qdrant)
cat > /opt/teamos/bin/kb-watcher.py << 'WATCHER'
#!/usr/bin/env python3
import os, time, subprocess, logging
from pathlib import Path
from watchdog.observers import Observer
from watchdog.events import FileSystemEventHandler

KNOWLEDGE_DIR = os.getenv('KNOWLEDGE_DIR', '/data/shared/knowledge')
MEILI_INDEXER = '/opt/teamos/bin/indexer.py'
HYBRID_INDEXER = '/opt/teamos/bin/hybrid_indexer.py'
PYTHON = '/opt/teamos/venv/bin/python3'

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(message)s')
logger = logging.getLogger(__name__)

class Handler(FileSystemEventHandler):
    def __init__(self):
        self.last = {}
    
    def _run(self, action, path):
        if not path.endswith('.md') or '/.git/' in path:
            return
        if time.time() - self.last.get(path, 0) < 2:
            return
        self.last[path] = time.time()
        
        env = os.environ.copy()
        
        try:
            subprocess.run([PYTHON, MEILI_INDEXER, action, path], env=env, check=False)
            logger.info(f"MeiliSearch indexed: {path}")
        except Exception as e:
            logger.error(f"MeiliSearch error: {e}")
        
        try:
            subprocess.run([PYTHON, HYBRID_INDEXER, action, path], env=env, check=False)
            logger.info(f"Qdrant indexed: {path}")
        except Exception as e:
            logger.error(f"Qdrant error: {e}")
    
    def on_modified(self, e):
        if not e.is_directory:
            self._run('--file', e.src_path)
    
    def on_created(self, e):
        if not e.is_directory:
            self._run('--file', e.src_path)
    
    def on_deleted(self, e):
        if not e.is_directory and e.src_path.endswith('.md'):
            self._run('--delete', e.src_path)

if __name__ == '__main__':
    logger.info(f"Watching: {KNOWLEDGE_DIR}")
    observer = Observer()
    observer.schedule(Handler(), KNOWLEDGE_DIR, recursive=True)
    observer.start()
    try:
        while True:
            time.sleep(1)
    except KeyboardInterrupt:
        observer.stop()
    observer.join()
WATCHER
chmod +x /opt/teamos/bin/kb-watcher.py

# Create systemd service for file watcher
cat > /etc/systemd/system/kb-watcher.service << EOF
[Unit]
Description=Knowledge Base File Watcher
After=network.target docker.service

[Service]
Type=simple
Environment=MEILI_MASTER_KEY=${MEILI_MASTER_KEY}
Environment=KNOWLEDGE_DIR=/data/shared/knowledge
ExecStart=/opt/teamos/venv/bin/python3 /opt/teamos/bin/kb-watcher.py
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

cat > /etc/systemd/system/opencode-server.service << 'OPENCODE_SVC'
[Unit]
Description=OpenCode Server
After=network.target docker.service

[Service]
Type=simple
User=root
ExecStart=/usr/bin/opencode serve --hostname 127.0.0.1 --port 4096
Restart=always
RestartSec=10
Environment=HOME=/root

[Install]
WantedBy=multi-user.target
OPENCODE_SVC

systemctl daemon-reload
systemctl enable kb-watcher.service
systemctl enable opencode-server.service
systemctl start opencode-server.service

# Add /opt/teamos/bin to PATH for all users
echo 'export PATH="/opt/teamos/bin:$PATH"' > /etc/profile.d/teamos-path.sh
chmod +x /etc/profile.d/teamos-path.sh

# Create Gitea custom styling
mkdir -p /data/docker/gitea/gitea/custom/templates/custom

cat > /data/docker/gitea/gitea/custom/templates/custom/header.tmpl << 'GITEA_CSS'
<style>
:root { --color-primary: #2563eb; }
.full.height > .navbar { background: linear-gradient(135deg, #1e3a5f 0%, #2563eb 100%) !important; }
.ui.repository.list > .item { border-left: 3px solid var(--color-primary); padding-left: 1em; }
.markup h1, .markup h2, .markup h3 { border-bottom: 1px solid #e2e8f0; padding-bottom: 0.3em; }
.markup table th { background: #f1f5f9; }
.markup table td, .markup table th { border: 1px solid #e2e8f0; padding: 0.5em 1em; }
</style>
GITEA_CSS

cat > /data/docker/gitea/gitea/custom/templates/custom/footer.tmpl << 'GITEA_FOOTER'
<div style="text-align: center; padding: 1em 0; color: #64748b; font-size: 0.9em;">
  <p>TeamOS Knowledge Platform | IT Operations</p>
</div>
GITEA_FOOTER

chown -R 1000:1000 /data/docker/gitea/gitea/custom

cat > /opt/teamos/bin/kb-mcp-server.py << 'MCPSERVER'
#!/usr/bin/env python3
import os, asyncio
from pathlib import Path
from datetime import datetime, timedelta
from typing import List, Dict, Any
import meilisearch
import frontmatter
from mcp.server import Server
from mcp.server.stdio import stdio_server
from mcp.types import Tool, TextContent

MEILI_URL = os.getenv('MEILI_URL', 'http://localhost:7700')
MEILI_KEY = os.getenv('MEILI_MASTER_KEY', '')
QDRANT_URL = os.getenv('QDRANT_URL', 'http://localhost:6333')
KNOWLEDGE_DIR = os.getenv('KNOWLEDGE_DIR', '/data/shared/knowledge')
INDEX_NAME = 'knowledge'
MAX_CHARS = 8000

try:
    from qdrant_client import QdrantClient
    from google.cloud import aiplatform
    from vertexai.language_models import TextEmbeddingModel
    aiplatform.init(project=os.getenv('GCP_PROJECT', 'it-services-automations'), location='europe-west1')
    embedding_model = TextEmbeddingModel.from_pretrained("text-embedding-005")
    qdrant = QdrantClient(url=QDRANT_URL)
    HYBRID_ENABLED = True
except:
    HYBRID_ENABLED = False

server = Server("teamos-knowledge-base")

def get_meili(): return meilisearch.Client(MEILI_URL, MEILI_KEY)
def truncate(s, n=MAX_CHARS): return s[:n] + "\n[truncated]" if len(s) > n else s

def reciprocal_rank_fusion(results_lists, k=60):
    scores = {}
    for results in results_lists:
        for rank, r in enumerate(results):
            doc_id = r.get("id", r.get("chunk_id", str(rank)))
            if doc_id not in scores:
                scores[doc_id] = {"score": 0, "data": r}
            scores[doc_id]["score"] += 1 / (k + rank + 1)
    return sorted(scores.values(), key=lambda x: x["score"], reverse=True)

async def hybrid_search(query: str, limit: int = 5, category: str = None) -> List[Dict]:
    keyword_results = []
    vector_results = []
    
    try:
        idx = get_meili().get_index(INDEX_NAME)
        params = {"limit": limit * 2}
        if category:
            params["filter"] = f"category = '{category}'"
        r = idx.search(query, params)
        keyword_results = [{"id": h.get("path"), "text": h.get("content", "")[:2000], 
                          "title": h.get("title"), "source": h.get("path"), "type": "keyword"} 
                         for h in r.get("hits", [])]
    except:
        pass
    
    if HYBRID_ENABLED:
        try:
            embeddings = embedding_model.get_embeddings([query])
            query_vector = embeddings[0].values
            
            search_filter = None
            if category:
                from qdrant_client.models import Filter, FieldCondition, MatchValue
                search_filter = Filter(must=[FieldCondition(key="category", match=MatchValue(value=category))])
            
            results = qdrant.search(collection_name=INDEX_NAME, query_vector=query_vector, 
                                   limit=limit * 2, query_filter=search_filter)
            vector_results = [{"id": r.payload.get("chunk_id"), "text": r.payload.get("text", ""),
                             "title": r.payload.get("title"), "source": r.payload.get("source"),
                             "heading": r.payload.get("heading"), "type": "vector"} for r in results]
        except:
            pass
    
    if not keyword_results and not vector_results:
        return []
    
    if not vector_results:
        return keyword_results[:limit]
    if not keyword_results:
        return vector_results[:limit]
    
    combined = reciprocal_rank_fusion([keyword_results, vector_results])
    seen_sources = set()
    deduplicated = []
    for item in combined:
        source = item["data"].get("source", "")
        if source not in seen_sources:
            seen_sources.add(source)
            deduplicated.append(item["data"])
    
    return deduplicated[:limit]

@server.list_tools()
async def list_tools() -> List[Tool]:
    return [
        Tool(name="kb_search", description="Search TeamOS knowledge base (hybrid: keyword + semantic)",
             inputSchema={"type":"object","properties":{"query":{"type":"string"},"category":{"type":"string"},
                         "limit":{"type":"integer","default":5},"mode":{"type":"string","enum":["hybrid","keyword","vector"],"default":"hybrid"}},
                         "required":["query"]}),
        Tool(name="kb_read", description="Read a document",
             inputSchema={"type":"object","properties":{"path":{"type":"string"}},"required":["path"]}),
        Tool(name="kb_list", description="List documents",
             inputSchema={"type":"object","properties":{"category":{"type":"string"},"limit":{"type":"integer","default":20}}}),
        Tool(name="kb_recent", description="Recent documents",
             inputSchema={"type":"object","properties":{"days":{"type":"integer","default":7}}})
    ]

@server.call_tool()
async def call_tool(name: str, args: Dict[str, Any]) -> List[TextContent]:
    if name == "kb_search":
        mode = args.get("mode", "hybrid")
        query = args.get("query", "")
        limit = min(args.get("limit", 5), 20)
        category = args.get("category")
        
        if mode == "hybrid" or mode == "vector":
            results = await hybrid_search(query, limit, category)
        else:
            try:
                idx = get_meili().get_index(INDEX_NAME)
                params = {"limit": limit}
                if category:
                    params["filter"] = f"category = '{category}'"
                r = idx.search(query, params)
                results = [{"title": h.get("title"), "source": h.get("path"), 
                           "text": h.get("content", "")[:2000], "type": "keyword"} for h in r.get("hits", [])]
            except:
                results = []
        
        if not results:
            return [TextContent(type="text", text="No results found.")]
        
        out = [f"Found {len(results)} results:\n"]
        for i, r in enumerate(results, 1):
            out.append(f"---\n**Result {i}** ({r.get('type', 'hybrid')}) | Source: `{r.get('source')}`")
            if r.get("heading"):
                out.append(f"Section: {r.get('heading')}")
            out.append(f"\n{truncate(r.get('text', ''), 1500)}\n")
        return [TextContent(type="text", text="\n".join(out))]
    
    elif name == "kb_read":
        p = Path(KNOWLEDGE_DIR) / args.get("path", "")
        if not p.exists(): return [TextContent(type="text", text="Not found")]
        post = frontmatter.load(p)
        return [TextContent(type="text", text=f"# {post.get('title')}\n\n{truncate(post.content)}")]
    
    elif name == "kb_list":
        try:
            idx = get_meili().get_index(INDEX_NAME)
            params = {"limit": min(args.get("limit", 20), 50)}
            if args.get("category"): params["filter"] = f"category = '{args['category']}'"
            r = idx.search("", params)
            out = [f"- {h.get('title')} ({h.get('path')})" for h in r.get("hits", [])]
            return [TextContent(type="text", text="\n".join(out) or "No docs")]
        except:
            return [TextContent(type="text", text="Index not available")]
    
    elif name == "kb_recent":
        try:
            idx = get_meili().get_index(INDEX_NAME)
            r = idx.search("", {"limit": 50, "sort": ["updated:desc"]})
            cutoff = datetime.now() - timedelta(days=args.get("days", 7))
            out = []
            for h in r.get("hits", []):
                try:
                    if datetime.strptime(h.get("updated", ""), "%Y-%m-%d") >= cutoff:
                        out.append(f"- {h.get('title')} (updated: {h.get('updated')})")
                except: pass
            return [TextContent(type="text", text="\n".join(out[:10]) or "No recent docs")]
        except:
            return [TextContent(type="text", text="Index not available")]
    
    return [TextContent(type="text", text="Unknown tool")]

async def main():
    async with stdio_server() as (r, w):
        await server.run(r, w, server.create_initialization_options())

if __name__ == "__main__": asyncio.run(main())
MCPSERVER
chmod +x /opt/teamos/bin/kb-mcp-server.py

echo "Knowledge Base infrastructure setup complete."

cat > /opt/teamos/.env << EOF
MEILI_MASTER_KEY=${MEILI_MASTER_KEY}
MEILI_URL=http://localhost:7700
QDRANT_URL=http://localhost:6333
KNOWLEDGE_DIR=/data/shared/knowledge
GCP_PROJECT=it-services-automations
OAUTH_CLIENT_ID=${OAUTH_CLIENT_ID}
ALLOWED_DOMAIN=${ALLOWED_DOMAIN}
EOF
chmod 600 /opt/teamos/.env

echo "Waiting for Gitea to be ready..."
sleep 15

if curl -sf http://localhost:3000/api/v1/version > /dev/null 2>&1; then
    echo "Creating knowledge-base repository..."
    
    curl -sf -X POST "http://localhost:3000/api/v1/admin/users/admin/repos" \
        -H "Content-Type: application/json" \
        -u "admin:TeamOS-Admin-2025!" \
        -d '{"name":"knowledge-base","description":"TeamOS Knowledge Base","private":false,"auto_init":true}' \
        2>/dev/null || echo "Repository may already exist"
    
    sleep 5
    
    if [ ! -d /data/shared/knowledge/.git ]; then
        cd /data/shared
        rm -rf knowledge 2>/dev/null || true
        git clone http://admin:TeamOS-Admin-2025!@localhost:3000/admin/knowledge-base.git knowledge 2>/dev/null || true
        
        if [ -d /data/shared/knowledge ]; then
            cd /data/shared/knowledge
            git config user.email "teamos@system.local"
            git config user.name "TeamOS System"
            
            mkdir -p api-docs runbooks decisions guides templates
            
            cat > AGENTS.md << 'AGENTSMD'
# AI Agent Guide for TeamOS Knowledge Base

## MCP Server
Path: `/opt/teamos/bin/kb-mcp-server.py`

## Available Tools

| Tool | Description |
|------|-------------|
| `kb_search` | Hybrid search (keyword + semantic) |
| `kb_read` | Read full document content |
| `kb_list` | List documents by category |
| `kb_recent` | Recently modified documents |

## CLI Access
```bash
kb search "query"
kb read path/to/doc.md
kb list category
kb recent 7
```

## Document Frontmatter
```yaml
---
title: "Document Title"
created: 2025-01-11
category: guide
status: published
tags: [tag1, tag2]
---
```
AGENTSMD
            
            git add -A
            git commit -m "Initial knowledge base structure" 2>/dev/null || true
            git push origin main 2>/dev/null || true
            
            echo "Knowledge base repository initialized"
        fi
    fi
    
    systemctl start kb-watcher
    
    sleep 3
    /opt/teamos/venv/bin/python3 /opt/teamos/bin/indexer.py 2>/dev/null || true
    /opt/teamos/venv/bin/python3 /opt/teamos/bin/hybrid_indexer.py 2>/dev/null || true
    
    echo "Initial indexing complete"
else
    echo "Gitea not ready, skipping repository creation"
fi

echo ""
echo "=============================================="
echo "  TeamOS Setup Complete!"
echo "=============================================="
echo ""
echo "  Server IP: ${EXTERNAL_IP}"
echo ""
echo "  URLs (after Pomerium starts):"
echo "    Assistant: https://assistant.${IP_DASHED}.nip.io"
echo "    Git:       https://git.${IP_DASHED}.nip.io"
echo ""
echo "  Direct Access (internal):"
echo "    Gitea:       http://localhost:3000"
echo "    MeiliSearch: http://localhost:7700"
echo "    Qdrant:      http://localhost:6333"
echo "    OpenCode:    http://localhost:4096"
echo ""
echo "  SSH: gcloud compute ssh teamos-server --zone=europe-west1-b"
echo ""
echo "=============================================="

echo "=== TeamOS Server Setup Completed: $(date) ==="
