# PoC-W0-2: build an MSIX package of the W02 console app and sign it with a self-signed certificate.
# Does NOT install anything. Installing needs the certificate in TrustedPeople (admin) -- see README step.
# Output: out\W02.msix, out\KallrPoc.cer
$ErrorActionPreference = 'Stop'
$root   = $PSScriptRoot
$out    = Join-Path $root 'out'
$stage  = Join-Path $out 'stage'
$subject = 'CN=KallrPoc'   # must equal Identity/@Publisher in Package\AppxManifest.xml

$kit = Get-ChildItem 'C:\Program Files (x86)\Windows Kits\10\bin\*\x64\makeappx.exe' |
  Sort-Object FullName -Descending | Select-Object -First 1 | Split-Path
$makeappx = Join-Path $kit 'makeappx.exe'
$signtool = Join-Path $kit 'signtool.exe'

Remove-Item $out -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Path "$stage\Assets" | Out-Null

# 1. publish (framework-dependent; the .NET runtime is installed machine-wide)
# dotnet may not be on PATH in this shell; fall back to the default install dir.
$dotnet = (Get-Command dotnet -ErrorAction SilentlyContinue).Source
if (-not $dotnet) { $dotnet = 'C:\Program Files\dotnet\dotnet.exe' }
& $dotnet publish "$root\W02.csproj" -c Release -o $stage
if ($LASTEXITCODE) { throw 'dotnet publish failed' }

# 2. manifest + placeholder logos (plain colored squares; only here to satisfy the manifest)
Copy-Item "$root\Package\AppxManifest.xml" $stage
Add-Type -AssemblyName System.Drawing
foreach ($a in @{ 'StoreLogo' = 50; 'Square44x44Logo' = 44; 'Square150x150Logo' = 150 }.GetEnumerator()) {
  $bmp = New-Object System.Drawing.Bitmap $a.Value, $a.Value
  $g = [System.Drawing.Graphics]::FromImage($bmp); $g.Clear([System.Drawing.Color]::SteelBlue); $g.Dispose()
  $bmp.Save("$stage\Assets\$($a.Key).png", [System.Drawing.Imaging.ImageFormat]::Png); $bmp.Dispose()
}

# 3. pack
& $makeappx pack /d $stage /p "$out\W02.msix" /nv /o
if ($LASTEXITCODE) { throw 'makeappx failed' }

# 4. self-signed code-signing cert (CurrentUser\My) -> sign
$cert = Get-ChildItem Cert:\CurrentUser\My | Where-Object Subject -eq $subject | Select-Object -First 1
if (-not $cert) {
  $cert = New-SelfSignedCertificate -Type Custom -Subject $subject -KeyUsage DigitalSignature `
    -FriendlyName 'Kallr PoC W02' -CertStoreLocation Cert:\CurrentUser\My `
    -TextExtension @('2.5.29.37={text}1.3.6.1.5.5.7.3.3', '2.5.29.19={text}')
}
Export-Certificate -Cert $cert -FilePath "$out\KallrPoc.cer" | Out-Null
& $signtool sign /fd SHA256 /sha1 $cert.Thumbprint "$out\W02.msix"
if ($LASTEXITCODE) { throw 'signtool failed' }

Write-Host "built: $out\W02.msix  (cert: $out\KallrPoc.cer, thumbprint $($cert.Thumbprint))"
