# Updates from GitHub Releases (https://github.com/<UpdateRepo>/releases). A release carries
# Mirrodex-<version>.zip and Mirrodex-<version>.zip.sha256, both made by tools/build-release.ps1.
# Checked at most once a day at startup, before the engine runs, so no program file is in use while replacing.

function Get-LatestRelease {
  [Net.ServicePointManager]::SecurityProtocol=[Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
  $release=Invoke-RestMethod -Uri "https://api.github.com/repos/$script:UpdateRepo/releases/latest" -Headers @{'User-Agent'='Mirrodex';Accept='application/vnd.github+json'} -TimeoutSec 6 -UseBasicParsing
  $version=$null
  if (-not [version]::TryParse(([string]$release.tag_name -replace '^v',''),[ref]$version)) { return $null }
  $zip=@($release.assets | Where-Object { $_.name -like 'Mirrodex-*.zip' })[0]
  if (-not $zip) { return $null }
  $sum=@($release.assets | Where-Object { $_.name -eq "$($zip.name).sha256" })[0]
  if (-not $sum) { return $null }
  return @{Version=$version; Zip=$zip.browser_download_url; Sum=$sum.browser_download_url; Size=[long]$zip.size; Notes=[string]$release.body}
}
function Test-NewerRelease ($Release) { return ($Release -and $Release.Version -gt [version]$script:AppVersion) }
# A Git working copy is the developer's source; releases must never overwrite it.
function Test-DeveloperCopy ($Folder=$Root) { return (Test-Path -LiteralPath (Join-Path $Folder '.git')) }

function Save-UpdatePackage ($Release, $Folder) {
  [Net.ServicePointManager]::SecurityProtocol=[Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
  $ProgressPreference='SilentlyContinue'
  $zip=Join-Path $Folder 'update.zip'; $sum=Join-Path $Folder 'update.zip.sha256'
  Invoke-WebRequest -Uri $Release.Zip -OutFile $zip -UseBasicParsing -TimeoutSec 600 -Headers @{'User-Agent'='Mirrodex'}
  Invoke-WebRequest -Uri $Release.Sum -OutFile $sum -UseBasicParsing -TimeoutSec 60 -Headers @{'User-Agent'='Mirrodex'}
  return @{Zip=$zip; Sum=$sum}
}
# Verifies the checksum, then replaces program files in $Target. This PC's settings and profiles are kept.
function Install-UpdatePackage ($Zip, $Sum, $Target=$Root) {
  $expected=([IO.File]::ReadAllText($Sum).Trim() -split '\s+')[0].ToLowerInvariant()
  $actual=(Get-FileHash -LiteralPath $Zip -Algorithm SHA256).Hash.ToLowerInvariant()
  if ($expected -notmatch '^[0-9a-f]{64}$' -or $expected -ne $actual) { throw '내려받은 업데이트 파일이 손상되었습니다. 지금 버전은 바꾸지 않았습니다.' }
  $extract=Join-Path (Split-Path $Zip) 'files'
  Expand-Archive -LiteralPath $Zip -DestinationPath $extract -Force
  $entry=@(Get-ChildItem -LiteralPath $extract -Recurse -Filter 'mirrodex.ps1' | Sort-Object { $_.FullName.Length })[0]
  if (-not $entry) { throw '업데이트 파일에 Mirrodex 프로그램이 없습니다. 지금 버전은 바꾸지 않았습니다.' }
  # The engine's background connection service may still hold its files from the last session.
  $adb=Join-Path $Target 'engine\mirrodex-adb.exe'
  if (Test-Path -LiteralPath $adb) { try { [void](Invoke-Tool $adb @('kill-server') 5000) } catch {} }
  foreach ($item in Get-ChildItem -LiteralPath $entry.DirectoryName -Force) {
    if ($item.Name -in $script:UserDataNames -or $item.Name -like 'backup-*') { continue }
    Copy-Item -LiteralPath $item.FullName -Destination $Target -Recurse -Force
  }
}
function Update-InstalledVersion ($Version, $Target=$Root) {
  $key='HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\Mirrodex'
  try {
    $entry=Get-ItemProperty -LiteralPath $key -ErrorAction Stop
    if ([IO.Path]::GetFullPath($entry.InstallLocation).TrimEnd('\') -eq [IO.Path]::GetFullPath($Target).TrimEnd('\')) { Set-ItemProperty -LiteralPath $key -Name DisplayVersion -Value ([string]$Version) }
  } catch {}
}
function Install-Update ($Release) {
  if (@(Get-Process mirrodex-engine -ErrorAction SilentlyContinue).Count) { throw '다른 Mirrodex 창이 열려 있어 업데이트할 수 없습니다. 모든 미러링 창을 닫은 뒤 다시 실행해 주십시오.' }
  $work=Join-Path ([IO.Path]::GetTempPath()) ('mirrodex-update-'+[guid]::NewGuid().ToString('N'))
  [void][IO.Directory]::CreateDirectory($work)
  $progress=New-GuideForm '업데이트를 설치하는 중입니다' "Mirrodex $($Release.Version) · 약 $([Math]::Max(1,[int]($Release.Size/1MB))) MB`n잠시 뒤 새 버전으로 다시 시작합니다. 창을 닫지 마십시오." @()
  $progress.UseWaitCursor=$true; $progress.Show(); [Windows.Forms.Application]::DoEvents()
  try {
    $package=Save-UpdatePackage $Release $work
    [Windows.Forms.Application]::DoEvents()
    Install-UpdatePackage $package.Zip $package.Sum $Root
    Update-InstalledVersion $Release.Version
  } finally {
    $progress.Dispose()
    if ((Split-Path $work -Leaf) -like 'mirrodex-update-*') { Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue }
  }
  Start-Process -FilePath (Join-Path $Root 'Mirrodex.bat') -WorkingDirectory $Root -WindowStyle Hidden
}
# Returns $true when Mirrodex restarted into the new version and this process should end.
function Invoke-StartupUpdateCheck {
  $today=Get-Date -Format 'yyyy-MM-dd'
  if ((Test-DeveloperCopy) -or (Get-UiPreference 'updatechecked' '') -eq $today) { return $false }
  Set-UiPreference 'updatechecked' $today
  try { $release=Get-LatestRelease } catch { return $false }  # offline or no release yet: start normally
  if (-not (Test-NewerRelease $release) -or (Get-UiPreference 'skipversion' '') -eq [string]$release.Version) { return $false }
  $notes=@(([string]$release.Notes -split '\r?\n') | Where-Object { $_.Trim() } | Select-Object -First 6) -join "`n"
  $text="Mirrodex $($release.Version)을 설치할 수 있습니다. 지금 버전은 $($script:AppVersion)입니다.`n설정, 녹화 파일, 스크린샷은 그대로 남습니다."
  if ($notes) { $text+="`n`n$notes" }
  try {
    $pick=Show-GuideChoice '새 버전이 있습니다' $text @(@{Key='update';Label='지금 업데이트하기'},@{Key='later';Label='내일 다시 알림'},@{Key='skip';Label='이 버전 건너뛰기';Variant='quiet'})
  } catch [OperationCanceledException] { return $false }
  if ($pick -eq 'skip') { Set-UiPreference 'skipversion' ([string]$release.Version); return $false }
  if ($pick -ne 'update') { return $false }
  try { Install-Update $release; return $true }
  catch {
    [void](Show-GuideChoice '업데이트하지 못했습니다' ($_.Exception.Message+"`n`n지금 버전으로 계속합니다. 나중에 GitHub의 Releases에서 직접 받을 수도 있습니다.") @(@{Key='ok';Label='지금 버전으로 계속하기'}))
    return $false
  }
}
# Side-menu check while mirroring: files are in use, so a found update installs at the next start.
function Get-UpdateStatus {
  $release=Get-LatestRelease
  if (-not (Test-NewerRelease $release)) { return @{Text="최신 버전입니다. 지금 버전: $script:AppVersion";Tone='success'} }
  Set-UiPreference 'updatechecked' ''; Set-UiPreference 'skipversion' ''
  if (Test-DeveloperCopy) { return @{Text="새 버전 $($release.Version)이 있습니다. 개발 폴더라서 자동으로 바꾸지 않습니다.";Tone='info'} }
  return @{Text="새 버전 $($release.Version)이 있습니다. 미러링을 끝내고 Mirrodex를 다시 실행하면 설치합니다.";Tone='info'}
}
