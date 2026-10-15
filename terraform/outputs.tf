output "url_on_vm" {
  value = "http://127.0.0.1:${var.http_port}"
}
output "container_name" {
  value = docker_container.nginx.name
}
output "network_name" {
  value = docker_network.nginx.name
}
output "volume_name" {
  value = docker_volume.html.name
}
