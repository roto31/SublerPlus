#!/usr/bin/env bash
set -euo pipefail

# Publish the working tree to the main repo and sync docs into the GitHub wiki.
# Usage: ./scripts/publish.sh
# Optional env:
#   REPO_URL     - override target repo (default: https://github.com/roto31/SublerPUS.git)
#   COMMIT_MSG   - commit message (default: "Publish")
#   NO_PROMPT=1  - skip interactive confirmation

REPO_URL="${REPO_URL:-https://github.com/roto31/SublerPLUS.git}"
COMMIT_MSG="${COMMIT_MSG:-Publish}"

main() {
  ensure_git_repo
  ensure_remote
  stage_changes
  maybe_confirm
  commit_changes
  push_repo
  sync_wiki
  echo "Done. Verify on GitHub: $REPO_URL"
}

ensure_git_repo() {
  if ! git rev-parse --show-toplevel >/dev/null 2>&1; then
    echo "Not a git repository. Run 'git init' first." >&2
    exit 1
  fi
}

ensure_remote() {
  local current
  current="$(git config --get remote.origin.url || true)"
  if [[ -z "$current" ]]; then
    git remote add origin "$REPO_URL"
    echo "Added remote origin -> $REPO_URL"
  elif [[ "$current" != "$REPO_URL" ]]; then
    echo "Remote origin is '$current' (expected '$REPO_URL')." >&2
    echo "Update manually if this is not intended." >&2
  fi
}

stage_changes() {
  git add -A
  git status --short
}

maybe_confirm() {
  if [[ "${NO_PROMPT:-0}" == "1" ]]; then return; fi
  echo "Review git status above. Press Enter to continue, or Ctrl+C to abort."
  read -r _
}

commit_changes() {
  if git diff --cached --quiet; then
    echo "No staged changes to commit; skipping commit."
    return
  fi
  git commit -m "$COMMIT_MSG"
}

push_repo() {
  local branch
  branch="$(git symbolic-ref --quiet --short HEAD || echo main)"
  git push -u origin "$branch"
}

sync_wiki() {
  local wiki_url tmp dir
  wiki_url="${REPO_URL%.git}.wiki.git"
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' EXIT
  git clone "$wiki_url" "$tmp/wiki"
  dir="$tmp/wiki"

  # Map project docs into wiki pages.
  cp "docs/USER_GUIDE.md" "$dir/Getting-Started.md" 2>/dev/null || true
  cp "docs/TECHNICAL.md" "$dir/Architecture.md" 2>/dev/null || true
  cp "docs/SECURITY.md" "$dir/Security.md" 2>/dev/null || true
  cp "docs/TROUBLESHOOTING.md" "$dir/Troubleshooting.md" 2>/dev/null || true

  cat > "$dir/Home.md" <<'EOF'
# SublerPlus Wiki

- [Getting Started](Getting-Started.md)
- [Architecture](Architecture.md)
- [Security](Security.md)
- [Troubleshooting](Troubleshooting.md)
EOF

  (cd "$dir" && git add -A && if git diff --cached --quiet; then echo "Wiki unchanged."; else git commit -m "Update wiki"; git push; fi)
}

main "$@"

