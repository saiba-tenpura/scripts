#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)
BACKUP_BASE_DIR="/var/backups/docker-db-dumps"
BACKUP_IMAGES="mysql mariadb postgres"

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

error() {
    printf '\e[93mERROR:\e[m %s\n' "${1}"
    exit 2
}

check() {
    if [[ "$EUID" -ne 0 ]]; then
        error "Please run this script as root!"
    fi
}

setup() {
    printf 'Setup crontab!\n'
    local script_name="$(basename $0)"
	cat <<-EOF > /etc/cron.d/docker-db-dumps
	0 8 * * * root ${SCRIPT_DIR}/${script_name} --daily >/dev/null 2>&1
	30 8 1 * * root ${SCRIPT_DIR}/${script_name} --monthly >/dev/null 2>&1
	EOF

    exit 0
}

backup_container() {
    local container="$1"
    local cmd="$2"
    local dump_cmd="$3"
    local backup_dir="$4"

    local project=$(docker inspect --format='{{ index .Config.Labels "com.docker.compose.project"}}' $container)
    mkdir -p "${backup_dir}/${project}"

    databases=$(docker exec $container bash -c "$cmd")
    for db in $databases; do
        docker exec $container bash -c "$dump_cmd" -- "${db}" | bzip2 --best > "${backup_dir}/${project}/${db}.sql.bz2"
    done
}

run_backup() {
    local backup_dir="$1"
    local retention_period="$2"

    local date=$(date +%Y-%m-%d)
    for image in $BACKUP_IMAGES; do
        images=$(docker images --filter "reference=${image}:*" --filter "reference=*/${image}:*" --filter "reference=*/*/${image}:*" -q)
        containers=$(for hash in $images; do docker ps --filter "ancestor=${hash}" -q; done)
        for container in $containers; do
            backup_container "$container" "${CMD[$image]}" "${DUMP_CMD[$image]}" "${backup_dir}/${date}/${image}"
        done
    done

    # Cleanup old backups
    ls -dt "${backup_dir}/"* | tail -n +$retention_period | xargs -I {} rm -rf -- {}
    exit 0
}

if [[ $# -eq 0 ]] ; then
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
            run_backup "${BACKUP_BASE_DIR}/daily" 15
            ;;
        -m|--monthly)
            check
            run_backup "${BACKUP_BASE_DIR}/monthly" 13
            ;;
        *)
            error "Unsupported option $1 was given. See -h|--help for available options."
            ;;
    esac
done

