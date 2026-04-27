#!/usr/bin/env bash

set -eo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)
LOG_FILE="${SCRIPT_DIR}/truenas-acme.log"

error() {
    printf '\e[93mERROR:\e[m %s\n' "${1}"
    exit 2
}

log() {
    printf '[%s] %s\n' "$(date '+%F %T')" "$*" >> "$LOG_FILE"
}

setup() {
    if [ ! -f "$LOG_FILE" ]; then
        touch "$LOG_FILE"
    fi

    if [ ! -f "${SCRIPT_DIR}/config.sh" ]; then
        error "Missing configuration file!"
    fi

    source "${SCRIPT_DIR}/config.sh"
    if [ ! -f "${SCRIPT_DIR}/acme.sh/acme.sh" ]; then
        error "Missing acme.sh!"
    fi

    source "${SCRIPT_DIR}/acme.sh/acme.sh"
    if [ ! -f "${SCRIPT_DIR}/acme.sh/dnsapi/${PROVIDER}.sh" ]; then
       error "The configured ACME provider doesn't exists!"
    fi

    source "${SCRIPT_DIR}/acme.sh/dnsapi/${PROVIDER}.sh"
}

if [ "$#" -ne 4 ]; then
    error "Not enough arguments 4 are required."
fi

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
        error "Unknown action ${action} given"
        ;;
esac
