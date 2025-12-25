# API & WebUI

- Endpoints: `/api/status`, `/api/search`, `/api/enrich`, `/api/files` (POST JSON).
- Auth: optional `X-Auth-Token` when `WEBUI_TOKEN` is set.
- CORS: http://127.0.0.1:8080 only; content-type `application/json`; body capped.
- Web UI served at `/`; assets under `/assets/`.
- File validation: only MP4/M4V/MOV accepted for enrich/files.

