# RYU — Your Personal Music Experience

Pemutar musik lokal Android berdesain futuristik (*premium dark interface* dengan aksen *violet*, *indigo*, *blue*, dan efek *Liquid Glass*) yang dibangun menggunakan **Flutter**, **Dart**, dan integrasi native Android **`MediaStore`** + **`just_audio_background`**.

---

## Fitur Utama

- **Home**: Sapaan dinamis sesuai waktu, *Quick Playlists* (*Favorites*, *Shuffle All*, *Most Played*, *Recently Added*, dan playlist kustom), *Recently Played*, *Featured Albums*, serta *Recommendations* berbasis koleksi musik lokal nyata.
- **Music Player & Background Audio**:
  - Pemindaian audio lokal Android (`MediaStore`) lengkap dengan metadata & ekstraksi album cover resolusi tinggi.
  - Kontrol pemutaran lengkap (*Play*, *Pause*, *Next*, *Previous*, *Seek Bar*, *Shuffle*, *Repeat Off/All/One*).
  - *Queue* interaktif (ubah urutan antrean dengan *drag & drop*, geser untuk hapus, lompat ke lagu tertentu).
  - Pemutaran latar belakang (*background playback*) dengan *audio focus* (`audio_session`) serta kontrol media di *notification shade* & *lock screen* Android lengkap dengan *album art*.
- **Library & Search**:
  - Tab *Songs* (dengan opsi pengurutan), *Albums*, *Artists*, dan *Playlists*.
  - *Favorites* dan *Listening History* tersimpan persisten secara lokal (`shared_preferences`).
  - Manajemen playlist kustom lengkap (buat, ubah nama/deskripsi, tambah banyak lagu sekaligus, hapus lagu).
  - Pencarian instan lintas *Songs*, *Albums*, *Artists*, dan *Playlists* dengan riwayat pencarian (*Recent Searches*).
- **Now Playing & Apple Music-Inspired Synced Lyrics**:
  - *Dynamic ambient background* yang mengekstrak palet warna dominan dari *album artwork* lagu yang sedang diputar.
  - Tampilan lirik berukuran besar dengan *highlight* baris aktif, *auto-scroll* tersinkronisasi, tombol *Sync* saat pengguna menggulir manual, dan *tap baris lirik* untuk melompat ke timestamp tersebut.
  - Mendukung file `.lrc`/`.txt` pendamping di folder yang sama, tag lirik ID3v2 `USLT` tertanam pada file MP3, impor file `.lrc`/`.txt` dari penyimpanan perangkat, input/tempel lirik manual, serta pencarian opsional ke database terbuka [LRCLIB](https://lrclib.net/).

---

## Ringkasan Perbaikan Lengkap

1. **Gradle Wrapper & Build System (`android/gradlew`, `android/settings.gradle.kts`, `.github/workflows/build.yml`)**:
   - Memperbaiki skrip POSIX `android/gradlew` menggunakan standar resmi Gradle 9.3.1 (`eval set --` + `exec "$JAVACMD" "$@"`) dengan *line ending* Unix `LF` dan izin eksekusi `0755`, disertai *auto-bootstrap* non-destruktif untuk `gradle-wrapper.jar`.
   - Memperbarui `android/settings.gradle.kts` agar memvalidasi keberadaan path Flutter SDK (`local.properties`, `FLUTTER_ROOT`, `FLUTTER_HOME`, maupun `PATH`) sehingga aman di GitHub Actions (`ubuntu-latest`) maupun lokal Windows/macOS/Linux.
   - Menyediakan workflow final `.github/workflows/build.yml` (Java 17 Temurin, Flutter `3.50.1`, `flutter pub get`, bootstrap aman `gradle-wrapper.jar`, `flutter analyze`, `flutter test`, `flutter build apk --release`, serta upload artefak `RYU-release-apk`).
2. **Stabilitas & Manajemen Antrean `AudioController` (`lib/core/controllers/audio_controller.dart`)**:
   - Memperbaiki *race condition* `currentIndexStream` saat pemuatan playlist baru (`_isSettingSource` guard) agar `_onSongChanged` dieksekusi secara deterministik satu kali.
   - Memperbaiki penanganan selesai antrean (`ProcessingState.completed` pada mode `Repeat Off`), navigasi `seekToNext()` / `seekToPrevious()` dengan dukungan *wrap-around* pada `Repeat All`, serta `seek()` sebelum durasi metadata terbaca.
   - Memperbaiki sinkronisasi `_originalQueue` saat *shuffle*, `playNextInQueue`, `addToQueue`, `moveQueueItem`, dan menghapus lagu yang sedang diputar pada `removeFromQueue`.
   - Menambahkan *pre-caching* artwork untuk lagu berikutnya dan proteksi `_disposed` terhadap pembaruan state asinkron.
3. **Responsivitas `NowPlayingScreen` (`lib/features/player/now_playing_screen.dart`)**:
   - Menggunakan `LayoutBuilder` yang menghitung ukuran *album artwork*, jarak vertikal, ukuran tombol transport, dan skala teks berdasarkan lebar sekaligus tinggi viewport aktual sehingga bebas *overflow* di layar kompak (`360x640`), *split-screen*, *accessibility font scale*, maupun orientasi *landscape*.
4. **Integrasi Native Android `MainActivity.kt` (`android/app/src/main/kotlin/com/ryu/music/MainActivity.kt`)**:
   - Menggunakan `ExecutorService` terkelola untuk pemindaian `MediaStore`, ekstraksi thumbnail dengan `bitmap.recycle()` di blok `finally`, pembacaan tag ID3v2 `USLT` (UTF-16/UTF-8/ISO-8859-1) yang akurat sesuai spesifikasi, serta penanganan aman `pickLrcFile` dengan deteksi BOM UTF-8/UTF-16.

---

## Cara Build APK via GitHub Actions

1. Ekstrak file ZIP ini dan unggah seluruh isi folder `ryu/` (termasuk `.github/workflows/build.yml` dan `.gitignore`) ke repositori GitHub Anda.
2. Buka tab **Actions** pada repositori GitHub Anda:
   - Workflow **Build Android APK** berjalan otomatis saat `push` ke branch `main`/`master` atau dapat dijalankan manual via **Run workflow** (`workflow_dispatch`).
3. Unduh hasil kompilasi pada bagian **Artifacts -> `RYU-release-apk`** (`RYU-release.apk`).

---

## Cara Build APK Secara Lokal

```bash
# 1. Unduh dependency Flutter
flutter pub get

# 2. Lengkapi gradle-wrapper.jar secara aman (tanpa menimpa file proyek) & set izin eksekusi
mkdir -p android/gradle/wrapper
TMP_GW=$(mktemp -d)
flutter create "$TMP_GW/app" --platforms=android >/dev/null
cp "$TMP_GW/app/android/gradle/wrapper/gradle-wrapper.jar" android/gradle/wrapper/gradle-wrapper.jar
rm -rf "$TMP_GW"
chmod +x android/gradlew

# 3. Jalankan analisis statis & unit/widget test
flutter analyze
flutter test

# 4. Build Release APK
flutter build apk --release
```

File APK siap instal tersedia di `build/app/outputs/flutter-apk/app-release.apk`.
