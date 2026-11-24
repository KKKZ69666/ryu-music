@echo off
setlocal

echo === [1/5] Mengunduh dependency Flutter (flutter pub get) ===
call flutter pub get
if %errorlevel% neq 0 exit /b %errorlevel%

if not exist "android\gradle\wrapper\gradle-wrapper.jar" (
  echo === [2/5] Melengkapi Gradle Wrapper ^& local.properties ===
  call flutter create . --platforms=android
  if %errorlevel% neq 0 exit /b %errorlevel%
) else (
  echo === [2/5] Gradle Wrapper sudah tersedia ===
)

echo === [3/5] Analisis statis (flutter analyze) ===
call flutter analyze
if %errorlevel% neq 0 exit /b %errorlevel%

echo === [4/5] Menjalankan unit test (flutter test) ===
call flutter test
if %errorlevel% neq 0 exit /b %errorlevel%

echo === [5/5] Build Release APK (flutter build apk --release) ===
call flutter build apk --release
if %errorlevel% neq 0 exit /b %errorlevel%

copy /Y "build\app\outputs\flutter-apk\app-release.apk" "RYU-release.apk" >nul
echo.
echo SUKSES! File APK siap instalasi tersimpan di: %cd%\RYU-release.apk
endlocal
