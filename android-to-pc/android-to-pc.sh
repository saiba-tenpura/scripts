#!/usr/bin/env bash

set -euo pipefail

shopt -s nullglob

# Mount all available connected MTP devices
gio mount -li | awk -F= '{if(index($2,"mtp") == 1)system("gio mount "$2)}'

# Source config with base_target & sources
source "$1"

# Copy documents, pictures and videos
declare -A type_to_extension=(
  [Audio]='*.aac *.wav'
  [Documents]='*.json *.md *.opus *.pdf *.stl *.txt *.vcf *.zip'
  [Pictures]='*.bmp *.gif *.jpg *.jpeg *.png *.tgs *.tif *.tiff *.webp'
  [Videos]='*.mp4 *.webm'
)

for src in "${sources[@]}"; do
    printf 'Dir: %s \n' "$src"
    for type in "${!type_to_extension[@]}"; do 
        printf 'Type: %s \n' "$type"
        for extension in ${type_to_extension[$type]}; do
            for file in "$src"/$pattern; do
                [[ -e "$file" ]] || continue

                year="$(date -r "$file" +%Y)"
                target_dir="$base_target/$year/$type"

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
