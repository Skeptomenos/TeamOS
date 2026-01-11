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

output "gitea_url" {
  description = "URL to access Gitea"
  value       = "http://${google_compute_instance.teamos_server.network_interface[0].access_config[0].nat_ip}:3000"
}
