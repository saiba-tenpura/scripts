#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)
source "${SCRIPT_DIR}/config.sh"

mkdir -p "$WORKDIR"
cd "$WORKDIR"

page=1
repos=()
while true; do
    response=$(curl -s \
        -H "Authorization: token $GITHUB_TOKEN" \
        "https://api.github.com/user/repos?per_page=$PER_PAGE&page=$page")

    count=$(echo "$response" | jq '. | length')
    [[ "$count" -eq 0 ]] && break

    repos+=($(echo "$response" | jq -r '.[].clone_url'))
    ((page++))
done

echo "Found ${#repos[@]} repositories."

for repo_url in "${repos[@]}"; do
    repo_name=$(basename -s .git "$repo_url")
    echo "Processing $repo_name"
    if [ ! -d "$repo_name.git" ]; then
        echo "${repo_url/:\/\//:\/\/$GITHUB_TOKEN@}"
        git clone --mirror "${repo_url/:\/\//:\/\/$GITHUB_TOKEN@}" "$repo_name.git"
    fi

    cd "$repo_name.git"
    echo "Ensuring repo exists on Gitea..."
    curl -s -X POST \
        "$GITEA_URL/api/v1/user/repos" \
        -H "Authorization: token $GITEA_TOKEN" \
        -H "Content-Type: application/json" \
        -d "{\"name\": \"$repo_name\", \"private_repo\": true}" \
        > /dev/null || true

    echo "Pushing to mirror..."
    git push --mirror "${GITEA_URL/:\/\//:\/\/$GITEA_USER:$GITEA_TOKEN@}/$GITEA_USER/$repo_name.git"

    cd ..
done

echo "Mirror complete!"
