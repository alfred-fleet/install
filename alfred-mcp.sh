#!/usr/bin/env bash
# AlfredMCP public bootstrap — delegates to the private installer via gh auth.
# Minimal on purpose. Source: https://github.com/alfred-fleet/install

(  # subshell: partial download = unclosed paren = parse error = nothing runs
set -euo pipefail

REPO="alfred-fleet/alfred-mcp-client"
STAGE="$(mktemp -d -t alfred-mcp-bootstrap.XXXXXXXX)"
trap 'rm -rf "$STAGE"' EXIT

B="\033[1m"; G="\033[32m"; Y="\033[33m"; R="\033[31m"; N="\033[0m"
[[ -t 1 ]] || { B=""; G=""; Y=""; R=""; N=""; }

printf '%b\n' "${B}AlfredMCP bootstrap${N}"
echo ""

# --- preflight ---
OS="$(uname -s)"
[[ "$OS" == "Darwin" ]] || { printf '%bERROR:%b macOS-only in v1 (detected: %s)\n' "$R" "$N" "$OS" >&2; exit 1; }

missing=()
for cmd in gh bun jq sqlite3 zstd; do
  command -v "$cmd" >/dev/null || missing+=("$cmd")
done
if (( ${#missing[@]} > 0 )); then
  printf '%bMissing:%b %s\n\n' "$R" "$N" "${missing[*]}" >&2
  echo "Install with Homebrew (if missing):" >&2
  for c in "${missing[@]}"; do
    case "$c" in
      bun) echo "  curl -fsSL https://bun.sh/install | bash" >&2 ;;
      *)   echo "  brew install $c" >&2 ;;
    esac
  done
  exit 1
fi

# --- gh auth ---
if ! gh auth status >/dev/null 2>&1; then
  cat >&2 <<'AUTH'
You're not logged in to GitHub. Set up a fine-grained PAT scoped to this repo:

   1. https://github.com/settings/personal-access-tokens/new
        Token name:      alfred-mcp-consumer
        Resource owner:  alfred-fleet
        Repository access: Only select → alfred-mcp-client
        Permissions:
          Contents:  Read-only
          Metadata:  Read-only
        Expiration: 90 days

   2. gh auth login --hostname github.com
      (paste the github_pat_... string when prompted)

   3. Re-run this installer:
      curl -fsSL https://raw.githubusercontent.com/alfred-fleet/install/main/alfred-mcp.sh | bash
AUTH
  exit 1
fi

# Refuse classic PATs (blast-radius protection).
if gh auth status 2>&1 | grep -qE 'Token scopes.*(^|,)\s*(repo|admin|workflow)\b'; then
  printf '%bClassic PAT detected.%b AlfredMCP requires a fine-grained token.\n' "$R" "$N" >&2
  echo "Create one at: https://github.com/settings/personal-access-tokens/new" >&2
  echo "Then: gh auth logout && gh auth login --hostname github.com" >&2
  exit 1
fi

# Confirm allowlist membership.
if ! gh api "repos/$REPO" >/dev/null 2>&1; then
  printf '%bNo access to %s.%b You may not be on the allowlist yet. Contact Ian.\n' "$R" "$REPO" "$N" >&2
  exit 1
fi

printf '%b✓%b GitHub auth confirmed\n' "$G" "$N"

# --- clone private repo + hand off ---
printf '%b→%b fetching %s...\n' "$B" "$N" "$REPO"
GH_TOKEN="$(gh auth token)"
git clone --depth 1 "https://x-access-token:${GH_TOKEN}@github.com/${REPO}.git" "$STAGE/client" >/dev/null 2>&1 \
  || { printf '%bERROR:%b clone failed (check your PAT scopes)\n' "$R" "$N" >&2; exit 1; }

printf '%b→%b running installer...\n\n' "$B" "$N"
exec bash "$STAGE/client/install.sh"
)
