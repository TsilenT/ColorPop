# Configuration
$ITCH_USER = "sihl"
$ITCH_GAME = "colorpop"
$CHANNEL = "html5"
$GODOT_PATH = "C:\Users\sihl\Desktop\Godot_v4.3-stable_win64_console.exe"
$BUTLER_PATH = "C:\Program Files\butler\butler.exe"
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

# 3. Push with Butler
Write-Host "Pushing to itch.io..." -ForegroundColor Cyan
& $BUTLER_PATH push $BUILD_DIR "$ITCH_USER/$ITCH_GAME`:$CHANNEL"

Write-Host "Deployment Complete!" -ForegroundColor Green
