# FluxShare document conversion endpoint

This container implements the JSON endpoint used by FluxShare for DOCX to PDF, PDF merge, page extraction, and content-stream compression. Deploy it to a container service (for example Cloud Run) and set the resulting HTTPS `/convert` URL as `LIBREOFFICE_URL` in Vercel and in the Windows release workflow. Set `ALLOWED_ORIGINS` to the exact FluxShare site origin(s), comma separated.

Requests and responses use base64 JSON. Individual input files and outputs are capped at 50 MB; JSON requests are capped at 75 MB, so PDF merge input must fit within that aggregate request cap. DOCX conversion has a 90-second timeout. The service has no API key because this Flutter client cannot safely hold a private secret. Restrict origins, service ingress, and request quotas at the hosting layer before exposing it publicly. For authenticated/private uploads, put an auth-aware API gateway in front of this service.

Build locally with `docker build -t fluxshare-converter services/document-converter` and run with `docker run -p 8080:8080 -e ALLOWED_ORIGINS=https://fluxshare-lac.vercel.app fluxshare-converter`. Health check: `/health`.

PDF compression rewrites the PDF and compresses page content streams. It cannot recompress embedded images and may not reduce every file's size.

