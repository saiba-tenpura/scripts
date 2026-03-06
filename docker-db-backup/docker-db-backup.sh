#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)
BACKUP_BASE_DIR="/var/backups/docker-db-dumps"

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

run_backup() {
    BACKUP_DIR="$1"
    RETENTION_AMOUNT=$2
    DATE=$(date +%Y-%m-%d)

    # Get all MySQL containers
    mysql_images=$(docker images --filter "reference=mysql:*" -q)
    mysql_containers=$(for hash in $mysql_images; do docker ps --filter "ancestor=$hash" -q; done)
    for container in $mysql_containers; do
        # Get compose project name
        project=$(docker inspect --format='{{ index .Config.Labels "com.docker.compose.project"}}' $container)

        # Backup MySQL database
        mkdir -p "${BACKUP_DIR}/${DATE}/${project}"
        databases=$(docker exec $container bash -c 'mysql -u root --password="$MYSQL_ROOT_PASSWORD" -e "show databases" -s --skip-column-names | grep -Ev "(sys|information_schema|performance_schema)"')
        for db in $databases; do
            docker exec $container bash -c 'mysqldump -u root --password="$MYSQL_ROOT_PASSWORD" --opt $1' -- "${db}" | bzip2 --best > "${BACKUP_DIR}/${DATE}/${project}/${db}.sql.bz2"
        done
    done

    mariadb_images=$(docker images --filter "reference=mariadb:*" -q)
    mariadb_containers=$(for hash in $mariadb_images; do docker ps --filter "ancestor=$hash" -q; done)
    for container in $mariadb_containers; do
        # Get compose project name
        project=$(docker inspect --format='{{ index .Config.Labels "com.docker.compose.project"}}' $container)

        # Backup MariaDB database
        mkdir -p "${BACKUP_DIR}/${DATE}/${project}"
        databases=$(docker exec $container bash -c 'mariadb -u root --password="$MYSQL_ROOT_PASSWORD" -e "show databases" -s --skip-column-names | grep -Ev "(sys|information_schema|performance_schema)"')
        for db in $databases; do
            docker exec $container bash -c 'mariadb-dump -u root --password="$MYSQL_ROOT_PASSWORD" --opt $1' -- "${db}" | bzip2 --best > "${BACKUP_DIR}/${DATE}/${project}/${db}.sql.bz2"
        done
    done

    # Cleanup old backups
    ls -dt "${BACKUP_DIR}/"* | tail -n +$RETENTION_AMOUNT | xargs -I {} rm -rf -- {}
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

