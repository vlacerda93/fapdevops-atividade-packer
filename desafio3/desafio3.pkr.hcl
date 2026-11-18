packer {
  required_plugins {
    docker = {
      version = ">= 1.0.8"
      source  = "github.com/hashicorp/docker"
    }
  }
}

source "docker" "node_base" {
  image  = "ubuntu:jammy"
  commit = true
}

build {
  name    = "dev-node"
  sources = ["source.docker.node_base"]

  provisioner "shell" {
    inline = [
      "apt-get update",
      "DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends nodejs npm ca-certificates",
      "mkdir -p /app",
      "apt-get clean"
    ]
  }

  provisioner "file" {
    source      = "package.json"
    destination = "/app/package.json"
  }

  provisioner "shell" {
    inline = [
      "cd /app && npm install"
    ]
  }

  post-processor "docker-tag" {
    repository = "ambiente-node"
    tags       = ["v1"]
  }
}
