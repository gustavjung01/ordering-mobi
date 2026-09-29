param(
    [Parameter(Mandatory = $true)]
    [string]$UpdateBaseUrl,
    [Parameter(Mandatory = $false)]
    [string]$ExpectedVersion = $env:KM_RELEASE_VERSION
)

$ErrorActionPreference = "Stop"

$CanonicalUpdateBaseUrl = "https://pub-381648426a2447a7a5edd970ca02d14e.r2.dev/ordering"

$UpdateBaseUrl = $UpdateBaseUrl.Trim().TrimEnd("/")
if (-not [string]::Equals(
    $UpdateBaseUrl,
    $CanonicalUpdateBaseUrl,
    [StringComparison]::OrdinalIgnoreCase
)) {
    throw "UpdateBaseUrl must match the Ordering Key Manager public update base: $CanonicalUpdateBaseUrl"
}
$uri = $null
if (-not [Uri]::TryCreate($UpdateBaseUrl, [UriKind]::Absolute, [ref]$uri) -or $uri.Scheme -ne "https") {
    throw "UpdateBaseUrl must be a public HTTPS URL."
}
if ($uri.Host.EndsWith(".r2.cloudflarestorage.com", [StringComparison]::OrdinalIgnoreCase)) {
    throw "UpdateBaseUrl points to the private R2 S3 endpoint. Use the public R2 download URL or custom domain."
}

$manifestUrl = "$UpdateBaseUrl/latest.json"
Write-Host "Checking published manifest..."
try {
    $manifest = Invoke-RestMethod -Uri $manifestUrl -Method Get -TimeoutSec 20
}
catch {
    throw "Published latest.json is not reachable from the public update URL."
}

$version = [string]$manifest.version
$apkUrl = [string]$manifest.url
$sha256 = ([string]$manifest.sha256).ToLowerInvariant()
if ([string]::IsNullOrWhiteSpace($version) -or
    [string]::IsNullOrWhiteSpace($apkUrl) -or
    $sha256 -notmatch '^[0-9a-f]{64}$') {
    throw "Published latest.json is invalid."
}
if (-not [string]::IsNullOrWhiteSpace($ExpectedVersion) -and
    $version -ne $ExpectedVersion.Trim()) {
    throw "Published version $version does not match expected version $($ExpectedVersion.Trim())."
}

$apkUri = $null
if (-not [Uri]::TryCreate($apkUrl, [UriKind]::Absolute, [ref]$apkUri) -or
    $apkUri.Scheme -ne "https") {
    throw "Published APK URL is invalid."
}

$expectedApkName = "Ordering-$version.apk"
$basePath = $uri.AbsolutePath.TrimEnd("/") + "/"
if (-not [string]::Equals($apkUri.Scheme, $uri.Scheme, [StringComparison]::OrdinalIgnoreCase) -or
    -not [string]::Equals($apkUri.Host, $uri.Host, [StringComparison]::OrdinalIgnoreCase) -or
    $apkUri.Port -ne $uri.Port -or
    -not $apkUri.AbsolutePath.StartsWith($basePath, [StringComparison]::Ordinal) -or
    [IO.Path]::GetFileName($apkUri.AbsolutePath) -ne $expectedApkName) {
    throw "Published APK URL must point to $expectedApkName under the Ordering public update base."
}

$tempApk = Join-Path ([IO.Path]::GetTempPath()) "ordering-publication-check-$([Guid]::NewGuid().ToString('N')).apk"
try {
    Write-Host "Downloading published APK for SHA-256 verification..."
    Invoke-WebRequest -Uri $apkUri.AbsoluteUri -OutFile $tempApk -TimeoutSec 120
    $actualSha256 = (Get-FileHash -LiteralPath $tempApk -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actualSha256 -ne $sha256) {
        throw "Published APK SHA-256 does not match latest.json."
    }
}
finally {
    if (Test-Path -LiteralPath $tempApk) {
        Remove-Item -LiteralPath $tempApk -Force
    }
}

Write-Host "Public Ordering Mobile update publication verified."
Write-Host "Version: $version"
