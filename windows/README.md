# Windows VDI templates

Builds Windows templates that OpenTofu then clones. One template per OS:
`win10`, `win11`, `win25`. The templates are **not** sysprep-generalized — see
[What a build produces](#what-a-build-produces) for why.

This directory is a Packer configuration of its own — `packer build .` builds
every source it finds, so keeping each image family in its own directory stops a
Windows build from also rebuilding unrelated images.

## Where to run it

The builder needs the Proxmox API *and* a WinRM connection to the VM it is
creating. On macOS the WinRM connection is denied when that VM sits on a subnet
the machine is directly attached to, and the failure presents as a connection
timeout rather than a permission error. Build from a host that reaches the VM
over a routed path.

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
| `PKR_VAR_WINDOWS_ADMIN_PASSWORD` | local Administrator password |

How an operator populates these is documented privately, not here.

`PKR_VAR_WINDOWS_ADMIN_PASSWORD` is not a per-build value. It comes from the
estate defaults object in the secret store, which the packer role is granted
read on, and it is what the answer file bakes into the local Administrator
account. Using a build-specific password instead produces a template whose
guests can only be reached by whoever recorded that build's value — and a VDI
guest is reached by a human at an RDP or console prompt, where copy/paste is
not available. Ansible converges the same account toward the same default, so a
guest built from an older template ends up matching rather than drifting.

`PKR_VAR_proxmox_node` is a build parameter, not a credential — templates are
node-local unless the storage is shared, so it must name the node the clones
live on.

## Usage

```bash
packer validate .
packer build -only=proxmox-iso.win11 .     # 8-20 min
```

Always pass `-only=`. Without it Packer builds all three at once, and each build
boots a VM with the same memory the finished guest gets, so three at once will
exhaust a node.

## What a build produces

A template in the 9xxx VMID band. Packer generates the answer ISO from
`answer/autounattend.pkrtpl.xml`, attaches it alongside the virtio driver ISO,
and removes it afterwards.

One answer file, `autounattend.pkrtpl.xml`, applied during install. It sets up
virtio-scsi in WinPE, the guest tools, the Administrator password, WinRM and
RDP — and because the template is **not** sysprep-generalized, all of that is
captured into the image and inherited by every clone verbatim.

`sysprep /generalize` was removed deliberately. It buys a unique SID and machine
name per clone, which matters for domain join, WSUS/SCCM and KMS activation —
none of which exist here. What it cost was most of this build's failure surface:
it refuses on a BitLocker-encrypted volume, fails `0x80070005` when its answer
file is staged at the path it caches into, races the builder's own power-off,
and does not block a PowerShell `&`, so a half-resealed image converts cleanly
and misbehaves later. The trade is that clones share a SID and boot with the
template's machine name; rename via configuration management if that ever
matters.

The build asserts the guest agent service and an up network adapter both exist
before capturing. A template whose clones would be unreachable fails the build
instead of being captured.

## Consuming a template

Set `clone_template` on the VM in `deployment.json`:

```json
"clone_template": { "template_id": 9210, "full": false }
```

`full` defaults to `true`, which copies the template's whole disk up front —
9-12 GB per clone for a Windows image. On a small boot pool two of those can
exhaust it. `full: false` makes a **linked clone**: copy-on-write off the
template's snapshot, starting near zero and growing only with what the guest
writes. That is the usual choice for VDI, where guests are disposable and the
template is the artifact worth keeping.

The trade: a template cannot be deleted while a linked clone of it exists, and
the clone must live on the same storage as its template.

`clone` is in `ignore_changes` in `modules/proxmox-vm`, so adding it to a VM that
already exists is a no-op — the VM must be recreated to become a clone.

### Always set `cpu_type` and `os_type` too

The `vms` object type defaults to `cpu_type = "x86-64-v2-AES"` and
`os_type = "l26"`. Both are Linux defaults, and nothing warns when they land on
a Windows guest. A template built with `cpu_type = "host"` then clones onto
different emulated silicon than Windows installed on, and **the clone hangs
immediately after `bootmgfw.efi`** — no logo, no spinner, just a black screen
that looks like a broken disk or a bad boot order and is neither.

Declare them on every Windows guest:

```json
"cpu_type": "host",
"os_type": "win11"
```

Use `win10` for a Windows 10 image; Windows Server 2025 uses `win11`.

To tell a hung clone from a slow one, sample the guest's disk counters twice a
minute apart. Frozen counters mean it is not booting. Two failed boots also drop
Windows into recovery, which does not clear itself once the CPU is corrected —
the console needs two keypresses to leave it.

### Starting a cloned guest

The VDI guests are declared `on_boot: false` and `started: false`, so neither a
node reboot nor an apply powers them on. Starting them is a human action.
`started` is ignored after creation, so a guest an operator starts by hand stays
running and no later apply shuts it down. Both fields are published in
`ansible_inventory`, so a converge can skip a guest that is switched off.
