#!/usr/bin/env bash

set -euo pipefail

shopt -s nocaseglob nullglob

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
SCRIPT_NAME="$(basename "$0")"
CONFIG_FILE="${SCRIPT_DIR}/config.sh"

declare -A TYPE_MAP=(
  [Audio]='aac flac m4a mp3 ogg opus wav'
  [Documents]='csv docx epub json md pdf pptx stl txt vcf xlsx zip'
  [Pictures]='bmp gif heic heif jpg jpeg png svg tga tif tiff webp'
  [Videos]='3gp mkv mp4 mov webm'
)

error() {
    printf "[ERROR] %s\n" "$*" >&2
    exit 2
}

warn() {
    printf "[WARN] %s\n" "$*" >&2
}

usage() {
	cat <<-EOF
	Usage: ${SCRIPT_NAME} [options] [config]

	Copies media files from a connected MTP device into the output dir,
	organized by year and file type.

	Options:
	-h, --help      Show this help message.
	EOF

    exit 1
}

check_prerequisites() {
    command -v gio >/dev/null 2>&1 || error "gio is required but not installed"
    command -v rsync >/dev/null 2>&1 || error "rsync is required but not installed"
}

load_config() {
    [ ! -f "$CONFIG_FILE" ] && error "Missing configuration file: $CONFIG_FILE"

    printf 'Config: %s\n' "$CONFIG_FILE"
    source "$CONFIG_FILE"

    local required_vars=(
        "OUTPUT_DIR"
        "SOURCE_DIRS"
    )

    for var in "${required_vars[@]}"; do
        if [ -z "${!var:-}" ]; then
            error "Required configuration variable $var is not defined in $CONFIG_FILE"
        fi
    done
}

mount_mtp_devices() {
    gio mount -li | awk -F= '{if(index($2,"mtp") == 1)system("gio mount "$2)}'
}

main() {
    if [[ $# -gt 0 ]]; then
        CONFIG_FILE="$1"
    fi

    while [ $# -gt 0 ]; do
         case "$1" in
            -h|--help)
                usage
                ;;
            *)
                error "Unknown option $1 was given. See -h|--help for available options."
                ;;
        esac
        shift
    done

    check_prerequisites
    load_config
    mount_mtp_devices

    local copied=0
    for src in "${SOURCE_DIRS[@]}"; do
        printf 'Dir: %s \n' "$src"
        if [ ! -d "$src" ]; then
            warn "Source dir missing, is the device mounted?: $src"
            continue
        fi

        for type in "${!TYPE_MAP[@]}"; do
            printf 'Type: %s \n' "$type"
            for extension in ${TYPE_MAP[$type]}; do
                printf 'Extension: %s\n' "$extension"
                for file in "$src/"*.$extension; do
                    [[ -e "$file" ]] || continue

                    year="$(date -r "$file" +%Y)"
                    target_dir="$OUTPUT_DIR/$year/$type"

                    mkdir -p "$target_dir"
                    printf 'File: %s to %s \n' "$file" "$target_dir"
                    rsync -avz "$file" "$target_dir/" > /dev/null
                    copied=$((copied + 1))
                done
            done

            printf '\n'
        done

        printf '\n'
    done

    if [ "$copied" -eq 0 ]; then
        warn 'No files were copied!'
    fi

    printf 'Finished copying!\n'
}

main "$@"
