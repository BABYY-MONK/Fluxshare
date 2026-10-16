#!/usr/bin/env bash
set -euo pipefail

FLUTTER_VERSION="3.47.7"
FLUTTER_SDK_DIR="${FLUTTER_SDK_DIR:-/tmp/fluxshare-flutter-sdk}"
FLUTTER_ARCHIVE="${FLUTTER_ARCHIVE:-/tmp/fluxshare-flutter.tar.xz}"

if ! command -v flutter >/dev/null 2>&1; then
  if [[ ! -x "$FLUTTER_SDK_DIR/bin/flutter" ]]; then
    if [[ -e "$FLUTTER_SDK_DIR" ]]; then
      echo "Flutter SDK directory exists but is incomplete: $FLUTTER_SDK_DIR" >&2
      exit 1
    fi
    mkdir -p "$(dirname "$FLUTTER_SDK_DIR")"
    curl --fail --location --retry 3 \
      "https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz" \
      --output "$FLUTTER_ARCHIVE"
    mkdir -p "$FLUTTER_SDK_DIR"
    tar -xJf "$FLUTTER_ARCHIVE" -C "$FLUTTER_SDK_DIR" --strip-components=1
    rm -f "$FLUTTER_ARCHIVE"
  fi
  # Vercel runs builds as root while the extracted SDK may have another owner.
  # Mark only this downloaded SDK checkout as safe for Flutter's git checks.
  git config --global --add safe.directory "$FLUTTER_SDK_DIR"
  export PATH="$FLUTTER_SDK_DIR/bin:$PATH"
fi

export FLUTTER_TOOL_ARGS="${FLUTTER_TOOL_ARGS:---no-version-check}"
flutter config --no-analytics
flutter pub get --enforce-lockfile

BUILD_DEFINES=()
if [[ -n "${SUPABASE_URL:-}" && -n "${SUPABASE_PUBLISHABLE_KEY:-}" ]]; then
  BUILD_DEFINES+=("--dart-define=SUPABASE_URL=${SUPABASE_URL}")
  BUILD_DEFINES+=("--dart-define=SUPABASE_PUBLISHABLE_KEY=${SUPABASE_PUBLISHABLE_KEY}")
  if [[ -n "${FLUXSHARE_PUBLIC_URL:-}" ]]; then
    BUILD_DEFINES+=("--dart-define=FLUXSHARE_PUBLIC_URL=${FLUXSHARE_PUBLIC_URL}")
  fi
elif [[ -f .env.local.json ]]; then
  BUILD_DEFINES+=("--dart-define-from-file=.env.local.json")
fi

flutter build web --release "${BUILD_DEFINES[@]}"
