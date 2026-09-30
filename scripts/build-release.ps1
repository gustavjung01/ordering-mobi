param(
    [Parameter(Mandatory = $false)]
    [string]$Flutter = "flutter",
    [Parameter(Mandatory = $true)]
    [string]$UpdateBaseUrl
)

$ErrorActionPreference = "Stop"

$CanonicalUpdateBaseUrl = "https://pub-381648426a2447a7a5edd970ca02d14e.r2.dev/ordering"

$version = $env:KM_RELEASE_VERSION
if ([string]::IsNullOrWhiteSpace($version)) {
    throw "KM_RELEASE_VERSION is required."
}
if ($version -notmatch '^\d+\.\d+\.\d+$') {
    throw "Ordering release version must use major.minor.patch."
}
if ($env:ORDERING_CI_RELEASE_VALIDATION -eq "true") {
    throw "ORDERING_CI_RELEASE_VALIDATION is only for CI validation and must not be used for a distributable release."
}

function Remove-OuterQuotes([string]$Value) {
    $normalized = $Value.Trim()
    while ($normalized.Length -ge 2) {
        $first = $normalized[0]
        $last = $normalized[$normalized.Length - 1]
        $hasMatchingQuotes =
            ($first -eq [char]34 -and $last -eq [char]34) -or
            ($first -eq [char]39 -and $last -eq [char]39)
        if (-not $hasMatchingQuotes) {
            break
        }
        $normalized = $normalized.Substring(1, $normalized.Length - 2).Trim()
    }
    return $normalized
}

$Flutter = Remove-OuterQuotes $Flutter
$UpdateBaseUrl = (Remove-OuterQuotes $UpdateBaseUrl).TrimEnd("/")
if (-not [string]::Equals(
    $UpdateBaseUrl,
    $CanonicalUpdateBaseUrl,
    [StringComparison]::OrdinalIgnoreCase
)) {
    throw "UpdateBaseUrl must match the Ordering Key Manager public update base: $CanonicalUpdateBaseUrl"
}

$requiredSigningVariables = @(
    "ORDERING_ANDROID_KEYSTORE",
    "ORDERING_ANDROID_KEYSTORE_PASSWORD",
    "ORDERING_ANDROID_KEY_ALIAS",
    "ORDERING_ANDROID_KEY_PASSWORD"
)

foreach ($name in $requiredSigningVariables) {
    $value = [Environment]::GetEnvironmentVariable($name)
    if ([string]::IsNullOrWhiteSpace($value)) {
        throw "$name is required for a distributable Android release."
    }
}

$keystorePath = Remove-OuterQuotes $env:ORDERING_ANDROID_KEYSTORE
if (-not (Test-Path -LiteralPath $keystorePath -PathType Leaf)) {
    throw "ORDERING_ANDROID_KEYSTORE does not point to an existing keystore file."
}
$env:ORDERING_ANDROID_KEYSTORE = (Resolve-Path -LiteralPath $keystorePath).Path

$updateUri = $null
try {
    $updateUri = [System.Uri]::new($UpdateBaseUrl, [System.UriKind]::Absolute)
}
catch {
    $updateUri = $null
}

if ($null -eq $updateUri -or
    $updateUri.Scheme -ne "https" -or
    [string]::IsNullOrWhiteSpace($updateUri.Host)) {
    throw "UpdateBaseUrl must be a public HTTPS URL."
}
if ($updateUri.Host.EndsWith(".r2.cloudflarestorage.com", [StringComparison]::OrdinalIgnoreCase)) {
    throw "UpdateBaseUrl must not use the private R2 S3 endpoint. Use the public R2 download URL or custom domain."
}

$releaseConfigPath = Join-Path $PSScriptRoot "..\release-config.json"
$releaseConfig = Get-Content -LiteralPath $releaseConfigPath -Raw | ConvertFrom-Json
if ($releaseConfig.version -ne $version) {
    throw "release-config.json version $($releaseConfig.version) does not match KM_RELEASE_VERSION $version."
}

$pubspecPath = Join-Path $PSScriptRoot "..\pubspec.yaml"
$pubspecContent = Get-Content -LiteralPath $pubspecPath -Raw
$pubspecVersionMatch = [regex]::Match(
    $pubspecContent,
    '(?m)^\s*version:\s*(\d+\.\d+\.\d+)(?:\+\d+)?\s*$'
)
if (-not $pubspecVersionMatch.Success) {
    throw "pubspec.yaml must contain a semantic version in the form major.minor.patch with an optional build number."
}
$pubspecVersionName = $pubspecVersionMatch.Groups[1].Value
if ($pubspecVersionName -ne $version) {
    throw "pubspec.yaml version $pubspecVersionName does not match KM_RELEASE_VERSION $version."
}

$parts = $version.Split(".")
$major = [int]$parts[0]
$minor = [int]$parts[1]
$patch = [int]$parts[2]
if ($minor -ge 1000 -or $patch -ge 1000) {
    throw "Minor and patch versions must stay below 1000 for Android build numbers."
}

$buildNumber = ($major * 1000000) + ($minor * 1000) + $patch
if ($buildNumber -le 0 -or $buildNumber -gt 2100000000) {
    throw "Calculated Android build number is outside the supported range."
}

$root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$outputDir = Join-Path $root "dist\android-release"
$apkName = "Ordering-$version.apk"
$aabName = "Ordering-$version.aab"
$apkPath = Join-Path $outputDir $apkName
$aabPath = Join-Path $outputDir $aabName
$manifestPath = Join-Path $outputDir "latest.json"

if (Test-Path -LiteralPath $outputDir) {
    Remove-Item -LiteralPath $outputDir -Recurse -Force
}
New-Item -ItemType Directory -Path $outputDir -Force | Out-Null

Push-Location $root
try {
    & $Flutter clean
    if ($LASTEXITCODE -ne 0) { throw "flutter clean failed." }

    & $Flutter pub get
    if ($LASTEXITCODE -ne 0) { throw "flutter pub get failed." }

    & $Flutter build apk --release "--build-name=$version" "--build-number=$buildNumber" "--dart-define=ORDERING_UPDATE_BASE_URL=$UpdateBaseUrl"
    if ($LASTEXITCODE -ne 0) { throw "flutter build apk --release failed." }

    & $Flutter build appbundle --release "--build-name=$version" "--build-number=$buildNumber" "--dart-define=ORDERING_UPDATE_BASE_URL=$UpdateBaseUrl"
    if ($LASTEXITCODE -ne 0) { throw "flutter build appbundle --release failed." }
}
finally {
    Pop-Location
}

$sourceApk = Join-Path $root "build\app\outputs\flutter-apk\app-release.apk"
$sourceAab = Join-Path $root "build\app\outputs\bundle\release\app-release.aab"
if (-not (Test-Path -LiteralPath $sourceApk)) {
    throw "Release APK was not produced at $sourceApk."
}
if (-not (Test-Path -LiteralPath $sourceAab)) {
    throw "Release AAB was not produced at $sourceAab."
}

Copy-Item -LiteralPath $sourceApk -Destination $apkPath -Force
Copy-Item -LiteralPath $sourceAab -Destination $aabPath -Force

$apk = Get-Item -LiteralPath $apkPath
$sha256 = (Get-FileHash -LiteralPath $apkPath -Algorithm SHA256).Hash.ToLowerInvariant()
$releaseNotes = if ([string]::IsNullOrWhiteSpace($env:KM_RELEASE_NOTES)) {
    "Cập nhật và cải thiện ứng dụng."
}
else {
    $env:KM_RELEASE_NOTES.Trim()
}

$manifest = [ordered]@{
    schemaVersion = 1
    version = $version
    buildNumber = $buildNumber
    apk = $apkName
    url = "$UpdateBaseUrl/$apkName"
    size = $apk.Length
    sha256 = $sha256
    releaseNotes = $releaseNotes
    publishedAt = (Get-Date).ToUniversalTime().ToString("o")
}

$manifestJson = ($manifest | ConvertTo-Json -Depth 4) + [Environment]::NewLine
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($manifestPath, $manifestJson, $utf8NoBom)

Write-Host "Ordering Mobile release ready"
Write-Host "Version: $version"
Write-Host "Build number: $buildNumber"
Write-Host "APK: $apkPath"
Write-Host "AAB: $aabPath"
Write-Host "Manifest: $manifestPath"
Write-Host "After publishing, run scripts\verify-release-publication.ps1 against the public update URL."
