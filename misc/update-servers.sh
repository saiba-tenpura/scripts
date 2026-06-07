#!/usr/bin/env bash

usage() {
    cat <<-EOF
	Usage: $(basename "$0") [options]

	Options:
	-h, --help      Show this help message.
	-s, --servers   Comma-separated list of servers to update.
	EOF

    exit 1
}

request_confirmation() {
    local prompt="$1"
    while true; do
        read -rp "$prompt [y/n]: " input
        case $input in
            [Yy]*)
                return 0
                ;;
            [Nn]*)
                return 1
                ;;
            *)
                echo "Please answer yes or no."
                ;;
        esac
    done
}

check_reboot_required() {
    local server="$1"
    ssh_cmd="ssh $server 'if [ -f /var/run/reboot-required ]; then echo REBOOT; fi'"
    result=$($ssh_cmd 2>/dev/null)
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
    echo "No SSH key loaded. Please run: ssh-add"
    exit 1
fi

for SERVER in "${SERVERS[@]}"; do
    echo "====================="
    echo "Connecting to $SERVER"
    echo "====================="

    echo "Fetch available updates..."
    ssh -t $SERVER 'sudo -v && sudo apt update'

    echo "Checking for available updates..."
    updates=$(ssh -t "$SERVER" "apt list --upgradable 2>/dev/null | tail -n +2")

    if [[ -z "$updates" ]]; then
        echo "No updates available on $SERVER."
    else
        echo "Updates available on $SERVER:"
        echo "$updates"

        if request_confirmation "Do you want to install updates on $SERVER?"; then
            echo "Installing updates..."
            ssh $SERVER 'sudo apt upgrade -y'

            if request_confirmation "Remove unused packages on $SERVER?"; then
                ssh $SERVER 'sudo apt autoremove -y'
            fi

            if request_confirmation "Clean package cache on $SERVER?"; then
                ssh $SERVER 'sudo apt clean'
            fi
        fi

        if check_reboot_required "$SERVER"; then
            echo "Reboot is required on $SERVER."
            if request_confirmation "Do you want to reboot $SERVER now?"; then
                # ssh $SERVER 'sudo reboot'
                echo "$SERVER sudo reboot"
            fi
        else
            echo "No reboot required on $SERVER."
        fi
    fi

    echo ""
done

echo "All servers processed."
