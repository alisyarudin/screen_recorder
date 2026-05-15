# Screen Recorder — Ringkasan Aplikasi

> Aplikasi desktop macOS/Windows untuk merekam layar sekaligus memantau aktivitas agent call center.  
> Bahasa UI: Bahasa Indonesia. Tech stack: Flutter + BLoC + Hive + ScreenCaptureKit (macOS) / FFmpeg (Windows).

---

## Struktur Navigasi

```
App
├── Home Screen          (layar utama — rekam & daftar file)
│   ├── → Dashboard Screen
│   └── → Settings Screen
├── Dashboard Screen     (monitoring agent — 2 tab)
└── Settings Screen      (semua pengaturan)
```

---

## 1. Home Screen

**Fungsi:** Kontrol rekaman layar dan manajemen file hasil rekaman.

### Layout
```
┌─────────────────────────────────────────────────────┐
│  🎥 Screen Recorder          [↺]  [📊]  [⚙]        │  ← Title Bar
├─────────────────────────────────────────────────────┤
│  [●]  Siap merekam layar                            │  ← Recording Bar
│       [  Mulai Rekam  ]                             │
├─────────────────────────────────────────────────────┤
│  3 rekaman                                          │
│  ┌───────────────────────────────────────────────┐  │
│  │ 🎬  rekaman_20250515.mp4      [✏][📁][▶][🗑] │  │  ← File List
│  │     Hari ini 09:30  •  245 MB                 │  │
│  └───────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────┘
```

### Status Rekaman
| State | Tampilan |
|---|---|
| Idle | Tombol merah "Mulai Rekam" |
| Starting | Spinner + teks "Memulai rekaman…" |
| Active | Animasi pulse + timer `Merekam — 00:12:34` + path file + tombol "Berhenti" |

### Aksi per File
- **✏ Rename** — dialog ganti nama (auto-append `.mp4`)
- **📁 Buka Folder** — buka lokasi file di Finder/Explorer
- **▶ Putar** — buka dengan media player default
- **🗑 Hapus** — konfirmasi dialog sebelum hapus

---

## 2. Dashboard Screen

**Fungsi:** Memantau aktivitas agent secara real-time (app yang digunakan, idle, screenshot periodik).

### Layout
```
┌─────────────────────────────────────────────────────┐
│  Dashboard Monitoring        [▶ Mulai Monitor]      │  ← AppBar
├──────────────────┬──────────────────────────────────┤
│  Penggunaan App  │  Screenshot                      │  ← TabBar
├──────────────────┴──────────────────────────────────┤
│                                                     │
│  ● AKTIF   💻 Google Chrome                  🔴REC │  ← Status Panel
│                                                     │
│  ┌────────┐ ┌────────┐ ┌────────┐ ┌────────┐       │
│  │  Sesi  │ │ Aktif  │ │  Idle  │ │  📷   │       │  ← Stat Cards
│  │ 01:23  │ │ 01:10  │ │  0:13  │ │   5   │       │
│  └────────┘ └────────┘ └────────┘ └────────┘       │
│                                                     │
│  Screenshot tiap: [Off] [30d] [1m] [2m] [5m]       │  ← Interval Chips
├─────────────────────────────────────────────────────┤
│  TAB CONTENT (lihat bawah)                          │
└─────────────────────────────────────────────────────┘
```

### Status Badge
| Badge | Warna | Kondisi |
|---|---|---|
| OFFLINE | Abu-abu | Monitoring tidak aktif |
| IDLE | Kuning | Agent tidak bergerak |
| AKTIF | Hijau | Agent sedang bekerja |

### Tab 1 — Penggunaan App
```
┌─────────────────────────────────────────────────────┐
│  3 aplikasi digunakan                               │
│                                                     │
│  Google Chrome          00:45:12  ████████████░░░  │
│  Microsoft Teams        00:22:05  ██████░░░░░░░░░  │
│  Notepad                00:05:48  █░░░░░░░░░░░░░░  │
│                                                     │
│  LOG AKTIVITAS                                      │
│  • Google Chrome   09:30:00 – sekarang              │
│  • Microsoft Teams 09:15:00 – 09:30:00              │
│  • Google Chrome   09:00:00 – 09:15:00              │
└─────────────────────────────────────────────────────┘
```

### Tab 2 — Screenshot
```
┌─────────────────────────────────────────────────────┐
│  ┌──────────┐ ┌──────────┐ ┌──────────┐            │
│  │  [img]   │ │  [img]   │ │  [img]   │            │  ← 3-column grid
│  │ 09:30:00 │ │ 09:28:00 │ │ 09:26:00 │            │
│  │  Chrome  │ │  Teams   │ │  Chrome  │            │
│  └──────────┘ └──────────┘ └──────────┘            │
└─────────────────────────────────────────────────────┘
```
- Klik gambar → tampil fullscreen dialog (background hitam)

---

## 3. Settings Screen

**Fungsi:** Konfigurasi semua aspek aplikasi. Scroll vertikal, dikelompokkan per seksi.

### Seksi: FOLDER OUTPUT
```
┌─────────────────────────────────────────────────────┐
│  /Users/agent/ScreenRecordings          [📁 Pilih]  │
└─────────────────────────────────────────────────────┘
```

### Seksi: KUALITAS VIDEO
```
  [  Rendah  ] [  Sedang  ] [  Tinggi  ]
  ~1.5 Mbps — cocok untuk rekaman panjang
```

### Seksi: UKURAN FILE VIDEO
```
  Frame Rate:        [ 15 fps ] [ 30 fps ]
  Resolusi Maks:   [ Original ] [ 1080p ] [ 720p ]
  Gunakan HEVC:    ○──────────●  (macOS saja)
                   File ~40% lebih kecil dari H.264
```

### Seksi: JENDELA
```
  Selalu di atas   ●──────────○
```

### Seksi: IZIN macOS *(macOS only)*
```
  ┌─────────────────────────────────────────────────┐
  │  ℹ  Rekam layar memerlukan izin Screen Recording │
  │                    [ Buka System Settings ↗ ]   │
  └─────────────────────────────────────────────────┘
```

### Seksi: FFMPEG *(Windows only)*
```
  ✅ FFmpeg ditemukan — siap merekam
  Path: C:\ffmpeg\bin\ffmpeg.exe     [  Cek  ]
```

### Seksi: ADMIN
```
  Jalankan saat Login   ●──────────○   (macOS only)
  (KeepAlive — restart otomatis jika ditutup paksa)

  ┌─────────────────────────────────────────────────┐
  │  🔒 Password Admin                              │
  │  ✅ Password sudah diatur          [  Ubah  ]   │
  │  (diperlukan untuk menutup app)                 │
  └─────────────────────────────────────────────────┘
```

### Seksi: KONTROL DARI SERVER
```
  https://admin.perusahaan.com/agent-command  [💾]
  Server merespons JSON: {"command":"exit"}
```

### Seksi: TENTANG
```
  Screen Recorder  •  Versi 1.0.0
  macOS — menggunakan ScreenCaptureKit
```

---

## Dialogs & Modals

| Dialog | Trigger | Konten |
|---|---|---|
| Rename File | Klik ✏ di file list | TextField nama baru + [Simpan] [Batal] |
| Konfirmasi Hapus | Klik 🗑 di file list | "Hapus Rekaman?" + [Hapus] [Batal] |
| Error Rekaman | Gagal start/stop | Pesan error + [Coba Lagi] [Tutup] |
| Password Tutup App | Klik ✕ window (jika password di-set) | NSSecureTextField + [Tutup Aplikasi] [Batal] |
| Password Salah | Input salah di dialog tutup | Alert "Password Salah" + [OK] |
| Set Password Admin | Klik "Set Password" di Settings | 2x NSSecureTextField (baru + konfirmasi) |
| Ubah Password Admin | Klik "Ubah" di Settings | 3x NSSecureTextField (lama + baru + konfirmasi) |
| Screenshot Fullscreen | Klik gambar di tab Screenshot | Image fullscreen + header app/waktu + [✕] |

---

## Data & State

| Cubit/Bloc | State | Dipakai di |
|---|---|---|
| `RecordingBloc` | Idle / Starting / Active / Error + durasi + path file | Home |
| `FileListCubit` | List file rekaman + loading flag | Home, Settings |
| `SettingsCubit` | quality, frameRate, maxResolution, useHevc, alwaysOnTop, ffmpegPath, outputDir, serverControlUrl | Settings |
| `MonitoringCubit` | isMonitoring, isIdle, currentApp, appLog, screenshots, sesi/idle/aktif duration, screenshotInterval | Dashboard |

---

## Fitur Admin & Keamanan

| Fitur | Mekanisme |
|---|---|
| Proteksi tutup app | `windowShouldClose` Swift → NSAlert password dialog |
| Password storage | SHA-256 hash di macOS UserDefaults |
| Auto-start + KeepAlive | LaunchAgent plist di `~/Library/LaunchAgents/` |
| Remote quit via server | HTTP polling 30 detik → JSON `{"command":"exit"}` |
| Single-instance lock | `LSMultipleInstancesProhibited` di Info.plist + Hive lock catch |

---

## Platform Support

| Fitur | macOS | Windows |
|---|---|---|
| Screen recording | ScreenCaptureKit (macOS 12.3+) | FFmpeg (gdigrab) |
| Audio capture | ✅ AAC via SCStream | ✅ via FFmpeg |
| HEVC codec | ✅ (macOS 13+) | ❌ |
| Activity monitor | ✅ IOKit + NSWorkspace | ❌ |
| Admin password | ✅ CryptoKit SHA-256 | ❌ |
| Auto-start KeepAlive | ✅ LaunchAgent | ❌ (belum) |
| Arsitektur build | x64 | x64 only |
