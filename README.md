# RYU — Your Personal Music Experience

Pemutar musik lokal Android berdesain futuristik (*premium dark interface* dengan aksen *violet*, *indigo*, *blue*, dan efek *Liquid Glass*) yang dibangun menggunakan **Flutter**, **Dart**, dan integrasi native Android **`MediaStore`** + **`just_audio_background`**.

---

## Fitur Utama

- **Home**: Sapaan dinamis sesuai waktu, *Quick Playlists* (*Favorites*, *Shuffle All*, *Most Played*, *Recently Added*, dan playlist kustom), *Recently Played*, *Featured Albums*, serta *Recommendations* berbasis koleksi musik lokal nyata.
- **Music Player & Background Audio**:
  - Pemindaian audio lokal Android (`MediaStore`) lengkap dengan metadata & ekstraksi album cover resolusi tinggi.
  - Kontrol pemutaran lengkap (*Play*, *Pause*, *Next*, *Previous*, *Seek Bar*, *Shuffle*, *Repeat Off/All/One*).
  - *Queue* interaktif (ubah urutan antrean dengan *drag & drop*, hapus antrean, lompat ke lagu tertentu).
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

## Prasyarat Toolchain Build

Pastikan komputer Anda memiliki:
1. **Flutter SDK** (`>= 3.27.0`, Dart `>= 3.4.0 < 4.0.0`) — pastikan `flutter` terdaftar di `PATH`.
2. **Android SDK** (`compileSdk 35`, `minSdk 23`, Android SDK Build-Tools & Platform-Tools) — variabel `ANDROID_HOME` terkonfigurasi.
3. **Java Development Kit (JDK 17)**.
4. **Koneksi internet** saat build pertama untuk mengunduh package `pub.dev` dan distribusi Gradle `8.7`.

Verifikasi kesiapan environment dengan perintah:
```bash
flutter doctor
```

---

## Cara Build APK Paling Sederhana

### Opsi A — Menggunakan Skrip Otomatis (1 Perintah)

1. Ekstrak `RYU-complete-source.zip` dan masuk ke direktori `ryu`:
   ```bash
   unzip RYU-complete-source.zip
   cd ryu
   ```
2. Jalankan skrip build sesuai sistem operasi:
   - **Linux / macOS**:
     ```bash
     chmod +x build_apk.sh
     ./build_apk.sh
     ```
   - **Windows (CMD / PowerShell)**:
     ```cmd
     build_apk.bat
     ```
   Skrip otomatis menjalankan `flutter pub get`, melengkapi `gradle-wrapper.jar` & `local.properties` jika belum ada, menjalankan `flutter analyze` dan `flutter test`, mem-build APK release, lalu menyalin hasilnya menjadi `RYU-release.apk` di folder proyek.

### Opsi B — Langkah Manual via CLI

```bash
unzip RYU-complete-source.zip
cd ryu

# 1. Unduh dependency Dart & Flutter
flutter pub get

# 2. Lengkapi binary gradle-wrapper.jar & local.properties (jika belum ada)
flutter create . --platforms=android

# 3. Verifikasi analisis statis & unit test
flutter analyze
flutter test

# 4. Build Release APK
flutter build apk --release
```

### Lokasi Output APK & Instalasi ke Perangkat/Emulator

- **Lokasi APK Universal**:
  `build/app/outputs/flutter-apk/app-release.apk` (atau `./RYU-release.apk` jika memakai skrip otomatis).
- **Build APK per Arsitektur (ukuran lebih ringan untuk HP modern `arm64-v8a`)**:
  ```bash
  flutter build apk --split-per-abi --release
  ```
  Output: `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`
- **Instalasi ke Perangkat Android / Emulator via ADB**:
  ```bash
  adb install -r build/app/outputs/flutter-apk/app-release.apk
  ```

---

## Struktur Proyek

```text
ryu/
├── android/                  # Konfigurasi Gradle 8.7 (AGP 8.5.2, Kotlin 1.9.24), Manifest, & MainActivity.kt
├── lib/
│   ├── core/
│   │   ├── controllers/      # AudioController & LibraryController
│   │   ├── models/           # Song, Album, Artist, RyuPlaylist, LyricLine, HistoryEntry
│   │   ├── services/         # LocalMusicScanner, ArtworkService, LyricsService, PaletteService, StorageService
│   │   ├── theme/            # RyuColors & RyuTheme
│   │   └── utils/            # DurationFormatter & LrcParser
│   ├── features/
│   │   ├── home/             # HomeScreen
│   │   ├── library/          # LibraryScreen, AlbumDetail, ArtistDetail, PlaylistDetail, HistoryScreen
│   │   ├── player/           # NowPlayingScreen, LyricsView, QueueSheet
│   │   ├── search/           # SearchScreen
│   │   └── shell/            # AppShell
│   ├── shared/widgets/       # GlassContainer, MiniPlayer, SongTile, ArtworkImage, SongOptionsSheet, dll.
│   └── main.dart
├── test/                     # Unit tests (DurationFormatter & LrcParser)
├── build_apk.sh              # Skrip build otomatis (Linux/macOS)
├── build_apk.bat             # Skrip build otomatis (Windows)
├── pubspec.yaml
└── README.md
```

## Audius online search (initial integration)

This source snapshot includes an initial read-only Audius integration:
- `lib/core/services/audius_service.dart` searches public Audius tracks.
- Search screen submits the query to Audius and shows online tracks.
- Selecting an online result sends its Audius stream endpoint to the existing `just_audio` player.

The integration has not yet been built or device-tested in this environment. Audius API access and stream availability can be subject to provider limits and may require an API key for reliable production use. Do not embed an API secret in the mobile app.
