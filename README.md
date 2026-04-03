# Ansible — Debian Server Automation

## Architecture

```
Windows ──(scp/git)──→ deployer ──SSH──→ target
                          ansible-playbook
```

- **deployer** — server that runs Ansible (control node)
- **target** — server being provisioned

## Structure

```
ansible/
├── ansible.cfg              # Ansible config (vault password, remote user)
├── inventory.yml            # Target IP, port, SSH key path
├── playbook.yml             # Main playbook
├── group_vars/all.yml         # Public variables (domain, ports, appuser)
├── group_vars/vault.yml       # Secrets (passwords) — NEVER commit to git
├── group_vars/vault.yml.example # Template for vault.yml (safe to commit)
├── .vault-pass                # Vault password file (NEVER commit to git)
├── .gitignore               # Excludes .vault-pass from git
├── prepare-deployer.sh      # One-time deployer setup (ansible + per-target SSH key)
├── deploy.sh                # Run provisioning: `basic` or `full`
├── README.md                # This file
├── AGENTS.md                # Instructions for AI agents
└── roles/
    ├── base/                # apt upgrade, 14 utils, fail2ban, SSH hardening
    ├── appuser/             # App user + directory structure
    ├── firewall/            # UFW (configurable SSH/proxy ports)
    ├── nginx/               # Nginx HTTP only (port 80, test page)
    ├── ssl/                 # Let's Encrypt SSL certificate
    ├── tinyproxy/           # HTTP proxy with BasicAuth (configurable port)
    ├── docker/              # Docker installation
    ├── syncthing/           # Syncthing for appuser + auto-add sync folder via API
    └── appuser/             # App user (no sudo, no SSH) + app/logs/sync dirs
```

## Quick Start

### 1. Edit variables

Before anything else, configure your settings:

**`inventory.yml`** — target server:
```yaml
all:
  hosts:
    target:
      ansible_host: 192.227.173.39     # Target IP
      ansible_port: 2222                # SSH port (must match ssh_port in all.yml)
      ansible_user: root
      ansible_ssh_private_key_file: /root/.ssh/id_ed25519_target_192_227_173_39
```

**`group_vars/all.yml`** — public variables:
```yaml
ssh_port: 2222              # SSH port (non-standard to reduce brute-force)
proxy_port: 8888            # tinyproxy port
domain: example.com         # Domain for Nginx + SSL
domain_www: "www.{{ domain }}"
admin_email: "admin@{{ domain }}"
appuser: appuser            # Application user (no sudo, no SSH)
```

**`group_vars/vault.yml`** — secrets (NEVER commit to git):
```yaml
tp_user: myuser
tp_pass: mypassword
syncthing_gui_user: admin
syncthing_gui_pass: mypassword
```

Copy from template and edit:
```bash
cp group_vars/vault.yml.example group_vars/vault.yml
# Edit vault.yml with your real passwords
```

**`group_vars/vault.yml.example`** — template with placeholders (safe to commit).

### 2. Upload to deployer

```bash
scp -r ansible/ root@deployer_ip:/root/ansible/
ssh root@deployer_ip
```

### 3. Setup deployer (one-time)

```bash
cd /root/ansible/
chmod +x prepare-deployer.sh deploy.sh
./prepare-deployer.sh
```

The script will:
- Install Ansible
- Generate a per-target SSH key (named by target IP)
- Copy the key to target (requires root password for target)
- Verify connection via Ansible ping

### 4. Provision target

```bash
# Full setup (all roles)
./deploy.sh full

# Basic setup (base + appuser + firewall only)
./deploy.sh basic
```

### 5. Set up secrets on deployer

On the deployer, create the real `vault.yml` with your passwords:

```bash
cp group_vars/vault.yml.example group_vars/vault.yml
nano group_vars/vault.yml
```

**Important:** `vault.yml` is in `.gitignore` and will never be committed. The `vault.yml.example` template is safe to push to git.

## Working with the server

### Switch to appuser

After SSH as root:
```bash
su - appuser
```

View app logs:
```bash
tail -f /home/appuser/logs/app.log
```

Exit back to root:
```bash
exit
```

### Syncthing

Access the GUI at `http://<target_ip>:8384`. The sync folder `/home/appuser/sync` is added automatically.

Directory structure:
```
/home/appuser/
├── app/          # Application code
├── logs/         # Real directory for logs
└── sync/
    ├── state/    # App state files
    ├── env/      # .env files
    └── logs/     # Symlink → /home/appuser/logs/
```

## Individual roles

Run specific roles only:
```bash
ansible-playbook -i inventory.yml playbook.yml --tags "base,appuser"
ansible-playbook -i inventory.yml playbook.yml --tags "nginx,ssl"
ansible-playbook -i inventory.yml playbook.yml --tags "tinyproxy"
ansible-playbook -i inventory.yml playbook.yml --tags "syncthing"
```

## Adding a new target

1. Add to `inventory.yml`:
```yaml
    target2:
      ansible_host: 172.245.197.49
      ansible_port: 2222
      ansible_user: root
      ansible_ssh_private_key_file: /root/.ssh/id_ed25519_target_172_245_197_49
```

2. Run `prepare-deployer.sh` — it will generate a new key for this target and copy it:
```bash
./prepare-deployer.sh
```

3. Run for specific server:
```bash
ansible-playbook -i inventory.yml playbook.yml -l target2
```

## Managing secrets

`vault.yml` is in `.gitignore` — it will never be committed.

To update secrets:
1. Edit `group_vars/vault.yml` locally on Windows
2. Copy to deployer: `scp ansible/group_vars/vault.yml root@deployer_ip:/root/ansible/group_vars/vault.yml`
3. Run `./deploy.sh`

The `vault.yml.example` file is a template with placeholders — safe to commit.

## Role execution order

```
base → appuser → firewall → nginx → ssl → tinyproxy → docker → syncthing
```

Each role is idempotent — safe to run multiple times.
