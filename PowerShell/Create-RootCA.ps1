## Create-RootCA
## This script creates a self-signed Root CA certificate and exports it as a PFX (with private key) and CRT (public key).
## The generated Root CA can then be used to sign other certificates.

$ConfigFileName = "./certs-config.json"

if (!(Test-Path $ConfigFileName)) {
    Write-Host "Configuration file not found: $ConfigFileName" -ForegroundColor Red
    Write-Host "Please create a certs-config.json file with the necessary parameters." -ForegroundColor Yellow
    exit 1
}

$config = Get-Content $ConfigFileName -Raw | ConvertFrom-Json
$CAOutPath = Join-Path $config.OutPath "Root"

# 1. Setup Environment
if (!(Test-Path $CAOutPath)) { New-Item -ItemType Directory -Path $CAOutPath -Force | Out-Null }


# 2. Define CA Parameters
$rootParams = @{
    Subject           = "CN=$($config.CACommonName), O=$($config.Organization), C=$($config.Country), OU=$($config.OrganizationUnit)"
    FriendlyName      = "$($config.CACommonName) (Internal Root)"
    CertStoreLocation = $config.CertStoreLocation
    KeyExportPolicy   = "Exportable"
    KeyUsage          = "CertSign", "CRLSign", "DigitalSignature"
    HashAlgorithm     = $config.HashAlgorithm
    KeyLength         = $config.KeyLength
    NotAfter          = (Get-Date).AddYears($config.CAValidityYears)
    # Basic Constraints: ca=1 (This marks it as a real CA)
    TextExtension     = @("2.5.29.19={text}ca=1&pathlength=0")
}

Write-Host "Generating Production Root CA: $($config.CACommonName)" -ForegroundColor Cyan
$rootCA = New-SelfSignedCertificate @rootParams

# 3. Export PFX
$securePass = ConvertTo-SecureString -String $config.CASecret -Force -AsPlainText
Export-PfxCertificate -Cert $rootCA -FilePath (Join-Path $CAOutPath "$($config.CACommonName).pfx") -Password $securePass | Out-Null

# 4. Export Public CER (To be distributed/trusted)
Export-Certificate -Cert $rootCA -FilePath (Join-Path $CAOutPath "$($config.CACommonName).crt") | Out-Null

# 5. Cleanup local store (Don't install yet)
Get-ChildItem $config.CertStoreLocation | Where-Object { $_.Thumbprint -eq $rootCA.Thumbprint } | Remove-Item

Write-Host "Success! Root CA created in $CAOutPath" -ForegroundColor Green
Write-Host "Note: Install the .crt file into 'Trusted Root Certification Authorities' to use it." -ForegroundColor Yellow