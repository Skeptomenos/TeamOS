# Concept Paper: Conflict Handling and Resolution Strategies

**Version:** 1.1  
**Date:** 2025-01-11  
**Status:** Implemented  
**Author:** TeamOS

---

## 1. Executive Summary

This document analyzes the various types of conflicts that can occur when collaboratively using a Knowledge Base and presents strategies for preventing and resolving them. The focus is on practical solutions for a team of 10 people who work with both CLI tools (OpenCode, Gemini CLI) and GUI tools (Obsidian).

---

## 2. Conflict Taxonomy

### 2.1 Types of Conflicts

```
┌─────────────────────────────────────────────────────────────────┐
│                    Conflict Types                               │
│                                                                 │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  1. WRITE-WRITE CONFLICT                                │   │
│  │     Two people edit the same file simultaneously        │   │
│  │     → Changes overwrite each other                      │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                 │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  2. READ-WRITE CONFLICT                                 │   │
│  │     Person A reads file, Person B modifies it           │   │
│  │     → Person A works with outdated data                 │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                 │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  3. STRUCTURAL CONFLICT                                 │   │
│  │     File is moved/renamed while being edited            │   │
│  │     → Orphaned changes, duplicate files                 │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                 │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  4. SEMANTIC CONFLICT                                   │   │
│  │     Changes are syntactically compatible, but           │   │
│  │     content is contradictory                            │   │
│  │     → Inconsistent documentation                        │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### 2.2 Conflict Probability

| Scenario | Probability | Impact |
|----------|-------------|--------|
| Two people edit the same file | Medium | High |
| LLM and human edit simultaneously | High | Medium |
| Structural changes during editing | Low | High |
| Semantic contradictions | Medium | Medium |

---

## 3. Conflict Prevention Strategies

### 3.1 Strategy 1: File Locking (Pessimistic)

```
┌─────────────────────────────────────────────────────────────────┐
│                    File Locking                                 │
│                                                                 │
│  Time t=0:                                                      │
│  ┌─────────────┐                    ┌─────────────┐            │
│  │   User A    │                    │   User B    │            │
│  │  wants edit │                    │  wants edit │            │
│  └──────┬──────┘                    └──────┬──────┘            │
│         │                                  │                    │
│         ▼                                  │                    │
│  ┌─────────────┐                           │                    │
│  │ doc.md.lock │ ← Lock created            │                    │
│  │ "user_a"    │                           │                    │
│  └─────────────┘                           │                    │
│         │                                  ▼                    │
│         │                           ┌─────────────┐            │
│         │                           │   BLOCKED   │            │
│         │                           │ "Locked by  │            │
│         │                           │  User A"    │            │
│         │                           └─────────────┘            │
│         ▼                                                       │
│  ┌─────────────┐                                               │
│  │   EDITING   │                                               │
│  └─────────────┘                                               │
│         │                                                       │
│         ▼                                                       │
│  ┌─────────────┐                                               │
│  │ Lock removed│ → User B can now edit                         │
│  └─────────────┘                                               │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

#### Implementation

```bash
#!/bin/bash
# /usr/local/bin/kb-lock

KNOWLEDGE_DIR="/shared/knowledge"
LOCK_TIMEOUT=3600  # 1 hour

lock_file() {
    local file="$1"
    local lockfile="${file}.lock"
    local user="${USER_EMAIL:-$USER}"
    local timestamp=$(date +%s)
    
    # Check if lock exists
    if [ -f "$lockfile" ]; then
        local lock_info=$(cat "$lockfile")
        local lock_user=$(echo "$lock_info" | cut -d'|' -f1)
        local lock_time=$(echo "$lock_info" | cut -d'|' -f2)
        local current_time=$(date +%s)
        local age=$((current_time - lock_time))
        
        # Lock expired?
        if [ $age -gt $LOCK_TIMEOUT ]; then
            echo "Stale lock removed (was held by $lock_user)"
            rm -f "$lockfile"
        else
            echo "ERROR: File locked by $lock_user (${age}s ago)"
            echo "Use 'kb-lock --force $file' to override"
            return 1
        fi
    fi
    
    # Create lock
    echo "${user}|${timestamp}" > "$lockfile"
    echo "Lock acquired for $file"
    return 0
}

unlock_file() {
    local file="$1"
    local lockfile="${file}.lock"
    
    if [ -f "$lockfile" ]; then
        rm -f "$lockfile"
        echo "Lock released for $file"
    fi
}

check_lock() {
    local file="$1"
    local lockfile="${file}.lock"
    
    if [ -f "$lockfile" ]; then
        cat "$lockfile"
        return 1
    fi
    return 0
}

case "$1" in
    lock)   lock_file "$2" ;;
    unlock) unlock_file "$2" ;;
    check)  check_lock "$2" ;;
    --force)
        rm -f "${3}.lock"
        lock_file "$3"
        ;;
    *)
        echo "Usage: kb-lock <lock|unlock|check|--force> <file>"
        ;;
esac
```

#### LLM Integration (AGENTS.md)

```markdown
## File Locking Protocol for AI Agents

When editing files in /shared/knowledge/:

1. **Before editing**: Check for lock
   ```bash
   kb-lock check /shared/knowledge/path/to/file.md
   ```

2. **If locked**: 
   - Wait 30 seconds
   - Re-read the file (it may have changed)
   - Try again
   - After 3 attempts, notify user

3. **If unlocked**: Acquire lock
   ```bash
   kb-lock lock /shared/knowledge/path/to/file.md
   ```

4. **After editing**: Release lock
   ```bash
   kb-lock unlock /shared/knowledge/path/to/file.md
   ```

5. **On error/crash**: Locks expire after 1 hour automatically
```

#### Evaluation

| Aspect | Rating |
|--------|--------|
| Conflict Prevention | ⭐⭐⭐⭐⭐ |
| User-friendliness | ⭐⭐⭐ |
| Parallelism | ⭐⭐ |
| Implementation Effort | ⭐⭐⭐⭐ |

---

### 3.2 Strategy 2: Optimistic Locking (Git-based)

```
┌─────────────────────────────────────────────────────────────────┐
│                    Optimistic Locking                           │
│                                                                 │
│  Time t=0:                                                      │
│  ┌─────────────┐                    ┌─────────────┐            │
│  │   User A    │                    │   User B    │            │
│  │  git pull   │                    │  git pull   │            │
│  │  (v1)       │                    │  (v1)       │            │
│  └──────┬──────┘                    └──────┬──────┘            │
│         │                                  │                    │
│         ▼                                  ▼                    │
│  ┌─────────────┐                    ┌─────────────┐            │
│  │   EDITING   │                    │   EDITING   │            │
│  │   (local)   │                    │   (local)   │            │
│  └──────┬──────┘                    └──────┬──────┘            │
│         │                                  │                    │
│         ▼                                  │                    │
│  ┌─────────────┐                           │                    │
│  │ git commit  │                           │                    │
│  │ git push    │ → v2                      │                    │
│  │ SUCCESS     │                           │                    │
│  └─────────────┘                           │                    │
│                                            ▼                    │
│                                     ┌─────────────┐            │
│                                     │ git commit  │            │
│                                     │ git push    │            │
│                                     │ REJECTED!   │            │
│                                     └──────┬──────┘            │
│                                            │                    │
│                                            ▼                    │
│                                     ┌─────────────┐            │
│                                     │ git pull    │            │
│                                     │ --rebase    │            │
│                                     │ MERGE!      │            │
│                                     └─────────────┘            │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

#### Workflow

```bash
# Before editing
git pull --rebase

# After editing
git add -A
git commit -m "Update: description"
git push

# On conflict
git pull --rebase
# Resolve conflicts
git add -A
git rebase --continue
git push
```

#### Evaluation

| Aspect | Rating |
|--------|--------|
| Conflict Prevention | ⭐⭐⭐ |
| User-friendliness | ⭐⭐⭐⭐ |
| Parallelism | ⭐⭐⭐⭐⭐ |
| Implementation Effort | ⭐⭐⭐⭐⭐ |

---

### 3.3 Strategy 3: Ownership Model

```
┌─────────────────────────────────────────────────────────────────┐
│                    Ownership Model                              │
│                                                                 │
│  /shared/knowledge/                                            │
│  ├── api-docs/                                                 │
│  │   ├── entra-id/          ← Owner: admin@company.com        │
│  │   ├── google-workspace/  ← Owner: anna@company.com         │
│  │   └── slack/             ← Owner: max@company.com          │
│  ├── runbooks/                                                 │
│  │   └── incident-response/ ← Owner: ops-team                 │
│  └── decisions/             ← Owner: architecture-team        │
│                                                                 │
│  Rules:                                                        │
│  - Only owner may MODIFY files in their area                   │
│  - Everyone may READ                                           │
│  - Change proposals via Pull Request                           │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

#### Implementation via CODEOWNERS

```
# /shared/knowledge/.github/CODEOWNERS

# API Docs
/api-docs/entra-id/          @admin
/api-docs/google-workspace/  @anna
/api-docs/slack/             @max

# Runbooks
/runbooks/                   @ops-team

# Decisions
/decisions/                  @architecture-team

# Default: Everyone can propose, review required
*                            @knowledge-admins
```

#### Evaluation

| Aspect | Rating |
|--------|--------|
| Conflict Prevention | ⭐⭐⭐⭐⭐ |
| User-friendliness | ⭐⭐⭐ |
| Parallelism | ⭐⭐⭐⭐ |
| Implementation Effort | ⭐⭐⭐ |

---

### 3.4 Strategy 4: CRDT-based Synchronization

```
┌─────────────────────────────────────────────────────────────────┐
│                    CRDT (Conflict-free Replicated Data Types)   │
│                                                                 │
│  Principle: Changes are stored as operations,                  │
│             not states. Operations are commutative.            │
│                                                                 │
│  User A: "Insert 'Hello' at position 0"                        │
│  User B: "Insert 'World' at position 0"                        │
│                                                                 │
│  Result (deterministic): "HelloWorld" or "WorldHello"          │
│  (based on Timestamp/User-ID)                                  │
│                                                                 │
│  Implementation: Obsidian Livesync (CouchDB)                   │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

#### Evaluation

| Aspect | Rating |
|--------|--------|
| Conflict Prevention | ⭐⭐⭐⭐⭐ |
| User-friendliness | ⭐⭐⭐⭐⭐ |
| Parallelism | ⭐⭐⭐⭐⭐ |
| Implementation Effort | ⭐⭐ |

---

## 4. Conflict Resolution Strategies

### 4.1 Resolving Git Merge Conflicts

```
┌─────────────────────────────────────────────────────────────────┐
│                    Git Merge Conflict                           │
│                                                                 │
│  <<<<<<< HEAD                                                  │
│  The API supports OAuth 2.0 with PKCE.                         │
│  =======                                                        │
│  The API supports OAuth 2.0 with Client Credentials.           │
│  >>>>>>> feature-branch                                         │
│                                                                 │
│  Resolution options:                                           │
│  1. Manual: Review both versions, choose best                  │
│  2. Theirs: git checkout --theirs file.md                      │
│  3. Ours: git checkout --ours file.md                          │
│  4. Merge: Combine information from both                       │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

#### Merge Tool Configuration

```bash
# Configure Git merge tool
git config --global merge.tool vscode
git config --global mergetool.vscode.cmd 'code --wait $MERGED'

# On conflict
git mergetool
```

#### LLM-assisted Merge

```python
#!/usr/bin/env python3
"""
AI-assisted merge conflict resolution
"""

import subprocess
import openai

def get_conflict_content(file_path: str) -> tuple:
    """Extracts both versions from a conflict"""
    with open(file_path, 'r') as f:
        content = f.read()
    
    # Parse conflict markers
    ours = []
    theirs = []
    in_ours = False
    in_theirs = False
    
    for line in content.split('\n'):
        if line.startswith('<<<<<<<'):
            in_ours = True
        elif line.startswith('======='):
            in_ours = False
            in_theirs = True
        elif line.startswith('>>>>>>>'):
            in_theirs = False
        elif in_ours:
            ours.append(line)
        elif in_theirs:
            theirs.append(line)
    
    return '\n'.join(ours), '\n'.join(theirs)

def resolve_with_llm(ours: str, theirs: str, context: str) -> str:
    """Uses LLM to resolve conflict"""
    prompt = f"""
    You are a technical documentation expert.
    
    There is a merge conflict in a Markdown file.
    
    VERSION A (current):
    {ours}
    
    VERSION B (incoming):
    {theirs}
    
    CONTEXT:
    {context}
    
    Please create a merged version that:
    1. Contains all correct information from both versions
    2. Resolves contradictions (prefer the more current/correct info)
    3. Is well formatted
    
    Respond ONLY with the merged text, no explanations.
    """
    
    response = openai.chat.completions.create(
        model="gpt-4",
        messages=[{"role": "user", "content": prompt}]
    )
    
    return response.choices[0].message.content

if __name__ == '__main__':
    import sys
    file_path = sys.argv[1]
    
    ours, theirs = get_conflict_content(file_path)
    
    # Context from filename/path
    context = f"File: {file_path}"
    
    resolved = resolve_with_llm(ours, theirs, context)
    
    print("Proposed solution:")
    print("-" * 40)
    print(resolved)
    print("-" * 40)
    
    confirm = input("Apply? (y/n): ")
    if confirm.lower() == 'y':
        with open(file_path, 'w') as f:
            f.write(resolved)
        print(f"Conflict in {file_path} resolved")
```

---

### 4.2 Syncthing Conflict Files

```
┌─────────────────────────────────────────────────────────────────┐
│                    Syncthing Conflicts                          │
│                                                                 │
│  On conflict, Syncthing creates:                               │
│                                                                 │
│  document.md                    ← Winner (newest change)       │
│  document.sync-conflict-20250110-143022-ABCDEF.md  ← Loser     │
│                                                                 │
│  Resolution:                                                   │
│  1. Compare both files                                         │
│  2. Manually merge                                             │
│  3. Delete conflict file                                       │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

#### Conflict Finder Script

```bash
#!/bin/bash
# find-conflicts.sh

KNOWLEDGE_DIR="/shared/knowledge"

echo "=== Syncthing Conflicts ==="
find "$KNOWLEDGE_DIR" -name "*.sync-conflict-*" -type f

echo ""
echo "=== Git Conflicts ==="
cd "$KNOWLEDGE_DIR"
git diff --name-only --diff-filter=U

echo ""
echo "=== Stale Locks ==="
find "$KNOWLEDGE_DIR" -name "*.lock" -mmin +60 -type f
```

---

### 4.3 Last-Write-Wins (SSHFS)

```
┌─────────────────────────────────────────────────────────────────┐
│                    Last-Write-Wins Problem                      │
│                                                                 │
│  t=0: User A opens doc.md (Version 1)                          │
│  t=1: User B opens doc.md (Version 1)                          │
│  t=2: User A saves (Version 2)                                 │
│  t=3: User B saves (Version 3) ← User A's changes GONE!        │
│                                                                 │
│  SSHFS has NO conflict handling!                               │
│                                                                 │
│  Mitigation:                                                   │
│  - Use File Locking                                            │
│  - Or: Use SSHFS for read-only access only                     │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## 5. Recommended Strategy

### 5.1 Hybrid Approach

```
┌─────────────────────────────────────────────────────────────────┐
│                    Recommended Hybrid Approach                  │
│                                                                 │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  LAYER 1: Ownership (Prevention)                        │   │
│  │  - Clear responsibilities per area                      │   │
│  │  - Reduces conflict probability by 80%                  │   │
│  └─────────────────────────────────────────────────────────┘   │
│                            │                                    │
│                            ▼                                    │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  LAYER 2: Git-based Optimistic Locking                  │   │
│  │  - Parallel work possible                               │   │
│  │  - Conflicts detected on push                           │   │
│  └─────────────────────────────────────────────────────────┘   │
│                            │                                    │
│                            ▼                                    │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  LAYER 3: File Locking for critical documents           │   │
│  │  - Only for frequently edited shared documents          │   │
│  │  - LLM agents always use locking                        │   │
│  └─────────────────────────────────────────────────────────┘   │
│                            │                                    │
│                            ▼                                    │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  LAYER 4: LLM-assisted merge on conflicts               │   │
│  │  - Automatic suggestions                                │   │
│  │  - Human confirmation                                   │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### 5.2 Implementation Checklist

| Component | Priority | Status |
|-----------|----------|--------|
| Git-based Workflow | High | [ ] |
| CODEOWNERS for Ownership | High | [ ] |
| File Locking Script | Medium | [ ] |
| LLM Merge Tool | Low | [ ] |
| Conflict Finder Script | Medium | [ ] |
| Team Training | High | [ ] |

---

## 6. Special Case: LLM Agent Conflicts

### 6.1 Problem

LLM agents (OpenCode, Gemini CLI) can edit many files very quickly, which leads to conflicts.

### 6.2 Solution: Agent Protocol

```markdown
## LLM Agent File Access Protocol

### Before each file change:

1. **Check lock**
   ```bash
   if kb-lock check "$FILE"; then
       # File is free
   else
       # Wait and retry
       sleep 30
       # Re-read file (may have changed)
   fi
   ```

2. **Acquire lock**
   ```bash
   kb-lock lock "$FILE"
   ```

3. **Read file** (always get latest version)
   ```bash
   cat "$FILE"
   ```

4. **Make changes**

5. **Release lock**
   ```bash
   kb-lock unlock "$FILE"
   ```

6. **Git Commit**
   ```bash
   git add "$FILE"
   git commit -m "Update: $FILE - $DESCRIPTION"
   git push || git pull --rebase && git push
   ```

### On conflict:

1. Do NOT overwrite changes
2. Create conflict file: `$FILE.conflict.$TIMESTAMP`
3. Notify user
4. Wait for manual resolution
```

### 6.3 Conflict Notification

```bash
#!/bin/bash
# notify-conflict.sh

FILE="$1"
USER="$2"
CONFLICT_TYPE="$3"

# Slack Notification
curl -X POST -H 'Content-type: application/json' \
    --data "{
        \"text\": \"Warning: Conflict in Knowledge Base\",
        \"blocks\": [
            {
                \"type\": \"section\",
                \"text\": {
                    \"type\": \"mrkdwn\",
                    \"text\": \"*File:* $FILE\n*User:* $USER\n*Type:* $CONFLICT_TYPE\"
                }
            }
        ]
    }" \
    "$SLACK_WEBHOOK_URL"
```

---

## 7. Monitoring & Metrics

### 7.1 Metrics to Monitor

| Metric | Threshold | Action |
|--------|-----------|--------|
| Conflicts per day | >5 | Review ownership structure |
| Stale Locks | >0 (older than 1h) | Remove automatically |
| Merge conflicts | >3 per week | Improve team communication |
| Conflict files | >0 | Resolve immediately |

### 7.2 Dashboard Script

```bash
#!/bin/bash
# conflict-dashboard.sh

echo "=== Knowledge Base Conflict Dashboard ==="
echo "Date: $(date)"
echo ""

echo "=== Active Locks ==="
find /shared/knowledge -name "*.lock" -type f -exec ls -la {} \;

echo ""
echo "=== Conflict Files ==="
find /shared/knowledge -name "*.conflict.*" -o -name "*.sync-conflict-*" | wc -l

echo ""
echo "=== Git Status ==="
cd /shared/knowledge
git status --short

echo ""
echo "=== Recent Conflicts (Git Log) ==="
git log --oneline --grep="conflict" --since="7 days ago"
```

---

## 8. Training Material

### 8.1 Quick Reference Card

```
┌─────────────────────────────────────────────────────────────────┐
│                    CONFLICT HANDLING QUICK REFERENCE            │
│                                                                 │
│  BEFORE EDITING:                                                │
│  1. git pull                                                   │
│  2. kb-lock check <file>                                       │
│  3. kb-lock lock <file>                                        │
│                                                                 │
│  AFTER EDITING:                                                 │
│  1. kb-lock unlock <file>                                      │
│  2. git add -A                                                 │
│  3. git commit -m "Description"                                │
│  4. git push                                                   │
│                                                                 │
│  ON CONFLICT:                                                  │
│  1. git pull --rebase                                          │
│  2. Resolve conflicts in editor                                │
│  3. git add <file>                                             │
│  4. git rebase --continue                                      │
│  5. git push                                                   │
│                                                                 │
│  HELP:                                                         │
│  - find-conflicts.sh                                           │
│  - conflict-dashboard.sh                                       │
│  - #knowledge-base Slack Channel                               │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## 9. Summary

### Recommended Strategy

| Situation | Strategy |
|-----------|----------|
| Normal editing | Git + Optimistic Locking |
| Critical documents | File Locking |
| LLM Agents | Always File Locking |
| Conflict occurred | LLM-assisted Merge |
| Frequent conflicts | Implement Ownership Model |

### Next Steps

1. [ ] Implement File Locking script
2. [ ] Create CODEOWNERS file
3. [ ] Train team on workflow
4. [ ] Set up monitoring
5. [ ] Evaluate LLM Merge tool

---

## Appendix A: References

- [Git Merge Strategies](https://git-scm.com/docs/merge-strategies)
- [CRDT Explained](https://crdt.tech/)
- [Obsidian Livesync](https://github.com/vrtmrz/obsidian-livesync)
- [Syncthing Conflict Handling](https://docs.syncthing.net/users/syncing.html#conflicting-changes)

---

## Related Documents

- [[00-vision]]
- [[01-knowledge-base-document-search]]
- [[05-overall-architecture]]
