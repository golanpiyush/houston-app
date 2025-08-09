# 🚀 Houston

<div align="center">

[![Latest Release](https://img.shields.io/github/v/release/golanpiyush/houston-app?label=Latest%20Release&style=for-the-badge&color=00D4AA)](https://github.com/golanpiyush/houston-app/releases/latest)
[![License: GPL-3.0](https://img.shields.io/badge/License-GPLv3-blue?style=for-the-badge)](https://github.com/golanpiyush/houston/blob/main/LICENSE)
[![GitHub Stars](https://img.shields.io/github/stars/golanpiyush/houston-app?style=for-the-badge&color=FFD700)](https://github.com/golanpiyush/houston-app/stars)


**A modern, minimal, offline-capable music player built for knowledge-seekers, not time wasters.**

*Material 3 design • Offline + online sync • EQ & effects • In-app updates • Radio streaming*

</div>
<div align="center">
  <img src="assets/icons/icon_launcher.png" alt="Houston App Icon" width="120" height="120" style="border-radius: 20px; margin: 20px 0;" />
</div>

## 🎯 Overview

Houston is a powerful Android music player that combines the best of local and remote playback in one seamless experience.  
Inspired by **YouTube Music's interface** but designed for users who value **privacy**, **offline capability**, and **advanced audio controls**.

---
## ✨ Features

### 🎵 **Core Playback**
- **Unified Queue System** – Mix local and remote tracks seamlessly
- **Multiple Queue Management** – Create, save, and switch between playlists
- **Advanced Queue Editing** – Drag & drop reordering with undo
- **Background Playback** – With Media controls 

### 🎚️ **Audio Enhancement**
- **Professional Equalizer** – Multi-band EQ with presets
- **Audio Effects Suite** – Normalization, reverb, bass boost
- **Smart Audio Processing** – Auto level adjustment & quality optimization
- **Custom Presets** – Save your audio/albumart quality settings

### 🌐 **Connectivity & Sync**
- **Hybrid Playback** – Local files + streaming
- **Smart Fallback** – Auto-switch source on failure
- **Advanced Sync** – Playlist & library sync with conflict resolution
- **Radio Streaming** – Support for custom stations

### 🔧 **Advanced Features**
- **In-App Updates** – Auto-update via GitHub releases with rollback protection
- **Offline Downloads** – Cache management & explicit offline mode
- **Smart Library** – Tag-aware metadata & related song suggestions
- **Custom Sources** – Add M3U playlists & stream endpoints

---

## 📱 Installation

### Quick Install
1. 📥 Download the latest APK from [Releases](https://github.com/yourusername/houston/releases/latest)
2. ⚙️ Enable **installation from unknown sources** in Android settings
3. 📲 Install by tapping the APK
4. 🔄 Future updates handled by **in-app updater**

### Required Permissions
- 📁 **Storage** – Local music playback
- 🔔 **Notifications** – Media controls
- 🌐 **Network** – Streaming & updates
- 🔐 **Account Sync** *(Optional)* – Cloud sync

---

## 🎨 Screenshots

<details>
<summary>📸 View Screenshots</summary>

<div align="center">
  <img src="assets/ss/houstonhomescreen.jpg" alt="Home Screen" width="200" />
  <img src="assets/ss/houstonplayerscreenwithsyncedlyrics.jpg" alt="Now Playing Screen" width="200" />
  <img src="assets/ss/houstonrelatedsongsqueuescreen.jpg" alt="Queue Edit Screen" width="200" />
  <img src="assets/ss/houstonsavedscreen.jpg" alt="Saved/Downloaded Screen" width="200" />
  <img src="assets/ss/houstonsettingsscreen.jpg" alt="Settings Screen" width="200" />
</div>

</details>


## 🛠️ Building from Source

### Prerequisites
- **Android Studio** Arctic Fox or later
- **JDK 11+**
- **Android SDK 30+**

### Build Steps
```bash
# Clone the repository
git clone https://github.com/yourusername/houston.git
cd houston

# Build debug version
./gradlew assembleDebug

# Build release version (requires signing)
./gradlew assembleRelease

# Install directly to a connected device
./gradlew installDebug
