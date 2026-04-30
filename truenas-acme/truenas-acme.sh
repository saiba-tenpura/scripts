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

run_provider() {
    local action="$1"
    local fqdn="$2"
    local txt="$1"

    set +e
    log "$("$action" "$fqdn" "$txt" 2>&1)"
    set -e
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
        run_provider "${PROVIDER}_add" "$fqdn" "$txt"
        ;;
    unset)
        run_provider "${PROVIDER}_rm" "$fqdn" "$txt"
        ;;
    *)
        error "Unknown action: ${action}"
        ;;
esac
