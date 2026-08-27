param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^https://')]
    [string]$ApiBaseUrl
)

$ErrorActionPreference = 'Stop'

$normalizedApiBaseUrl = $ApiBaseUrl.TrimEnd('/')
flutter build apk --release `
    --dart-define="SUPERCAMPUS_API_BASE_URL=$normalizedApiBaseUrl" `
    --dart-define="SUPERCAMPUS_USE_MOCK_DATA=false"

if ($LASTEXITCODE -ne 0) {
    throw "Flutter release build failed with exit code $LASTEXITCODE"
}
