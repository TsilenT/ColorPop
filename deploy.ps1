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
if (-not $GODOT_PATH) { $GODOT_PATH = "C:\Users\sihl\Desktop\Godot_v4.3-stable_win64_console.exe" }
if (-not $BUTLER_PATH) { $BUTLER_PATH = "C:\Program Files\butler\butler.exe" }

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

# 3. Push with Butler
Write-Host "Pushing to itch.io..." -ForegroundColor Cyan
& $BUTLER_PATH push $BUILD_DIR "$ITCH_USER/$ITCH_GAME`:$CHANNEL"

Write-Host "Deployment Complete!" -ForegroundColor Green
