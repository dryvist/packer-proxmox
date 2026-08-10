# packer-proxmox — AI Agent Documentation

Packer templates for the Proxmox VE homelab. This repo builds **images**;
`tofu-proxmox` provisions guests from them.

## Hard rules

**Never name a secret store, a credential path, an auth role, or how a
credential is obtained anywhere in this repo** — not in HCL, not in a README,
not in a comment, not in a commit message or PR body. This repo is public. Every
credential reaches Packer as an environment variable, and the variable *name* is
the only thing that may appear here. Where those values come from is documented
privately.

**No wrapper scripts around Packer.** `packer init`, `packer validate` and
`packer build -only=...` are the interface. A shell script that reads secrets and
re-exports them as `PKR_VAR_*` is exactly what this repo was created to delete —
the plugin already reads its own credentials from the environment. A `shell` or
`powershell` *provisioner* is different and fine: that is guest-side
configuration, which is what provisioners are for.

**Never hardcode a node name, an IP, or a domain.** Node is
`var.proxmox_node`, supplied per build.

## How credentials reach the builder

The `proxmox` plugin reads these itself. They are **not** declared as Packer
variables and must not be:

| Variable | Purpose |
| --- | --- |
| `PROXMOX_URL` | API URL including `/api2/json` |
| `PROXMOX_USERNAME` | `user@realm!tokenid` |
| `PROXMOX_TOKEN` | token secret |

Everything else is a declared variable set via `PKR_VAR_<name>`. Secrets get
`sensitive = true`. Nothing is read from a `-var-file`, and `*.pkrvars.hcl` is
gitignored in every image directory.

## Layout

One Packer configuration directory per image family, because `packer build .`
builds every source it finds in a directory:

| Directory | Builder | Templates |
| --- | --- | --- |
| `windows/` | `proxmox-iso` | `win10` 9210, `win11` 9211, `win25` 9212 |
| `splunk/` | `proxmox-clone` | `splunk-docker` 9200 |

The Debian cloud-init base template is not built here — it imports a cloud image
rather than running an installer, which no Packer builder does. It is declared as
OpenTofu in `tofu-proxmox`.

## Working on this repo

```bash
direnv allow                            # packer from the nix dev shell
cd windows
packer init . && packer validate .
packer build -only=proxmox-iso.win11 .
```

- On macOS, a build is denied when the guest it creates sits on a subnet the
  machine is directly attached to. The WinRM and SSH connections fail as a
  connection timeout, not a permission error — never diagnose that as an
  outage. Build from a host that reaches the guest over a routed path.
- Always pass `-only=` in `windows/`. Without it all three build at once, each
  booting a VM with the finished guest's full memory.
- Build one image at a time.

## Gotchas that cost real time

- **`packer validate` only checks sources referenced by a `build` block.** An
  orphaned source passes silently. Keep every source wired into a build.
- **Windows clones inherit Linux defaults.** A Windows guest cloned without
  `cpu_type` and `os_type` set hangs immediately after `bootmgfw.efi` — black
  screen, no error, looks like a bad disk and is not. Set `cpu_type = "host"`
  and `os_type = "win10"`/`"win11"` on every Windows guest.
- **The Windows templates are deliberately not sysprep-generalized.**
  `/generalize` buys a unique SID per clone, which nothing here needs, and cost
  most of the build's failure surface. Do not "restore" it without a reason you
  can name.
- **`cpu_type = "host"`, `virtio-scsi-pci` and `os = "l26"` are load-bearing**,
  not style. The default `kvm64` causes TSC clock instability and guest freezes.
- WIM indices are read off the actual ISOs with `wiminfo`, never assumed. A wrong
  index installs a different Windows edition silently, and Home editions cannot
  accept incoming RDP at all.

## PR checklist

- [ ] No secret store, credential path, auth role, or credential-fetch procedure
      named anywhere — including the PR body.
- [ ] No new wrapper script around Packer.
- [ ] `packer fmt -check` and `packer validate` pass in each touched directory.
- [ ] Secrets marked `sensitive = true`.
- [ ] Conventional commit subject.
