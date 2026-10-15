# ⚡ FluxShare

**Browser-based file conversion and sharing — built with Flutter Web.**

Convert images (JPG, PNG, WEBP, GIF, BMP, TIFF) to other image formats or PDF entirely client-side. Upload to Firebase Cloud Storage, generate mobile-friendly QR codes, paste directly from clipboard (Ctrl+V), and track freemium conversion quotas.

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
│   ├── main.dart                    # App entry point + Firebase initialization
│   ├── firebase_options.dart        # Firebase credentials config template
│   ├── theme/
│   │   └── app_theme.dart           # Design tokens, colors, ThemeData
│   ├── models/
│   │   └── file_item.dart           # FileItem, FileStatus, OutputFormat, cloud fields
│   ├── services/
│   │   ├── conversion_service.dart  # Image to image/PDF logic (client-side)
│   │   ├── drag_drop_service.dart   # Browser drag-drop & Ctrl+V clipboard paste bridge
│   │   └── firebase_service.dart    # Firebase Auth, Cloud Storage, Firestore & Quotas
│   ├── screens/
│   │   └── home_screen.dart         # Main workspace screen & state coordination
│   └── widgets/
│       ├── navbar.dart              # Top navigation bar with Auth & Quota badges
│       ├── drop_zone.dart           # Animated upload zone
│       ├── stats_bar.dart           # File queue stats + batch action buttons
│       ├── file_card.dart           # Per-file card with status, formats & cloud sync
│       ├── share_dialog.dart        # QR code & multi-platform share modal
│       └── upgrade_modal.dart       # Free vs Pro comparison & upgrade modal
└── web/
    └── index.html                   # Splash screen + SEO meta
```

---

## ✨ Features

### Phase 1: Core Client-Side Engine
- [x] Drag & drop file upload
- [x] File picker (multi-select)
- [x] Client-side image conversion (JPG, PNG, WEBP, GIF, BMP, TIFF)
- [x] Image to PDF generation
- [x] Per-file format selector
- [x] Instant browser download
- [x] Local session Blob URL copying
- [x] Batch "Convert All"
- [x] Dark, electric-blue theme with micro-animations

### Phase 2: Cloud Backend & Sharing
- [x] **Clipboard Paste (Ctrl+V)**: Paste screenshots directly from OS clipboard into the app
- [x] **Firebase Authentication**: Seamless anonymous guest login + Google Sign-In
- [x] **Firebase Cloud Storage**: Upload converted files with live progress tracking
- [x] **Firestore File Registry**: Store file metadata, user ownership, and 24h expiration timestamps
- [x] **QR Code Generation**: Instant mobile transfer via `qr_flutter` scan modal
- [x] **Freemium Quota Management**: 3 free daily conversions for guests, with quota counter in navbar
- [x] **Pro Upgrade Modal**: Feature tier comparison and Pro mode activation
- [x] **Batch Cloud Sync**: "Sync All to Cloud" button for queued files
- [x] **Web Share API**: Native system share sheet support on supported browsers
- [x] **Graceful Fallback Mode**: Works out of the box with simulated cloud persistence if Firebase credentials have not yet been configured

---

## 🔧 Firebase Setup (Optional)

FluxShare works out of the box with local simulations. To connect real Firebase Cloud Storage and Firestore:

1. Create a Firebase project at [Firebase Console](https://console.firebase.google.com).
2. Enable:
   - **Authentication** (Anonymous + Google provider)
   - **Cloud Firestore**
   - **Cloud Storage**
3. Add a Web App to your Firebase project.
4. Replace the placeholders in `lib/firebase_options.dart` with your Web config values, or run:
   ```bash
   flutterfire configure
   ```

---

## 📊 Plans & Quotas (PRD Scope)

| Feature | Free Tier | Pro Plan ($5/mo) |
|---|---|---|
| Daily Conversions | 3 per day | Unlimited |
| Max File Size | 50 MB | 2 GB |
| Link Expiration | 24 Hours | Permanent |
| Cloud Storage Sync | Included | Included |
| QR Code Mobile Share | Included | Included |
