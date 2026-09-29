# Per-user install without administrator rights: %LOCALAPPDATA%\Programs\Mirrodex, Start menu and desktop
# shortcuts, and an entry in Settings > Apps so Mirrodex is removed like any other app.
# Files that belong to this PC (settings, device profiles with the phone serial). An update never replaces them
# and a release package never contains them; installing from an existing folder carries them over.
$script:UserDataNames = @('mirrodex.cfg','mirrodex.cfg.bak','mirrodex.regression.cfg','preferences.cfg','language.cfg',
  'current-context.cfg','refresh-recovery.cfg','refresh-repair.cfg','profiles','diagnostics')
function Get-InstallPaths {
  @{
    Dir=Join-Path $env:LOCALAPPDATA 'Programs\Mirrodex'
    StartMenu=Join-Path ([Environment]::GetFolderPath('Programs')) 'Mirrodex'
    Desktop=[Environment]::GetFolderPath('Desktop')
    Registry='HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\Mirrodex'
  }
}
function Set-Shortcut ($Path, $Target, $Arguments, $Directory, $Description) {
  $shell=New-Object -ComObject WScript.Shell
  $shortcut=$shell.CreateShortcut($Path)
  $shortcut.TargetPath=$Target; $shortcut.Arguments=[string]$Arguments; $shortcut.WorkingDirectory=$Directory
  $shortcut.WindowStyle=7; $shortcut.IconLocation=(Join-Path $Directory 'mirrodex.ico')+',0'; $shortcut.Description=$Description
  $shortcut.Save()
}
# One entry point: the assistant lives in the side menu and in the start-failure dialog, so the separate
# 'Mirrodex 도우미' shortcut of earlier versions is removed wherever it points to this Mirrodex.
function Remove-LegacyAssistantShortcut ($Folders=@([Environment]::GetFolderPath('Desktop'),(Join-Path ([Environment]::GetFolderPath('Programs')) 'Mirrodex'))) {
  $full=[IO.Path]::GetFullPath($Root).TrimEnd('\')
  foreach ($folder in $Folders) {
    $path=Join-Path $folder 'Mirrodex 도우미.lnk'
    if (-not (Test-Path -LiteralPath $path)) { continue }
    try {
      $target=(New-Object -ComObject WScript.Shell).CreateShortcut($path).TargetPath
      if ($target -and [IO.Path]::GetFullPath($target).StartsWith($full,[StringComparison]::OrdinalIgnoreCase)) { Remove-Item -LiteralPath $path -Force }
    } catch {}
  }
}
function Test-InstallDirectory ($Dir) {
  # Guard for removal: only a folder named Mirrodex directly inside a Programs folder is ever deleted.
  $full=[IO.Path]::GetFullPath($Dir).TrimEnd('\')
  return ((Split-Path $full -Leaf) -eq 'Mirrodex' -and (Split-Path (Split-Path $full) -Leaf) -eq 'Programs')
}
function Install-Mirrodex ($Source=$Root, $Paths=(Get-InstallPaths), [switch]$Quiet) {
  $dir=$Paths.Dir
  if ([IO.Path]::GetFullPath($Source).TrimEnd('\') -eq [IO.Path]::GetFullPath($dir).TrimEnd('\')) {
    if (-not $Quiet) { [void](Show-GuideChoice '이미 설치되어 있습니다' '시작 메뉴나 바탕화면의 Mirrodex로 실행하십시오. 제거는 Windows 설정 > 앱에서 할 수 있습니다.' @(@{Key='ok';Label='확인'})) }
    return
  }
  if (-not $Quiet) {
    [void](Show-GuideChoice 'Mirrodex를 이 PC에 설치합니다' "설치 위치: $dir`n시작 메뉴와 바탕화면에 바로가기를 만들고, Windows 설정 > 앱에서 제거할 수 있게 등록합니다. 관리자 권한은 필요하지 않습니다." @(@{Key='install';Label='설치하기'}))
  }
  [void][IO.Directory]::CreateDirectory($dir)
  # Program files plus this PC's settings; development backups, tests and diagnostics stay behind.
  foreach ($item in Get-ChildItem -LiteralPath $Source -Force) {
    if ($item.Name -like 'backup-*' -or $item.Name -in @('tests','diagnostics','.git','.claude') -or $item.Name -like '*.tmp') { continue }
    Copy-Item -LiteralPath $item.FullName -Destination $dir -Recurse -Force
  }
  $launcher=Join-Path $dir 'Mirrodex.bat'
  [void][IO.Directory]::CreateDirectory($Paths.StartMenu)
  foreach ($folder in @($Paths.StartMenu,$Paths.Desktop)) {
    Set-Shortcut (Join-Path $folder 'Mirrodex.lnk') $launcher '' $dir (T 'Mirrodex - 휴대폰 화면 미러링')
  }
  if ($Paths.Registry) {
    $size=[int]((Get-ChildItem -LiteralPath $dir -Recurse -File | Measure-Object Length -Sum).Sum/1KB)
    [void](New-Item -Path $Paths.Registry -Force)
    $values=@{DisplayName='Mirrodex'; DisplayVersion=$script:AppVersion; Publisher=$script:Creator; DisplayIcon=(Join-Path $dir 'mirrodex.ico');
      InstallLocation=$dir; UninstallString="`"$launcher`" uninstall"}
    foreach ($name in $values.Keys) { [void](New-ItemProperty -Path $Paths.Registry -Name $name -Value $values[$name] -PropertyType String -Force) }
    foreach ($name in 'NoModify','NoRepair') { [void](New-ItemProperty -Path $Paths.Registry -Name $name -Value 1 -PropertyType DWord -Force) }
    [void](New-ItemProperty -Path $Paths.Registry -Name EstimatedSize -Value $size -PropertyType DWord -Force)
  }
  if (-not $Quiet) {
    $next=Show-GuideChoice '설치를 마쳤습니다' '시작 메뉴나 바탕화면의 Mirrodex로 실행하십시오. 지금 연 압축 해제 폴더는 지워도 됩니다.' @(@{Key='launch';Label='Mirrodex 실행하기'})
    if ($next -eq 'launch') { Start-Process -FilePath $launcher -WorkingDirectory $dir -WindowStyle Hidden }
  }
}
function Uninstall-Mirrodex ($Paths=(Get-InstallPaths), [switch]$Quiet) {
  $dir=$Paths.Dir
  if (-not $Quiet) {
    try {
      [void](Show-GuideChoice 'Mirrodex를 제거하시겠습니까?' '프로그램, 저장된 설정, 바로가기를 지웁니다. 녹화 파일과 스크린샷(동영상·사진 폴더의 Mirrodex)은 남습니다.' @(@{Key='remove';Label='제거하기';Variant='danger'}) -Closable)
    } catch [OperationCanceledException] { return }
  }
  $full=[IO.Path]::GetFullPath($dir).TrimEnd('\')
  foreach ($folder in @($Paths.StartMenu,$Paths.Desktop)) {
    foreach ($name in 'Mirrodex.lnk','Mirrodex 도우미.lnk') {
      $path=Join-Path $folder $name
      if (-not (Test-Path -LiteralPath $path)) { continue }
      $target=(New-Object -ComObject WScript.Shell).CreateShortcut($path).TargetPath
      if ($target -and [IO.Path]::GetFullPath($target).StartsWith($full,[StringComparison]::OrdinalIgnoreCase)) { Remove-Item -LiteralPath $path -Force }
    }
  }
  if ((Test-Path -LiteralPath $Paths.StartMenu) -and -not (Get-ChildItem -LiteralPath $Paths.StartMenu -Force)) { Remove-Item -LiteralPath $Paths.StartMenu -Force }
  if ($Paths.Registry -and (Test-Path -LiteralPath $Paths.Registry)) { Remove-Item -LiteralPath $Paths.Registry -Recurse -Force }
  # The running launcher lives in this folder, so a detached shell removes it once this process has exited.
  if ((Test-Path -LiteralPath $dir) -and (Test-InstallDirectory $dir)) {
    Start-Process -FilePath (Join-Path $env:SystemRoot 'System32\cmd.exe') -WindowStyle Hidden -WorkingDirectory $env:TEMP -ArgumentList "/c ping -n 3 127.0.0.1 >nul & rmdir /s /q `"$full`""
  }
}
