# Session supervision and local, environment-specific preferences. No telemetry upload.
$script:Context = $null
$script:LastSession = $null
$script:TrialLabel = '화면 확인'
$script:TrialGeometry = $null
$script:SidebarEnabled = $false
$script:Recording = $false; $script:RecordFile = $null; $script:RecordStarted = $null; $script:LastRecording = $null; $script:SidebarExpanded = $false
$script:Source = @{Kind='screen'}; $script:Notice = $null; $script:EnginePath = $null; $script:DeviceLocks = @{}
$script:AlwaysOnTop = ((Get-UiPreference 'ontop' '0') -eq '1'); $script:TopHandle = [IntPtr]::Zero; $script:TopApplied = $null

function Initialize-Context ($Adb, $Serial) {
  Add-Type -AssemblyName System.Windows.Forms
  $screen=[Windows.Forms.Screen]::FromPoint([Windows.Forms.Cursor]::Position)
  $identity=Invoke-Tool $Adb @('-s',$Serial,'shell','getprop','ro.serialno')
  $id=if ($identity.Code -eq 0 -and $identity.Text.Trim()) { $identity.Text.Trim() } else { $Serial }
  $transport=if ($Serial -match ':|_adb-tls-connect') { 'wireless' } else { 'usb' }
  $label="$transport / $($screen.Bounds.Width)x$($screen.Bounds.Height)"
  $hash=[Security.Cryptography.SHA256]::Create()
  try { $key=([BitConverter]::ToString($hash.ComputeHash([Text.Encoding]::UTF8.GetBytes("$env:COMPUTERNAME|$id|$transport|$($screen.DeviceName)|$($screen.Bounds)")))).Replace('-','').ToLowerInvariant() }
  finally { $hash.Dispose() }
  $script:Context=@{Key=$key; Label=$label; Directory=(Join-Path $Root "profiles/$key"); Screen=$screen}
}

function Get-ProfilePath ($Name) {
  if ($script:Context) { return (Join-Path $script:Context.Directory "$Name.cfg") }
  return "$Cfg.$Name"
}
function Save-Profile ($Name, $Config) {
  $path=Get-ProfilePath $Name
  [void][IO.Directory]::CreateDirectory((Split-Path $path))
  Write-Pairs $path $Config
}
function Read-Profile ($Name, $Serial) {
  $path=Get-ProfilePath $Name
  if (-not (Test-Path -LiteralPath $path)) { return $null }
  $c=Import-Config $path
  if (-not $script:Context -and $c.serial -ne $Serial) { return $null }
  $c.serial=$Serial
  return $c
}
function Read-PreviousConfig ($Serial) {
  if ($script:Context) { return (Read-Profile 'previous' $Serial) }
  if (Test-Path -LiteralPath ($Cfg+'.bak')) {
    $c=Import-Config ($Cfg+'.bak')
    if ($c.serial -eq $Serial) { return $c }
  }
  return $null
}
function Select-Environment ($Config, $Serial) {
  $marker=Join-Path $Root 'current-context.cfg'
  $previous=if (Test-Path -LiteralPath $marker) { (Read-Pairs $marker).key } else { '' }
  if ($previous -and $previous -ne $script:Context.Key) {
    $saved=Read-Profile 'current' $Serial
    $choices=@(@{Key='guide';Label='이 환경에서 화면 맞추기'})
    if ($saved) { $choices=@(@{Key='saved';Label='이 환경에서 저장했던 설정 사용'})+$choices }
    if ($Config -and $Config.serial -eq $Serial) { $choices+=@{Key='keep';Label='현재 설정을 그대로 시험하기'} }
    $pick=Show-GuideChoice '연결 환경이 달라졌습니다' ("휴대폰·연결 방식·PC·화면 중 하나가 달라졌습니다. 설정을 자동으로 바꾸지는 않습니다.`n현재: " + $script:Context.Label) $choices
    if ($pick -eq 'saved') { Save-Config $saved; return $saved }
    $script:GuideMode=$true
    if ($pick -eq 'guide') { return $null }
  }
  # Remember only environments actually selected, or the existing installation on first migration.
  if ($Config -and $Config.serial -eq $Serial) {
    Save-Profile 'current' $Config
    Write-Pairs $marker @{key=$script:Context.Key}
  }
  return $Config
}

function Get-SessionKind ($Code, $Text) {
  if ($Code -eq 0) { return 'ok' }
  if ($Text -match 'unauthorized|not authorized') { return 'authorization' }
  if ($Code -eq 2 -or $Text -match 'device (disconnected|offline|not found)|no .*devices|connection (reset|closed)') { return 'connection' }
  if ($Text -match '(?i)audio.*(failed|disabled|error)|failed.*audio|could not.*audio') { return 'audio' }
  if ($Text -match '(?i)(could not|failed to|unable to) (create|configure|start|find).*encoder|MediaCodec\$CodecException|invalid encoder|encoder.*not found') { return 'encoder' }
  return 'unknown'
}
function Get-SessionSummary ($Code, $Text) {
  $samples=@([regex]::Matches($Text,'(?m)\b(\d+) fps\b') | ForEach-Object { [int]$_.Groups[1].Value })
  $skips=@([regex]::Matches($Text,'\b(\d+) frames? skipped\b') | ForEach-Object { [int]$_.Groups[1].Value })
  return @{Code=$Code; Kind=(Get-SessionKind $Code $Text); Samples=$samples.Count;
    Min=($samples | Measure-Object -Minimum).Minimum; Max=($samples | Measure-Object -Maximum).Maximum;
    Skipped=($skips | Measure-Object -Sum).Sum; VideoStarted=($Text -match 'Texture:|video size:')}
}
function Export-Diagnostics ($Config) {
  $dir=Join-Path $Root 'diagnostics'; [void][IO.Directory]::CreateDirectory($dir)
  $path=Join-Path $dir ('Mirrodex-'+(Get-Date -Format 'yyyyMMdd-HHmmss-fff')+'.txt')
  $lines=@('Mirrodex local diagnostics', ('time='+(Get-Date -Format o)), 'No screen, clipboard, raw log or device serial is collected.')
  if ($script:Context) { $lines+='environment='+$script:Context.Label }
  foreach ($key in @('codec','encoder','size','rate','buffer','fps','arr','audio','audiobuffer','requireaudio')) { if ($Config) { $lines+="$key=$($Config[$key])" } }
  if ($script:LastSession) { foreach ($key in @('Code','Kind','Samples','Min','Max','Skipped','VideoStarted')) { $lines+="$key=$($script:LastSession[$key])" } }
  $lines+='FPS is supporting evidence only. Static screens can report low FPS. Skipped counts are not network loss. No latency or end-to-end smoothness measurement.'
  [IO.File]::WriteAllLines($path,[string[]]$lines,[Text.Encoding]::UTF8)
  return $path
}
function Show-Diagnostics ($Config) {
  $path=Export-Diagnostics $Config
  [void](Show-GuideChoice '문제 정보를 저장했습니다' ("화면이나 기기 식별자는 포함하지 않습니다. 파일은 이 PC에만 저장했습니다.`n`n$path") @(@{Key='ok';Label='확인하고 닫기'}))
}

function Get-AlternativeEncoder ($Config, $Device) {
  foreach ($codec in @($Config.codec, $(if ($Config.codec -eq 'h264') { 'h265' } else { 'h264' }))) {
    foreach ($line in ($Device.Encoders -split '\r?\n')) {
      if ($line -match "--video-codec=$codec\s+--video-encoder=([A-Za-z0-9._-]+)\s+\(hw\)" -and $line -notmatch 'alias for') {
        $encoder=$Matches[1]
        if ($codec -eq $Config.codec -and (-not $Config.encoder -or $encoder -eq $Config.encoder)) { continue }
        $c=$Config.Clone(); $c.codec=$codec; $c.encoder=$encoder; return $c
      }
    }
  }
  return $null
}
function Get-RecoveryChoice ($Kind, $CanAlternate, $CanRetry=$true, [switch]$CanGuide) {
  $text=switch ($Kind) {
    'authorization' { '휴대폰 잠금을 풀고 이 PC의 USB 디버깅을 허용해 주십시오.' }
    'connection' { '휴대폰 연결이 끊겼습니다. 같은 휴대폰을 다시 연결해 주십시오. 케이블·USB 포트 또는 무선 연결을 확인하십시오.' }
    'encoder' { '화면을 보내는 인코더를 시작하지 못했습니다. 기기가 지원한다고 보고한 다른 인코더를 한 번 시험할 수 있습니다.' }
    'audio' { '소리 연결을 시작하지 못했습니다. 휴대폰 잠금을 풀고 다시 연결해 주십시오. 방송 전에 노트북에서 소리가 나는지 확인하십시오.' }
    default { '실행을 마치지 못했습니다. 원인을 확정할 수 없어 설정을 자동으로 바꾸지 않습니다.' }
  }
  $choices=@()
  if ($CanRetry) { $choices+=@{Key='retry';Label='연결을 확인했습니다 · 같은 설정으로 재시도'} }
  if ($CanAlternate) { $choices+=@{Key='alternate';Label='다른 인코더로 한 번 시험하기'} }
  if ($CanGuide) { $choices+=@{Key='guide';Label='도우미로 화면 다시 맞추기'} }
  $choices+=@{Key='export';Label='문제 정보 저장하고 종료';Variant='quiet'}
  return (Show-GuideChoice '화면 실행 확인' $text $choices)
}

# Full-resolution capture from the phone itself; the running mirror is not interrupted.
function Save-Screenshot ($Serial) {
  $dir=Join-Path ([Environment]::GetFolderPath('MyPictures')) 'Mirrodex'
  [void][IO.Directory]::CreateDirectory($dir)
  $path=Join-Path $dir ('Mirrodex-'+(Get-Date -Format 'yyyyMMdd-HHmmss')+'.png')
  $ok=$false
  try {
    $info=New-Object Diagnostics.ProcessStartInfo
    $info.FileName=$env:ADB; $info.Arguments="-s $Serial exec-out screencap -p"
    $info.UseShellExecute=$false; $info.CreateNoWindow=$true; $info.RedirectStandardOutput=$true
    $p=[Diagnostics.Process]::Start($info)
    try {
      $file=[IO.File]::Create($path)
      try { $p.StandardOutput.BaseStream.CopyTo($file) } finally { $file.Dispose() }
      $bytes=[IO.File]::ReadAllBytes($path)
      $ok=$p.WaitForExit(15000) -and $p.ExitCode -eq 0 -and $bytes.Length -gt 8 -and $bytes[0] -eq 0x89 -and $bytes[1] -eq 0x50
    } finally { $p.Dispose() }
  } catch { $ok=$false }
  if (-not $ok) { Remove-Item -LiteralPath $path -ErrorAction SilentlyContinue; throw '스크린샷을 저장하지 못했습니다. 휴대폰 연결을 확인해 주십시오.' }
  return $path
}

function New-RecordPath {
  $dir=Join-Path ([Environment]::GetFolderPath('MyVideos')) 'Mirrodex'
  [void][IO.Directory]::CreateDirectory($dir)
  return (Join-Path $dir ('Mirrodex-'+(Get-Date -Format 'yyyyMMdd-HHmmss')+'.mp4'))
}

function Initialize-WindowApi {
  if ('MirrodexWindow' -as [type]) { return }
  Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class MirrodexWindow {
 [StructLayout(LayoutKind.Sequential)] public struct Rect { public int Left,Top,Right,Bottom; }
 [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out Rect r);
 [DllImport("user32.dll")] public static extern bool GetClientRect(IntPtr h, out Rect r);
 [DllImport("user32.dll",CharSet=CharSet.Unicode)] public static extern bool SetWindowText(IntPtr h,string s);
 [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr h, IntPtr after, int x, int y, int cx, int cy, uint flags);
}
'@
}
function Invoke-MirrorProcess ($File, [string[]]$Arguments, [int]$TrialSeconds=0) {
  $script:MirrorBecameReady=$false
  $info=New-Object Diagnostics.ProcessStartInfo
  $info.FileName=$File
  $info.Arguments=(@($Arguments | ForEach-Object { '"'+[regex]::Replace([regex]::Replace($_,'(\\*)"','$1$1\"'),'(\\+)$','$1$1')+'"' })) -join ' '
  $info.UseShellExecute=$false; $info.CreateNoWindow=$true
  $info.RedirectStandardOutput=$true; $info.RedirectStandardError=$true
  $p=New-Object Diagnostics.Process; $p.StartInfo=$info; $started=$false
  $form=$null; $panel=$null; $request=$null; $cancelled=$false; $timer=[Diagnostics.Stopwatch]::StartNew()
  try {
    if ($TrialSeconds -gt 0) {
      Initialize-WindowApi
      $form=New-TrialForm $TrialSeconds
      $form.Show()
    } elseif ($script:SidebarEnabled -and $script:ActiveConfig -and $script:PanelDevice) {
      Initialize-WindowApi
      $panel=New-Sidebar $script:ActiveConfig $script:PanelDevice
      $area=[Windows.Forms.Screen]::FromPoint([Windows.Forms.Cursor]::Position).WorkingArea
      $panel.Height=[Math]::Min($panel.Height,$area.Height-24)
      $panel.Location=New-Object Drawing.Point(($area.Right-$panel.Width-12),($area.Top+12))
      $panel.Show()
    }
    if (-not $p.Start()) { throw '미러링 프로그램을 실행하지 못했습니다.' }
    $started=$true
    $timer.Restart()
    $stdout=$p.StandardOutput.ReadToEndAsync(); $stderr=$p.StandardError.ReadToEndAsync()
    while (-not $p.WaitForExit(200)) {
      if ($panel) {
        [Windows.Forms.Application]::DoEvents()
        if ($panel.Tag.Request) { $request=$panel.Tag.Request; break }
        $p.Refresh(); $handle=$p.MainWindowHandle
        if ($handle -and $handle -ne [IntPtr]::Zero) {
          $panel.Tag.Ready=$true
          Update-MirrorTopmost $handle
          $script:MirrorBecameReady=$true
          $r=New-Object MirrodexWindow+Rect; $c=New-Object MirrodexWindow+Rect
          if ([MirrodexWindow]::GetWindowRect($handle,[ref]$r) -and [MirrodexWindow]::GetClientRect($handle,[ref]$c) -and $r.Left -gt -30000 -and $c.Right -gt 0) {
            $script:TrialGeometry=@($r.Left,$r.Top,$c.Right,$c.Bottom)
            Move-BesideMirror $panel $handle $r
          }
        }
      }
      if ($form) {
        [Windows.Forms.Application]::DoEvents()
        if (-not $form.Visible) { $cancelled=$true; break }
        $left=[Math]::Max(0,$TrialSeconds-[int]$timer.Elapsed.TotalSeconds)
        $form.Text=T "Mirrodex · $script:TrialLabel · 약 $left 초"
        if ($form.PSObject.Properties['MxTrack']) {
          $form.MxTrack.Remaining=[float][Math]::Max(0,1-$timer.Elapsed.TotalSeconds/$TrialSeconds)
          $form.MxTrack.TimeText=T "약 $($left)초 남았습니다"; $form.MxTrack.AccessibleName=$form.MxTrack.TimeText; $form.MxTrack.Invalidate()
        }
        $p.Refresh()
        $handle=$p.MainWindowHandle
        if ($handle -and $handle -ne [IntPtr]::Zero) {
          [void][MirrodexWindow]::SetWindowText($handle,(T "Mirrodex · $script:TrialLabel · 약 $left 초"))
          $r=New-Object MirrodexWindow+Rect; $c=New-Object MirrodexWindow+Rect
          if ([MirrodexWindow]::GetWindowRect($handle,[ref]$r) -and [MirrodexWindow]::GetClientRect($handle,[ref]$c) -and $r.Left -gt -30000 -and $c.Right -gt 0) {
            $script:TrialGeometry=@($r.Left,$r.Top,$c.Right,$c.Bottom)
            # The trial window never covers the picture being judged: it waits beside the mirror, like the side menu.
            Move-BesideMirror $form $handle $r
          }
        }
        if ($timer.Elapsed.TotalSeconds -gt ($TrialSeconds+20)) { throw '시험 실행 응답 시간이 초과됐습니다.' }
      }
    }
    # A recording is only playable after scrcpy finalizes it, so allow a clean exit before killing.
    if (($cancelled -or $request) -and -not $p.HasExited) { [void]$p.CloseMainWindow(); if (-not $p.WaitForExit(10000)) { $p.Kill(); $p.WaitForExit() } }
    $p.WaitForExit()
    $result=Get-SessionSummary $p.ExitCode ($stdout.Result+"`n"+$stderr.Result)
    $result.Canceled=($cancelled -or ($TrialSeconds -gt 0 -and $result.Code -eq 0 -and $timer.Elapsed.TotalSeconds -lt ($TrialSeconds-1)))
    $result.Request=$request
    return $result
  } finally {
    if ($started -and -not $p.HasExited) { [void]$p.CloseMainWindow(); if (-not $p.WaitForExit(2000)) { $p.Kill() } }
    $p.Dispose(); if ($form) { $form.Dispose() }; if ($panel) { $panel.Dispose() }
  }
}

# Side menu and trial window sit beside the mirror window (right if there is room, else left) and follow it,
# unless the user minimized them.
function Move-BesideMirror ($Window, $Handle, $Rect) {
  if ($Window.WindowState -ne 'Normal') { return }
  $area=[Windows.Forms.Screen]::FromHandle($Handle).WorkingArea
  $x=if ($Rect.Right+$Window.Width+8 -le $area.Right) { $Rect.Right+8 } else { [Math]::Max($area.Left,$Rect.Left-$Window.Width-8) }
  $y=[Math]::Max($area.Top,[Math]::Min($Rect.Top,$area.Bottom-$Window.Height))
  if ($Window.Left -ne $x -or $Window.Top -ne $y) { $Window.StartPosition='Manual'; $Window.Location=New-Object Drawing.Point($x,$y) }
}

function Start-ResilientMirror ($Scrcpy, $Adb, $Config, $Serial) {
  $active=$Config; $alternateUsed=$false; $rollback=$null
  for ($attempt=0; $attempt -lt 3; $attempt++) {
    try {
      Restore-Refresh $Adb $Serial
      $script:LastSession=$null
      Start-Mirror $Scrcpy $Adb $active $Serial
      if ($script:LastSession -and $script:LastSession.Request) {
        $rollback=$active.Clone()
        if ($script:LastSession.Request.Kind -eq 'record') { $script:Recording=-not $script:Recording }
        elseif ($script:LastSession.Request.Kind -eq 'source') { $script:Source=$script:LastSession.Request.Source }
        elseif ($script:LastSession.Request.Kind -eq 'serial') {
          # Same phone, now over Wi-Fi: keep its lock under the new address too.
          $Serial=$script:LastSession.Request.Serial; [void](Lock-Device $Serial)
          $active=$active.Clone(); $active.serial=$Serial; $rollback=$null
        }
        elseif ($script:LastSession.Request.Kind -eq 'guide') {
          # The assistant runs its own trials; closing it midway keeps mirroring with the current settings.
          $rollback=$null
          try { $tuned=Invoke-Guide $Scrcpy $Adb $active $script:PanelDevice $Serial; if ($tuned) { $active=$tuned } }
          catch [OperationCanceledException] { }
        }
        else { $active=$script:LastSession.Request.Config }
        $attempt=-1; continue
      }
      if ($alternateUsed) {
        $answer=Show-GuideChoice '다른 인코더는 어떠셨습니까?' '화면이 실제로 잘 보이고 움직임도 편했을 때만 저장하십시오.' @(@{Key='keep';Label='기존 설정 유지'},@{Key='save';Label='잘 동작했습니다 · 새 설정 저장'})
        if ($answer -eq 'save') { Save-Config $active }
      }
      return
    } catch [OperationCanceledException] { throw }
    catch {
      if ($rollback -and -not $script:MirrorBecameReady) {
        [void](Show-GuideChoice '변경한 설정을 실행하지 못했습니다' '저장된 설정은 바꾸지 않았습니다. 변경 전 화면으로 돌아갑니다.' @(@{Key='back';Label='변경 전 설정으로 다시 열기'}))
        $active=$rollback; $rollback=$null; $script:Recording=$false; $script:Source=@{Kind='screen'}; $attempt=-1; continue
      }
      $rollback=$null
      $kind=$_.Exception.Data['Kind']; if (-not $kind) { $kind='unknown' }
      $alt=$null
      if ($kind -eq 'encoder' -and -not $alternateUsed -and $attempt -lt 2) { $alt=Get-AlternativeEncoder $active (Inspect-Device $Adb $Scrcpy $Serial) }
      $action=Get-RecoveryChoice $kind ([bool]$alt) ($attempt -lt 2) -CanGuide
      if ($action -eq 'export') { Show-Diagnostics $active; return }
      # The side menu is unreachable while mirroring cannot start, so the assistant is offered here instead.
      if ($action -eq 'guide') { $tuned=Invoke-Guide $Scrcpy $Adb $active $script:PanelDevice $Serial; if ($tuned) { $active=$tuned }; $attempt=-1; continue }
      if ($action -eq 'alternate') { $active=$alt; $alternateUsed=$true }
      else { [void](Connect-Device $Adb $Serial -RequirePreferred) }
    }
  }
}

# ---- What to show: whole screen, one app on its own virtual display, or a camera --------------------
function Get-SourceOptions ($Source, [string[]]$Options) {
  switch ($Source.Kind) {
    # A separate display shows only this app: notifications and other apps stay on the phone.
    'app' { return @($Options) + @('--new-display', "--start-app=$($Source.Package)") }
    'camera' {
      # The phone screen stays on for the camera; audio switches to the microphone like a webcam.
      $camera=@($Options | Where-Object { $_ -notin @('--turn-screen-off','--stay-awake') } | ForEach-Object { if ($_ -eq '--audio-source=output') {'--audio-source=mic'} else {$_} })
      return $camera + @('--video-source=camera', "--camera-facing=$($Source.Facing)")
    }
    default { return @($Options) }
  }
}
function Get-DeviceApps ($Scrcpy, $Serial) {
  $result=Invoke-Tool $Scrcpy @("--serial=$Serial",'--list-apps') 45000
  $apps=foreach ($line in ($result.Text -split '\r?\n')) {
    if ($line -match '^\s*([*-])\s+(.+?)\s{2,}([A-Za-z][A-Za-z0-9_]*(?:\.[A-Za-z0-9_]+)+)\s*$') {
      [pscustomobject]@{Label=$Matches[2].Trim(); Package=$Matches[3]; System=($Matches[1] -eq '-')}
    }
  }
  if (-not $apps) { throw '앱 목록을 불러오지 못했습니다. 휴대폰 잠금을 풀고 다시 시도해 주십시오.' }
  return @($apps | Sort-Object System,Label)
}
function Select-MirrorSource ($Button, $Status, $Serial) {
  $kinds=@(
    @{Key='screen';Label='휴대폰 화면 전체';Detail='지금처럼 휴대폰 화면을 그대로 보여 줍니다'},
    @{Key='app';Label='앱 하나만';Detail='방송용 · 알림과 다른 앱은 보이지 않습니다 (Android 10 이상)'},
    @{Key='back';Label='후면 카메라';Detail='휴대폰 카메라를 PC 화면에 띄웁니다 (Android 12 이상)'},
    @{Key='front';Label='전면 카메라';Detail='휴대폰 카메라를 PC 화면에 띄웁니다 (Android 12 이상)'})
  $current=if ($script:Source.Kind -eq 'camera') { $script:Source.Facing } else { [string]$script:Source.Kind }
  $kind=Show-GuidePicker '보여줄 화면을 고르십시오' '바꾸면 화면이 잠시 다시 연결됩니다. 카메라는 PC 마이크 대신 휴대폰 마이크 소리를 씁니다.' $kinds '이 화면 보여 주기' -Selected $current
  if (-not $kind) { return $null }
  switch ($kind) {
    'screen' { return @{Kind='screen'} }
    'back' { return @{Kind='camera';Facing='back'} }
    'front' { return @{Kind='camera';Facing='front'} }
    'app' {
      $apps=$null
      Invoke-UiBusy $Button $Status '앱 목록을 불러오는 중입니다…' { $script:LoadedApps=Get-DeviceApps $script:EnginePath $Serial }
      $apps=$script:LoadedApps
      Set-UiStatus $Status ''
      $items=@($apps | ForEach-Object { @{Key=$_.Package;Label=$_.Label;Detail=$_.Package} })
      $package=Show-GuidePicker '방송할 앱을 고르십시오' '고른 앱만 새 화면에 열립니다. 휴대폰 알림과 다른 앱은 보이지 않습니다.' $items '이 앱만 보여 주기' -Search -Selected ([string]$script:Source.Package)
      if (-not $package) { return $null }
      return @{Kind='app';Package=$package;Label=@($apps | Where-Object { $_.Package -eq $package })[0].Label}
    }
  }
}

# ---- Wireless ----------------------------------------------------------------------------------------
function Test-WirelessSerial ($Serial) { return ([string]$Serial -match ':|_adb-tls-connect') }
function Find-AdbService ($Adb, $Type) {
  $result=Invoke-Tool $Adb @('mdns','services') 10000
  foreach ($line in ($result.Text -split '\r?\n')) { if ($line -match "$Type\._tcp\.?\s+(\d{1,3}(?:\.\d{1,3}){3}:\d{2,5})") { return $Matches[1] } }
  return ''
}
function Test-DeviceReady ($Adb, $Serial) { return [bool]@(Get-Devices $Adb | Where-Object { $_.Serial -eq $Serial -and $_.State -eq 'device' }).Count }
# Cable to Wi-Fi: the phone listens on TCP 5555 until it restarts. Works on every Android version.
function Switch-ToWireless ($Adb, $Serial) {
  $address=Invoke-Tool $Adb @('-s',$Serial,'shell','ip','-f','inet','addr','show','wlan0')
  if ($address.Text -notmatch 'inet (\d{1,3}(?:\.\d{1,3}){3})') { throw '휴대폰이 Wi-Fi에 연결되어 있지 않습니다. 휴대폰과 PC를 같은 Wi-Fi에 연결해 주십시오.' }
  $target="$($Matches[1]):5555"
  $listen=Invoke-Tool $Adb @('-s',$Serial,'tcpip','5555')
  if ($listen.Code -ne 0) { throw '휴대폰을 무선 연결 모드로 바꾸지 못했습니다. 휴대폰 잠금을 풀고 다시 시도해 주십시오.' }
  for ($try=0; $try -lt 6; $try++) {
    Start-Sleep -Milliseconds 800; [Windows.Forms.Application]::DoEvents()
    [void](Invoke-Tool $Adb @('connect',$target))
    if (Test-DeviceReady $Adb $target) { return $target }
  }
  throw '무선 연결에 실패했습니다. 휴대폰과 PC가 같은 Wi-Fi에 있는지 확인해 주십시오.'
}
# No cable at all (Android 11+): pair once with the code shown under Wireless debugging, then connect.
function Invoke-WirelessPairing ($Adb) {
  $ready=Show-GuideChoice '무선으로 연결하기' "1. 휴대폰과 PC를 같은 Wi-Fi에 연결하십시오.`n2. 휴대폰 설정 > 개발자 옵션에서 '무선 디버깅'을 켜십시오.`n3. '무선 디버깅'을 눌러 들어간 뒤 '페어링 코드로 기기 페어링'을 누르십시오.`n`n휴대폰에 6자리 코드와 IP 주소·포트가 나타나면 다음으로 넘어가십시오." @(@{Key='next';Label='코드가 보입니다 · 다음';Icon='wifi'},@{Key='cable';Label='케이블로 연결하기'})
  if ($ready -ne 'next') { return $null }
  $address=Find-AdbService $Adb '_adb-tls-pairing'; $code=''
  while ($true) {
    $values=Show-GuideInput '페어링 코드 입력' '휴대폰 화면에 보이는 값을 그대로 입력하십시오. 찾은 주소가 있으면 미리 채워 두었습니다.' @(
      @{Key='address';Label='IP 주소 및 포트';Value=$address;Placeholder='192.168.0.10:37123'},
      @{Key='code';Label='Wi-Fi 페어링 코드';Value=$code;Placeholder='6자리 숫자'}) '페어링하고 연결하기'
    if (-not $values) { return $null }
    $address=$values.address; $code=$values.code
    $problem=if ($address -notmatch '^\d{1,3}(\.\d{1,3}){3}:\d{2,5}$') { 'IP 주소와 포트를 192.168.0.10:37123 형식으로 입력해 주십시오.' }
      elseif ($code -notmatch '^\d{6}$') { '페어링 코드는 숫자 6자리입니다.' }
      else {
        $pair=Invoke-Tool $Adb @('pair',$address,$code) 30000
        if ($pair.Text -notmatch 'Successfully paired') { '페어링하지 못했습니다. 코드가 바뀌었을 수 있습니다. 휴대폰의 새 코드와 주소로 다시 입력해 주십시오.' }
      }
    if ($problem) { [void](Show-GuideChoice '다시 확인해 주십시오' $problem @(@{Key='retry';Label='다시 입력하기'})); continue }
    break
  }
  # Paired phones announce their connect address; fall back to asking for it.
  $host_=($address -split ':')[0]
  for ($try=0; $try -lt 8; $try++) {
    $connect=Find-AdbService $Adb '_adb-tls-connect'
    if ($connect -like "$host_`:*") { [void](Invoke-Tool $Adb @('connect',$connect)); if (Test-DeviceReady $Adb $connect) { return $connect } }
    $auto=@(Get-Devices $Adb | Where-Object { $_.State -eq 'device' -and ($_.Serial -like "$host_`:*" -or $_.Serial -like '*_adb-tls-connect*') })
    if ($auto.Count) { return $auto[0].Serial }
    Start-Sleep -Milliseconds 700
  }
  $values=Show-GuideInput '연결 주소 입력' "페어링했습니다. 무선 디버깅 화면 맨 위의 'IP 주소 및 포트'를 입력하십시오. 페어링 때와 포트가 다릅니다." @(@{Key='address';Label='IP 주소 및 포트';Value="$host_`:";Placeholder='192.168.0.10:41235'}) '연결하기'
  if (-not $values -or $values.address -notmatch '^\d{1,3}(\.\d{1,3}){3}:\d{2,5}$') { return $null }
  [void](Invoke-Tool $Adb @('connect',$values.address))
  if (Test-DeviceReady $Adb $values.address) { return $values.address }
  throw '무선 연결에 실패했습니다. 휴대폰과 PC가 같은 Wi-Fi에 있는지 확인해 주십시오.'
}

# ---- Several phones: one Mirrodex process per phone, guarded by a per-device lock -------------------
function Get-DeviceMutexName ($Serial) { return 'Local\Mirrodex.Device.' + ([string]$Serial -replace '[\\/]', '_') }
function Test-DeviceInUse ($Serial) {
  if ($script:DeviceLocks -and $script:DeviceLocks.ContainsKey($Serial)) { return $false }
  try { $m=[Threading.Mutex]::OpenExisting((Get-DeviceMutexName $Serial)); $m.Dispose(); return $true } catch { return $false }
}
function Lock-Device ($Serial) {
  if (-not $script:DeviceLocks) { $script:DeviceLocks=@{} }
  if ($script:DeviceLocks.ContainsKey($Serial)) { return $true }
  $mutex=New-Object Threading.Mutex($false,(Get-DeviceMutexName $Serial))
  $owned=$false
  try { $owned=$mutex.WaitOne(0) } catch [Threading.AbandonedMutexException] { $owned=$true }
  if (-not $owned) { $mutex.Dispose(); return $false }
  $script:DeviceLocks[$Serial]=$mutex; return $true
}
function Unlock-Devices {
  if (-not $script:DeviceLocks) { return }
  foreach ($mutex in $script:DeviceLocks.Values) { try { $mutex.ReleaseMutex() } catch {}; $mutex.Dispose() }
  $script:DeviceLocks=@{}
}
function Start-AdditionalDevice {
  $entry=Join-Path $Root 'mirrodex.ps1'
  Start-Process -FilePath (Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe') -WindowStyle Hidden -ArgumentList @('-NoLogo','-NoProfile','-ExecutionPolicy','Bypass','-WindowStyle','Hidden','-File',"`"$entry`"",'add')
  return '다른 휴대폰의 연결 창을 여는 중입니다. 휴대폰을 케이블이나 무선으로 연결하십시오.'
}
# ---- Always on top -----------------------------------------------------------------------------------
function Set-AlwaysOnTop ([bool]$On) { $script:AlwaysOnTop=$On; Set-UiPreference 'ontop' ([int]$On) }
function Update-MirrorTopmost ($Handle) {
  if ($Handle -eq $script:TopHandle -and $script:AlwaysOnTop -eq $script:TopApplied) { return }
  [void][MirrodexWindow]::SetWindowPos($Handle,[IntPtr]$(if ($script:AlwaysOnTop) {-1} else {-2}),0,0,0,0,0x13)
  $script:TopHandle=$Handle; $script:TopApplied=$script:AlwaysOnTop
}
