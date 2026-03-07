---
description: Build APK and copy to project root folder
---

// turbo-all

1. Build the release APK
```
flutter build apk --release 2>&1
```

2. Copy the APK to the project root (c:\Apps\flowy\)
```
Copy-Item -Path "build\app\outputs\flutter-apk\app-release.apk" -Destination "flowy.apk" -Force; Write-Host "✅ APK copiada a c:\Apps\flowy\flowy.apk"
```
