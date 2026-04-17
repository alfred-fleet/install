# alfred-fleet/install

Public bootstrap for [AlfredMCP](https://github.com/alfred-fleet/alfred-mcp-client).

This repo exists because the actual client lives in a private repo, so
`raw.githubusercontent.com` can't serve it without auth. This tiny wrapper
runs a prereq check, verifies your `gh` auth has access to the private repo,
then delegates to the real installer.

## Usage

```bash
curl -fsSL https://raw.githubusercontent.com/alfred-fleet/install/main/alfred-mcp.sh | bash
```

## What it does

1. Checks macOS + required CLIs (`gh`, `bun`, `jq`, `sqlite3`, `zstd`).
2. Confirms `gh auth status` and that your token is fine-grained (refuses classic PATs).
3. Clones `alfred-fleet/alfred-mcp-client` using your `gh` token.
4. Executes `install.sh` from that clone.

Trust model: TLS to github.com + your fine-grained PAT + private-repo
membership (managed via `alfred-mcp-client/allowlist.yml`).

## Auditing before you run

```bash
curl -fsSL https://raw.githubusercontent.com/alfred-fleet/install/main/alfred-mcp.sh | less
```

Read it before piping. The bootstrap is ~70 lines; the real work is in
the private installer, which you'll see after it clones.
