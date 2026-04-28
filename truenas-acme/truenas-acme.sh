#!/usr/bin/env bash

set -eo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)
CONFIG_FILE="${SCRIPT_DIR}/config.sh"
LOG_FILE="${SCRIPT_DIR}/truenas-acme.log"

error() {
    printf '\e[93mERROR:\e[m %s\n' "${1}"
    exit 2
}

log() {
    printf '[%s] %s\n' "$(date '+%F %T')" "$*" >> "$LOG_FILE"
}

require_file() {
    [[ -f "$1" ]] || error "Missing required file: $1"
}

setup() {
    touch "$LOG_FILE"

    require_file "$CONFIG_FILE"
    source "$CONFIG_FILE"

    ACME_DIR="${ACME_DIR:-${SCRIPT_DIR}/acme.sh/}"
    require_file "${ACME_DIR}/acme.sh"
    source "${ACME_DIR}/acme.sh"

    require_file "${ACME_DIR}/dnsapi/${PROVIDER}.sh"
    source "${ACME_DIR}/dnsapi/${PROVIDER}.sh"
}

[[ "$#" -eq 4 ]] || error "Exactly 4 arguments are required: <set|unset> <domain> <fqdn> <txt>"

setup

action="$1"
domain="$2"
fqdn="$3"
txt="$4"

log "Called with: $@"
case "$action" in
    set)
        set +e
        log "$("${PROVIDER}_add" "$fqdn" "$txt")"
        set -e
        exit 0
        ;;
    unset)
        set +e
        log "$("${PROVIDER}_rm" "$fqdn" "$txt")"
        set -e
        exit 0
        ;;
    *)
        error "Unknown action: ${action}"
        ;;
esac
