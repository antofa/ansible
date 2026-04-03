# AGENTS.md — Instructions for AI Agents

## Project Overview

This is an Ansible automation project for provisioning Debian servers.

**Architecture:**
```
Windows ──(scp/git)──→ deployer ──SSH──→ target
                          ansible-playbook
```

- **deployer** — Debian server that runs Ansible (control node)
- **target** — Debian server being provisioned

## Structure

```
ansible/
├── ansible.cfg              # Ansible config (remote_user=root, become=true, vault_password_file)
├── inventory.yml            # Target server IP, port, SSH key path
├── playbook.yml             # Main playbook (hosts: target)
├── group_vars/all.yml       # Public variables (domain, ports, appuser)
├── group_vars/vault.yml     # Encrypted secrets (passwords) via Ansible Vault
├── .vault-pass              # Vault password file (NEVER commit to git)
├── .gitignore               # Excludes .vault-pass from git
├── prepare-deployer.sh      # One-time deployer setup (installs ansible, per-target SSH key)
├── deploy.sh                # Run provisioning: `basic` or `full`
├── README.md                # User-facing documentation
└── roles/
    ├── base/                # apt upgrade, 14 utils, fail2ban, SSH hardening (key-only auth)
    ├── appuser/             # App user (no sudo, no SSH) + app/logs/sync dirs
    ├── firewall/            # UFW (configurable SSH/proxy ports via variables)
    ├── nginx/               # Nginx HTTP only (port 80, test page)
    ├── ssl/                 # Let's Encrypt SSL certificate
    ├── tinyproxy/           # HTTP proxy with BasicAuth (configurable port)
    ├── docker/              # Docker installation
    └── syncthing/           # Syncthing for appuser + auto-add sync folder via API
```

## Code Conventions

- **All code comments MUST be in English**
- YAML files use `---` at the top
- Role structure: `tasks/main.yml`, `handlers/main.yml`, `templates/*.j2`
- Templates use Jinja2 syntax with variables from `group_vars/all.yml`
- Handlers are triggered via `notify:` and run only when tasks report changes

## How to Run

### Initial deployer setup (one-time)
```bash
scp -r ansible/ root@deployer_ip:/root/ansible/
ssh root@deployer_ip "cd /root/ansible && chmod +x *.sh && ./prepare-deployer.sh"
```

### Provision target
```bash
# Full setup (all roles)
ssh root@deployer_ip "cd /root/ansible && ./deploy.sh full"

# Basic setup (base + appuser + firewall only)
ssh root@deployer_ip "cd /root/ansible && ./deploy.sh basic"

# Single role
ssh root@deployer_ip "cd /root/ansible && ansible-playbook -i inventory.yml playbook.yml --tags nginx"
```

## Adding a New Target

1. Add to `inventory.yml` under `all.hosts:` with matching `ansible_ssh_private_key_file`
2. Run `./prepare-deployer.sh` — generates a new per-target SSH key and copies it
3. Run with `-l <host_name>` flag to limit to specific host

## Modifying Variables

Edit `group_vars/all.yml` for public values (domain, ports, appuser):
```yaml
ssh_port: 2222
proxy_port: 8888
domain: example.com
appuser: appuser
```

Edit secrets via Ansible Vault:
```bash
ansible-vault edit group_vars/vault.yml
```

Or manually edit and encrypt:
```bash
ansible-vault encrypt group_vars/vault.yml
```

Secrets stored in `vault.yml`:
```yaml
tp_user: proxyuser
tp_pass: proxypass
syncthing_gui_user: admin
syncthing_gui_pass: syncthingpass
```

## Important Notes

- Ansible does NOT work natively on Windows — must run from a Linux deployer
- All roles are idempotent — safe to run multiple times
- `.vault-pass` is in `.gitignore` — NEVER commit it
- `ansible.cfg` points to `vault_password_file = .vault-pass` for auto-decryption
- `prepare-deployer.sh` generates per-target SSH keys named by target IP
- SSL certificate task uses `creates:` argument to avoid re-requesting certs
- Tinyproxy config backup uses `force: false` to avoid overwriting existing backup
- Firewall rules are applied BEFORE enabling UFW to prevent SSH lockout
- SSH hardening disables password auth, requires key-only login
- Syncthing uses appuser (not root), sync folder added automatically via REST API
- appuser has no sudo and no SSH access — use `su - appuser` from root
