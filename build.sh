#!/bin/bash

echo "🚀 Cek Flutter..."
if cd flutter; then
  git pull && cd ..
else
  git clone https://github.com/flutter/flutter.git -b stable flutter
fi

echo "✅ Flutter Siap. Mulai Build..."
ls
flutter/bin/flutter doctor
flutter/bin/flutter clean
flutter/bin/flutter config --enable-web
flutter/bin/flutter build web --release
echo "🎉 Build Selesai!"