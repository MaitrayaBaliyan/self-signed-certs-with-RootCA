# self-signed-certs-with-RootCA

Here is a ready-to-use **README.md** content for your utility:

---

# Self-Signed Certificate Generator using Custom ROOT CA

## Overview

This utility generates server/client certificates signed by a custom Root Certificate Authority (Root CA).
All certificate properties are driven by a configuration JSON file, allowing fully automated and repeatable certificate creation.

This tool is suitable for:

* Internal environments
* Development and testing
* Local network deployments
* Private PKI setups

---

## Features

* Create or reuse a Root CA certificate
* Generate server certificates signed by Root CA
* Support for Subject Alternative Names (SAN)
* Export certificates in:

  * PFX
  * CRT
  * KEY
* Config-driven execution (JSON based)
* Custom validity period
* Custom key length and algorithm

---

## Project Structure

```
/cert-generator
│
├── certs-config.json
├── Create-RootCA.ps1
├── Self-Sign-Certificate.ps1
├── README.md
```

---

## Configuration Parameters

### RootCA Section

| Parameter     | Description                          |
| ------------- | ------------------------------------ |
| Subject       | Distinguished name of Root CA        |
| ValidYears    | Certificate validity in years        |
| KeyLength     | RSA key size (2048/4096 recommended) |
| HashAlgorithm | SHA256 recommended                   |
| ExportPath    | Directory to save Root CA files      |

---

### Certificate Section

| Parameter     | Description               |
| ------------- | ------------------------- |
| Subject       | Certificate subject       |
| DnsNames      | Subject Alternative Names |
| ValidYears    | Validity period           |
| KeyLength     | RSA key size              |
| HashAlgorithm | SHA256 recommended        |
| ExportPath    | Output directory          |
| ExportPfx     | Boolean to export PFX     |
| PfxPassword   | Password for PFX export   |

---

## Execution Steps

### 1. Create Root CA

```powershell
.\Create-RootCA.ps1
```

If Root CA already exists, it will be reused.

---

### 2. Create Signed Certificate

```powershell
.\Self-Sign-Certificate.ps1
```

This will:

* Read Root CA details
* Generate private key
* Create CSR (internally)
* Sign certificate using Root CA
* Export files

---

## Output Files

After execution, the following files are generated:

```
RootCA/
  RootCA.cer
  RootCA.pfx

ServerCert/
  server.crt
  server.key
  server.pfx
```

---

## Installing Root CA (Windows)

To trust the Root CA locally:

```powershell
Import-Certificate -FilePath .\RootCA.cer -CertStoreLocation Cert:\LocalMachine\Root
```

---

## Installing Root CA (Linux)

Copy the Root CA certificate:

```bash
sudo cp RootCA.cer /usr/local/share/ca-certificates/
sudo update-ca-certificates
```

---

## Security Notes

* Protect Root CA private key securely.
* Do not use the same Root CA in production and development.
* Use strong passwords for PFX exports.
* Recommended key sizes:

  * Root CA: 4096
  * Server Certificate: 2048 or higher
* SHA256 or higher should always be used.

---

## Use Cases

* Internal HTTPS servers
* Kubernetes ingress TLS
* NGINX local SSL
* API Gateway SSL
* Development certificates

---

## Example Use Case

Generate certificate for:

* `dnv-vessel.app`
* `www.dnv-vessel.app`

Just update `DnsNames` in `config.json` and execute the script.

---

## Troubleshooting

### Certificate Not Trusted

Ensure Root CA is installed in:

* Trusted Root Certification Authorities (Windows)
* System CA store (Linux)

---

### Browser Shows Invalid Certificate

* Verify SAN entries match domain
* Clear browser cache
* Restart browser

---

## Future Enhancements

* ECDSA support
* CSR export option
* Automatic certificate rotation
* CRL support
* Intermediate CA support

---

## License

Internal utility.
Use at your own risk.

---

If you want, I can also generate:

* Full PowerShell implementation
* Cross-platform OpenSSL version
* Python-based certificate generator
* Version with Intermediate CA support
