# Android APK derleme

Oyun **Android APK**'ya derlenebiliyor. Araç zinciri repo dışında (`C:\OttomanTD\` altında) tutulur.

## Kurulu araçlar (bu makinede)
| Araç | Yol |
|------|-----|
| Godot 4.3 | `C:\OttomanTD\godot\Godot_v4.3-stable_win64_console.exe` |
| JDK 17 | `C:\OttomanTD\androidtools\jdk-17.0.12+7` |
| Android SDK | `C:\OttomanTD\android-sdk` (cmdline-tools/latest, platform-tools, build-tools;34.0.0, platforms;android-34) |
| Debug keystore | `C:\OttomanTD\androidtools\debug.keystore` (parola: `android`, alias: `androiddebugkey`) |
| Export şablonları | `%APPDATA%\Godot\export_templates\4.3.stable\` |

## Önemli notlar
- **SSL/proxy:** FortiClient VPN HTTPS'i kendi CA'sıyla imzalıyor; `sdkmanager` için `JAVA_OPTS=-Djavax.net.ssl.trustStoreType=WINDOWS-ROOT` gerekti.
- **Editör ayarları** (`%APPDATA%\Godot\editor_settings-4.3.tres`) içinde `export/android/android_sdk_path`, `java_sdk_path`, `debug_keystore` dolu olmalı. Dosyayı **BOM'suz** yaz (Windows PowerShell'de `Set-Content -Encoding utf8` BOM ekler → .tres bozulur; `[System.IO.File]::WriteAllText(..., UTF8Encoding $false)` kullan).
- Ayarları yazdıktan **sonra `--editor` çalıştırma** (SDK yolunu sıfırlar). Doğrudan export et.

## Derleme komutu (debug APK)
```powershell
$env:JAVA_HOME = "C:\OttomanTD\androidtools\jdk-17.0.12+7"
$env:Path = "$env:JAVA_HOME\bin;" + $env:Path
& "C:\OttomanTD\godot\Godot_v4.3-stable_win64_console.exe" `
  --headless --path "C:\OttomanTD\game" `
  --export-debug "Android" "C:\OttomanTD\game\build\OttomanRage.apk"
```
Çıktı: `build/OttomanRage.apk` (~47 MB, imzalı).

## Telefona kurma
- **USB (adb):** `C:\OttomanTD\android-sdk\platform-tools\adb.exe install -r build\OttomanRage.apk`
- **Elle:** APK'yı telefona kopyala → "Bilinmeyen kaynaklara izin ver" → dokun, kur.

## Play Store için (sonraki adım)
- `--export-release` + **release keystore** (kendi anahtarın) + `.aab` (Android App Bundle) üretimi gerekir.
- `export_presets.cfg`'de `gradle_build/export_format` ve imzalama ayarlanır; Play Console hesabı ($25) açılır.
