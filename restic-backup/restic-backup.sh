#!/usr/bin/env bash

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
SCRIPT_NAME="$(basename $0)"
CONFIG_VARS="RESTIC_REPOSITORY RESTIC_PASSWORD_FILE FILES"
CONFIG_FILE="${SCRIPT_DIR}/config.sh"
LOG_FILE="/var/log/restic.log"

usage() {
	cat <<-EOF
	Usage: $(basename "$0") [options]

	Options:
	-h, --help      Show this help message.
	-r, --run       Execute backup of target files, prune old backups afterwards and check backup integrity.
	-s, --setup     Setup password file, init repository and create cron entry.
	--sync          Sync the restic repository to one of the configured drives.
	EOF

    exit 1
}

log() {
    printf '[%s] %s\n' "$(date '+%F %T')" "$*" >> "$LOG_FILE"
}

error() {
    printf "[ERROR] %s\n" "$*" >&2
    exit 2
}

load_config() {
    [ ! -f "$CONFIG_FILE" ] && error "Missing configuration file!"

    source "$CONFIG_FILE"
    for var in $CONFIG_VARS; do
        if [ -z "${!var}" ]; then
            error "Please configure a value for ${var} in the config.sh!"
        fi
    done
}

check() {
    [ "$EUID" -ne 0 ] && error "Script must be executed as root!"

    ! type -p restic 2>&1 >/dev/null && error "Missing restic binary, please ensure it is installed!"

    [ ! -f "$CONFIG_FILE" ] && error "Missing configuration file!"

    load_config
}

run() {
    local hostname="$(uname -n)"

    log 'Start backup'
    restic backup -vv --host "$hostname" $@

    log 'Prune backups'
    restic forget --keep-daily 7 --keep-weekly 5 --keep-monthly 12 --keep-yearly 24 --prune

    log 'Run repository check'
    restic check | tee -a "$LOG_FILE"

    log 'Mirror repository'
    mirror

    log 'Backup run completed successfully'
    exit 0
}

mirror() {
    if [[ -z "${MIRROR_HOST:-}" ]]; then
        log 'Mirror not configured, skipping!'
        return
    fi

    rsync -avz --delete \
      "${RESTIC_REPOSITORY}" \
      "${MIRROR_USER}@${MIRROR_HOST}:${MIRROR_PATH}/" | tee -a "$LOG_FILE"

    if [ $? -eq 0 ]; then
        log 'Mirror completed successfully!'
    else
        error 'Mirror failed!\n'
    fi
}

sync_drives() {
    local uuid="$1"

    sleep 5
    for uuid in $(lsblk --noheadings --list --output uuid); do
        if [[ " ${SYNC_DRIVE_UUIDS[*]} " =~ " $uuid " ]]; then
            break
        fi

        uuid=
    done

    if [[ -z "$uuid" ]]; then
        printf 'No backup disk found, exit.\n'
        exit 0
    fi

    local mountpoint="$(findmnt -n -o TARGET /dev/disk/by-uuid/$uuid)"
    if [ ! "$mountpoint" ]; then
        printf 'No mountpoint found, exit.\n'
        exit 0
    fi

    rsync -az "$RESTIC_REPOSITORY" "$mountpoint"

    sync

    printf 'Completed sync for: %s\n' "$mountpoint"
    exit 0
}

setup() {
    if [[ -f "$RESTIC_PASSWORD_FILE" ]]; then
        error "Password file already exists. Aborting setup!"
    fi

    local password
    local password_confirmation
    read -rsp 'Password: ' password
    echo
    read -rsp 'Confirm Password: ' password_confirmation
    echo

    [[ "${password}" == "${password_confirmation}" ]] || error "Passwords do not match!"

    PASSWORD_DIR="$(dirname "$RESTIC_PASSWORD_FILE")"
    [ ! -d "${PASSWORD_DIR}" ] && mkdir -m 700 -p "${PASSWORD_DIR}"
    echo "$password" > "$RESTIC_PASSWORD_FILE"
    chmod 600 "$RESTIC_PASSWORD_FILE"

    printf 'Init new restic repository!\n'
    mkdir -p "$RESTIC_REPOSITORY"
    restic init

    setup_cron
    setup_service

    exit 0
}

setup_cron() {
    local minute
    local morning_hour
    local night_hour
    local hostname="$(uname -n)"
    local seed="$(cksum <<<"$hostname" | cut -d' ' -f1)"
    minute=$(( (seed % 60 / 5) * 5 ))

    # Run between 6 - 10
    morning_hour=$(( (seed % 5) + 6 ))

    # Run between 20 - 23
    night_hour=$(( (seed % 4) + 20 ))

	cat <<-EOF > /etc/cron.d/restic
	${minute} ${morning_hour} * * * root ${SCRIPT_DIR}/${SCRIPT_NAME} -r
	${minute} ${night_hour} * * * root ${SCRIPT_DIR}/${SCRIPT_NAME} -r
	EOF

    chmod 644 /etc/cron.d/restic
    printf 'Finished crontab setup!\n'
}

setup_service() {
    ln -sf "${SCRIPT_DIR}/sync.rules" /etc/udev/rules.d/80-backup-sync.rules
	cat <<-EOF > /etc/systemd/system/backup-sync.service
	[Service]
	Type=oneshot
	ExecStart=${SCRIPT_DIR}/${SCRIPT_NAME} --sync
	EOF

    printf 'Finished service setup!\n'
}

while [ $# -gt 0 ]; do
    case "$1" in
        -h|--help)
            usage
            ;;
        -s|--setup)
            check
            setup
            ;;
        --sync)
            check
            sync_drives
            ;;
        -r|--run)
            check
            run ${FILES[@]}
            ;;
	-m|--mirror)
	    check
	    mirror
	    ;;
        *)
            error "Unknown option $1 was given. See -h|--help for available options."
            ;;
   esac
   shift
done

