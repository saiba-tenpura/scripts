#!/usr/bin/env bash

set -euo pipefail

# Colors
BLUE=$'\e[33m'
NC=$'\e[0m'

usage() {
    cat <<-EOF
	Usage: $(basename "$0") [options]

	Options:
	-h, --help      Show this help message.
	-s, --servers   Comma-separated list of servers to update.
	EOF

    exit 1
}

info() {
    printf "\n${BLUE}%s${NC}\n" "$1"
}

header() {
    printf "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
    printf "${BLUE} Server: ${NC}%-35s\n" "$1"
    printf "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
}

request_confirmation() {
    local prompt="$1"
    while true; do
        echo ""
        read -rp "${BLUE}$prompt ${NC}[y/n]: " input
        case $input in
            [Yy]*)
                return 0
                ;;
            [Nn]*)
                return 1
                ;;
            *)
                info "Please answer yes or no!"
                ;;
        esac
    done
}

check_reboot_required() {
    local server="$1"
    local result
    result="$(ssh $server 'if [ -f /var/run/reboot-required ]; then echo REBOOT; fi')"
    [[ "$result" == "REBOOT" ]];
}

if [[ $# -eq 0 ]]; then
    echo "No parameters were provided."
    exit 2
fi

while [ $# -gt 0 ]; do
     case "$1" in
        -h|--help)
            usage
            ;;
        -s|--servers)
            IFS=',' read -r -a SERVERS <<< "$2"
            shift
            ;;
        *)
            echo "Unknown option $1 was given. See -h|--help for available options." >&2;
            exit 2
            ;;
    esac
    shift
done

if ! ssh-add -l >/dev/null 2>&1; then
    info "No SSH key loaded. Running: ssh-add"
    ssh-add || printf "Failed to load SSH key!" && exit 2
fi

for SERVER in "${SERVERS[@]}"; do
    header "$SERVER"

    info "Fetching available updates..."
    ssh -t "$SERVER" 'sudo apt update'

    info "Checking for available updates..."
    updates=$(ssh -t "$SERVER" "apt list --upgradable 2>/dev/null | tail -n +2")

    if [[ -z "$updates" ]]; then
        info "No updates available on $SERVER."
    else
        info "Updates available on $SERVER:"
        echo "$updates"

        if request_confirmation "Do you want to install updates on $SERVER?"; then
            info "Installing updates..."
            ssh -t "$SERVER" 'sudo apt upgrade -y'

            if request_confirmation "Remove unused packages on $SERVER?"; then
                ssh -t "$SERVER" 'sudo apt autoremove -y'
            fi

            if request_confirmation "Clean package cache on $SERVER?"; then
                ssh -t "$SERVER" 'sudo apt clean'
            fi
        fi
    fi

    if check_reboot_required "$SERVER"; then
        info "Reboot is required on $SERVER"
        if request_confirmation "Do you want to reboot $SERVER now?"; then
            ssh -t "$SERVER" 'sudo reboot'
        fi
    else
        info "No reboot required on $SERVER."
    fi
done

info "All servers processed."
