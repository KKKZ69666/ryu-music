#!/usr/bin/env bash
set -e

echo "=== [1/5] Mengunduh dependency Flutter (flutter pub get) ==="
flutter pub get

mkdir -p android/gradle/wrapper
if [ ! -f "android/gradle/wrapper/gradle-wrapper.jar" ]; then
  echo "=== [2/5] Melengkapi Gradle Wrapper JAR secara aman ==="
  TMP_GW=$(mktemp -d)
  if command -v gradle >/dev/null 2>&1; then
    (cd "$TMP_GW" && gradle wrapper --gradle-version 9.3.1 --distribution-type all)
    cp "$TMP_GW/gradle/wrapper/gradle-wrapper.jar" android/gradle/wrapper/gradle-wrapper.jar
  else
    flutter create "$TMP_GW/app" --platforms=android >/dev/null
    cp "$TMP_GW/app/android/gradle/wrapper/gradle-wrapper.jar" android/gradle/wrapper/gradle-wrapper.jar
  fi
  rm -rf "$TMP_GW"
else
  echo "=== [2/5] Gradle Wrapper sudah tersedia ==="
fi
chmod +x android/gradlew

echo "=== [3/5] Analisis statis (flutter analyze) ==="
flutter analyze

echo "=== [4/5] Menjalankan unit test (flutter test) ==="
flutter test

echo "=== [5/5] Build Release APK (flutter build apk --release) ==="
flutter build apk --release

cp build/app/outputs/flutter-apk/app-release.apk ./RYU-release.apk
echo ""
echo "SUKSES! File APK siap instalasi tersimpan di: $(pwd)/RYU-release.apk"
