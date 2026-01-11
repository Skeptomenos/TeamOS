output "vm_external_ip" {
  description = "External IP address of the TeamOS server"
  value       = google_compute_instance.teamos_server.network_interface[0].access_config[0].nat_ip
}

output "vm_name" {
  description = "Name of the TeamOS server instance"
  value       = google_compute_instance.teamos_server.name
}

output "ssh_command" {
  description = "Command to SSH into the server"
  value       = "gcloud compute ssh ${google_compute_instance.teamos_server.name} --zone=${var.zone} --project=${var.project_id}"
}

locals {
  ip_dashed = replace(google_compute_instance.teamos_server.network_interface[0].access_config[0].nat_ip, ".", "-")
}

output "assistant_url" {
  description = "URL to access the AI assistant (via Pomerium)"
  value       = "https://assistant.${local.ip_dashed}.nip.io"
}

output "gitea_url" {
  description = "URL to access Gitea (via Pomerium)"
  value       = "https://git.${local.ip_dashed}.nip.io"
}

output "auth_url" {
  description = "Pomerium authentication URL"
  value       = "https://auth.${local.ip_dashed}.nip.io"
}

output "oauth_redirect_uri" {
  description = "Use this as the OAuth redirect URI in GCP Console"
  value       = "https://auth.${local.ip_dashed}.nip.io/oauth2/callback"
}
