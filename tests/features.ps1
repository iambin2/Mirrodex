$ErrorActionPreference='Stop'
. (Join-Path (Split-Path $PSScriptRoot) 'mirrodex.ps1')
$script:checks=0
function Assert ($Value,$Message) { if (-not $Value) { throw $Message }; $script:checks++ }
$temp=Join-Path ([IO.Path]::GetTempPath()) ('mirrodex-features-'+[guid]::NewGuid().ToString('N'))
[void][IO.Directory]::CreateDirectory($temp)
$script:PreferencesFile=Join-Path $temp 'preferences.cfg'; $script:UiPreferences=$null
$base=@('--serial=T','--window-title=Mirrodex','--audio-source=output','--turn-screen-off','--stay-awake','--disable-screensaver')
try {
  # What to show.
  Assert ((@(Get-SourceOptions @{Kind='screen'} $base) -join ' ') -eq ($base -join ' ')) 'whole screen keeps options unchanged'
  $app=@(Get-SourceOptions @{Kind='app';Package='com.example.game'} $base)
  Assert ($app -contains '--new-display' -and $app -contains '--start-app=com.example.game' -and $app -contains '--turn-screen-off') 'one app runs on its own display'
  $camera=@(Get-SourceOptions @{Kind='camera';Facing='front'} $base)
  Assert ($camera -contains '--video-source=camera' -and $camera -contains '--camera-facing=front' -and $camera -contains '--audio-source=mic') 'camera uses the phone camera and microphone'
  Assert ($camera -notcontains '--turn-screen-off' -and $camera -notcontains '--stay-awake' -and $camera -notcontains '--audio-source=output') 'camera drops options the engine rejects for it'
  function Invoke-MirrorProcess ($File,$Arguments,$TrialSeconds) { $script:passed=$Arguments; return @{Code=0;Kind='unknown';Canceled=$false} }
  function Restore-Refresh { }
  $c=@{codec='h264';encoder='';size='1024';rate='8M';buffer='50';fps='60';arr='0';serial='T';audio='output';audiobuffer='50';requireaudio='0'}
  $script:Source=@{Kind='app';Package='com.example.game';Label='Game'}
  Start-Mirror 'engine' 'adb' $c 'T'
  Assert ($script:passed -contains '--start-app=com.example.game') 'real session shows the chosen app'
  Start-Mirror 'engine' 'adb' $c 'T' 30
  Assert ($script:passed -notcontains '--new-display') 'comparison trials always use the whole screen'
  $script:Source=@{Kind='screen'}

  # App list parsing: user apps first, system apps after, each alphabetically.
  function Invoke-Tool ($File,$Arguments,$Timeout) { return @{Code=0;Text="[server] INFO: List of apps:`n - Settings                       com.android.settings`n * YouTube                        com.google.android.youtube`n * Among Us                       com.innersloth.spacemafia`nnoise line"} }
  $apps=@(Get-DeviceApps 'engine' 'T')
  Assert ($apps.Count -eq 3 -and $apps[0].Label -eq 'Among Us' -and $apps[1].Package -eq 'com.google.android.youtube' -and $apps[2].System) 'app list parsed and ordered'
  function Invoke-Tool ($File,$Arguments,$Timeout) { return @{Code=0;Text='nothing'} }
  $failed=$false; try { [void](Get-DeviceApps 'engine' 'T') } catch { $failed=$_.Exception.Message -eq '앱 목록을 불러오지 못했습니다. 휴대폰 잠금을 풀고 다시 시도해 주십시오.' }
  Assert $failed 'empty app list explains the recovery'

  # Cable to Wi-Fi.
  $script:tcpip=$false
  function Invoke-Tool ($File,$Arguments,$Timeout) {
    $joined=$Arguments -join ' '
    if ($joined -like '*addr show wlan0*') { return @{Code=0;Text='    inet 192.168.0.23/24 brd 192.168.0.255 scope global wlan0'} }
    if ($joined -like '*tcpip 5555') { $script:tcpip=$true; return @{Code=0;Text='restarting in TCP mode port: 5555'} }
    return @{Code=0;Text='connected'}
  }
  function Get-Devices ($Adb) { if ($script:tcpip) { @{Serial='192.168.0.23:5555';State='device';Detail='model:Phone'} } }
  Assert ((Switch-ToWireless 'adb' 'USB1') -eq '192.168.0.23:5555') 'cable connection switches to Wi-Fi on port 5555'
  function Invoke-Tool ($File,$Arguments,$Timeout) { return @{Code=0;Text='no address'} }
  $failed=$false; try { [void](Switch-ToWireless 'adb' 'USB1') } catch { $failed=$_.Exception.Message -like '*Wi-Fi*' }
  Assert $failed 'phone without Wi-Fi gets a clear message'
  Assert ((Test-WirelessSerial '192.168.0.23:5555') -and (Test-WirelessSerial 'adb-X._adb-tls-connect._tcp') -and -not (Test-WirelessSerial 'SERIAL0001')) 'wireless serials recognized'

  # Pairing with a code: invalid input is re-asked, then pairing and the announced connect address are used.
  $script:inputs=New-Object 'Collections.Generic.Queue[object]'
  $script:inputs.Enqueue(@{address='192.168.0.23:37000';code='12'}); $script:inputs.Enqueue(@{address='192.168.0.23:37000';code='123456'})
  $script:prompts=@(); $realChoice=${function:Show-GuideChoice}; $realInput=${function:Show-GuideInput}
  function Show-GuideChoice ($Title,$Text,$Choices) { $script:prompts+=$Title; return $Choices[0].Key }
  function Show-GuideInput ($Title,$Text,$Fields,$Action) { $script:lastFields=$Fields; return $script:inputs.Dequeue() }
  $script:paired=$false
  function Invoke-Tool ($File,$Arguments,$Timeout) {
    switch ($Arguments[0]) {
      'mdns' { if ($script:paired) { return @{Code=0;Text="List of discovered mdns services`nadb-X	_adb-tls-connect._tcp	192.168.0.23:41235"} } else { return @{Code=0;Text="List of discovered mdns services`nadb-X	_adb-tls-pairing._tcp	192.168.0.23:37000"} } }
      'pair' { $script:paired=($Arguments[2] -eq '123456'); return @{Code=0;Text='Successfully paired to 192.168.0.23:37000'} }
      default { return @{Code=0;Text='connected'} }
    }
  }
  function Get-Devices ($Adb) { if ($script:paired) { @{Serial='192.168.0.23:41235';State='device';Detail='model:Phone'} } }
  Assert ((Invoke-WirelessPairing 'adb') -eq '192.168.0.23:41235') 'pairing code connects without a cable'
  Assert ($script:prompts -contains '다시 확인해 주십시오' -and $script:lastFields[0].Value -eq '192.168.0.23:37000') 'wrong code is re-asked with the discovered address kept'
  function Show-GuideChoice ($Title,$Text,$Choices) { return 'cable' }
  Assert ($null -eq (Invoke-WirelessPairing 'adb')) 'choosing a cable leaves pairing without side effects'
  Set-Item function:Show-GuideChoice $realChoice; Set-Item function:Show-GuideInput $realInput

  # One process per phone.
  Assert ((Lock-Device 'LOCKTEST') -and -not (Test-DeviceInUse 'LOCKTEST')) 'own phone is not reported busy to itself'
  $probe="try { [Threading.Mutex]::OpenExisting('$(Get-DeviceMutexName 'LOCKTEST')').Dispose(); 'busy' } catch { 'free' }"
  Assert ((& powershell -NoProfile -Command $probe) -eq 'busy') 'other Mirrodex processes see the phone as busy'
  Unlock-Devices
  Assert ((& powershell -NoProfile -Command $probe) -eq 'free') 'lock released when the session ends'
  function Get-Devices ($Adb) { @{Serial='BUSY';State='device';Detail='model:A'}; @{Serial='FREE';State='device';Detail='model:B'} }
  function Test-DeviceInUse ($Serial) { return ($Serial -eq 'BUSY') }
  Assert ((Connect-Device 'adb' 'BUSY') -eq 'FREE') 'a phone mirrored elsewhere is skipped'

  # Always on top: remembered per PC and applied to the mirror window handle.
  Set-AlwaysOnTop $true
  $script:UiPreferences=$null
  Assert ((Get-UiPreference 'ontop' '0') -eq '1') 'always-on-top choice persists'
  Add-Type -Name WinStyle -Namespace MxTest -MemberDefinition '[DllImport("user32.dll")] public static extern int GetWindowLong(IntPtr h, int i);'
  $window=New-Object Windows.Forms.Form; $window.Show()
  try {
    Update-MirrorTopmost $window.Handle
    Assert (([MxTest.WinStyle]::GetWindowLong($window.Handle,-20) -band 8) -ne 0) 'mirror window becomes topmost'
    Set-AlwaysOnTop $false; Update-MirrorTopmost $window.Handle
    Assert (([MxTest.WinStyle]::GetWindowLong($window.Handle,-20) -band 8) -eq 0) 'turning it off releases topmost'
  } finally { $window.Dispose() }

  # Screenshot: the phone's PNG is stored byte for byte; output that is not a PNG is refused.
  $shot=Join-Path $temp 'shot.png'; $bitmap=New-Object Drawing.Bitmap(4,4); $bitmap.Save($shot); $bitmap.Dispose()
  [IO.File]::WriteAllText((Join-Path $temp 'shot.txt'),'error: device offline')
  $fakeAdb=Join-Path $temp 'adb.cmd'
  [IO.File]::WriteAllText($fakeAdb,"@powershell -NoProfile -Command `"`$b=[IO.File]::ReadAllBytes('%~dp0%MX_SHOT%'); [Console]::OpenStandardOutput().Write(`$b,0,`$b.Length)`"`r`n")
  $realAdb=$env:ADB; $env:ADB=$fakeAdb
  try {
    $env:MX_SHOT='shot.png'; $saved=Save-Screenshot 'T'
    try { Assert ((Get-FileHash $saved).Hash -eq (Get-FileHash $shot).Hash) 'screenshot stores the phone picture unchanged' } finally { Remove-Item -LiteralPath $saved }
    $env:MX_SHOT='shot.txt'; $failed=$false; try { [void](Save-Screenshot 'T') } catch { $failed=$true }
    Assert ($failed -and -not (Test-Path -LiteralPath $saved)) 'output that is not a PNG is refused and leaves no file'
  } finally { $env:ADB=$realAdb; Remove-Item Env:MX_SHOT }

  # Picker search and input form.
  $items=@(@{Key='a';Label='Among Us';Detail='com.innersloth'},@{Key='y';Label='YouTube';Detail='com.google.youtube'},@{Key='s';Label='Settings';Detail='com.android.settings'})
  $picker=New-GuidePicker '방송할 앱을 고르십시오' '고른 앱만 새 화면에 열립니다. 휴대폰 알림과 다른 앱은 보이지 않습니다.' $items '이 앱만 보여 주기' -Search
  try {
    $picker.Show(); [Windows.Forms.Application]::DoEvents()
    $layout=$picker.MxLayout; $search=@($layout.Controls | Where-Object { $_.PSObject.Properties['Input'] })[0].Input
    $search.Text='tube'; [Windows.Forms.Application]::DoEvents()
    Assert ($picker.MxList.Items.Count -eq 1 -and @($picker.MxList.MxVisible)[0].Key -eq 'y') 'search narrows the list by name or package'
    Assert ($picker.CancelButton -and $picker.AcceptButton) 'picker has Enter to pick and Esc to close'
  } finally { $picker.Dispose() }
  $timer=New-Object Windows.Forms.Timer; $timer.Interval=150
  $timer.Add_Tick({
    foreach ($f in @([Windows.Forms.Application]::OpenForms)) {
      if ($f.PSObject.Properties['MxGuide'] -and $f.Visible) {
        $boxes=@($f.MxLayout.Controls | Where-Object { $_.PSObject.Properties['Input'] } | ForEach-Object { $_.Input })
        $boxes[0].Text=' 192.168.0.9:5555 '; $boxes[1].Text='654321'; $timer.Stop(); $f.AcceptButton.PerformClick()
      }
    }
  })
  $timer.Start()
  try { $values=Show-GuideInput '페어링 코드 입력' '휴대폰 화면에 보이는 값을 그대로 입력하십시오. 찾은 주소가 있으면 미리 채워 두었습니다.' @(@{Key='address';Label='IP 주소 및 포트'},@{Key='code';Label='Wi-Fi 페어링 코드'}) '페어링하고 연결하기' } finally { $timer.Dispose() }
  Assert ($values.address -eq '192.168.0.9:5555' -and $values.code -eq '654321') 'input form returns trimmed values'

  # Earlier versions' separate assistant shortcut is removed only when it points to this Mirrodex.
  $legacy=Join-Path $temp 'legacy'; [void][IO.Directory]::CreateDirectory($legacy)
  $other=Join-Path $temp 'other'; [void][IO.Directory]::CreateDirectory($other)
  Set-Shortcut (Join-Path $legacy 'Mirrodex 도우미.lnk') (Join-Path $Root 'Mirrodex.bat') 'guide' $Root 'old'
  Set-Shortcut (Join-Path $other 'Mirrodex 도우미.lnk') (Join-Path $temp 'Somewhere\Mirrodex.bat') 'guide' $temp 'foreign'
  Remove-LegacyAssistantShortcut @($legacy,$other)
  Assert (-not (Test-Path (Join-Path $legacy 'Mirrodex 도우미.lnk')) -and (Test-Path (Join-Path $other 'Mirrodex 도우미.lnk'))) 'old assistant shortcut removed, unrelated shortcuts kept'

  # Mirroring that cannot start offers the assistant, since the side menu never appears.
  $script:starts=0; $script:guided=$false
  function Start-Mirror ($Scrcpy,$Adb,$Config,$Serial) { $script:starts++; $script:LastSession=$null; if ($Config.size -ne '800') { $e=[Exception]::new('boom'); $e.Data['Kind']='unknown'; throw $e } }
  function Show-GuideChoice ($Title,$Text,$Choices) { if (@($Choices | Where-Object { $_.Key -eq 'guide' }).Count) { return 'guide' }; return $Choices[0].Key }
  function Invoke-Guide ($Scrcpy,$Adb,$Current,$Device,$Serial) { $script:guided=$true; $t=$Current.Clone(); $t.size='800'; return $t }
  function Restore-Refresh { }
  Start-ResilientMirror 'engine' 'adb' $c 'T'
  Assert ($script:guided -and $script:starts -eq 2) 'start failure leads to the assistant, then mirroring with its result'
  Set-Item function:Show-GuideChoice $realChoice

  # Install and remove, entirely inside a temporary Programs folder (no registry in tests).
  $paths=@{Dir=(Join-Path $temp 'Programs\Mirrodex'); StartMenu=(Join-Path $temp 'Start\Mirrodex'); Desktop=(Join-Path $temp 'Desktop'); Registry=$null}
  [void][IO.Directory]::CreateDirectory($paths.Desktop)
  Install-Mirrodex (Split-Path $PSScriptRoot) $paths -Quiet
  Assert ((Test-Path (Join-Path $paths.Dir 'engine\mirrodex-engine.exe')) -and (Test-Path (Join-Path $paths.Dir 'mirrodex.ps1'))) 'program and engine installed'
  Assert (-not (Test-Path (Join-Path $paths.Dir 'tests')) -and -not @(Get-ChildItem $paths.Dir -Filter 'backup-*').Count) 'tests and backups are not installed'
  $link=(New-Object -ComObject WScript.Shell).CreateShortcut((Join-Path $paths.StartMenu 'Mirrodex.lnk'))
  Assert ($link.TargetPath -eq (Join-Path $paths.Dir 'Mirrodex.bat') -and (Test-Path (Join-Path $paths.Desktop 'Mirrodex.lnk'))) 'Start menu and desktop shortcuts point to the installed copy'
  Assert (-not (Test-Path (Join-Path $paths.Desktop 'Mirrodex 도우미.lnk')) -and -not (Test-Path (Join-Path $paths.StartMenu 'Mirrodex 도우미.lnk'))) 'one Mirrodex icon: no separate assistant shortcut'
  Assert (-not (Test-InstallDirectory $temp) -and (Test-InstallDirectory $paths.Dir)) 'removal is limited to a Programs\Mirrodex folder'
  Uninstall-Mirrodex $paths -Quiet
  for ($i=0; $i -lt 40 -and (Test-Path $paths.Dir); $i++) { Start-Sleep -Milliseconds 250 }
  Assert (-not (Test-Path $paths.Dir) -and -not (Test-Path (Join-Path $paths.Desktop 'Mirrodex.lnk')) -and -not (Test-Path $paths.StartMenu)) 'uninstall removes program folder and shortcuts'

  # Every start asks the phone for its details once (listing encoders starts the engine on the phone) and hands that
  # same answer to the session. Order: first start without settings, saved settings, tune, assistant.
  $Root=$temp; $Cfg=Join-Path $temp 'mirrodex.cfg'; $Recovery=Join-Path $temp 'refresh-recovery.cfg'

  # The encoder list is asked from the phone once per system build and Mirrodex version, then read from profiles\.
  $script:build='samsung/x/x:16/AB1/1:user/release-keys'; $script:listed=0
  function Invoke-Tool ($File,$Arguments,$Timeout) {
    if ($Arguments -contains '--list-encoders') { $script:listed++; return @{Code=0;Text="INFO: -->   (usb)  SERIAL0001   device`n[server] INFO: List of video encoders:`n    --video-codec=h264 --video-encoder=vendor.avc (hw)`n    --audio-codec=opus --audio-encoder=c2.android.opus.encoder (sw)"} }
    return @{Code=0;Text="Phone`nfp=$script:build`nPhysical size: 1080x2340"}
  }
  $first=Inspect-Device 'adb' 'engine' 'T'; $second=Inspect-Device 'adb' 'engine' 'T'
  Assert ($script:listed -eq 1 -and (Get-Encoder $second.Encoders 'h264') -eq 'vendor.avc' -and $second.Long -eq 2340) 'the encoder list is asked once, then remembered'
  $kept=Get-Content (Get-ChildItem (Join-Path $temp 'profiles') -Filter 'encoders-*.txt').FullName -Raw
  Assert ($kept -match 'audio-encoder' -and $kept -notmatch 'SERIAL0001') 'only encoder lines are stored, never the serial number'
  [void](Inspect-Device 'adb' 'engine' 'T' -Fresh)
  Assert ($script:listed -eq 2) 'diagnostics and encoder recovery ask the phone again'
  $script:build='samsung/x/x:17/CD2/2:user/release-keys'; [void](Inspect-Device 'adb' 'engine' 'T')
  $version=$script:AppVersion; $script:AppVersion='0.0.0'; [void](Inspect-Device 'adb' 'engine' 'T'); $script:AppVersion=$version
  Assert ($script:listed -eq 4) 'a system update or a new Mirrodex version asks again'
  $script:build=''; [void](Inspect-Device 'adb' 'engine' 'T'); [void](Inspect-Device 'adb' 'engine' 'T')
  Assert ($script:listed -eq 6) 'a phone that reports no build is asked every time'

  function Invoke-StartupUpdateCheck { $false }
  function Remove-LegacyAssistantShortcut { }
  function New-DesktopShortcut { }
  function Get-Scrcpy { Join-Path $temp 'engine\mirrodex-engine.exe' }
  function Connect-Device ($Adb,$Preferred) { 'T' }
  function Initialize-Context ($Adb,$Serial) { $script:Context=@{Key='k';Label='usb';Directory=(Join-Path $temp 'profiles\k')} }
  function Inspect-Device ($Adb,$Scrcpy,$Serial) { $script:inspections++; @{Model='Phone';Long=2340;Short=1080;Encoders='--video-codec=h264 --video-encoder=vendor.avc (hw)'} }
  function Invoke-Guide ($Scrcpy,$Adb,$Current,$Device,$Serial) { Get-QuickStartConfig $Device $Serial }
  function Invoke-Tuning ($Scrcpy,$Adb,$Config,$Device,$Serial) { $Config }
  function Start-ResilientMirror ($Scrcpy,$Adb,$Config,$Serial) { $script:sessionDevice=$script:PanelDevice; $script:sessionConfig=$Config }
  foreach ($Mode in 'run','run','tune','guide') {
    $script:inspections=0; $script:sessionDevice=$null
    Main
    Assert ($script:inspections -eq 1 -and $script:sessionDevice.Long -eq 2340 -and $script:sessionConfig.encoder -eq 'vendor.avc') "one device inspection per start, shared with the session ($Mode)"
  }
  Write-Output "PASS: $script:checks feature checks ($($PSVersionTable.PSVersion))"
} finally {
  Unlock-Devices
  if ((Split-Path $temp -Leaf) -like 'mirrodex-features-*') { Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue }
}
