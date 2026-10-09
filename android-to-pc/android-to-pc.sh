#!/usr/bin/env bash

set -euo pipefail

shopt -s nullglob

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/config.sh"

error() {
    printf "[ERROR] %s\n" "$*" >&2
    exit 2
}

load_config() {
    [ ! -f "$CONFIG_FILE" ] && error "Missing configuration file: $CONFIG_FILE"

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

if [[ $# -gt 0 ]]; then
    CONFIG_FILE="$1"
fi

load_config

# Mount all available connected MTP devices
gio mount -li | awk -F= '{if(index($2,"mtp") == 1)system("gio mount "$2)}'

# Copy documents, pictures and videos
declare -A type_to_extension=(
  [Audio]='aac wav'
  [Documents]='json md opus pdf stl txt vcf zip'
  [Pictures]='bmp gif jpg jpeg png tgs tif tiff webp'
  [Videos]='mp4 webm'
)

for src in "${SOURCE_DIRS[@]}"; do
    printf 'Dir: %s \n' "$src"
    for type in "${!type_to_extension[@]}"; do 
        printf 'Type: %s \n' "$type"
        for extension in ${type_to_extension[$type]}; do
            printf 'Extension: %s\n' "$extension"
            for file in "$src/"*.$extension; do
                [[ -e "$file" ]] || continue

                year="$(date -r "$file" +%Y)"
                target_dir="$OUTPUT_DIR/$year/$type"

                mkdir -p "$target_dir"
                printf 'File: %s to %s \n' "$file" "$target_dir"
                rsync -avz "$file" "$target_dir/" > /dev/null
            done
        done

        printf '\n'
    done

    printf '\n'
done

printf 'Finished copying!\n'
