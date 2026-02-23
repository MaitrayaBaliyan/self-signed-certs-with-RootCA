## This script creates a self-signed certificate signed by a custom Root CA. 
## It requires the Root CA's PFX file and password to sign the new certificate.
## The generated certificate is exported as a PFX (with private key), CRT (public key)

$ConfigFileName = "./certs-config.json"

if (!(Test-Path $ConfigFileName)) {
    Write-Host "Configuration file not found: $ConfigFileName" -ForegroundColor Red
    Write-Host "Please create a certs-config.json file with the necessary parameters." -ForegroundColor Yellow
    exit 1
}

$Config = $(Get-Content $ConfigFileName -Raw | ConvertFrom-Json).SignedCert
$RootConfig = $(Get-Content $ConfigFileName -Raw | ConvertFrom-Json).RootCA # Load Root CA config for paths and parameters

if (!(Test-Path $Config.OutPath)) { New-Item -ItemType Directory -Path $Config.OutPath -Force | Out-Null }

$OutPath = Join-Path $Config.OutPath "Root"
$RootPfxPath = (Join-Path $OutPath "$($RootConfig.CommonName).pfx")

write-Host "Using Root CA PFX: $RootPfxPath" -ForegroundColor Cyan

try {
    # 1. Temporarily import Root CA into the Store (Required for Signer parameter)
    Write-Host "Temporarily loading Root CA into Store..." -ForegroundColor Cyan
    $rootStore = New-Object System.Security.Cryptography.X509Certificates.X509Store("My", "CurrentUser")
    $rootStore.Open("ReadWrite")
    
    $rootCert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2
    $rootCert.Import($RootPfxPath, $RootConfig.Secret, [System.Security.Cryptography.X509Certificates.X509KeyStorageFlags]::Exportable)
    $rootStore.Add($rootCert)

    # 2. Generate the Signed Certificate
    Write-Host "Issuing certificate for $($Config.DNSName)..." -ForegroundColor Cyan
    $certParams = @{
        Subject           = "CN=$($Config.DNSName), O=$($Config.Organization), OU=$($Config.OrganizationUnit), C=$($Config.Country)"
        DnsName           = @($Config.DNSName) + $Config.AltDNSNames
        Signer            = $rootCert
        CertStoreLocation = $Config.CertStoreLocation
        KeyExportPolicy   = "Exportable"
        Type              = "SSLServerAuthentication"
        HashAlgorithm     = $Config.HashAlgorithm
        KeyLength         = $Config.KeyLength
        NotAfter          = (Get-Date).AddYears($Config.ValidityYears)
        TextExtension     = @("2.5.29.37={text}1.3.6.1.5.5.7.3.1") # Explicit Server Auth EKU
    }
    $childCert = New-SelfSignedCertificate @certParams

    $fileName = $certParams.DnsName
    if ($fileName.StartsWith("*.")) {
        $fileName = $fileName.Substring(2) + ".wildcard"
    }

    # 3. Export PFX
    $pfxPath = Join-Path $Config.OutPath "$($fileName).pfx"
    $pfxData = $childCert.Export([System.Security.Cryptography.X509Certificates.X509ContentType]::Pfx, $Config.Secret)
    [System.IO.File]::WriteAllBytes($pfxPath, $pfxData)

    # 4. Export CRT (Public Key)
    $base64 = [System.Convert]::ToBase64String($childCert.RawData, "InsertLineBreaks")
    "-----BEGIN CERTIFICATE-----`r`n$base64`r`n-----END CERTIFICATE-----" | Out-File (Join-Path $Config.OutPath "$($fileName).crt") -Encoding ascii

    # 5. Export KEY (Private Key - PKCS#8)
    Write-Host "Extracting Private Key..." -ForegroundColor Yellow
    $rsaKey = [System.Security.Cryptography.X509Certificates.RSACertificateExtensions]::GetRSAPrivateKey($childCert)
    $keyBytes = $rsaKey.Key.Export([System.Security.Cryptography.CngKeyBlobFormat]::Pkcs8PrivateBlob)
    $keyBase64 = [System.Convert]::ToBase64String($keyBytes, "InsertLineBreaks")
    "-----BEGIN PRIVATE KEY-----`r`n$keyBase64`r`n-----END PRIVATE KEY-----" | Out-File (Join-Path $Config.OutPath "$($fileName).key") -Encoding ascii

}
finally {
    # 6. CLEANUP: Remove both from Store so the machine stays clean
    Write-Host "Cleaning up Windows Certificate Store..." -ForegroundColor Gray
    if ($null -ne $childCert) {
        Get-ChildItem $Config.CertStoreLocation | Where-Object { $_.Thumbprint -eq $childCert.Thumbprint } | Remove-Item
    }
    if ($null -ne $rootCert) {
        Get-ChildItem $Config.CertStoreLocation | Where-Object { $_.Thumbprint -eq $rootCert.Thumbprint } | Remove-Item
    }
    if ($null -ne $rootStore) { $rootStore.Close() }
}

Write-Host "`nSuccess! Files for $($Config.DNSName) created in $($Config.OutPath)" -ForegroundColor Green
