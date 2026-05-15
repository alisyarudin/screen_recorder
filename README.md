# Screen Recorder

Aplikasi rekam layar desktop untuk **macOS** dan **Windows**, dibangun dengan Flutter.

---

## Fitur

- **Rekam layar** — mulai/berhenti dengan satu klik
- **Timer rekaman** — tampil durasi real-time (MM:SS)
- **Daftar rekaman** — semua file `.mp4` tersaji otomatis, diurutkan terbaru
- **Hapus rekaman** — dengan konfirmasi dialog
- **Ganti nama** — rename file langsung dari daftar
- **Buka folder** — buka direktori output di Finder / Explorer
- **Putar video** — buka dengan aplikasi default sistem
- **Pengaturan** — folder output, kualitas video, selalu di atas (always on top)
- **Light / Dark mode** — mengikuti tema sistem

---

## Platform & Teknologi

| Platform | Capture | Encode | Format |
|----------|---------|--------|--------|
| macOS 12.3+ | ScreenCaptureKit | AVAssetWriter | H.264 MP4 |
| Windows | FFmpeg `gdigrab` | libx264 | H.264 MP4 |

---

## Prasyarat

### macOS
- macOS 12.3 (Monterey) atau lebih baru
- Xcode 14+
- Izin **Screen Recording** di System Settings → Privacy & Security → Screen & System Audio Recording

### Windows
- Windows 10/11
- [FFmpeg](https://ffmpeg.org/download.html) terinstall dan tersedia di PATH

  Cara install cepat via PowerShell (Administrator):
  ```powershell
  winget install ffmpeg
  # atau
  choco install ffmpeg
  ```

---

## Menjalankan Aplikasi

```bash
# macOS
flutter run -d macos

# Windows
flutter run -d windows
```

### Build Release

```bash
# macOS
flutter build macos

# Windows
flutter build windows
```

---

## Struktur Project

```
lib/
├── main.dart                          — Entry point, window setup, MultiBlocProvider
├── core/
│   ├── app_colors.dart                — Sistem warna light/dark
│   ├── di.dart                        — Dependency injection
│   ├── logger.dart                    — Logger (pretty printer)
│   ├── screen_recording_service.dart  — Service rekam (macOS native + Windows FFmpeg)
│   └── settings_service.dart          — Penyimpanan pengaturan (Hive)
├── data/models/
│   └── recording_entry.dart           — Model data file rekaman
└── presentation/
    ├── blocs/
    │   ├── recording/                 — RecordingBloc (start/stop/timer/error)
    │   ├── settings/                  — SettingsCubit
    │   └── file_list/                 — FileListCubit (load/delete/rename)
    └── screens/
        ├── home_screen.dart           — Layar utama (tombol REC + daftar)
        └── settings_screen.dart       — Pengaturan

macos/Runner/
├── ScreenRecorder.swift               — Implementasi ScreenCaptureKit + AVAssetWriter
├── MainFlutterWindow.swift            — MethodChannel handler Flutter ↔ Swift
├── Info.plist                         — NSScreenCaptureUsageDescription
├── DebugProfile.entitlements
└── Release.entitlements
```

---

## Kualitas Video

| Kualitas | Bitrate | FFmpeg Preset | Cocok untuk |
|----------|---------|---------------|-------------|
| Rendah | 1.5 Mbps | `ultrafast` / CRF 35 | Rekaman panjang, hemat ruang |
| Sedang *(default)* | 4 Mbps | `fast` / CRF 28 | Keseimbangan kualitas & ukuran |
| Tinggi | 8 Mbps | `medium` / CRF 23 | Kualitas terbaik |

---

## Pengaturan

| Pengaturan | Default | Keterangan |
|------------|---------|------------|
| Folder Output | `~/ScreenRecordings` | Lokasi penyimpanan file MP4 |
| Path FFmpeg | *(otomatis)* | Windows only; kosong = cari otomatis |
| Kualitas Video | Sedang | Rendah / Sedang / Tinggi |
| Selalu di Atas | Nonaktif | Jendela app tidak tertutup app lain |

---

## Dependensi Utama

```yaml
flutter_bloc: ^9.0.0    # State management
hive: ^2.2.3            # Penyimpanan lokal (settings)
path_provider: ^2.1.0   # Direktori app
file_picker: ^8.0.0     # Pilih folder output
window_manager: ^0.4.0  # Always on top, window control
url_launcher: ^6.3.1    # Buka file / folder
intl: ^0.20.2           # Format tanggal/waktu
logger: ^2.5.0          # Logging
```

---

## Lisensi

Hak cipta © 2026 Jasnita. Semua hak dilindungi.
