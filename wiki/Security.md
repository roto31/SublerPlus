# Security

- WebUI: localhost-only (127.0.0.1), optional `WEBUI_TOKEN`/`X-Auth-Token`.
- CORS locked; JSON content-type + body-size checks; rate limiting.
- Providers over HTTPS with retry/backoff and circuit breakers.
- Keys stored in Keychain (or env) for TPDB/TMDB/TVDB/OpenSubtitles; secrets scrubbed from logs; `LOG_LEVEL=minimal` to reduce PII.
- Atom writes: temp + replace; pure Swift (no native shims).
- Tests: `make security` (warnings-as-errors + `swift test --filter Security`).
- Sandboxing (optional for release): restrict network to TPDB/TMDB/TVDB/RapidAPI; file access only via user selection; watch folder monitoring via security-scoped bookmarks.

