#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"

log() {
  printf "[INFO] %s\n" "$*"
}

error() {
  printf "[ERROR] %s\n" "$*" >&2
}

get_github_repos() {
    local -n _repos="${1}"

    local page=1
    while true; do
        local response="$(curl -fsSL \
            -H "Authorization: token ${GITHUB_TOKEN}" \
            "https://api.github.com/user/repos?per_page=${PER_PAGE}&page=${page}")"

        local count="$(echo "$response" | jq '. | length')"
        [[ "$count" -eq 0 ]] && break

        _repos+=($(echo "$response" | jq -r '.[].clone_url'))
        ((page++))
    done
}

add_basic_auth() {
    local url="${1}"
    local auth="${2}"

    printf '%s\n' "${url/\/\//\/\/${auth}@}"
}

pull_github_repo() {
    local name="${1}"
    local url="${2}"
    local dir="${name}.git"

    if [ ! -d "$name.git" ]; then
        log "Cloning $name..."
        git clone --mirror "$(add_basic_auth "$url" "$GITHUB_TOKEN")" "$name.git"
    else
        log "Updating $name..."
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

    check_gitea_repo "$name"
    log "Pushing $name to Gitea..."
    local remote_url="$(add_basic_auth "$GITEA_URL" "$GITEA_USER:$GITEA_TOKEN")/$GITEA_USER/$name.git"
    git push --mirror "$remote_url"
}

check_gitea_repo() {
    local name="${1}"

    log "Ensuring repo exists on Gitea..."
    curl -s -X POST \
        "$GITEA_URL/api/v1/user/repos" \
        -H "Authorization: token $GITEA_TOKEN" \
        -H "Content-Type: application/json" \
        -d "{\"name\": \"$name\", \"private_repo\": true}" \
        > /dev/null || true
}

main() {
    source "${SCRIPT_DIR}/config.sh"
    TMP_DIR="${TMP_DIR:-${SCRIPT_DIR}/.tmp_mirror}"
    mkdir -p "$TMP_DIR"
    cd "$TMP_DIR"

    get_github_repos repos
    log "Found ${#repos[@]} repositories."
    for repo_url in "${repos[@]}"; do
        local repo_name=$(basename -s .git "$repo_url")
        if [[ "${EXCLUDED_REPOS[*]}" =~ "${repo_name}" ]]; then
            log "Skip excluded repo $repo_name"
            continue
        fi

        log "Processing $repo_name"
        pull_github_repo "$repo_name" "$repo_url"

        pushd "$repo_name.git" > /dev/null
        cleanup_pull_requests
        push_gitea_repo "$repo_name"
        popd > /dev/null
    done

    log "Mirror complete!"
}

main
