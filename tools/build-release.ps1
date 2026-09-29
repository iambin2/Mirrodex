# Builds dist\Mirrodex-<version>.zip and its .sha256 for a GitHub release (tag v<version>).
# The package has one top folder, Mirrodex\, and never contains this PC's settings, backups, tests or tools.
param([string]$OutDir=(Join-Path (Split-Path $PSScriptRoot) 'dist'))
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot
. (Join-Path $root 'mirrodex-install.ps1')
$version=[regex]::Match([IO.File]::ReadAllText((Join-Path $root 'mirrodex-ui.ps1')),"\`$script:AppVersion='([^']+)'").Groups[1].Value
if (-not $version) { throw 'AppVersion not found in mirrodex-ui.ps1' }
$skip=@($script:UserDataNames)+@('tests','tools','dist','.git','.gitignore','.claude')
$stage=Join-Path $OutDir 'stage'; $app=Join-Path $stage 'Mirrodex'
if (Test-Path -LiteralPath $stage) { Remove-Item -LiteralPath $stage -Recurse -Force }
[void][IO.Directory]::CreateDirectory($app)
foreach ($item in Get-ChildItem -LiteralPath $root -Force) {
  if ($item.Name -in $skip -or $item.Name -like 'backup-*' -or $item.Name -like '*.tmp') { continue }
  Copy-Item -LiteralPath $item.FullName -Destination $app -Recurse -Force
}
$zip=Join-Path $OutDir "Mirrodex-$version.zip"
if (Test-Path -LiteralPath $zip) { Remove-Item -LiteralPath $zip -Force }
# Entries are named with '/' explicitly: Windows PowerShell 5.1 (Compress-Archive and ZipFile alike) writes a backslash,
# which other unzip tools treat as part of the file name. Non-ASCII names (the Korean shortcut file) are stored as UTF-8.
Add-Type -AssemblyName System.IO.Compression, System.IO.Compression.FileSystem
$archive=[IO.Compression.ZipFile]::Open($zip,[IO.Compression.ZipArchiveMode]::Create)
try {
  foreach ($file in Get-ChildItem -LiteralPath $stage -Recurse -File) {
    $name=$file.FullName.Substring($stage.Length+1).Replace([IO.Path]::DirectorySeparatorChar,'/')
    [void][IO.Compression.ZipFileExtensions]::CreateEntryFromFile($archive,$file.FullName,$name,[IO.Compression.CompressionLevel]::Optimal)
  }
} finally { $archive.Dispose() }
$hash=(Get-FileHash -LiteralPath $zip -Algorithm SHA256).Hash.ToLowerInvariant()
[IO.File]::WriteAllText("$zip.sha256","$hash  Mirrodex-$version.zip`n")
Remove-Item -LiteralPath $stage -Recurse -Force
Write-Output "Built $zip"
Write-Output "SHA-256 $hash"
Write-Output "Upload both files to a GitHub release tagged v$version."
