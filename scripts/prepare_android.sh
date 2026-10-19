#!/usr/bin/env bash
set -euo pipefail

if [[ ! -d android ]]; then
  flutter create --platforms=android --org com.fluxshare --project-name fluxshare .
fi

test -f android/app/build.gradle.kts -o -f android/app/build.gradle
