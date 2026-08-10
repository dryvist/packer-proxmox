# ==============================================================================
# BUILD PARAMETERS
# ==============================================================================
# Values come from PKR_VAR_<name> environment variables, or from the defaults
# below where the value is not environment-specific.
#
# Proxmox API credentials are NOT declared here. The proxmox plugin reads
# PROXMOX_URL, PROXMOX_USERNAME and PROXMOX_TOKEN from the environment on its
# own, so the source block never names them.
# ==============================================================================

variable "proxmox_node" {
  type        = string
  description = "Proxmox node to build the template on. Templates are node-local unless the storage is shared."
}

variable "proxmox_insecure" {
  type        = bool
  description = "Skip TLS verification against the Proxmox API"
  default     = false
}

variable "base_template" {
  type        = string
  description = "Name of the cloud-init base template this image clones from"
  default     = "debian-12-base"
}

variable "vm_storage_pool" {
  type        = string
  description = "Datastore for the template's cloud-init drive"
  default     = "local-zfs"
}

variable "bridge" {
  type        = string
  description = "Network bridge for the build VM"
  default     = "vmbr0"
}

variable "splunk_image" {
  type        = string
  description = "Splunk container image pre-pulled into the template, pinned for reproducibility"
  default     = "splunk/splunk:10.0.2"
}

variable "ssh_private_key_file" {
  type        = string
  description = <<-EOT
    Private key Packer uses to reach the build VM. Defaults to the usual path
    when it exists, and to "" when it does not — `packer validate` stats this
    file, so a hard-coded path fails anywhere the key is absent (CI) even
    though validate needs no build credentials. A build still requires a real
    key: set PKR_VAR_ssh_private_key_file, or -var, where the default misses.
  EOT
  default     = ""
}
