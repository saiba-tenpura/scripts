#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)

get_github_repos() {
    local -n github_repos="${1}"

    local page=1
    while true; do
        local response=$(curl -s \
            -H "Authorization: token $GITHUB_TOKEN" \
            "https://api.github.com/user/repos?per_page=$PER_PAGE&page=$page")

        local count=$(echo "$response" | jq '. | length')
        [[ "$count" -eq 0 ]] && break

        github_repos+=($(echo "$response" | jq -r '.[].clone_url'))
        ((page++))
    done
}

add_basic_auth() {
    local url="${1}"
    local auth="${2}"

    echo "${url/:\/\//:\/\/$auth@}"
}

pull_github_repo() {
    local name="${1}"
    local url="${2}"

    if [ ! -d "$name.git" ]; then
        git clone --mirror "$(add_basic_auth "$url" "$GITHUB_TOKEN")" "$name.git"
    else
        git -C "$name.git" fetch --prune origin
    fi
}

cleanup_pull_requests() {
    git for-each-ref --format="%(refname)" refs/pull/ | \
    while read ref; do
      git update-ref -d "$ref"
    done
}

push_gitea_repo() {
    local name="${1}"

    echo "Ensuring repo exists on Gitea..."
    curl -s -X POST \
        "$GITEA_URL/api/v1/user/repos" \
        -H "Authorization: token $GITEA_TOKEN" \
        -H "Content-Type: application/json" \
        -d "{\"name\": \"$name\", \"private_repo\": true}" \
        > /dev/null || true

    echo "Pushing to mirror..."
    git push --mirror "$(add_basic_auth "$GITEA_URL" "$GITEA_USER:$GITEA_TOKEN")/$GITEA_USER/$name.git"
}

source "${SCRIPT_DIR}/config.sh"
mkdir -p "$TMP_DIR"
cd "$TMP_DIR"

get_github_repos repos
echo "Found ${#repos[@]} repositories."
for repo_url in "${repos[@]}"; do
    repo_name=$(basename -s .git "$repo_url")
    if [[ "${EXCLUDED_REPOS[*]}" =~ "${repo_name}" ]]; then
        echo "Skip excluded repo $repo_name"
        continue
    fi

    echo "Processing $repo_name"
    pull_github_repo "$repo_name" "$repo_url"

    cd "$repo_name.git"
    cleanup_pull_requests
    push_gitea_repo "$repo_name"
    cd ..
done

echo "Mirror complete!"
