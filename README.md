<p align="center">
  <img src="app/assets/app_icon_foreground.png" width="120" alt="Contacts Go Logo" />
</p>

<h1 align="center">Contacts Go</h1>

<p align="center">
  <b>A privacy-first contacts app powered by Go + Flutter</b><br/>
  <sub>Your contacts. Your files. Your rules.</sub>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter&logoColor=white" alt="Flutter" />
  <img src="https://img.shields.io/badge/Go-1.25-00ADD8?logo=go&logoColor=white" alt="Go" />
  <img src="https://img.shields.io/badge/SQLite-Local%20DB-003B57?logo=sqlite&logoColor=white" alt="SQLite" />
  <img src="https://img.shields.io/badge/Backup-File--Based-4CAF50?logo=files&logoColor=white" alt="File-Based Backup" />
  <img src="https://img.shields.io/badge/Platform-Android-3DDC84?logo=android&logoColor=white" alt="Android" />
  <img src="https://img.shields.io/badge/License-MIT-yellow" alt="License" />
</p>

---

## ✨ What is Contacts Go?

**Contacts Go** is a modern, open-source contacts manager that replaces cloud-dependent sync with a **zero-effort, file-based backup system**. A high-performance **Go engine** handles all data persistence and backup logic via FFI, while a premium **Flutter** frontend delivers a Material You experience.

> **No accounts. No cloud lock-in. No telemetry.** Just a JSON file in a folder you control — sync it with Syncthing, Dropbox, OneDrive, Google Drive, or any folder-sync tool you already use.

---

## 🏗️ Architecture

```
┌─────────────────────────────────────────────┐
│              Flutter UI (Dart)              │
│  ┌─────────┐  ┌────────┐  ┌─────────────┐  │
│  │Contacts │  │ Dialer │  │Backup/Settings│ │
│  └────┬────┘  └───┬────┘  └──────┬───────┘  │
│       └───────────┼──────────────┘           │
│               FFI Bridge                     │
├─────────────────────────────────────────────┤
│              Go Engine (C-Shared)            │
│  ┌────────┐  ┌────────┐  ┌───────────────┐  │
│  │ SQLite │  │ Backup │  │ Import/Export │  │
│  │ Store  │  │ Daemon │  │ VCF/CSV/LDIF │  │
│  └────────┘  └────────┘  └───────────────┘  │
└─────────────────────────────────────────────┘
```

| Layer | Tech | Role |
|-------|------|------|
| **UI** | Flutter + Material 3 | Premium interface with Dynamic Color, glassmorphism, animated transitions |
| **Bridge** | Dart FFI | Zero-overhead calls between Flutter and the compiled Go library |
| **Engine** | Go (c-shared) | SQLite persistence, JSON backup, multi-format import/export |
| **Storage** | SQLite (modernc) | Pure-Go SQLite — no CGo dependency for the database driver |

---

## 🚀 Features

### 📇 Contact Management
- **Full CRUD** — Create, read, update, and delete contacts with rich fields (name, phone, email, organization, notes)
- **Favorites** — Star your most-used contacts; they float to the top with a dedicated ★ section
- **Alphabetical Grouping** — Contacts auto-grouped by first letter with sticky section headers
- **Search** — Instant full-text search across name, phone, email, and organization
- **Batch Operations** — Long-press to multi-select, then batch delete or export
- **Swipe-to-Call** — Swipe right on any contact to instantly dial via the system phone app

### 📞 Dialer
- **T9 Smart Search** — Type digits and get contact suggestions via T9 letter mapping
- **Auto Country Code** — Detects your locale and prepends the correct international prefix
- **Glassmorphic Keypad** — Animated, translucent dialer with DTMF-style keys
- **Quick Save** — Create a new contact directly from any dialed number

### 💾 Zero-Effort Backup
- **Auto-Backup on Save** — Every contact change triggers an automatic backup in the background
- **Background Daemon** — Configurable periodic backup (1 / 5 / 10 min intervals) via Android background service
- **File-Based Sync** — Backup is a single `contacts_backup.json` file — point it at any synced folder
- **One-Tap Restore** — Pick a backup file to restore all contacts instantly
- **Backup Status Dashboard** — See last backup time, contact count, and file location at a glance

### 📁 Import / Export
| Format | Import | Export |
|--------|--------|--------|
| **VCF** (vCard) | ✅ | ✅ |
| **CSV** | ✅ | ✅ |
| **LDIF** | ✅ | — |
| **Markdown** | — | ✅ |

- Share exported files directly via the system share sheet

### 🎨 Design
- **Material You** — Dynamic Color support; adapts to your device wallpaper
- **Theme Modes** — System / Light / Dark with one-tap toggle
- **Google Fonts (Outfit)** — Premium typography throughout
- **Glassmorphism** — Frosted glass navigation bar and search bar with backdrop blur
- **Micro-Animations** — Animated page transitions, avatar gradients, pulsing backup indicator
- **Gradient FAB** — Eye-catching primary-to-tertiary gradient floating action button

---

## 📦 Project Structure

```
Contacts/
├── engine/                    # Go engine (compiled to .so / .dylib)
│   ├── main.go                # C-exported FFI functions
│   ├── db/sqlite.go           # SQLite store (CRUD + search)
│   ├── models/contact.go      # Contact struct definition
│   ├── backup/backup.go       # JSON backup & restore logic
│   ├── io/parsers.go          # VCF, CSV, LDIF, Markdown parsers
│   ├── go.mod
│   └── go.sum
├── app/                       # Flutter application
│   ├── lib/
│   │   ├── main.dart          # App entry, theme, navigation
│   │   ├── core/
│   │   │   ├── ffi_bridge.dart       # Dart ↔ Go FFI bindings
│   │   │   ├── backup_daemon.dart    # Background backup service
│   │   │   └── call_service.dart     # System dialer integration
│   │   ├── models/
│   │   │   └── contact.dart          # Dart contact model
│   │   └── features/
│   │       ├── contacts/             # Contact list + detail pages
│   │       ├── dialer/               # T9 dialer page
│   │       └── backup/               # Backup settings page
│   └── android/               # Android platform config
├── Makefile                   # Build commands for Go engine
└── README.md
```

---

## 🛠️ Getting Started

### Prerequisites

| Tool | Version |
|------|---------|
| Flutter SDK | ≥ 3.11 |
| Go | ≥ 1.25 |
| Android NDK | 28+ (for Android builds) |

### Build the Go Engine

**Android (arm64):**
```bash
make build-engine-android
```

**macOS (development):**
```bash
make build-engine-macos
```

> The Makefile compiles the Go engine as a C-shared library (`.so` for Android, `.dylib` for macOS) and places it in the correct Flutter project directory.

### Run the App

```bash
cd app
flutter pub get
flutter run
```

### Build APK

```bash
cd app
flutter build apk --release
```

---

## 🔄 How Backup Sync Works

```
┌──────────────┐     auto-save     ┌──────────────────────┐
│  Contacts Go │ ──────────────▶  │  contacts_backup.json │
│  (your phone)│                  │  (local folder)       │
└──────────────┘                  └──────────┬───────────┘
                                             │
                              Syncthing / Dropbox / OneDrive
                                             │
                                  ┌──────────▼───────────┐
                                  │  contacts_backup.json │
                                  │  (other devices)      │
                                  └───────────────────────┘
```

1. **Set** the backup folder to your Syncthing / Dropbox / OneDrive sync directory
2. **Contacts** are auto-saved as `contacts_backup.json` on every change
3. **Your sync app** handles the cloud upload — zero configuration needed
4. **Restore** on another device by picking the synced backup file

---

## 🔐 Privacy

- **100% Local** — All data lives on your device in a local SQLite database
- **No Accounts** — No sign-up, no login, no user tracking
- **No Network Calls** — The app never phones home; backup files stay in folders you control
- **Open Source** — Audit every line of code yourself

---

## 📄 License

This project is licensed under the [MIT License](LICENSE).

---

<p align="center">
  <sub>Built with ❤️ using Go + Flutter</sub>
</p>
