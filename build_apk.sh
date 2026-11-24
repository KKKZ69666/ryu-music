#!/usr/bin/env bash
set -e

echo "=== [1/5] Mengunduh dependency Flutter (flutter pub get) ==="
flutter pub get

if [ ! -f "android/gradle/wrapper/gradle-wrapper.jar" ]; then
  echo "=== [2/5] Melengkapi Gradle Wrapper & local.properties ==="
  flutter create . --platforms=android
else
  echo "=== [2/5] Gradle Wrapper sudah tersedia ==="
fi

echo "=== [3/5] Analisis statis (flutter analyze) ==="
flutter analyze

echo "=== [4/5] Menjalankan unit test (flutter test) ==="
flutter test

echo "=== [5/5] Build Release APK (flutter build apk --release) ==="
flutter build apk --release

cp build/app/outputs/flutter-apk/app-release.apk ./RYU-release.apk
echo ""
echo "SUKSES! File APK siap instalasi tersimpan di: $(pwd)/RYU-release.apk"
