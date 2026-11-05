$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot
flutter create --project-name hide_hunt_flutter --org com.hidehunt --platforms=android,ios,web,windows,macos,linux --no-pub .
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
flutter pub get
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
flutter analyze
flutter test
