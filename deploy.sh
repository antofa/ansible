# Run ON the deployer server
# Provisions the target server
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODE="${1:-full}"

case "$MODE" in
    basic)
        echo "=== Basic target setup (base + appuser + firewall) ==="
        ansible-playbook -i "$SCRIPT_DIR/inventory.yml" "$SCRIPT_DIR/playbook.yml" --tags "base,appuser,firewall"
        ;;
    full)
        echo "=== Full target setup ==="
        ansible-playbook -i "$SCRIPT_DIR/inventory.yml" "$SCRIPT_DIR/playbook.yml"
        ;;
    *)
        echo "Usage: $0 [basic|full]"
        echo "  basic — updates, fail2ban, firewall only"
        echo "  full  — everything (nginx, tinyproxy, docker, syncthing)"
        exit 1
        ;;
esac
