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

variable "ssh_private_key_file" {
  type        = string
  description = "Private key Packer authenticates to the cloned guest with. `packer validate` stats this file, so it must exist wherever validate runs."
  default     = "~/.ssh/id_ed25519"
}

variable "splunk_image" {
  type        = string
  description = "Splunk container image pre-pulled into the template, pinned for reproducibility"
  default     = "splunk/splunk:10.0.2"
}
