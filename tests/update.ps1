$ErrorActionPreference='Stop'
. (Join-Path (Split-Path $PSScriptRoot) 'mirrodex.ps1')
$script:checks=0
function Assert ($Value,$Message) { if (-not $Value) { throw $Message }; $script:checks++ }
$temp=Join-Path ([IO.Path]::GetTempPath()) ('mirrodex-updatetest-'+[guid]::NewGuid().ToString('N'))
[void][IO.Directory]::CreateDirectory($temp)
$script:PreferencesFile=Join-Path $temp 'preferences.cfg'; $script:UiPreferences=$null
function New-TestZip ($Folder, $Zip) {
  Add-Type -AssemblyName System.IO.Compression, System.IO.Compression.FileSystem
  $archive=[IO.Compression.ZipFile]::Open($Zip,'Create')
  try { foreach ($f in Get-ChildItem -LiteralPath $Folder -Recurse -File) { [void][IO.Compression.ZipFileExtensions]::CreateEntryFromFile($archive,$f.FullName,$f.FullName.Substring($Folder.Length+1).Replace('\','/')) } } finally { $archive.Dispose() }
}
try {
  # Release metadata from the GitHub API.
  function Invoke-RestMethod { [pscustomobject]@{tag_name='v2.1.0';body="Faster start`n`nNew menu";assets=@(
    [pscustomobject]@{name='Mirrodex-2.1.0.zip';browser_download_url='https://example.invalid/z';size=12000000},
    [pscustomobject]@{name='Mirrodex-2.1.0.zip.sha256';browser_download_url='https://example.invalid/s';size=90})} }
  $release=Get-LatestRelease
  Assert ($release.Version -eq [version]'2.1.0' -and $release.Zip -like '*/z' -and $release.Sum -like '*/s') 'latest release and its two files found'
  Assert ((Test-NewerRelease $release) -and -not (Test-NewerRelease @{Version=[version]$script:AppVersion}) -and -not (Test-NewerRelease $null)) 'only a higher version counts as new'
  function Invoke-RestMethod { [pscustomobject]@{tag_name='v2.1.0';assets=@([pscustomobject]@{name='Mirrodex-2.1.0.zip';browser_download_url='x';size=1})} }
  Assert ($null -eq (Get-LatestRelease)) 'a release without a checksum is never offered'
  Remove-Item function:Invoke-RestMethod

  # Package install: program files replaced, this PC's data kept, damaged downloads rejected.
  $src=Join-Path $temp 'pkg'; $app=Join-Path $src 'Mirrodex'
  [void][IO.Directory]::CreateDirectory((Join-Path $app 'engine')); [void][IO.Directory]::CreateDirectory((Join-Path $app 'profiles'))
  [IO.File]::WriteAllText((Join-Path $app 'mirrodex.ps1'),'# new'); [IO.File]::WriteAllText((Join-Path $app 'engine\part.dll'),'new')
  [IO.File]::WriteAllText((Join-Path $app 'mirrodex.cfg'),'serial=PACKAGED'); [IO.File]::WriteAllText((Join-Path $app 'profiles\x.cfg'),'packaged')
  $zip=Join-Path $temp 'update.zip'; New-TestZip $src $zip
  $sum=Join-Path $temp 'update.zip.sha256'
  $target=Join-Path $temp 'installed'; [void][IO.Directory]::CreateDirectory((Join-Path $target 'profiles'))
  [IO.File]::WriteAllText((Join-Path $target 'mirrodex.ps1'),'# old'); [IO.File]::WriteAllText((Join-Path $target 'mirrodex.cfg'),'serial=MINE')
  [IO.File]::WriteAllText((Join-Path $target 'profiles\mine.cfg'),'mine')
  [IO.File]::WriteAllText($sum,('0'*64)+'  Mirrodex-2.1.0.zip')
  $failed=$false; try { Install-UpdatePackage $zip $sum $target } catch { $failed=$_.Exception.Message -like '*손상*' }
  Assert ($failed -and [IO.File]::ReadAllText((Join-Path $target 'mirrodex.ps1')) -eq '# old') 'checksum mismatch leaves the installed version untouched'
  [IO.File]::WriteAllText($sum,(Get-FileHash $zip -Algorithm SHA256).Hash.ToLowerInvariant()+'  Mirrodex-2.1.0.zip')
  Install-UpdatePackage $zip $sum $target
  Assert ([IO.File]::ReadAllText((Join-Path $target 'mirrodex.ps1')) -eq '# new' -and (Test-Path (Join-Path $target 'engine\part.dll'))) 'program files replaced'
  Assert ([IO.File]::ReadAllText((Join-Path $target 'mirrodex.cfg')) -eq 'serial=MINE' -and (Test-Path (Join-Path $target 'profiles\mine.cfg')) -and -not (Test-Path (Join-Path $target 'profiles\x.cfg'))) 'settings and device profiles survive the update'

  # Startup check: once a day, skippable, never in a developer's Git folder.
  $Root=Join-Path $temp 'app'; [void][IO.Directory]::CreateDirectory($Root)
  $script:asked=0; $script:installed=$null; $script:answer='skip'
  function Get-LatestRelease { $script:asked++; return @{Version=[version]'9.0.0';Notes='Line one'} }
  function Show-GuideChoice ($Title,$Text,$Choices) { $script:lastText=$Text; return $script:answer }
  function Install-Update ($Release) { $script:installed=$Release.Version }
  Assert (-not (Invoke-StartupUpdateCheck) -and (Get-UiPreference 'skipversion' '') -eq '9.0.0') 'skipping remembers the version'
  Assert (-not (Invoke-StartupUpdateCheck) -and $script:asked -eq 1) 'checked at most once a day'
  Set-UiPreference 'updatechecked' ''; Set-UiPreference 'skipversion' ''; $script:answer='update'
  Assert ((Invoke-StartupUpdateCheck) -and $script:installed -eq [version]'9.0.0') 'accepting installs and restarts'
  Assert ($script:lastText -like '*Line one*' -and $script:lastText -like "*$script:AppVersion*") 'prompt shows both versions and release notes'
  Set-UiPreference 'updatechecked' ''; [void][IO.Directory]::CreateDirectory((Join-Path $Root '.git')); $script:asked=0
  Assert (-not (Invoke-StartupUpdateCheck) -and $script:asked -eq 0) 'a Git working copy is never updated'
  Assert ((Get-UpdateStatus).Text -like '*9.0.0*') 'menu check reports a newer version'
  function Get-LatestRelease { return @{Version=[version]$script:AppVersion} }
  Assert ((Get-UpdateStatus).Tone -eq 'success') 'menu check confirms the latest version'

  # Easter egg: five quick logo clicks.
  $script:cards=0
  function Show-CreatorCard { $script:cards++ }
  $logo=New-Object Windows.Forms.PictureBox
  1..4 | ForEach-Object { Register-LogoClick $logo }
  Assert ($script:cards -eq 0) 'four clicks do nothing'
  Register-LogoClick $logo
  Assert ($script:cards -eq 1 -and $logo.MxClicks.Count -eq 0) 'the fifth quick click opens the creator card'
  1..4 | ForEach-Object { Register-LogoClick $logo }
  for ($i=0; $i -lt 4; $i++) { $logo.MxClicks[$i]=$logo.MxClicks[$i].AddSeconds(-5) }
  Register-LogoClick $logo
  Assert ($script:cards -eq 1) 'slow clicks never add up'
  $logo.Dispose()

  # Release package: forward-slash paths, no personal data, matching checksum.
  $dist=Join-Path $temp 'dist'
  & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path (Split-Path $PSScriptRoot) 'tools\build-release.ps1') -OutDir $dist | Out-Null
  $built=Join-Path $dist "Mirrodex-$script:AppVersion.zip"
  Add-Type -AssemblyName System.IO.Compression.FileSystem
  $archive=[IO.Compression.ZipFile]::OpenRead($built); $names=@($archive.Entries | ForEach-Object FullName); $archive.Dispose()
  Assert ($names -contains 'Mirrodex/mirrodex.ps1' -and $names -contains 'Mirrodex/engine/mirrodex-engine.exe' -and -not @($names | Where-Object { $_ -like '*\*' }).Count) 'package has one Mirrodex folder with standard paths'
  Assert (-not @($names | Where-Object { $_ -match '/(profiles|tests|tools|backup-[^/]*)/|/(mirrodex\.cfg|preferences\.cfg|refresh-repair\.cfg|mirrodex\.regression\.cfg)$' }).Count) 'package never contains settings, device profiles, tests or backups'
  Assert ((([IO.File]::ReadAllText("$built.sha256") -split '\s+')[0]) -eq (Get-FileHash $built -Algorithm SHA256).Hash.ToLowerInvariant()) 'checksum file matches the package'
  Write-Output "PASS: $script:checks update checks ($($PSVersionTable.PSVersion))"
} finally {
  if ((Split-Path $temp -Leaf) -like 'mirrodex-updatetest-*') { Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue }
}
