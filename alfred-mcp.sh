#!/usr/bin/env bash
# AlfredMCP public bootstrap (v4) — delegates to the private installer via gh auth.
# Minimal on purpose. Source: https://github.com/alfred-fleet/install

(  # subshell: partial download = unclosed paren = parse error = nothing runs
set -euo pipefail

REPO="alfred-fleet/alfred-mcp-client"
# Pin the private client repo to a specific audited commit.
# Rotate via PR to alfred-fleet/install; then update SOP-teammate-connect.md's
# pinned-installer URL + SHA-256 in the palace in lockstep.
CLIENT_PINNED_SHA="234af79b96061cf9469e902a189d987302ad18e1"
STAGE="$(mktemp -d -t alfred-mcp-bootstrap.XXXXXXXX)"
trap 'rm -rf "$STAGE"' EXIT

B="\033[1m"; G="\033[32m"; Y="\033[33m"; R="\033[31m"; N="\033[0m"
[[ -t 1 ]] || { B=""; G=""; Y=""; R=""; N=""; }

printf '%b\n' "${B}AlfredMCP bootstrap (v4)${N}"
echo ""

# --- Preflight (v4 client-side needs: gh, jq, curl, tailscale) ---
OS="$(uname -s)"
[[ "$OS" == "Darwin" ]] || { printf '%bERROR:%b macOS-only in v1 (detected: %s)\n' "$R" "$N" "$OS" >&2; exit 1; }

missing=()
for cmd in gh jq curl tailscale; do
  command -v "$cmd" >/dev/null || missing+=("$cmd")
done
if (( ${#missing[@]} > 0 )); then
  printf '%bMissing:%b %s\n\n' "$R" "$N" "${missing[*]}" >&2
  echo "Install with Homebrew (macOS):" >&2
  for c in "${missing[@]}"; do
    case "$c" in
      tailscale) echo "  brew install --cask tailscale" >&2 ;;
      *)         echo "  brew install $c" >&2 ;;
    esac
  done
  exit 1
fi

# --- Tailscale must be running ---
if ! tailscale status >/dev/null 2>&1; then
  cat >&2 <<'TS'
Tailscale is installed but not running / not authenticated.

  1. Open the Tailscale app (or run: open /Applications/Tailscale.app)
  2. Sign in with your @voxeteach.com Google account
  3. Tell Ian the device name so he can approve it + apply the tag:alfred-mcp-consumer
  4. Re-run this installer once Ian confirms
TS
  exit 1
fi

# --- gh auth ---
if ! gh auth status >/dev/null 2>&1; then
  cat >&2 <<'AUTH'
You're not logged in to GitHub. Set up a fine-grained PAT scoped to the client repo:

   1. https://github.com/settings/personal-access-tokens/new
        Token name:       alfred-mcp-consumer
        Resource owner:   alfred-fleet
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

printf '%b✓%b Tailscale up, GitHub auth confirmed\n' "$G" "$N"

# --- Clone private repo + checkout pinned SHA + hand off ---
printf '%b→%b fetching %s at pinned SHA %s...\n' "$B" "$N" "$REPO" "${CLIENT_PINNED_SHA:0:12}"
GH_TOKEN="$(gh auth token)"
git clone "https://x-access-token:${GH_TOKEN}@github.com/${REPO}.git" "$STAGE/client" >/dev/null 2>&1 \
  || { printf '%bERROR:%b clone failed (check your PAT scopes)\n' "$R" "$N" >&2; exit 1; }

# Integrity pin: check out the audited commit, not whatever main happens to be.
# If this SHA no longer exists in the remote (force-push, repo rewrite), we refuse.
git -C "$STAGE/client" checkout --detach "$CLIENT_PINNED_SHA" >/dev/null 2>&1 \
  || { printf '%bERROR:%b pinned SHA %s not present in %s (force-push?)\n' \
       "$R" "$N" "$CLIENT_PINNED_SHA" "$REPO" >&2; exit 1; }

printf '%b✓%b client repo verified at pinned SHA\n' "$G" "$N"
printf '%b→%b running installer...\n\n' "$B" "$N"
exec bash "$STAGE/client/install.sh"
)
