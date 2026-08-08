# packer-proxmox

Packer templates for the Proxmox VE homelab. This repo builds the **images**;
[`tofu-proxmox`](https://github.com/dryvist/tofu-proxmox) provisions guests from
them, and the Ansible repos configure those guests.

Each image family is its own Packer configuration directory, because
`packer build .` builds every source it finds in a directory:

| Directory | Builder | Templates |
| --- | --- | --- |
| [`windows/`](./windows) | `proxmox-iso` | `win10` 9210, `win11` 9211, `win25` 9212 |
| [`splunk/`](./splunk) | `proxmox-clone` | `splunk-docker` 9200 |

The Debian cloud-init base template is **not** built here. It imports a cloud
image rather than running an installer, which no Packer builder does, so it is
declared as OpenTofu in `tofu-proxmox`.

## Installation

`packer` comes from the nix dev shell:

```bash
direnv allow      # or: nix develop
```

Then, in whichever image directory you are building:

```bash
packer init .
```

## Environment

No credential is declared in any HCL file in this repo. The Proxmox plugin reads
its own credentials from the environment:

| Variable | Purpose |
| --- | --- |
| `PROXMOX_URL` | API URL, including `/api2/json` |
| `PROXMOX_USERNAME` | `user@realm!tokenid` |
| `PROXMOX_TOKEN` | the token secret |

Every other input is a Packer variable set through `PKR_VAR_<name>`; see each
directory's README. No `-var-file` is used for anything sensitive, and a
`*.pkrvars.hcl` file is gitignored everywhere.

**How an operator obtains and exports these values is documented privately and
must not be described in this repo.**

## Usage

```bash
cd windows
packer validate .
packer build -only=proxmox-iso.win11 .
```

Builds run on a LAN host, not a macOS workstation — macOS Local Network privacy
denies the WinRM and SSH connections a build makes to the guest it is creating,
and the failure looks like a connection timeout rather than a permission error.

Always pass `-only=` in `windows/`. Without it Packer builds all three images at
once, and each boots a VM with the finished guest's full memory.

## Consuming a template

Set `clone_template` on the VM in `tofu-proxmox`:

```json
"clone_template": { "template_id": 9211, "full": false }
```

`full: false` makes a linked clone — copy-on-write off the template's snapshot,
which is the usual choice for disposable guests. A template cannot be deleted
while a linked clone of it exists, and the clone must live on the same storage.

For Windows guests, always set `cpu_type` and `os_type` as well. The defaults are
Linux values, and a Windows clone that inherits them **hangs immediately after
`bootmgfw.efi`** with no error — see [`windows/README.md`](./windows/README.md).
