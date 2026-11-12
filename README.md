# WiDrop - Wi-Fi Link Sender (Flutter Mobile App)

Send links, device names, and destination folders to your laptop server running on port 8080 over local Wi-Fi.

## How to Build the APK on your Computer

### Prerequisites
1. Install Flutter SDK: https://flutter.dev/docs/get-started/install
2. Android Studio (or Android SDK Command-line Tools)

### Build Command:
```bash
# 1. Install dependencies
flutter pub get

# 2. Build release APK
flutter build apk --release
```

The compiled APK will be located at:
`build/app/outputs/flutter-apk/app-release.apk`

Copy this file to your phone and open it to install!

---

## Free Cloud Build via GitHub (No Flutter installation needed)
1. Push this project to a free GitHub repository.
2. The included `.github/workflows/build-apk.yml` will automatically build the APK.
3. In GitHub, go to **Actions** -> click latest build -> download **app-release.apk**!

---

## Laptop Server (Port 8080)
Before sending links from your phone, run the laptop receiver:

```bash
python3 laptop_server.py
```

Check your laptop IP:
- Windows: `ipconfig` (look for IPv4)
- macOS: `ipconfig getifaddr en0`
- Linux: `hostname -I`
