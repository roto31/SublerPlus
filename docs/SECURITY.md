# Security Overview

## Threat Model (summary)
- **Assets:** API keys (TPDB/TMDB/TVDB), media files, artwork cache, ambiguity cache, logs/status.
- **Trust boundaries:** Localhost WebUI/API (Swifter), filesystem (user-selected files), outbound provider HTTPS calls.
- **Adversaries:** Local untrusted users/processes on the same machine; network attackers to providers (MITM mitigated by TLS); malicious media names/paths.

## Hardening Baselines
- WebUI bound to `127.0.0.1`; CORS restricted to localhost; assets block traversal; optional auth token recommended.
- All provider traffic via HTTPS; retry/backoff to reduce hammering; no plaintext secrets in logs.
- API keys stored in Keychain; env vars only as runtime fallback.
- Concurrency isolation with actors for shared state (settings, status, artwork, job queue).
- MP4 writes use temp-output replace to avoid partial writes; pure Swift AtomCodec (no native shims).

## Recommended Settings
- Set `WEBUI_TOKEN` to enable token auth for WebUI API calls; use embedded WebView only.
- Provide API keys via Settings (Keychain). Avoid long-lived env vars on shared machines.
- Keep media/artwork on local trusted volumes; avoid network shares for batch writes.

## Operational Checks
- Run `swift test --filter Security` (after security tests added) before release.
- Verify logs in Console.app do not contain keys or full URLs with secrets.
- If enabling sandbox entitlements, restrict network domains and file access to user-selected files.

## Known Limitations
- Localhost trust: a compromised local user/process could call the WebUI API; use the optional token to reduce risk.
- Rate limiting is lightweight and aimed at abuse mitigation, not strong auth.

## Sandboxing (optional for release)
- Enable app sandbox with outbound network only to TPDB/TMDB/TVDB domains; disable JIT and file access except user-chosen open/save panels.
- Keep temporary writes in app container or user-selected folder; AtomCodec already writes to temp then replaces.
- Verify entitlements against Apple HIG and store policies before distribution.

