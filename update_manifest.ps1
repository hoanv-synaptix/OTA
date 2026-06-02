$ErrorActionPreference = "Stop"

$sourceBin = "D:\Projects\PWM\pwm_stm32f103cbt6_testboot\build\Debug\pwm_stm32f103cbt6_testboot.bin"
$targetDir = "D:\Projects\OTA"
$targetBin = Join-Path $targetDir "pwm_stm32f103cbt6_testboot.bin"
$manifestFile = Join-Path $targetDir "manifest.json"

Write-Host "Checking for source firmware..."
if (-not (Test-Path $sourceBin)) {
    Write-Host "Error: Source firmware file not found: $sourceBin" -ForegroundColor Red
    Write-Host "Please build your STM32 project first." -ForegroundColor Red
    exit
}

# 1. First, parse existing manifest to get the new version
if (-not (Test-Path $manifestFile)) {
    Write-Host "`nError: Manifest file not found at $manifestFile" -ForegroundColor Red
    exit
}
$manifest = Get-Content -Path $manifestFile -Raw | ConvertFrom-Json
$manifest.version_code = $manifest.version_code + 1
$newVersion = $manifest.version_code

# 2. Copy the file (Use static name to keep Repo clean)
$targetBinName = "pwm_stm32f103cbt6_testboot.bin"
$targetBin = Join-Path $targetDir $targetBinName

Write-Host "Copying firmware to $targetBinName..."
if (-not (Test-Path $targetDir)) { New-Item -ItemType Directory -Path $targetDir | Out-Null }

Copy-Item -Path $sourceBin -Destination $targetBin -Force

# 3. Get file size and SHA256
$firmwareSize = (Get-Item $targetBin).Length
$firmwareSha256 = (Get-FileHash -Path $targetBin -Algorithm SHA256).Hash.ToLower()

Write-Host "`nSize: $firmwareSize bytes"
Write-Host "SHA256: $firmwareSha256"

# 4. Update manifest.json URL
$manifest.firmware_size = $firmwareSize
$manifest.firmware_sha256 = $firmwareSha256
$manifest.firmware_url = "https://raw.githubusercontent.com/hoanv-synaptix/OTA/refs/heads/main/$targetBinName"

# Save back to file (use WriteAllText to prevent UTF-8 BOM)
$jsonString = $manifest | ConvertTo-Json -Depth 10
$utf8NoBom = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText($manifestFile, $jsonString, $utf8NoBom)

Write-Host "`nSuccess! Updated $manifestFile"
Write-Host "New version_code: $newVersion"

# 5. Auto Git Commit & Push
Write-Host "`nStarting Git Commit & Push..."
Set-Location -Path $targetDir

try {
    git add manifest.json $targetBinName
    git commit -m "OTA Update: v$newVersion (Size: $($firmwareSize)B)"
    git push
    Write-Host "`n🚀 Firmware successfully pushed to Github! (Note: It takes ~3-5 minutes for Github Cache to clear before you can OTA)" -ForegroundColor Green
} catch {
    Write-Host "`n❌ Git operation failed!" -ForegroundColor Red
}
