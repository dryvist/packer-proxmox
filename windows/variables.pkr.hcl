# ==============================================================================
# BUILD PARAMETERS
# ==============================================================================
# Values come from PKR_VAR_<name> environment variables. Nothing is read from a
# -var-file, so no secret ever lands on disk.
#
# Proxmox API credentials are NOT declared here. The proxmox plugin reads
# PROXMOX_URL, PROXMOX_USERNAME and PROXMOX_TOKEN from the environment on its
# own, so the source blocks never name them.
# ==============================================================================

variable "WINDOWS_ADMIN_PASSWORD" {
  type        = string
  description = "Local Administrator password baked into the answer file. Packer authenticates over WinRM with it during the build."
  sensitive   = true
}

variable "proxmox_node" {
  type        = string
  description = "Proxmox node to build the templates on. Templates are node-local unless the storage is shared, so this must be the node the VDI guests are cloned onto."
}

variable "proxmox_insecure" {
  type        = bool
  description = "Skip TLS verification against the Proxmox API"
  default     = false
}

variable "iso_storage_pool" {
  type        = string
  description = "Datastore that already holds the Windows and virtio install ISOs, and where Packer stages the generated answer ISO"
  default     = "local"
}

variable "vm_storage_pool" {
  type        = string
  description = "Datastore for the template's disk, EFI vars and TPM state"
  default     = "local-zfs"
}

variable "bridge" {
  type        = string
  description = "Network bridge for the build VM"
  default     = "vmbr0"
}

variable "vlan_tag" {
  type        = string
  description = "VLAN tag for the build VM. Must be a VLAN Packer can reach over WinRM from wherever the build runs."
  default     = "90"
}
