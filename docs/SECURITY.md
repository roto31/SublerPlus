# SublerPlus Security Notes

## Threat Model (local-only)
- WebUI bound to `127.0.0.1:8080`; no remote exposure expected.
- Secrets: TPDB/TMDB/TVDB/OpenSubtitles keys, optional WebUI token, Keychain-backed.
- Assets: local media paths, metadata lookups, subtitle downloads, logs (scrubbed).

## Controls
- Auth: optional `X-Auth-Token` for `/api/*`; prompt in app when missing.
- Network: HTTPS-only provider calls; retries with backoff and circuit breaker.
- Input validation: file extension allowlist (`mp4/m4v/mov`), body size limit, JSON content-type checks, directory traversal guards for assets.
- Logging hygiene: API keys scrubbed; StatusStream uses scrubbed text.
- Rate limiting: token bucket on WebUI API routes.
- Key storage: Keychain preferred; env vars allowed with warning.

## Operational Guidance
- Rotate API tokens quarterly; UI shows rotation guidance and generator.
- Set `WEBUI_TOKEN` in app settings for shared machines.
- Review Console.app logs under subsystem `com.sublerplus.app` for security lane.
- Prune old build artifacts regularly (`build/App builds/`), or run `scripts/build.sh --release` with pruning enabled (see script).

## Testing
- `swift test` includes: CORS/auth, body-size rejection, path traversal guards, provider retry/backoff, logging scrub, file-type validation.

# Security Overview

## Threat Model (summary)
- **Assets:** API keys (TPDB/TMDB/TVDB/OpenSubtitles), media files, artwork cache, ambiguity cache, logs/status.
- **Trust boundaries:** Localhost WebUI/API (Swifter), filesystem (user-selected files, watch folders), outbound provider HTTPS calls.
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

### Sandbox/Entitlements Plan
- App Sandbox: enable; allow **Outgoing Network**; restrict domains via ATS `NSExceptionDomains` to `api.theporndb.net`, `api.themoviedb.org`, `api4.thetvdb.com`, `image.tmdb.org`, and `rapidapi.com` (for OpenSubtitles). Deny inbound.
- File access: rely on `NSOpenPanel`/`NSSavePanel` security-scoped bookmarks for user-selected files/folders; no broad file-read/write entitlements. Keep temp writes inside app container or selected output directory.
- Keychain: continue using generic password items; no access groups required. Add `com.apple.security.personal-information.keychain` only if sandbox requires explicit entitlement for generic passwords.
- Web server: keep bound to `127.0.0.1`; no Bonjour/remote; no additional network listeners.
- Harden ATS: require HTTPS for all provider calls; no arbitrary loads.
- Build/verify: add an entitlements file for the SwiftUI app target and run `codesign --display --entitlements :- SublerPlus.app` to confirm. Exercise `swift test --filter WebServerSecurityTests` with sandbox on.

