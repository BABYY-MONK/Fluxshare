# FluxShare

FluxShare converts supported files locally in the browser or Windows desktop app. Files stay on the device unless the user chooses **Share**, which uploads the converted file to a private Supabase Storage bucket and creates a 24-hour link.

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

Vercel runs the same pinned Flutter 3.47.7 build script. Configure `SUPABASE_URL`, `SUPABASE_PUBLISHABLE_KEY`, and `FLUXSHARE_PUBLIC_URL` in Vercel for Production, Preview, and Development. They are build-time public client settings; RLS and bucket policies protect writes and files. The service-role key is not used.

The generated web app is an installable PWA (manifest, service worker, and standalone display mode). Install it from a supported browser after deployment over HTTPS.

## Download the Windows app

Run the **Windows release** GitHub Actions workflow manually, or push a `v*` tag. It runs tests, builds the Windows x64 release, compiles an Inno Setup installer, and publishes `FluxShare-Setup-x64.exe` as a workflow artifact. A tagged run also attaches the installer to the GitHub release. Set the repository Actions variables `SUPABASE_URL`, `SUPABASE_PUBLISHABLE_KEY`, and `FLUXSHARE_PUBLIC_URL` to enable cloud sharing in the installer. Without them, local conversion still works.

## Supported conversions

- Images: JPG, PNG, WebP, GIF (first frame), BMP, and TIFF to JPG, PNG, WebP, or PDF.
- Documents: DOCX, TXT, Markdown, HTML, and HTM to PDF, TXT, or HTML. DOCX-to-PDF needs a separately hosted `LIBREOFFICE_URL`; without it, the app returns an explicit error rather than silently dropping layout. DOCX-to-TXT extracts paragraph text locally.
- Audio/video conversion is not offered because an ffmpeg.wasm runtime is not bundled.
- Local conversion output downloads directly to the device. Cloud sharing is limited to 50 MB per file and three conversions per anonymous user per UTC day.

## Supabase setup

The migrations under `supabase/migrations/` create `share_links`, `daily_usage`, and a private `shared-files` bucket with RLS. They have been applied to the `fluxshare` project in the MONK organization. Enable **Anonymous Sign-Ins** under Authentication → Providers before enabling sharing. Add CAPTCHA/rate limiting before public launch. Expired links stop granting access; automatic physical deletion of expired storage objects is not configured.
