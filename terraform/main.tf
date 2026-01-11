# TeamOS Infrastructure
# Terraform configuration for one-click deployment

terraform {
  required_version = ">= 1.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

# =============================================================================
# NETWORKING
# =============================================================================

resource "google_compute_network" "teamos_vpc" {
  name                    = "teamos-vpc"
  auto_create_subnetworks = true

  lifecycle {
    ignore_changes = [description]
  }
}

resource "google_compute_firewall" "allow_ssh" {
  name    = "teamos-allow-ssh"
  network = google_compute_network.teamos_vpc.name

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["teamos-server"]
  description   = "Allow SSH access to TeamOS server"
}

resource "google_compute_firewall" "allow_gitea" {
  name    = "teamos-allow-gitea"
  network = google_compute_network.teamos_vpc.name

  allow {
    protocol = "tcp"
    ports    = ["3000", "2222"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["teamos-server"]
  description   = "Allow Gitea web and SSH access"
}

resource "google_compute_firewall" "allow_https" {
  name    = "teamos-allow-https"
  network = google_compute_network.teamos_vpc.name

  allow {
    protocol = "tcp"
    ports    = ["80", "443"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["teamos-server"]
  description   = "Allow HTTP/HTTPS for Pomerium reverse proxy"
}

# =============================================================================
# RANDOM SECRETS (auto-generated if not provided)
# =============================================================================

resource "random_password" "meili_master_key" {
  length  = 32
  special = false
}

resource "random_password" "pomerium_shared_secret" {
  length  = 32
  special = false
}

resource "random_password" "pomerium_cookie_secret" {
  length  = 32
  special = false
}

locals {
  meili_master_key       = var.meili_master_key != "" ? var.meili_master_key : random_password.meili_master_key.result
  pomerium_shared_secret = var.pomerium_shared_secret != "" ? var.pomerium_shared_secret : random_password.pomerium_shared_secret.result
  pomerium_cookie_secret = var.pomerium_cookie_secret != "" ? var.pomerium_cookie_secret : random_password.pomerium_cookie_secret.result
}

# =============================================================================
# SERVICE ACCOUNTS
# =============================================================================

resource "google_service_account" "teamos_opencode" {
  account_id   = "teamos-opencode"
  display_name = "TeamOS OpenCode Service Account"
  description  = "Service account for OpenCode AI access"
}

resource "google_service_account" "teamos_fluentbit" {
  account_id   = "teamos-fluentbit"
  display_name = "TeamOS Fluent Bit Logger"
  description  = "Service account for shipping logs to GCP Cloud Logging"
}

resource "google_project_iam_member" "opencode_vertex" {
  project = var.project_id
  role    = "roles/aiplatform.user"
  member  = "serviceAccount:${google_service_account.teamos_opencode.email}"
}

resource "google_project_iam_member" "fluentbit_logging" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.teamos_fluentbit.email}"
}

# =============================================================================
# STORAGE
# =============================================================================

resource "google_compute_disk" "data_disk" {
  name        = "teamos-data"
  type        = "pd-ssd"
  size        = var.data_disk_size
  zone        = var.zone
  description = "TeamOS data disk for Docker, knowledge base, and user data"

  labels = {
    environment = "production"
    project     = "teamos"
  }

  lifecycle {
    prevent_destroy = true
    ignore_changes  = [labels, description]
  }
}

# =============================================================================
# COMPUTE INSTANCE
# =============================================================================

resource "google_compute_instance" "teamos_server" {
  name                      = "teamos-server"
  machine_type              = var.machine_type
  zone                      = var.zone
  allow_stopping_for_update = true

  tags = ["teamos-server"]

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2404-lts-amd64"
      size  = 50
      type  = "pd-ssd"
    }
  }

  attached_disk {
    source      = google_compute_disk.data_disk.self_link
    device_name = "teamos-data"
  }

  network_interface {
    network = google_compute_network.teamos_vpc.name
    access_config {
      # Ephemeral public IP
    }
  }

  metadata = {
    enable-oslogin             = "TRUE"
    teamos-oauth-client-id     = var.google_oauth_client_id
    teamos-oauth-client-secret = var.google_oauth_client_secret
    teamos-allowed-domain      = var.allowed_domain
    teamos-meili-master-key    = local.meili_master_key
    teamos-pomerium-shared     = local.pomerium_shared_secret
    teamos-pomerium-cookie     = local.pomerium_cookie_secret
  }

  service_account {
    email  = google_service_account.teamos_opencode.email
    scopes = ["cloud-platform"]
  }

  labels = {
    environment = "production"
    project     = "teamos"
    team        = "it-operations"
  }

  # Run setup script on first boot
  metadata_startup_script = file("${path.module}/scripts/startup.sh")

  lifecycle {
    ignore_changes = [
      metadata_startup_script,
      attached_disk,
    ]
  }
}

# =============================================================================
# IAM - OS LOGIN ACCESS
# =============================================================================

resource "google_compute_instance_iam_member" "os_login" {
  count         = var.team_group_email != "identity-n-productivity@example.com" ? 1 : 0
  project       = var.project_id
  zone          = var.zone
  instance_name = google_compute_instance.teamos_server.name
  role          = "roles/compute.osAdminLogin"
  member        = "group:${var.team_group_email}"
}

# =============================================================================
# LOGGING
# =============================================================================

resource "google_logging_project_bucket_config" "teamos_audit" {
  project        = var.project_id
  location       = var.region
  bucket_id      = "teamos-audit-logs"
  retention_days = 180
  description    = "TeamOS audit logs with 180-day retention"
}

resource "google_logging_project_sink" "teamos_audit_sink" {
  name        = "teamos-audit-sink"
  project     = var.project_id
  destination = "logging.googleapis.com/projects/${var.project_id}/locations/${var.region}/buckets/teamos-audit-logs"
  filter      = "resource.type=\"gce_instance\""

  unique_writer_identity = true
}
