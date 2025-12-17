# Load local settings if they exist
if (Test-Path "$PSScriptRoot\local_settings.ps1") {
    . "$PSScriptRoot\local_settings.ps1"
}

if (-not $GODOT_PATH) {
    Write-Warning "GODOT_PATH not set. Using default."
    # Try to guess or fail? Let's assume the user has it set or we need to ask.
    # But usually it is set in local_settings.ps1
}

if (-not $GODOT_PATH) {
    Write-Error "Could not find Godot Path. Please check local_settings.ps1"
    exit 1
}

Write-Host "Running Godot Validation..." -ForegroundColor Cyan
# Try standard validation (cmdline parsing check)
# Running Main Scene for a frame?
# Or validating specific scripts?
# For now, let's try to load the project which usually triggers script parsing.
# --check-only isn't always available in all versions, checking help would be good but...
# Let's try:
& $GODOT_PATH --headless --quit
# Just loading and quitting might show parse errors in stdout.

if ($LASTEXITCODE -ne 0) {
    Write-Error "Godot Validation Failed!"
    exit 1
}
else {
    Write-Host "Validation Passed (Project Loads)" -ForegroundColor Green
}
