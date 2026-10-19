# FluxShare

FluxShare converts many supported files locally in the browser or desktop app. DOCX-to-PDF, PDF operations, OCR, and audio/video conversion send the selected file to the configured conversion service. Choosing **Share** uploads the converted result to private Supabase Storage and creates a 24-hour link.

## Run locally

Requirements: Flutter 3.47.7 and Chrome/Edge for web. Windows desktop builds require Visual Studio 2022 with the Desktop development with C++ workload.

```powershell
flutter pub get
flutter run -d chrome --dart-define-from-file=.env.local.json
```

`.env.local.json` is local-only and ignored by Git. Copy `.env.example.json` when setting up another checkout. The values are the Supabase project URL and publishable key; never put a Supabase service-role key in a client app.

## Build the web app

```bash
bash scripts/build_web.sh
```

Vercel runs the same pinned Flutter 3.47.7 build script. Configure `SUPABASE_URL`, `SUPABASE_PUBLISHABLE_KEY`, and `FLUXSHARE_PUBLIC_URL` in Vercel for Production, Preview, and Development. Set `LIBREOFFICE_URL` to the HTTPS `/convert` URL after deploying the container in [`services/document-converter/README.md`](services/document-converter/README.md). These are build-time public client settings; RLS and bucket policies protect writes and files. The service-role key is not used.

The generated web app is an installable PWA (manifest, service worker, and standalone display mode). Install it from a supported browser after deployment over HTTPS. On Android, the PWA is the quickest install while the APK workflow below provides a native Flutter package.

## Windows download manager

The Windows installer includes a separate **Download manager** mode in the FluxShare app bar. It accepts direct HTTPS file URLs, streams data to disk, uses up to four validated byte ranges for large files when the server provides a stable validator, and keeps task metadata and partial shards under `%LOCALAPPDATA%\FluxShare\downloads` for pause/resume after a restart. At most two tasks run at once. Completed files are merged into the selected destination without overwriting an existing file.

The download manager does not use Supabase or the Vercel converter: URLs, task state, shards, and downloaded files stay on the Windows device. It blocks embedded URL credentials and local/private network destinations, validates redirects and byte-range responses, and keeps TLS certificate checks enabled. Download URLs are present in the local task journal to support recovery, so use this feature only from a Windows account whose profile you trust. Closing the Windows window leaves the app in the system tray so transfers continue; choose **Exit FluxShare** from the tray menu to stop it. The first version supports direct HTTPS links only; FTP, browser capture, cookies/auth headers, dynamic range splitting, proxy/PAC configuration, speed limits, and retry scheduling are not included. The web/PWA downloader remains browser-based and does not show the Windows manager.

## Download the Windows app

Run the **Windows release** GitHub Actions workflow manually, or push a `v*` tag. It runs tests, builds the Windows x64 release, compiles an Inno Setup installer, and publishes `FluxShare-Setup-x64.exe` as a workflow artifact. A tagged run also attaches the installer to the GitHub release. Set the repository Actions variables `SUPABASE_URL`, `SUPABASE_PUBLISHABLE_KEY`, `FLUXSHARE_PUBLIC_URL`, and `LIBREOFFICE_URL` to enable cloud sharing and server-backed document/PDF tools in the installer. Without the converter URL, local conversions still work and server-backed tools explain that the endpoint is not configured.

## Android APK

Run the **Android APK** GitHub Actions workflow manually, or push a `v*` tag. It generates Flutter Android platform files when they are missing, runs analysis and tests, and publishes an installable APK artifact. A tagged run attaches the APK to the GitHub release. Set the same public Actions variables as the Windows workflow. This first APK uses Flutter's generated debug signing configuration for sideload testing; it is not a Play Store release. Configure a private Android signing key before distributing a production APK or AAB.

## Supported conversions

- Images: JPG, PNG, WebP, GIF (first frame), BMP, and TIFF to JPG, PNG, WebP, or PDF.
- Documents: DOCX, TXT, Markdown, HTML, and HTM to PDF, TXT, or HTML. DOCX-to-PDF needs a separately hosted `LIBREOFFICE_URL`; without it, the app returns an explicit error rather than silently dropping layout. DOCX-to-TXT extracts paragraph text locally.
- PDF/file tools: merge PDFs, compress page content streams, rotate pages by 90 degrees, OCR up to 20 pages to English text, extract selected pages to a ZIP, and create ZIP archives locally. PDF operations use the conversion service. OCR and server-side PDF tools upload file contents to that service and do not support encrypted PDFs. Image inputs can also be converted to PDF in the browser.
- Direct video downloads: HTTPS MP4, WebM, MOV, M4V, or OGV URLs up to 200 MB, when the source host permits browser cross-origin access. This does not extract videos from social platforms.
- Audio/video conversion: common audio/video inputs to MP4, WebM, MP3, WAV, or GIF through the hosted FFmpeg service. Files up to 50 MB are uploaded to the converter for processing.
- Local conversion output downloads directly to the device. Cloud sharing is limited to 50 MB per file and three conversions per anonymous user per UTC day.

## Supabase setup

The migrations under `supabase/migrations/` create `share_links`, `daily_usage`, and a private `shared-files` bucket with RLS. They have been applied to the `fluxshare` project in the MONK organization. Enable **Anonymous Sign-Ins** under Authentication → Providers before enabling sharing. The converter applies a per-process request limit; configure platform or host-level rate limits too because process-local limits do not coordinate across instances. To enable hourly cleanup, deploy `cleanup-expired-shares`, set a strong `FLUXSHARE_CLEANUP_SECRET` in Supabase Function Secrets, and add GitHub Actions secrets `FLUXSHARE_CLEANUP_URL` (the function URL ending in `/functions/v1/cleanup-expired-shares`) and `FLUXSHARE_CLEANUP_SECRET`. Before public launch, add CAPTCHA or another abuse-control gate to anonymous share creation: the current client-side Supabase policies allow new guest accounts, so the daily quota is per guest account and can be evaded by creating more accounts.
