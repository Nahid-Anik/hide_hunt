#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
flutter create --project-name hide_hunt_flutter --org com.hidehunt --platforms=android,ios,web,windows,macos,linux --no-pub .
flutter pub get
flutter analyze
flutter test
