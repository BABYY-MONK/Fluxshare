#!/usr/bin/env bash
set -euo pipefail

if [[ ! -d android ]]; then
  flutter create --platforms=android --org com.fluxshare --project-name fluxshare .
  # `flutter create` also emits its sample MyApp widget test; FluxShare has its
  # own application widget and test suite, so discard the unrelated scaffold.
  rm -f test/widget_test.dart
fi

test -f android/app/build.gradle.kts -o -f android/app/build.gradle
