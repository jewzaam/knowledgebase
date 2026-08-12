# Python Web Frameworks: Runtime Behaviors

Quirks and gotchas for Python web frameworks in dev and production environments.

## FastAPI/uvicorn HTTPS with Self-Signed Certificates

When a FastAPI backend runs `make dev` with uvicorn TLS options (`--ssl-certfile`, `--ssl-keyfile`), the dev server runs HTTPS with self-signed certificates.

**Cross-origin implications**: Browser clients must manually accept the self-signed certificate before API calls from a frontend running on HTTP will work. The browser blocks mixed content (HTTPS→HTTP is allowed, HTTP→HTTPS with untrusted cert is not) and shows ERR_CERT_AUTHORITY_INVALID until the user navigates to the HTTPS endpoint directly and accepts the security warning.

**curl clients**: need the `-k` / `--insecure` flag to skip certificate validation.

**Provenance**: observed in a local Nexus development environment (FastAPI backend on `https://localhost:8000`, React frontend on `http://localhost:5173`).

This is dev-environment behavior only. Production deployments use proper certificates via ingress/route TLS termination at the platform layer (Kubernetes Ingress, OpenShift Route), not uvicorn's `--ssl-*` flags.
