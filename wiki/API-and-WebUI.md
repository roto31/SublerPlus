# API & WebUI

- Endpoints: 
  - `/health`: Health check (no auth required)
  - `/api/status`: Get recent status events
  - `/api/search`: Search for metadata
  - `/api/enrich`: Enrich a single file
  - `/api/files`: Batch enrich multiple files
  - `/api/session`: Session management
- Auth: optional `X-Auth-Token` when `WEBUI_TOKEN` is set.
- CORS: http://127.0.0.1:8080 only; content-type `application/json`; body capped at 512KB.
- Rate limiting: Token bucket algorithm (5 requests/second default).
- Web UI served at `/`; assets under `/assets/`.
- File validation: only MP4/M4V/MOV accepted for enrich/files.
- Security: localhost-only binding (127.0.0.1, ::1), IP allowlist enforcement.

