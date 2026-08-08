# Splunk Docker template

Builds a Debian template with Docker installed and the Splunk container image
pre-pulled, which OpenTofu then clones. One template, VMID 9200.

This directory is a Packer configuration of its own — `packer build .` builds
every source it finds, so keeping each image family in its own directory stops a
Splunk build from also rebuilding unrelated images.

The source is `proxmox-clone`: it clones an existing cloud-init base template
rather than installing from an ISO.

## Installation

`packer` comes from the repo's nix dev shell — `direnv allow` at the repo root,
or `nix develop`. Then fetch the Proxmox plugin once per host:

```bash
packer init .
```

## Environment

The Proxmox plugin reads its own credentials from the environment, so no
credential is declared in the HCL and no `-var-file` is used:

| Variable | Purpose |
| --- | --- |
| `PROXMOX_URL` | API URL, including `/api2/json` |
| `PROXMOX_USERNAME` | `user@realm!tokenid` |
| `PROXMOX_TOKEN` | the token secret |
| `PKR_VAR_proxmox_node` | node to build on |

How an operator populates these is documented privately, not here.

The build also needs SSH access to the cloned guest as the `debian` user, using
`~/.ssh/id_ed25519`.

Everything else has a default in `variables.pkr.hcl` — the base template name,
storage pool, bridge, and the pinned Splunk image tag. Override any of them with
`PKR_VAR_<name>`.

## Usage

```bash
packer validate .
packer build .
```

## Hardware settings that are not preferences

`cpu_type = "host"`, `scsi_controller = "virtio-scsi-pci"` and `os = "l26"` are
load-bearing. The default `kvm64` CPU type causes TSC clock instability and
emulation overhead severe enough to freeze the guest. Do not "simplify" these to
provider defaults.
