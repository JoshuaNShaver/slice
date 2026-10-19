# 0104: GitHub Actions provision the server; secrets live in GitHub

- **Date:** 2026-10-18
- **Status:** Accepted
- **Decision:** A manual Provision server workflow creates the Hetzner
  server through its API (only when asked), configures it, and checks each
  secret before and after copying it onto the server, then deploys. Every
  key is a GitHub secret. The server's SSH host key is a secret too,
  installed on first boot, so GitHub never trusts an unknown host. The
  server's IP is looked up by name, not stored.
- **Why:** no hand setup to repeat or forget; rebuilding the server is
  one workflow run.
