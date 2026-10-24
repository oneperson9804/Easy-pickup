$ErrorActionPreference = 'Stop'
$projectRoot = $PSScriptRoot
$workspaceRoot = (Resolve-Path (Join-Path $projectRoot '..')).Path
$toolchainRoot = Join-Path $workspaceRoot '.local\toolchain'
$buildRoot = Join-Path $projectRoot 'build'
$outputRoot = Join-Path $workspaceRoot 'dist'
$signingRoot = Join-Path $workspaceRoot '.local\pickup-signing'

function Invoke-Checked {
    param([string]$Executable, [string[]]$Arguments)
    & $Executable @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "Command failed: $Executable (exit $LASTEXITCODE)"
    }
}

$aapt = (Get-ChildItem (Join-Path $toolchainRoot 'build-tools') -Filter aapt2.exe -Recurse | Select-Object -First 1).FullName
$androidJar = (Get-ChildItem (Join-Path $toolchainRoot 'platform') -Filter android.jar -Recurse | Select-Object -First 1).FullName
$javac = (Get-ChildItem (Join-Path $toolchainRoot 'jdk') -Filter javac.exe -Recurse | Select-Object -First 1).FullName
if (-not $aapt -or -not $androidJar -or -not $javac) {
    throw 'Expected official Android build-tools 35, platform 35, and JDK 17 under .local/toolchain.'
}
$buildTools = Split-Path $aapt
$javaBin = Split-Path $javac
$env:JAVA_HOME = Split-Path $javaBin
foreach ($directory in @($buildRoot, $outputRoot, $signingRoot, "$buildRoot\gen", "$buildRoot\classes", "$buildRoot\dex")) {
    New-Item -ItemType Directory -Path $directory -Force | Out-Null
}

$compiledResources = Join-Path $buildRoot 'resources.zip'
$unsignedApk = Join-Path $buildRoot 'unsigned.apk'
$alignedApk = Join-Path $buildRoot 'aligned.apk'
$finalApk = Join-Path $outputRoot 'pickup-shortcut-v1.0.apk'
Invoke-Checked $aapt @('compile', '--dir', "$projectRoot\res", '-o', $compiledResources)
Invoke-Checked $aapt @('link', '-I', $androidJar, '--manifest', "$projectRoot\AndroidManifest.xml", '--java', "$buildRoot\gen", '--version-code', '1', '--version-name', '1.0', '-o', $unsignedApk, $compiledResources)
$javaSources = @((Get-ChildItem "$projectRoot\src", "$buildRoot\gen" -Recurse -Filter *.java).FullName)
Invoke-Checked $javac (@('-encoding', 'UTF-8', '-source', '8', '-target', '8', '-Xlint:-options', '-classpath', $androidJar, '-d', "$buildRoot\classes") + $javaSources)
$classFiles = @((Get-ChildItem "$buildRoot\classes" -Recurse -Filter *.class).FullName)
Invoke-Checked "$buildTools\d8.bat" (@('--lib', $androidJar, '--min-api', '24', '--output', "$buildRoot\dex") + $classFiles)

Add-Type -AssemblyName System.IO.Compression.FileSystem
$archive = [IO.Compression.ZipFile]::Open($unsignedApk, [IO.Compression.ZipArchiveMode]::Update)
try {
    [IO.Compression.ZipFileExtensions]::CreateEntryFromFile($archive, "$buildRoot\dex\classes.dex", 'classes.dex', [IO.Compression.CompressionLevel]::Optimal) | Out-Null
} finally {
    $archive.Dispose()
}
Invoke-Checked "$buildTools\zipalign.exe" @('-f', '4', $unsignedApk, $alignedApk)

$keystore = Join-Path $signingRoot 'pickup.jks'
$passwordFile = Join-Path $signingRoot 'password.txt'
if ((Test-Path -LiteralPath $keystore) -xor (Test-Path -LiteralPath $passwordFile)) {
    throw 'Signing key/password pair is incomplete; preserve the existing key and restore its matching password.'
}
if (-not (Test-Path -LiteralPath $passwordFile)) {
    $passwordBytes = New-Object byte[] 32
    $random = [Security.Cryptography.RandomNumberGenerator]::Create()
    try { $random.GetBytes($passwordBytes) } finally { $random.Dispose() }
    [IO.File]::WriteAllText($passwordFile, [Convert]::ToBase64String($passwordBytes))
}
$env:PICKUP_SIGNING_PASS = [IO.File]::ReadAllText($passwordFile)
try {
    if (-not (Test-Path -LiteralPath $keystore)) {
        Invoke-Checked "$javaBin\keytool.exe" @('-genkeypair', '-keystore', $keystore, '-alias', 'pickup', '-keyalg', 'RSA', '-keysize', '3072', '-validity', '10000', '-dname', 'CN=Personal Pickup Shortcut', '-storepass:env', 'PICKUP_SIGNING_PASS', '-keypass:env', 'PICKUP_SIGNING_PASS', '-storetype', 'JKS', '-noprompt')
    }
    Invoke-Checked "$buildTools\apksigner.bat" @('sign', '--ks', $keystore, '--ks-key-alias', 'pickup', '--ks-pass', 'env:PICKUP_SIGNING_PASS', '--key-pass', 'env:PICKUP_SIGNING_PASS', '--out', $finalApk, $alignedApk)
} finally {
    Remove-Item Env:PICKUP_SIGNING_PASS -ErrorAction SilentlyContinue
}
Invoke-Checked "$buildTools\apksigner.bat" @('verify', '--verbose', '--print-certs', $finalApk)
Invoke-Checked "$buildTools\zipalign.exe" @('-c', '4', $finalApk)
Invoke-Checked $aapt @('dump', 'badging', $finalApk)
$permissionDump = & $aapt dump permissions $finalApk
if ($LASTEXITCODE -ne 0) { throw 'Unable to inspect packaged permissions.' }
if ($permissionDump -match 'uses-permission') { throw 'Unexpected requested permission in the APK.' }
$permissionDump
Get-FileHash -LiteralPath $finalApk -Algorithm SHA256 | Format-List
Get-Item -LiteralPath $finalApk | Select-Object Name, Length
