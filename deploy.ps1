# Load local settings if they exist
if (Test-Path "$PSScriptRoot\local_settings.ps1") {
    . "$PSScriptRoot\local_settings.ps1"
}
else {
    Write-Warning "local_settings.ps1 not found! Using default/environment values."
}

# Configuration
if (-not $ITCH_USER) { $ITCH_USER = "sihl" }
$ITCH_GAME = "colorpop"
$CHANNEL = "html5"
if (-not $GODOT_PATH) { $GODOT_PATH = "C:\Program Files\godot\godot_console.exe" }
if (-not $BUTLER_PATH) { $BUTLER_PATH = "C:\Program Files\butler\butler.exe" }

# Fix Java Environment for Signing
$env:JAVA_HOME = "C:\Program Files\Eclipse Adoptium\jdk-17.0.17.10-hotspot"
$env:Path = "$env:JAVA_HOME\bin;$env:Path"

Write-Host "Using Godot Path: $GODOT_PATH" -ForegroundColor Gray
Write-Host "Using Butler Path: $BUTLER_PATH" -ForegroundColor Gray
$BUILD_DIR = ".\builds\web"
$PRESET_NAME = "Web"

# 1. Clean previous build
if (Test-Path $BUILD_DIR) {
    Remove-Item -Recurse -Force $BUILD_DIR
}
New-Item -ItemType Directory -Force -Path $BUILD_DIR | Out-Null

# 2. Export from Godot
Write-Host "Exporting Project..." -ForegroundColor Cyan
& $GODOT_PATH --headless --export-release $PRESET_NAME "$BUILD_DIR/index.html"

if ($LASTEXITCODE -ne 0) {
    Write-Error "Godot export failed!"
    exit 1
}

# 3. Push Web Build
Write-Host "Pushing Web Build to itch.io..." -ForegroundColor Cyan
& $BUTLER_PATH push $BUILD_DIR "$ITCH_USER/$ITCH_GAME`:$CHANNEL"

# ---------------------------------------------------------
# ANDROID DEPLOYMENT
# ---------------------------------------------------------
$ANDROID_BUILD_DIR = ".\builds\android"
$ANDROID_PRESET_NAME = "Android"

# 4. Clean Android build
if (Test-Path $ANDROID_BUILD_DIR) {
    Remove-Item -Recurse -Force $ANDROID_BUILD_DIR
}
New-Item -ItemType Directory -Force -Path $ANDROID_BUILD_DIR | Out-Null

# 5. Export Android APK
Write-Host "Exporting Android APK (Debug)..." -ForegroundColor Cyan
& $GODOT_PATH --headless --export-debug $ANDROID_PRESET_NAME "$ANDROID_BUILD_DIR/$ITCH_GAME.apk"

if ($LASTEXITCODE -ne 0) {
    Write-Error "Godot Android export failed!"
    exit 1
}

# 6. Push Android Build
Write-Host "Pushing Android Build to itch.io..." -ForegroundColor Cyan
& $BUTLER_PATH push "$ANDROID_BUILD_DIR/$ITCH_GAME.apk" "$ITCH_USER/$ITCH_GAME`:android"

Write-Host "Deployment Complete!" -ForegroundColor Green
