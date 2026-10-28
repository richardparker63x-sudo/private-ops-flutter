#!/usr/bin/env bash
set -e
APP=private_ops_app
flutter create --org com.cyberpoka --project-name private_ops "$APP"
cp -r lib/. "$APP/lib/"
cp pubspec.yaml "$APP/pubspec.yaml"
sed -i 's#android:label="private_ops"#android:label="Private Ops"#' "$APP/android/app/src/main/AndroidManifest.xml"
cd "$APP" && flutter pub get
echo "Done. Run: cd $APP && flutter run   |   APK: flutter build apk --release"
