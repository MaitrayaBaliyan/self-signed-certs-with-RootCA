## Create-RootCA
## This script creates a self-signed Root CA certificate and exports it as a PFX (with private key) and CRT (public key).
## The generated Root CA can then be used to sign other certificates.

$ConfigFileName = "./certs-config.json"

if (!(Test-Path $ConfigFileName)) {
    Write-Host "Configuration file not found: $ConfigFileName" -ForegroundColor Red
    Write-Host "Please create a certs-config.json file with the necessary parameters." -ForegroundColor Yellow
    exit 1
}

$Config = $(Get-Content $ConfigFileName -Raw | ConvertFrom-Json).RootCA
$OutPath = Join-Path $Config.OutPath "Root"

# 1. Setup Environment
if (!(Test-Path $OutPath)) { New-Item -ItemType Directory -Path $OutPath -Force | Out-Null }


# 2. Define CA Parameters
$rootParams = @{
    Subject           = "CN=$($Config.CommonName), O=$($Config.Organization), C=$($Config.Country), OU=$($Config.OrganizationUnit)"
    FriendlyName      = "$($Config.CommonName) (Internal Root)"
    CertStoreLocation = $Config.CertStoreLocation
    KeyExportPolicy   = "Exportable"
    KeyUsage          = "CertSign", "CRLSign", "DigitalSignature"
    HashAlgorithm     = $Config.HashAlgorithm
    KeyLength         = $Config.KeyLength
    NotAfter          = (Get-Date).AddYears($Config.ValidityYears)
    # Basic Constraints: ca=1 (This marks it as a real CA)
    TextExtension     = @("2.5.29.19={text}ca=1&pathlength=0")
}

Write-Host "Generating Production Root CA: $($Config.CommonName)" -ForegroundColor Cyan
$rootCA = New-SelfSignedCertificate @rootParams

# 3. Export PFX
$securePass = ConvertTo-SecureString -String $Config.Secret -Force -AsPlainText
Export-PfxCertificate -Cert $rootCA -FilePath (Join-Path $OutPath "$($Config.CommonName).pfx") -Password $securePass | Out-Null

# 4. Export Public CER (To be distributed/trusted)
Export-Certificate -Cert $rootCA -FilePath (Join-Path $OutPath "$($Config.CommonName).crt") | Out-Null

# 5. Cleanup local store (Don't install yet)
Get-ChildItem $Config.CertStoreLocation | Where-Object { $_.Thumbprint -eq $rootCA.Thumbprint } | Remove-Item

Write-Host "Success! Root CA created in $OutPath" -ForegroundColor Green
Write-Host "Note: Install the .crt file into 'Trusted Root Certification Authorities' to use it." -ForegroundColor Yellow
