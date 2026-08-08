packer {
  required_plugins {
    proxmox = {
      version = ">= 1.1.0"
      source  = "github.com/hashicorp/proxmox"
    }
  }
}

source "proxmox-clone" "splunk-docker" {
  # Credentials come from PROXMOX_URL, PROXMOX_USERNAME and PROXMOX_TOKEN in the
  # environment, which the plugin reads on its own.
  node                     = var.proxmox_node
  insecure_skip_tls_verify = var.proxmox_insecure

  clone_vm      = var.base_template
  vm_id         = 9200
  vm_name       = "splunk-docker-template"
  template_name = "splunk-docker-template"
  full_clone    = true

  # CRITICAL: CPU and hardware configuration to prevent system freezes
  # cpu_type: "host" exposes all host CPU features with native performance
  # scsi_controller: virtio-scsi-pci is modern/fast vs. LSI Logic (default)
  # os: "l26" optimizes for Linux 2.6+ kernel
  cpu_type        = "host"
  scsi_controller = "virtio-scsi-pci"
  os              = "l26"

  # SSH configuration: Use the VM-specific SSH key (id_ed25519)
  ssh_username         = "debian"
  ssh_timeout          = "300s"
  ssh_agent_auth       = false
  ssh_private_key_file = pathexpand("~/.ssh/id_ed25519")

  cloud_init              = true
  cloud_init_storage_pool = var.vm_storage_pool

  network_adapters {
    bridge = var.bridge
    model  = "virtio"
  }
  ipconfig {
    ip = "dhcp"
  }

  cores  = 6
  memory = 6144
}

build {
  sources = ["source.proxmox-clone.splunk-docker"]

  # Install Docker and dependencies
  # Firewall is managed by Proxmox, not guest-level iptables
  provisioner "shell" {
    inline = [
      "sudo apt-get update",
      "sudo apt-get install -y ca-certificates curl gnupg",
      "sudo install -m 0755 -d /etc/apt/keyrings",
      "curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg",
      "sudo chmod a+r /etc/apt/keyrings/docker.gpg",
      "echo \"deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian $(. /etc/os-release && echo $VERSION_CODENAME) stable\" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null",
      "sudo apt-get update",
      "sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin",
      "sudo systemctl enable docker",
      "sudo usermod -aG docker debian"
    ]
  }

  # Pre-pull Splunk Docker image (pinned version for reproducibility)
  provisioner "shell" {
    inline = [
      "sudo docker pull ${var.splunk_image}"
    ]
  }

  # Create directories for Splunk configuration
  provisioner "shell" {
    inline = [
      "sudo mkdir -p /opt/splunk/var",
      "sudo mkdir -p /opt/splunk/etc",
      "sudo mkdir -p /opt/splunk-config",
      "sudo chown -R debian:debian /opt/splunk",
      "sudo chown -R debian:debian /opt/splunk-config"
    ]
  }

  # Clean up for template
  provisioner "shell" {
    inline = [
      "sudo apt-get clean",
      "sudo rm -rf /var/lib/apt/lists/*",
      "sudo rm -rf /tmp/*",
      "sudo cloud-init clean"
    ]
  }
}
