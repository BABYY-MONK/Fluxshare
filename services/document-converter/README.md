# FluxShare document conversion endpoint

This container implements the JSON endpoint used by FluxShare for DOCX to PDF, PDF merge, page extraction, and content-stream compression. Deploy it as a Vercel container project with the project root set to `services/document-converter`. Vercel detects `Dockerfile.vercel`, builds the OCI image, and serves its HTTP server as a Vercel Function. Set the resulting HTTPS `/convert` URL as `LIBREOFFICE_URL` in the FluxShare frontend's Vercel project and in the Windows release workflow.

Set `ALLOWED_ORIGINS` to the exact FluxShare site origins, comma separated. Requests and responses use base64 JSON. Individual input files and outputs are capped at 50 MB; JSON requests are capped at 75 MB, so PDF merge input must fit within that aggregate request cap. DOCX conversion has a 90-second timeout. The service has no API key because this Flutter client cannot safely hold a private secret. Restrict origins and request quotas at the hosting layer before exposing it publicly. For authenticated/private uploads, put an auth-aware API gateway in front of this service.

For local development, build with `docker build -t fluxshare-converter services/document-converter` and run with `docker run -p 8080:8080 -e ALLOWED_ORIGINS=http://localhost:3000 fluxshare-converter`. Health check: `/health`.

PDF compression rewrites the PDF and compresses page content streams. It cannot recompress embedded images and may not reduce every file's size.
