# ⚡ FluxShare

**Browser-based file conversion and sharing — built with Flutter Web.**

Convert images (JPG, PNG, WEBP, GIF, BMP, TIFF) to other image formats or PDF, entirely client-side. No server uploads, no sign-in required.

---

## 🚀 Quick Start

### Prerequisites
- Flutter SDK >= 3.0 (https://docs.flutter.dev/get-started/install)
- Chrome or Edge browser

### Run locally

```bash
cd fluxshare
flutter pub get
flutter run -d chrome
```

For a release build:
```bash
flutter build web --release
```

---

## 📁 Project Structure

```
fluxshare/
├── lib/
│   ├── main.dart                    # App entry point
│   ├── theme/
│   │   └── app_theme.dart           # Design tokens, colors, ThemeData
│   ├── models/
│   │   └── file_item.dart           # FileItem, FileStatus, OutputFormat
│   ├── services/
│   │   ├── conversion_service.dart  # Image to image/PDF logic (client-side)
│   │   └── drag_drop_service.dart   # Browser drag-drop bridge
│   ├── screens/
│   │   └── home_screen.dart         # Main workspace screen
│   └── widgets/
│       ├── navbar.dart              # Top navigation bar
│       ├── drop_zone.dart           # Animated upload zone
│       ├── stats_bar.dart           # File queue stats + actions
│       └── file_card.dart           # Per-file card with status + actions
└── web/
    └── index.html                   # Splash screen + SEO meta
```

---

## Features (MVP)

| Feature | Status |
|---|---|
| Drag and drop file upload | Done |
| File picker (multi-select) | Done |
| Image to JPG / PNG / WEBP / GIF | Done |
| Image to PDF | Done |
| Per-file format selector | Done |
| Instant download | Done |
| Copy blob URL for sharing | Done |
| Convert All (batch) | Done |
| Responsive (desktop / mobile) | Done |
| Premium dark UI with animations | Done |

---

## Roadmap

- Firebase Storage for cross-device sharing and persistent links
- ffmpeg.wasm for audio/video conversion (MP4 to MP3, video to GIF)
- PDF to image using pdf_render
- QR code generation for share links
- Firebase Auth + freemium quotas
- Clipboard paste (Ctrl+V)

---

## Tech Stack

- Flutter Web (CanvasKit renderer)
- image package - client-side image decoding/encoding
- pdf package - image-to-PDF generation
- file_picker - native file picker
- flutter_animate - micro-animations
- google_fonts - Inter typeface
- dotted_border - animated drop zone border
- uuid - unique file IDs

---

## Limitations (MVP)

- Sharing links are blob URLs - valid only while the current browser tab is open.
  For true cross-device sharing you need Firebase Storage.
- File size: Large files (>50 MB) may be slow due to WASM memory limits.
- Formats: Complex formats (PSD, AI, HEIC, DOCX, MP4) require a backend
  microservice and are out of scope for the MVP.
