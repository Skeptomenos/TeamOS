# TeamOS Infrastructure Variables
# ================================

variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "region" {
  description = "GCP Region"
  type        = string
  default     = "europe-west1"
}

variable "zone" {
  description = "GCP Zone"
  type        = string
  default     = "europe-west1-b"
}

variable "environment" {
  description = "Environment name (production, staging, development)"
  type        = string
  default     = "production"
}

# Network Configuration
variable "network_name" {
  description = "Name of the VPC network"
  type        = string
  default     = "teamos-vpc"
}

variable "subnet_cidr" {
  description = "CIDR range for the subnet"
  type        = string
  default     = "10.0.0.0/24"
}

# VM Configuration
variable "machine_type" {
  description = "GCE machine type"
  type        = string
  default     = "e2-standard-4"
}

variable "boot_disk_size" {
  description = "Boot disk size in GB"
  type        = number
  default     = 50
}

variable "data_disk_size" {
  description = "Data disk size in GB"
  type        = number
  default     = 200
}

variable "os_image" {
  description = "OS image for the VM"
  type        = string
  default     = "ubuntu-os-cloud/ubuntu-2404-lts-amd64"
}

# Access Configuration
variable "office_ip_ranges" {
  description = "List of office IP ranges allowed SSH access"
  type        = list(string)
  default     = []
}

variable "vpn_ip_ranges" {
  description = "List of VPN IP ranges allowed SSH access"
  type        = list(string)
  default     = []
}

variable "enable_iap" {
  description = "Enable Identity-Aware Proxy for SSH access"
  type        = bool
  default     = true
}

variable "enable_os_login" {
  description = "Enable GCP OS Login for SSH authentication"
  type        = bool
  default     = true
}

variable "team_group_email" {
  description = "Google Workspace group email for SSH access via OS Login"
  type        = string
  default     = "identity-n-productivity@example.com"
}

# Labels
variable "labels" {
  description = "Labels to apply to all resources"
  type        = map(string)
  default = {
    team    = "it-operations"
    project = "teamos"
  }
}

# Admin Users (for initial SSH access if not using OS Login)
variable "admin_ssh_keys" {
  description = "Map of admin usernames to their SSH public keys"
  type        = map(string)
  default     = {}
  sensitive   = true
}
