terraform {
  required_version = ">= 1.5.0, < 2.0.0"
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "4.6.0"
    }
  }
}

# Run Terraform on the VM after Ansible installs Docker.
# sudo grants access to the local socket without exposing the Docker API.
provider "docker" {
  host = "unix:///var/run/docker.sock"
}

resource "docker_network" "nginx" {
  name   = "homework-terraform-net"
  driver = "bridge"
}

resource "docker_volume" "html" {
  name = "homework-terraform-html"
}

resource "docker_image" "nginx" {
  name         = "nginx:1.28.0-alpine"
  keep_locally = true
}

resource "docker_container" "nginx" {
  name    = "homework-terraform-nginx"
  image   = docker_image.nginx.image_id
  restart = "unless-stopped"
  wait    = true

  networks_advanced {
    name = docker_network.nginx.name
  }

  # An empty named volume is populated with the image's default Nginx site.
  volumes {
    volume_name    = docker_volume.html.name
    container_path = "/usr/share/nginx/html"
    read_only      = true
  }

  ports {
    internal = 80
    external = var.http_port
    ip       = "127.0.0.1"
  }

  healthcheck {
    test     = ["CMD", "wget", "-q", "-O", "/dev/null", "http://127.0.0.1/"]
    interval = "5s"
    timeout  = "3s"
    retries  = 5
  }

  log_opts = {
    max-size = "10m"
    max-file = "3"
  }
}
