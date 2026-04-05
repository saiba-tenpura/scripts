#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)
LOG_FILE="/var/log/docker-db-dumps.log"
BACKUP_BASE_DIR="/var/backups/docker-db-dumps"
BACKUP_IMAGES=(mysql mariadb postgres)

declare -A CMD=(
    [mysql]='mysql -u root --password="$MYSQL_ROOT_PASSWORD" -e "show databases" -s --skip-column-names | grep -Ev "(sys|information_schema|performance_schema)"'
    [mariadb]='mariadb -u root --password="$MYSQL_ROOT_PASSWORD" -e "show databases" -s --skip-column-names | grep -Ev "(sys|information_schema|performance_schema)"'
    [postgres]='psql -U postgres -At -c "SELECT datname FROM pg_database WHERE not datistemplate"'
)

declare -A DUMP_CMD=(
    [mysql]='mysqldump -u root --password="$MYSQL_ROOT_PASSWORD" --opt $1'
    [mariadb]='mariadb-dump -u root --password="$MYSQL_ROOT_PASSWORD" --opt $1'
    [postgres]='pg_dump -U postgres $1'
)

usage() {
	cat <<-EOF
	Usage: $(basename "$0") [options]

	Options:
	-h, --help      Show this help message.
	-d, --daily     Run daily backup and cleanup functionality.
	-m, --monthly   Run monthly backup and cleanup functionality.
	-s, --setup     Setup cron entry.
	EOF

    exit 1
}

log() {
    printf '[%s] %s\n' "$(date '+%F %T')" "$*"
}

error() {
    printf 'ERROR: %s\n' "${1}" >&2
    exit 1
}

check() {
    [[ "$EUID" -eq 0 ]] || error "Please run this script as root!"
}

setup() {
    log 'Setting up cronjob!'
    local script="$(basename $0)"
	cat <<-EOF > /etc/cron.d/docker-db-dumps
	0 8 * * * root ${SCRIPT_DIR}/${script} --daily >> ${LOG_FILE} 2>&1
	30 8 1 * * root ${SCRIPT_DIR}/${script} --monthly >> ${LOG_FILE} 2>&1
	EOF

    exit 0
}

get_project_name() {
    local container="$1"

    docker inspect --format='{{ index .Config.Labels "com.docker.compose.project"}}' $container 2>/dev/null || true
}

backup_container() {
    local container="$1"
    local engine="$2"
    local backup_dir="$3"

    local project="$(get_project_name "$container")"
    project="${project:-unknown}"
    mkdir -p "${backup_dir}/${project}"

    log "Backing up $engine container $container"
    mapfile -t databases < <(docker exec $container bash -c "${CMD[$engine]}")
    for db in "${databases[@]}"; do
        log "Dumping database $db"
        docker exec $container bash -c "${DUMP_CMD[$engine]}" -- "${db}" | bzip2 --best > "${backup_dir}/${project}/${db}.sql.bz2"
    done
}

cleanup() {
    local backup_dir="$1"
    local retention_period="$2"
    log "Cleaning up backups"
    mapfile -t backups < <(printf '%s\n' "$backup_dir"/* | sort -r)
    for bkp in "${backups[@]:retention_period}"; do
        log "Remove backup: $bkp"
        rm -rf -- "$bkp"
    done
}

run_backup() {
    local type="$1"
    local retention_period="$2"

    local date="$(date +%F)"
    log "Start $type backup for $date"

    local backup_dir="${BACKUP_BASE_DIR}/${type}"
    for image in "${BACKUP_IMAGES[@]}"; do
        mapfile -t images < <(docker images --filter "reference=${image}:*" --filter "reference=*/${image}:*" --filter "reference=*/*/${image}:*" -q)
        mapfile -t containers < <(for hash in "${images[@]}"; do docker ps --filter "ancestor=${hash}" -q; done)
        for container in "${containers[@]}"; do
            backup_container "$container" "$image" "${backup_dir}/${date}/${image}"
        done
    done

    cleanup "$backup_dir" "$retention_period"
    log "Finished $type backup for $date"
    exit 0
}

if [[ $# -eq 0 ]]; then
    error "No options were given. See -h|--help for available options."
fi

while [ $# -gt 0 ]; do
    case "$1" in
        -h|--help)
            usage
            ;;
        -s|--setup)
            check
            setup
            ;;
        -d|--daily)
            check
            run_backup "daily" 15
            ;;
        -m|--monthly)
            check
            run_backup "monthly" 13
            ;;
        *)
            error "Unsupported option $1 was given. See -h|--help for available options."
            ;;
    esac
    shift
done

