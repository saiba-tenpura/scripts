#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)
source "${SCRIPT_DIR}/config.sh"

mkdir -p "$TMP_DIR"
cd "$TMP_DIR"

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
    if [[ "${EXCLUDED_REPOS[*]}" =~ "${repo_name}" ]]; then
        echo "Skip excluded repo $repo_name"
        continue
    fi

    echo "Processing $repo_name"
    if [ ! -d "$repo_name.git" ]; then
        git clone --mirror "${repo_url/:\/\//:\/\/$GITHUB_TOKEN@}" "$repo_name.git"
    else
        git -C "$repo_name.git" fetch --prune origin
    fi

    cd "$repo_name.git"
    git for-each-ref --format="%(refname)" refs/pull/ | \
    while read ref; do
      git update-ref -d "$ref"
    done

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
