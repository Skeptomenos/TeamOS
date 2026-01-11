# Konzeptpapier: Server-Einrichtung, Audit, Monitoring und Logging

**Version:** 1.0  
**Datum:** 2025-01-10  
**Status:** Entwurf  
**Autor:** IT Architecture Team

---

## 1. Executive Summary

Dieses Dokument beschreibt die Einrichtung einer gemeinsam genutzten VM in der Google Cloud Platform (GCP), die als zentrale Arbeitsumgebung für das Team dient. Der Fokus liegt auf Sicherheit, Nachvollziehbarkeit und Compliance durch umfassendes Auditing, Monitoring und Logging.

---

## 2. Anforderungen

### 2.1 Funktionale Anforderungen

| Anforderung | Beschreibung |
|-------------|--------------|
| Multi-User-Zugang | 10 Teammitglieder mit isolierten Workspaces |
| Shared Knowledge Area | Gemeinsamer Bereich für Dokumentation |
| CLI-Tool-Unterstützung | OpenCode, Gemini CLI, Standard-Unix-Tools |
| Persistenz | Daten überleben Neustarts und Updates |

### 2.2 Sicherheitsanforderungen

| Anforderung | Beschreibung |
|-------------|--------------|
| Authentifizierung | SSH-Key-basiert, optional SSO via Entra ID |
| Autorisierung | Least Privilege, sudo nur bei Bedarf |
| Audit Trail | Alle Aktionen nachvollziehbar |
| Immutable Logs | Logs können nicht manipuliert werden |
| Compliance | GDPR-konform, SOC2-ready |

---

## 3. Server-Architektur

### 3.1 GCP VM Spezifikation

```
┌─────────────────────────────────────────────────────────────────┐
│                    GCP Compute Engine                           │
│                                                                 │
│  Machine Type:  e2-standard-4 (4 vCPU, 16 GB RAM)              │
│  OS:            Ubuntu 24.04 LTS                                │
│  Boot Disk:     50 GB SSD (OS + Tools)                         │
│  Data Disk:     200 GB SSD (/data - User Homes + Shared)       │
│  Region:        europe-west3 (Frankfurt)                        │
│  Network:       VPC mit Private IP                              │
│                                                                 │
│  Firewall Rules:                                                │
│  - SSH (22) nur von Office IP / VPN                            │
│  - Kein direkter Internet-Zugang für Dienste                   │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### 3.2 Terraform-Konfiguration

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
    
    # Keine externe IP - Zugang nur via IAP oder VPN
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

# Firewall: SSH nur von bestimmten IPs
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

### 3.3 Disk-Layout

```
/                           # Boot Disk (50 GB SSD)
├── /home/                  # Symlink zu /data/home
├── /shared/                # Symlink zu /data/shared
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
# setup-user.sh - Neuen User anlegen

USERNAME=$1
EMAIL=$2
SSH_PUBKEY=$3

# User erstellen
sudo useradd -m -s /bin/bash -G users,docker "$USERNAME"

# SSH Key hinterlegen
sudo mkdir -p /home/$USERNAME/.ssh
echo "$SSH_PUBKEY" | sudo tee /home/$USERNAME/.ssh/authorized_keys
sudo chmod 700 /home/$USERNAME/.ssh
sudo chmod 600 /home/$USERNAME/.ssh/authorized_keys
sudo chown -R $USERNAME:$USERNAME /home/$USERNAME/.ssh

# Git konfigurieren
sudo -u $USERNAME git config --global user.email "$EMAIL"
sudo -u $USERNAME git config --global user.name "$USERNAME"

# Environment für OpenCode
cat << EOF | sudo tee /home/$USERNAME/.bashrc.d/opencode.sh
export USER_EMAIL="$EMAIL"
export MEILI_URL="http://localhost:7700"
export KNOWLEDGE_DIR="/shared/knowledge"
EOF

echo "User $USERNAME created successfully"
```

### 4.2 Gruppen und Berechtigungen

```
┌─────────────────────────────────────────────────────────────────┐
│                    Gruppen-Struktur                             │
│                                                                 │
│  users          Alle Teammitglieder                            │
│  ├── Zugriff auf /shared/knowledge (read/write)                │
│  └── Zugriff auf eigenes Home Directory                        │
│                                                                 │
│  docker         Docker-Nutzung                                  │
│  └── Kann Container starten/stoppen                            │
│                                                                 │
│  sudo           Nur Admins (admin, anna)                       │
│  └── Vollzugriff für Wartung                                   │
│                                                                 │
│  knowledge-admin  Knowledge Base Admins                         │
│  └── Kann Struktur ändern, Backups erstellen                   │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### 4.3 Berechtigungen für Shared-Bereich

```bash
# Shared Knowledge Base Berechtigungen
sudo chown -R root:users /shared/knowledge
sudo chmod -R 2775 /shared/knowledge

# Neue Dateien erben Gruppenrechte (SGID)
sudo find /shared/knowledge -type d -exec chmod 2775 {} \;
sudo find /shared/knowledge -type f -exec chmod 664 {} \;

# ACL für feinere Kontrolle
sudo setfacl -R -m g:users:rwx /shared/knowledge
sudo setfacl -R -d -m g:users:rwx /shared/knowledge
```

---

## 5. Audit-System

### 5.1 auditd Konfiguration

```bash
# /etc/audit/rules.d/team-audit.rules

# Alle Dateiänderungen im Shared-Bereich loggen
-w /shared/knowledge -p wa -k knowledge_changes

# Sudo-Nutzung loggen
-w /etc/sudoers -p wa -k sudoers_changes
-w /etc/sudoers.d -p wa -k sudoers_changes

# User-Management loggen
-w /etc/passwd -p wa -k user_changes
-w /etc/group -p wa -k group_changes
-w /etc/shadow -p wa -k password_changes

# SSH-Konfiguration loggen
-w /etc/ssh/sshd_config -p wa -k ssh_config

# Privilegierte Befehle loggen
-a always,exit -F arch=b64 -S execve -F euid=0 -k privileged_commands

# Dateilöschungen loggen
-a always,exit -F arch=b64 -S unlink -S unlinkat -S rename -S renameat -k file_deletion
```

### 5.2 Audit-Log-Analyse

```bash
# Alle Änderungen an Knowledge Base anzeigen
sudo ausearch -k knowledge_changes --interpret

# Wer hat was wann geändert?
sudo ausearch -k knowledge_changes -i | grep -E "(type=SYSCALL|name=)"

# Sudo-Nutzung der letzten 24h
sudo ausearch -k privileged_commands -ts today --interpret

# Fehlgeschlagene Zugriffsversuche
sudo ausearch --failed
```

### 5.3 Audit-Report-Script

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

## 6. Logging-Architektur

### 6.1 Log-Quellen

```
┌─────────────────────────────────────────────────────────────────┐
│                    Logging-Architektur                          │
│                                                                 │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐             │
│  │   auditd    │  │   syslog    │  │  App Logs   │             │
│  │  (Security) │  │  (System)   │  │ (MeiliSearch)│             │
│  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘             │
│         │                │                │                     │
│         └────────────────┼────────────────┘                     │
│                          ▼                                      │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │                    fluent-bit                            │   │
│  │   - Sammelt alle Logs                                   │   │
│  │   - Parst und enriched                                  │   │
│  │   - Forwarded zu GCP                                    │   │
│  └─────────────────────────────────────────────────────────┘   │
│                          │                                      │
│                          ▼                                      │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │              GCP Cloud Logging                           │   │
│  │   - Immutable Storage                                   │   │
│  │   - 30 Tage Retention (Standard)                        │   │
│  │   - Alerting & Monitoring                               │   │
│  │   - Export zu BigQuery möglich                          │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### 6.2 fluent-bit Konfiguration

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

# Output zu GCP Cloud Logging
[OUTPUT]
    Name              stackdriver
    Match             *
    google_service_credentials /etc/fluent-bit/gcp-credentials.json
    resource          gce_instance
    
# Lokales Backup
[OUTPUT]
    Name              file
    Match             *
    Path              /var/log/fluent-bit/
    Format            json_lines
```

### 6.3 GCP Cloud Logging Setup

```bash
# Service Account für Logging erstellen
gcloud iam service-accounts create fluent-bit-logger \
    --display-name="Fluent Bit Logger"

# Berechtigungen vergeben
gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:fluent-bit-logger@$PROJECT_ID.iam.gserviceaccount.com" \
    --role="roles/logging.logWriter"

# Key erstellen und auf VM kopieren
gcloud iam service-accounts keys create gcp-credentials.json \
    --iam-account=fluent-bit-logger@$PROJECT_ID.iam.gserviceaccount.com
```

---

## 7. Monitoring

### 7.1 Zu überwachende Metriken

| Kategorie | Metrik | Schwellwert | Aktion |
|-----------|--------|-------------|--------|
| **System** | CPU Usage | >80% für 5min | Alert |
| **System** | Memory Usage | >85% | Alert |
| **System** | Disk Usage | >80% | Alert + Cleanup |
| **Security** | Failed SSH Logins | >5 in 10min | Alert + Block IP |
| **Security** | Sudo Usage | Jede Nutzung | Log |
| **Application** | MeiliSearch Health | Unhealthy | Restart |
| **Knowledge** | Docs ohne Frontmatter | >0 | Warnung |

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

# Services prüfen
check_service "sshd"
check_service "auditd"
check_service "fluent-bit"
check_service "docker"

# Disk Space prüfen
DISK_USAGE=$(df /data | tail -1 | awk '{print $5}' | tr -d '%')
if [ "$DISK_USAGE" -gt 80 ]; then
    echo "WARNING: Disk usage at ${DISK_USAGE}%"
    curl -X POST -H 'Content-type: application/json' \
        --data "{\"text\":\"WARNING: Disk usage at ${DISK_USAGE}% on team-server\"}" \
        "$SLACK_WEBHOOK"
fi

# MeiliSearch prüfen
if ! curl -sf http://localhost:7700/health > /dev/null; then
    echo "CRITICAL: MeiliSearch not responding"
    docker restart meilisearch
fi

echo "Health check completed at $(date)"
```

### 7.4 Cron Jobs

```bash
# /etc/cron.d/team-server

# Health Check alle 5 Minuten
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

### 8.1 Automatische Session-Aufzeichnung

```bash
# /etc/profile.d/session-recording.sh

# Nur für interaktive SSH-Sessions
if [ -n "$SSH_CONNECTION" ] && [ -z "$SESSION_RECORDING" ]; then
    export SESSION_RECORDING=1
    
    SESSION_DIR="/var/log/sessions"
    SESSION_FILE="${SESSION_DIR}/${USER}_$(date +%Y%m%d_%H%M%S).log"
    
    # Session mit script aufzeichnen
    exec script -q -f "$SESSION_FILE"
fi
```

### 8.2 asciinema für detaillierte Aufzeichnung

```bash
# /etc/profile.d/asciinema-recording.sh

if [ -n "$SSH_CONNECTION" ] && [ -z "$ASCIINEMA_REC" ]; then
    export ASCIINEMA_REC=1
    
    SESSION_DIR="/var/log/asciinema"
    SESSION_FILE="${SESSION_DIR}/${USER}_$(date +%Y%m%d_%H%M%S).cast"
    
    # Asciinema Recording starten
    exec asciinema rec -q --stdin "$SESSION_FILE"
fi
```

### 8.3 Session-Replay

```bash
# Session abspielen
asciinema play /var/log/asciinema/admin_20250110_143022.cast

# Session in Terminal-Format konvertieren
asciinema cat /var/log/asciinema/admin_20250110_143022.cast > session.txt
```

---

## 9. Incident Response

### 9.1 Verdächtige Aktivitäten

| Indikator | Beschreibung | Reaktion |
|-----------|--------------|----------|
| Mehrfache fehlgeschlagene Logins | Brute-Force-Versuch | IP blocken, Alert |
| Ungewöhnliche sudo-Nutzung | Privilege Escalation | Sofortige Überprüfung |
| Massenlöschung in /shared | Sabotage/Fehler | Backup restore, Analyse |
| Zugriff außerhalb Arbeitszeiten | Kompromittierter Account | Account sperren |

### 9.2 Incident Response Playbook

```markdown
## Incident: Verdächtige Aktivität erkannt

### 1. Sofortmaßnahmen (< 5 Minuten)
- [ ] Alert bestätigen
- [ ] Betroffenen User identifizieren
- [ ] Bei Bedarf: User-Account sperren (`sudo usermod -L username`)

### 2. Analyse (< 30 Minuten)
- [ ] Audit-Logs prüfen: `sudo ausearch -ua <uid> -ts today`
- [ ] Session-Recordings prüfen
- [ ] Betroffene Dateien identifizieren

### 3. Eindämmung
- [ ] Bei Datenverlust: Backup restore
- [ ] Bei Kompromittierung: SSH-Keys rotieren
- [ ] Firewall-Regeln anpassen falls nötig

### 4. Dokumentation
- [ ] Incident-Report erstellen
- [ ] Root Cause Analysis
- [ ] Lessons Learned
```

---

## 10. Backup & Disaster Recovery

### 10.1 Backup-Strategie

```
┌─────────────────────────────────────────────────────────────────┐
│                    Backup-Strategie                             │
│                                                                 │
│  Täglich:                                                       │
│  - Git Push (Knowledge Base)                                   │
│  - MeiliSearch Dump                                            │
│  - Incremental Disk Snapshot                                   │
│                                                                 │
│  Wöchentlich:                                                   │
│  - Full Disk Snapshot                                          │
│  - Backup-Verification                                         │
│                                                                 │
│  Retention:                                                     │
│  - Daily Snapshots: 7 Tage                                     │
│  - Weekly Snapshots: 4 Wochen                                  │
│  - Git History: Unbegrenzt                                     │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### 10.2 Backup-Script

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
sleep 30  # Warten auf Dump
gsutil cp /data/containers/meilisearch/dumps/*.dump "$BACKUP_BUCKET/meilisearch/"

# 3. Disk Snapshot (via GCP API)
gcloud compute disks snapshot team-data-disk \
    --snapshot-names="team-data-$DATE" \
    --zone=europe-west3-a

# 4. Alte Snapshots löschen (älter als 7 Tage)
gcloud compute snapshots list --filter="creationTimestamp<-P7D" \
    --format="value(name)" | xargs -I {} gcloud compute snapshots delete {} --quiet

echo "Backup completed: $DATE"
```

---

## 11. Compliance & Dokumentation

### 11.1 Compliance-Checkliste

| Anforderung | Status | Nachweis |
|-------------|--------|----------|
| Zugangskontrolle | ✅ | SSH-Keys, keine Passwörter |
| Audit Trail | ✅ | auditd + GCP Logging |
| Immutable Logs | ✅ | GCP Cloud Logging |
| Verschlüsselung at Rest | ✅ | GCP Disk Encryption |
| Verschlüsselung in Transit | ✅ | SSH, HTTPS |
| Backup | ✅ | Daily Snapshots + Git |
| Incident Response | ✅ | Dokumentiertes Playbook |

### 11.2 Dokumentation

Folgende Dokumente müssen gepflegt werden:

- [ ] Netzwerkdiagramm
- [ ] User-Liste mit Berechtigungen
- [ ] Incident Response Playbook
- [ ] Backup & Recovery Procedures
- [ ] Change Log

---

## 12. Rollout-Plan

| Phase | Zeitraum | Aktivitäten |
|-------|----------|-------------|
| **Phase 1** | Tag 1-2 | VM provisionieren, Basis-Setup |
| **Phase 2** | Tag 3-4 | User anlegen, SSH-Keys konfigurieren |
| **Phase 3** | Tag 5 | auditd + fluent-bit einrichten |
| **Phase 4** | Tag 6-7 | Monitoring + Alerting konfigurieren |
| **Phase 5** | Tag 8-10 | Testing, Dokumentation, Team-Onboarding |

---

## Anhang A: Cheat Sheet

```bash
# User anlegen
sudo /usr/local/bin/setup-user.sh username email@company.com "ssh-rsa AAAA..."

# Audit-Logs prüfen
sudo ausearch -k knowledge_changes -ts today --interpret

# Session-Recordings anzeigen
ls -la /var/log/sessions/

# Health Check manuell
/usr/local/bin/health-check.sh

# Backup manuell starten
/usr/local/bin/backup.sh

# User sperren (bei Incident)
sudo usermod -L username

# Logs in GCP anzeigen
gcloud logging read "resource.type=gce_instance" --limit=50
```

---

## Anhang B: Referenzen

- [GCP Compute Engine Docs](https://cloud.google.com/compute/docs)
- [Linux Audit System](https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/7/html/security_guide/chap-system_auditing)
- [Fluent Bit Documentation](https://docs.fluentbit.io/)
- [GCP Cloud Logging](https://cloud.google.com/logging/docs)
