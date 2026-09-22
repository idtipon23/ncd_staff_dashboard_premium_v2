#!/bin/bash
set -e

# 1. ติดตั้ง Flutter SDK
if [ ! -d "_flutter" ]; then
  git clone https://github.com/flutter/flutter.git -b stable --depth 1 _flutter
fi

export PATH="$PATH:$(pwd)/_flutter/bin"

# 2. Build Web โดยปิด icon tree shaking เพื่อป้องกันไอคอนหาย
flutter config --no-analytics
flutter pub get
flutter build web --release --no-tree-shake-icons