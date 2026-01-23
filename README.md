# 📡 NAP Finder (LCP Locator)

A robust, offline-capable Flutter application designed for field technicians to locate Network Access Points (NAP/LCP) using GPS and Google Sheets as a backend.

## ✨ Key Features

* **📍 Offline Maps:** Map tiles are cached to the device storage, allowing full navigation without an internet connection.
* **☁️ Google Sheets Sync:** Uses a live Google Sheet as the database. Updates made in the sheet appear in the app instantly upon refresh.
* **🧠 Smart Parser:** Automatically detects OLT blocks and handles "ragged" rows or missing columns without crashing.
* **🧭 Live Navigation:** Real-time GPS tracking with a digital compass that rotates the user marker to show heading.
* **🔍 Power Search:** Instantly filter thousands of LCPs by Name, Site, or OLT ID.
* **📊 Data Clustering:** Smartly groups nearby markers to prevent map clutter.

---

## 🛠️ Project Architecture

This app uses a **Serverless Architecture**. There is no backend server to maintain; the app talks directly to Google Sheets CSV export.

* **Frontend:** Flutter (Dart)
* **Database:** Google Sheets (Published as CSV)
* **Maps:** OpenStreetMap (via `flutter_map`)
* **State Management:** `setState` (Simple & Robust)
* **Local Storage:** `dio_cache_interceptor_file_store` (For offline map tiles)

---

## 🚀 Getting Started

### 1. Prerequisites
* [Flutter SDK](https://docs.flutter.dev/get-started/install) installed (version 3.10 or higher).
* An Android device or Emulator.

### 2. Installation

1.  Clone the repository:
    ```bash
    git clone [https://github.com/yourusername/nap-finder.git](https://github.com/yourusername/nap-finder.git)
    cd nap-finder
    ```

2.  Install dependencies:
    ```bash
    flutter pub get
    ```

### 3. Android Configuration (Critical)
To enable GPS and Compass features, you must add permissions to your **`android/app/src/main/AndroidManifest.xml`**. Add these lines right before the `<application>` tag:

```xml
<manifest xmlns:android="[http://schemas.android.com/apk/res/android](http://schemas.android.com/apk/res/android)">
    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
    <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
    <uses-permission android:name="android.permission.INTERNET" />

    <application ...>
