#!/usr/bin/env bash

RESTIC_REPOSITORY="/var/backups/restic-repo"
RESTIC_PASSWORD_FILE="/root/.config/.restic"
FILES=(
    /home/saiba/
)

MIRROR_USER=""
MIRROR_HOST=""
MIRROR_PATH=""

SYNC_DRIVE_UUIDS=(
    E0CC0679CD06390D
)
