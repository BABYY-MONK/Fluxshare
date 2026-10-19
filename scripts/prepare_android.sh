#!/usr/bin/env bash
set -euo pipefail

if [[ ! -d android ]]; then
  flutter create --platforms=android --org com.fluxshare --project-name fluxshare .
  # `flutter create` also emits its sample MyApp widget test; FluxShare has its
  # own application widget and test suite, so discard the unrelated scaffold.
  rm -f test/widget_test.dart
fi

test -f android/app/build.gradle.kts -o -f android/app/build.gradle

# Current Flutter plugins (including flutter_plugin_android_lifecycle) require
# API 36 at compile time. Keep target/min SDK behavior controlled by Flutter;
# this only raises the compile SDK used by Gradle.
if [[ -f android/app/build.gradle.kts ]]; then
  sed -i -E 's/^[[:space:]]*compileSdk[[:space:]]*=.*/    compileSdk = 36/' android/app/build.gradle.kts
else
  sed -i -E 's/^[[:space:]]*compileSdkVersion[[:space:]].*/    compileSdkVersion 36/' android/app/build.gradle
fi

