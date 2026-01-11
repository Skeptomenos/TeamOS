# Concept Paper: Server Setup, Audit, Monitoring and Logging

**Version:** 1.1  
**Date:** 2025-01-11  
**Status:** Implemented  
**Author:** TeamOS

---

## 1. Executive Summary

This document describes the setup of a shared VM in the Google Cloud Platform (GCP) that serves as a central working environment for the team. The focus is on security, traceability, and compliance through comprehensive auditing, monitoring, and logging.

---

## 2. Requirements

### 2.1 Functional Requirements

| Requirement | Description |
|-------------|-------------|
| Multi-User Access | 10 team members with isolated workspaces |
| Shared Knowledge Area | Common area for documentation |
| CLI Tool Support | OpenCode, Gemini CLI, Standard Unix Tools |
| Persistence | Data survives restarts and updates |

### 2.2 Security Requirements

| Requirement | Description |
|-------------|-------------|
| Authentication | SSH key-based, optional SSO via Entra ID |
| Authorization | Least Privilege, sudo only when needed |
| Audit Trail | All actions traceable |
| Immutable Logs | Logs cannot be tampered with |
| Compliance | GDPR-compliant, SOC2-ready |

---

## 3. Server Architecture

### 3.1 GCP VM Specification

```
┌─────────────────────────────────────────────────────────────────┐
│                    GCP Compute Engine                           │
│                                                                 │
│  Machine Type:  e2-standard-4 (4 vCPU, 16 GB RAM)              │
│  OS:            Ubuntu 24.04 LTS                                │
│  Boot Disk:     50 GB SSD (OS + Tools)                         │
│  Data Disk:     200 GB SSD (/data - User Homes + Shared)       │
│  Region:        europe-west3 (Frankfurt)                        │
│  Network:       VPC with Private IP                             │
│                                                                 │
│  Firewall Rules:                                                │
│  - SSH (22) only from Office IP / VPN                          │
│  - No direct Internet access for services                      │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### 3.2 Terraform Configuration

```hcl
# main.tf

provider "google" {
  project = var.project_id
  region  = "europe-west3"
}

resource "google_compute_instance" "team_server" {
  name         = "team-knowledge-server"
  machine_type = "e2-standard-4"
  zone         = "europe-west3-a"

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2404-lts"
      size  = 50
      type  = "pd-ssd"
    }
  }

  attached_disk {
    source      = google_compute_disk.data_disk.self_link
    device_name = "data-disk"
  }

  network_interface {
    network    = google_compute_network.vpc.self_link
    subnetwork = google_compute_subnetwork.subnet.self_link
    
    # No external IP - Access only via IAP or VPN
  }

  metadata = {
    enable-oslogin = "TRUE"
  }

  service_account {
    email  = google_service_account.vm_sa.email
    scopes = ["cloud-platform"]
  }

  tags = ["ssh-allowed", "team-server"]
}

resource "google_compute_disk" "data_disk" {
  name = "team-data-disk"
  type = "pd-ssd"
  size = 200
  zone = "europe-west3-a"
}

# Firewall: SSH only from specific IPs
resource "google_compute_firewall" "ssh" {
  name    = "allow-ssh-office"
  network = google_compute_network.vpc.self_link

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = var.allowed_ssh_ips
  target_tags   = ["ssh-allowed"]
}
```

### 3.3 Disk Layout

```
/                           # Boot Disk (50 GB SSD)
├── /home/                  # Symlink to /data/home
├── /shared/                # Symlink to /data/shared
└── /var/log/               # System Logs

/data/                      # Data Disk (200 GB SSD)
├── /data/home/             # User Home Directories
│   ├── jsmith/
│   ├── anna/
│   └── max/
├── /data/shared/           # Shared Knowledge Base
│   └── knowledge/          # Git Repo
└── /data/containers/       # Docker Volumes
    └── meilisearch/
```

---

## 4. User Management

### 4.1 Linux User Setup

```bash
#!/bin/bash
# setup-user.sh - Create new user

USERNAME=$1
EMAIL=$2
SSH_PUBKEY=$3

# Create user
sudo useradd -m -s /bin/bash -G users,docker "$USERNAME"

# Store SSH key
sudo mkdir -p /home/$USERNAME/.ssh
echo "$SSH_PUBKEY" | sudo tee /home/$USERNAME/.ssh/authorized_keys
sudo chmod 700 /home/$USERNAME/.ssh
sudo chmod 600 /home/$USERNAME/.ssh/authorized_keys
sudo chown -R $USERNAME:$USERNAME /home/$USERNAME/.ssh

# Configure Git
sudo -u $USERNAME git config --global user.email "$EMAIL"
sudo -u $USERNAME git config --global user.name "$USERNAME"

# Environment for OpenCode
cat << EOF | sudo tee /home/$USERNAME/.bashrc.d/opencode.sh
export USER_EMAIL="$EMAIL"
export MEILI_URL="http://localhost:7700"
export KNOWLEDGE_DIR="/shared/knowledge"
EOF

echo "User $USERNAME created successfully"
```

### 4.2 Groups and Permissions

```
┌─────────────────────────────────────────────────────────────────┐
│                    Group Structure                              │
│                                                                 │
│  users          All team members                                │
│  ├── Access to /shared/knowledge (read/write)                  │
│  └── Access to own home directory                              │
│                                                                 │
│  docker         Docker usage                                    │
│  └── Can start/stop containers                                 │
│                                                                 │
│  sudo           Admins only (admin, anna)                       │
│  └── Full access for maintenance                               │
│                                                                 │
│  knowledge-admin  Knowledge Base Admins                         │
│  └── Can modify structure, create backups                      │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### 4.3 Permissions for Shared Area

```bash
# Shared Knowledge Base permissions
sudo chown -R root:users /shared/knowledge
sudo chmod -R 2775 /shared/knowledge

# New files inherit group rights (SGID)
sudo find /shared/knowledge -type d -exec chmod 2775 {} \;
sudo find /shared/knowledge -type f -exec chmod 664 {} \;

# ACL for finer control
sudo setfacl -R -m g:users:rwx /shared/knowledge
sudo setfacl -R -d -m g:users:rwx /shared/knowledge
```

---

## 5. Audit System

### 5.1 auditd Configuration

```bash
# /etc/audit/rules.d/team-audit.rules

# Log all file changes in shared area
-w /shared/knowledge -p wa -k knowledge_changes

# Log sudo usage
-w /etc/sudoers -p wa -k sudoers_changes
-w /etc/sudoers.d -p wa -k sudoers_changes

# Log user management
-w /etc/passwd -p wa -k user_changes
-w /etc/group -p wa -k group_changes
-w /etc/shadow -p wa -k password_changes

# Log SSH configuration
-w /etc/ssh/sshd_config -p wa -k ssh_config

# Log privileged commands
-a always,exit -F arch=b64 -S execve -F euid=0 -k privileged_commands

# Log file deletions
-a always,exit -F arch=b64 -S unlink -S unlinkat -S rename -S renameat -k file_deletion
```

### 5.2 Audit Log Analysis

```bash
# Show all changes to Knowledge Base
sudo ausearch -k knowledge_changes --interpret

# Who changed what and when?
sudo ausearch -k knowledge_changes -i | grep -E "(type=SYSCALL|name=)"

# Sudo usage in the last 24h
sudo ausearch -k privileged_commands -ts today --interpret

# Failed access attempts
sudo ausearch --failed
```

### 5.3 Audit Report Script

```bash
#!/bin/bash
# /usr/local/bin/audit-report.sh

echo "=== Daily Audit Report ==="
echo "Date: $(date)"
echo ""

echo "=== Knowledge Base Changes ==="
sudo ausearch -k knowledge_changes -ts today --interpret 2>/dev/null | \
    grep -E "(name=|uid=|auid=)" | head -50

echo ""
echo "=== Sudo Usage ==="
sudo ausearch -k privileged_commands -ts today --interpret 2>/dev/null | \
    grep -E "(comm=|uid=)" | head -20

echo ""
echo "=== Failed Access Attempts ==="
sudo ausearch --failed -ts today --interpret 2>/dev/null | head -20

echo ""
echo "=== User Logins ==="
last -20
```

---

## 6. Logging Architecture

### 6.1 Log Sources

```
┌─────────────────────────────────────────────────────────────────┐
│                    Logging Architecture                         │
│                                                                 │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐             │
│  │   auditd    │  │   syslog    │  │  App Logs   │             │
│  │  (Security) │  │  (System)   │  │ (MeiliSearch)│             │
│  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘             │
│         │                │                │                     │
│         └────────────────┼────────────────┘                     │
│                          ▼                                      │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │                    fluent-bit                            │   │
│  │   - Collects all logs                                   │   │
│  │   - Parses and enriches                                 │   │
│  │   - Forwards to GCP                                     │   │
│  └─────────────────────────────────────────────────────────────┘   │
│                          │                                      │
│                          ▼                                      │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │              GCP Cloud Logging                           │   │
│  │   - Immutable Storage                                   │   │
│  │   - 30 Days Retention (Standard)                        │   │
│  │   - Alerting & Monitoring                               │   │
│  │   - Export to BigQuery possible                         │   │
│  └─────────────────────────────────────────────────────────────┘   │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### 6.2 fluent-bit Configuration

```ini
# /etc/fluent-bit/fluent-bit.conf

[SERVICE]
    Flush         5
    Daemon        Off
    Log_Level     info
    Parsers_File  parsers.conf

# System Logs
[INPUT]
    Name              systemd
    Tag               system.*
    Systemd_Filter    _SYSTEMD_UNIT=sshd.service
    Systemd_Filter    _SYSTEMD_UNIT=sudo.service

# Audit Logs
[INPUT]
    Name              tail
    Path              /var/log/audit/audit.log
    Tag               audit
    Parser            audit

# Application Logs
[INPUT]
    Name              tail
    Path              /var/log/meilisearch/*.log
    Tag               meilisearch
    
# Knowledge Base File Changes (via inotify)
[INPUT]
    Name              tail
    Path              /var/log/knowledge-changes.log
    Tag               knowledge

# Output to GCP Cloud Logging
[OUTPUT]
    Name              stackdriver
    Match             *
    google_service_credentials /etc/fluent-bit/gcp-credentials.json
    resource          gce_instance
    
# Local Backup
[OUTPUT]
    Name              file
    Match             *
    Path              /var/log/fluent-bit/
    Format            json_lines
```

### 6.3 GCP Cloud Logging Setup

```bash
# Create service account for logging
gcloud iam service-accounts create fluent-bit-logger \
    --display-name="Fluent Bit Logger"

# Grant permissions
gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:fluent-bit-logger@$PROJECT_ID.iam.gserviceaccount.com" \
    --role="roles/logging.logWriter"

# Create key and copy to VM
gcloud iam service-accounts keys create gcp-credentials.json \
    --iam-account=fluent-bit-logger@$PROJECT_ID.iam.gserviceaccount.com
```

---

## 7. Monitoring

### 7.1 Metrics to Monitor

| Category | Metric | Threshold | Action |
|----------|--------|-----------|--------|
| **System** | CPU Usage | >80% for 5min | Alert |
| **System** | Memory Usage | >85% | Alert |
| **System** | Disk Usage | >80% | Alert + Cleanup |
| **Security** | Failed SSH Logins | >5 in 10min | Alert + Block IP |
| **Security** | Sudo Usage | Every usage | Log |
| **Application** | MeiliSearch Health | Unhealthy | Restart |
| **Knowledge** | Docs without Frontmatter | >0 | Warning |

### 7.2 GCP Monitoring Alerts

```yaml
# monitoring-alerts.yaml

# CPU Alert
- displayName: "High CPU Usage"
  conditions:
    - displayName: "CPU > 80%"
      conditionThreshold:
        filter: 'resource.type="gce_instance" AND metric.type="compute.googleapis.com/instance/cpu/utilization"'
        comparison: COMPARISON_GT
        thresholdValue: 0.8
        duration: 300s
  notificationChannels:
    - projects/$PROJECT_ID/notificationChannels/slack-alerts

# Failed SSH Alert
- displayName: "Multiple Failed SSH Attempts"
  conditions:
    - displayName: "Failed SSH > 5"
      conditionThreshold:
        filter: 'resource.type="gce_instance" AND logName="projects/$PROJECT_ID/logs/syslog" AND textPayload:"Failed password"'
        comparison: COMPARISON_GT
        thresholdValue: 5
        duration: 600s
  notificationChannels:
    - projects/$PROJECT_ID/notificationChannels/slack-alerts
    - projects/$PROJECT_ID/notificationChannels/email-security
```

### 7.3 Health Check Script

```bash
#!/bin/bash
# /usr/local/bin/health-check.sh

SLACK_WEBHOOK="${SLACK_WEBHOOK_URL}"

check_service() {
    local service=$1
    if ! systemctl is-active --quiet "$service"; then
        echo "CRITICAL: $service is not running"
        curl -X POST -H 'Content-type: application/json' \
            --data "{\"text\":\"ALERT: $service is down on team-server\"}" \
            "$SLACK_WEBHOOK"
        return 1
    fi
    return 0
}

# Check services
check_service "sshd"
check_service "auditd"
check_service "fluent-bit"
check_service "docker"

# Check disk space
DISK_USAGE=$(df /data | tail -1 | awk '{print $5}' | tr -d '%')
if [ "$DISK_USAGE" -gt 80 ]; then
    echo "WARNING: Disk usage at ${DISK_USAGE}%"
    curl -X POST -H 'Content-type: application/json' \
        --data "{\"text\":\"WARNING: Disk usage at ${DISK_USAGE}% on team-server\"}" \
        "$SLACK_WEBHOOK"
fi

# Check MeiliSearch
if ! curl -sf http://localhost:7700/health > /dev/null; then
    echo "CRITICAL: MeiliSearch not responding"
    docker restart meilisearch
fi

echo "Health check completed at $(date)"
```

### 7.4 Cron Jobs

```bash
# /etc/cron.d/team-server

# Health Check every 5 minutes
*/5 * * * * root /usr/local/bin/health-check.sh >> /var/log/health-check.log 2>&1

# Daily Audit Report
0 8 * * * root /usr/local/bin/audit-report.sh | mail -s "Daily Audit Report" admin@company.com

# Weekly Backup Verification
0 2 * * 0 root /usr/local/bin/verify-backups.sh >> /var/log/backup-verify.log 2>&1

# Log Rotation
0 0 * * * root /usr/sbin/logrotate /etc/logrotate.conf
```

---

## 8. Session Recording

### 8.1 Automatic Session Recording

```bash
# /etc/profile.d/session-recording.sh

# Only for interactive SSH sessions
if [ -n "$SSH_CONNECTION" ] && [ -z "$SESSION_RECORDING" ]; then
    export SESSION_RECORDING=1
    
    SESSION_DIR="/var/log/sessions"
    SESSION_FILE="${SESSION_DIR}/${USER}_$(date +%Y%m%d_%H%M%S).log"
    
    # Record session with script
    exec script -q -f "$SESSION_FILE"
fi
```

### 8.2 asciinema for Detailed Recording

```bash
# /etc/profile.d/asciinema-recording.sh

if [ -n "$SSH_CONNECTION" ] && [ -z "$ASCIINEMA_REC" ]; then
    export ASCIINEMA_REC=1
    
    SESSION_DIR="/var/log/asciinema"
    SESSION_FILE="${SESSION_DIR}/${USER}_$(date +%Y%m%d_%H%M%S).cast"
    
    # Start asciinema recording
    exec asciinema rec -q --stdin "$SESSION_FILE"
fi
```

### 8.3 Session Replay

```bash
# Play back session
asciinema play /var/log/asciinema/admin_20250110_143022.cast

# Convert session to terminal format
asciinema cat /var/log/asciinema/admin_20250110_143022.cast > session.txt
```

---

## 9. Incident Response

### 9.1 Suspicious Activities

| Indicator | Description | Response |
|-----------|-------------|----------|
| Multiple failed logins | Brute-force attempt | Block IP, Alert |
| Unusual sudo usage | Privilege Escalation | Immediate review |
| Mass deletion in /shared | Sabotage/Error | Backup restore, Analysis |
| Access outside business hours | Compromised account | Lock account |

### 9.2 Incident Response Playbook

```markdown
## Incident: Suspicious Activity Detected

### 1. Immediate Actions (< 5 Minutes)
- [ ] Acknowledge alert
- [ ] Identify affected user
- [ ] If necessary: Lock user account (`sudo usermod -L username`)

### 2. Analysis (< 30 Minutes)
- [ ] Review audit logs: `sudo ausearch -ua <uid> -ts today`
- [ ] Review session recordings
- [ ] Identify affected files

### 3. Containment
- [ ] If data loss: Backup restore
- [ ] If compromised: Rotate SSH keys
- [ ] Adjust firewall rules if necessary

### 4. Documentation
- [ ] Create incident report
- [ ] Root Cause Analysis
- [ ] Lessons Learned
```

---

## 10. Backup & Disaster Recovery

### 10.1 Backup Strategy

```
┌─────────────────────────────────────────────────────────────────┐
│                    Backup Strategy                              │
│                                                                 │
│  Daily:                                                         │
│  - Git Push (Knowledge Base)                                   │
│  - MeiliSearch Dump                                            │
│  - Incremental Disk Snapshot                                   │
│                                                                 │
│  Weekly:                                                        │
│  - Full Disk Snapshot                                          │
│  - Backup Verification                                         │
│                                                                 │
│  Retention:                                                     │
│  - Daily Snapshots: 7 Days                                     │
│  - Weekly Snapshots: 4 Weeks                                   │
│  - Git History: Unlimited                                      │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### 10.2 Backup Script

```bash
#!/bin/bash
# /usr/local/bin/backup.sh

set -e

DATE=$(date +%Y%m%d)
BACKUP_BUCKET="gs://company-backups/team-server"

# 1. Git Push
cd /shared/knowledge
git add -A
git commit -m "Auto-backup $DATE" || true
git push origin main

# 2. MeiliSearch Dump
DUMP_ID=$(curl -s -X POST "http://localhost:7700/dumps" \
    -H "Authorization: Bearer ${MEILI_KEY}" | jq -r '.taskUid')
sleep 30  # Wait for dump
gsutil cp /data/containers/meilisearch/dumps/*.dump "$BACKUP_BUCKET/meilisearch/"

# 3. Disk Snapshot (via GCP API)
gcloud compute disks snapshot team-data-disk \
    --snapshot-names="team-data-$DATE" \
    --zone=europe-west3-a

# 4. Delete old snapshots (older than 7 days)
gcloud compute snapshots list --filter="creationTimestamp<-P7D" \
    --format="value(name)" | xargs -I {} gcloud compute snapshots delete {} --quiet

echo "Backup completed: $DATE"
```

---

## 11. Compliance & Documentation

### 11.1 Compliance Checklist

| Requirement | Status | Evidence |
|-------------|--------|----------|
| Access Control | ✅ | SSH keys, no passwords |
| Audit Trail | ✅ | auditd + GCP Logging |
| Immutable Logs | ✅ | GCP Cloud Logging |
| Encryption at Rest | ✅ | GCP Disk Encryption |
| Encryption in Transit | ✅ | SSH, HTTPS |
| Backup | ✅ | Daily Snapshots + Git |
| Incident Response | ✅ | Documented Playbook |

### 11.2 Documentation

The following documents must be maintained:

- [ ] Network Diagram
- [ ] User List with Permissions
- [ ] Incident Response Playbook
- [ ] Backup & Recovery Procedures
- [ ] Change Log

---

## 12. Rollout Plan

| Phase | Timeframe | Activities |
|-------|-----------|------------|
| **Phase 1** | Day 1-2 | Provision VM, Basic Setup |
| **Phase 2** | Day 3-4 | Create users, Configure SSH keys |
| **Phase 3** | Day 5 | Set up auditd + fluent-bit |
| **Phase 4** | Day 6-7 | Configure Monitoring + Alerting |
| **Phase 5** | Day 8-10 | Testing, Documentation, Team Onboarding |

---

## Appendix A: Cheat Sheet

```bash
# Create user
sudo /usr/local/bin/setup-user.sh username email@company.com "ssh-rsa AAAA..."

# Check audit logs
sudo ausearch -k knowledge_changes -ts today --interpret

# View session recordings
ls -la /var/log/sessions/

# Manual health check
/usr/local/bin/health-check.sh

# Manual backup
/usr/local/bin/backup.sh

# Lock user (during incident)
sudo usermod -L username

# View logs in GCP
gcloud logging read "resource.type=gce_instance" --limit=50
```

---

## Appendix B: References

- [GCP Compute Engine Docs](https://cloud.google.com/compute/docs)
- [Linux Audit System](https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/7/html/security_guide/chap-system_auditing)
- [Fluent Bit Documentation](https://docs.fluentbit.io/)
- [GCP Cloud Logging](https://cloud.google.com/logging/docs)

---

## Related Documents

- [[00-vision]]
- [[01-knowledge-base-document-search]]
- [[05-overall-architecture]]
