$ErrorActionPreference='Stop'
. (Join-Path (Split-Path $PSScriptRoot) 'mirrodex.ps1')
$testRoot=Join-Path ([IO.Path]::GetTempPath()) ('mirrodex-sidebar-'+[guid]::NewGuid().ToString('N'))
[void][IO.Directory]::CreateDirectory($testRoot)
$Cfg=Join-Path $testRoot 'mirrodex.cfg'; $Root=$testRoot
$script:PreferencesFile=Join-Path $testRoot 'preferences.cfg'; $script:UiPreferences=$null
$c=@{codec='h265';encoder='vendor.hevc';size='2340';rate='8M';fps='60';buffer='50';arr='1';serial='TEST';audio='output';audiobuffer='50';requireaudio='0'}
$device=@{Model='SM-S948N';Long=2340;Encoders="--video-codec=h264 --video-encoder=vendor.avc (hw)`n--video-codec=h265 --video-encoder=vendor.hevc (hw)"}
$script:checks=0
function Assert ($Value,$Message) { if (-not $Value) { throw $Message }; $script:checks++ }
$form=$null
try {
  Write-Pairs $Cfg $c; Save-Profile 'good' $c
  $before=(Get-FileHash $Cfg).Hash
  # Both languages: the folded menu fits a 1200px screen at 125% and no key label is cut off (English runs longest).
  foreach ($lang in 'ko','en') {
    Set-UiLanguage $lang; $script:SidebarExpanded=$false
    $folded=New-Sidebar $c $device; $folded.Show(); [Windows.Forms.Application]::DoEvents()
    $g=[MxTheme]::Measure(); $px=$g.DpiX/96
    $fs=$folded.Tag
    Assert (-not $fs.Settings.Visible -and $fs.Record.Visible -and $fs.Screenshot.Visible) "quick actions visible, engine settings folded by default ($lang)"
    Assert (-not $folded.MxLayout.Parent.VerticalScroll.Visible -and $folded.MxLayout.Bottom -le $folded.MxLayout.Parent.ClientSize.Height) "folded menu fits without scrolling ($lang)"
    $cut=@(foreach ($key in @($fs.Record,$fs.AutoRecord,$fs.Mark,$fs.Screenshot,$fs.OnTop,$fs.Lock)) {
      $room=$key.Width-$(if ($key -is [MxToggle] -or $key.Lamp -ge 0 -or $key.Reconnects) {66} else {50})*$px
      $parts=[MxPaint]::Split($key.Text)
      if ([MxTheme]::Width($g,$parts[0],$key.Font) -gt $room -or [MxTheme]::Width($g,$parts[1],$key.DetailFont) -gt $room) { $key.Text }
    })
    Assert ($cut.Count -eq 0) "key labels fit without truncation ($lang): $($cut -join ', ')"
    $g.Dispose()
    if ($lang -eq 'ko') { $folded.Dispose() }
  }
  # Text sizes are measured once and remembered: the remembered size must equal a fresh measurement, font by font.
  $g=[MxTheme]::Measure(); $flags=[Windows.Forms.TextFormatFlags]'NoPadding,NoPrefix,SingleLine,PreserveGraphicsClipping,PreserveGraphicsTranslateTransform'
  $stale=@(foreach ($font in $fs.Record.Font,$fs.Record.DetailFont,$fs.Guide.Font) { foreach ($text in 'Mirrodex','화면 녹화 시작','Mirrodex') {
    if ([MxTheme]::Width($g,$text,$font) -ne [Windows.Forms.TextRenderer]::MeasureText($g,$text,$font,(New-Object Drawing.Size([int]::MaxValue,[int]::MaxValue)),$flags).Width) { "$text / $($font.Name) $($font.Size)" }
  } })
  $g.Dispose()
  Assert ($stale.Count -eq 0) "remembered text sizes equal fresh measurements: $($stale -join ', ')"
  $fs.Expand.PerformClick(); [Windows.Forms.Application]::DoEvents()
  Assert ($fs.Settings.Visible -and $script:SidebarExpanded -and $folded.ClientSize.Height -gt 300) 'expanding shows settings and remembers it for the next reconnection'
  $env:ADB=Join-Path $testRoot 'missing-adb.exe'
  $fs.Screenshot.PerformClick()
  Assert ($fs.Status.Text -eq (T '스크린샷을 저장하지 못했습니다. 휴대폰 연결을 확인해 주십시오.') -and -not $fs.Request) 'screenshot failure explains itself and never reconnects'
  $folded.Dispose()
  $form=New-Sidebar $c $device; $form.Show()
  [Windows.Forms.Application]::DoEvents(); $form.PerformLayout()
  $bitmap=New-Object Drawing.Bitmap($form.Width,$form.Height)
  try { $form.DrawToBitmap($bitmap,(New-Object Drawing.Rectangle(0,0,$form.Width,$form.Height))); $bitmap.Save((Join-Path $PSScriptRoot 'sidebar-preview.png')) } finally { $bitmap.Dispose() }
  $state=$form.Tag
  Assert ($state.Fields.size.SelectedItem -eq '2340' -and $state.Fields.fps.SelectedItem -eq '60') 'load known good without preset downgrade'
  Assert ($state.SavedChip.Text -eq (T '저장된 설정') -and $state.DraftCount -eq 0 -and $state.Apply.Variant -eq 'secondary') 'running settings read as saved; nothing pending, so Apply only reconnects'
  $state.Fields.size.SelectedItem='1920'
  Assert ((Get-FileHash $Cfg).Hash -eq $before -and -not $state.Request) 'draft selection does not save or restart'
  Assert ($state.DraftCount -eq 1 -and $state.Fields.size.Changed -and -not $state.Fields.fps.Changed -and $state.Apply.Variant -eq 'primary') 'a picked value is marked and counted, and Apply becomes the primary action'
  $state.Lock.Checked=$true
  Assert (-not $state.Apply.Enabled -and -not $state.Restore.Enabled) 'broadcast lock disables reconnect actions'
  Assert ($state.LockChip.Visible -and $state.Apply.Locked -and $state.Source.Locked -and -not $state.Screenshot.Locked) 'the lock is visible as a chip and on every blocked action'
  $state.Apply.PerformClick(); $state.Record.PerformClick()
  Assert (-not $state.Request -and -not $state.Record.Enabled -and -not $state.Guide.Enabled -and $state.Screenshot.Enabled) 'lock blocks reconnecting actions but not screenshots'
  $state.Lock.Checked=$false; $state.Apply.PerformClick()
  Assert ($state.Request.Config.size -eq '1920' -and $state.Request.Config.fps -eq '60') 'apply keeps FPS and requests selected resolution'
  Assert ((Get-FileHash $Cfg).Hash -eq $before) 'apply request is temporary until saved'
  $state.Request=$null; $state.Fields.codec.SelectedItem='h264'
  $candidate=Get-SidebarConfig $state
  Assert ($candidate.encoder -eq 'vendor.avc') 'codec selects matching advertised hardware encoder'
  $state.Fields.audio.SelectedItem='휴대폰'; $state.Required.Checked=$true
  $candidate=Get-SidebarConfig $state
  $options=@(Get-MirrorOptions $candidate 'TEST')
  Assert ($options -contains '--no-audio' -and $options -notcontains '--require-audio') 'phone playback disables forwarding without conflicting strict audio'
  $state.Fields.audio.SelectedItem='노트북'; $state.Fields.audiobuffer.SelectedItem='100'
  $candidate=Get-SidebarConfig $state; $options=@(Get-MirrorOptions $candidate 'TEST')
  Assert ($options -contains '--audio-source=output' -and $options -contains '--audio-buffer=100' -and $options -contains '--require-audio') 'broadcast audio options composed'
  Write-Pairs $Cfg $candidate
  Assert ((Import-Config).audiobuffer -eq '100') 'new configuration keys round trip'
  $candidate.audiobuffer='-1'; Write-Pairs $Cfg $candidate
  $threw=$false; try { Import-Config | Out-Null } catch { $threw=$true }
  Assert $threw 'invalid audio buffer rejected'
  Write-Pairs $Cfg $c
  $state.Restore.PerformClick()
  Assert ($state.Request.Config.size -eq '2340') 'restore returns user-confirmed good profile'
  $state.Export.PerformClick()
  Assert ($state.Status.MxOpen.Visible -and (Test-Path -LiteralPath $state.Status.MxPath) -and $state.Status.Glyph -eq 'check') 'a saved file is announced with its location link'
  # 'One app only' from the side menu: the change button drives the busy state and the app list loads for this phone.
  function Show-GuidePicker ($Title,$Text,$Items) { if ($Title -eq '보여줄 화면을 고르십시오') { 'app' } else { $Items[1].Key } }
  function Get-DeviceApps ($Scrcpy,$Serial) { $script:appsSerial=$Serial; @([pscustomobject]@{Label='Among Us';Package='com.x.among';System=$false},[pscustomobject]@{Label='YouTube';Package='com.google.youtube';System=$false}) }
  $state.Request=$null; $state.Source.PerformClick()
  Assert ($state.Request.Kind -eq 'source' -and $state.Request.Source.Package -eq 'com.google.youtube' -and $state.Request.Source.Label -eq 'YouTube' -and $script:appsSerial -eq 'TEST') 'one app only can be chosen from the side menu'
  # Game options are picked, applied and saved like the other settings; record-at-start is remembered per PC.
  Assert (-not $state.Checks.ContainsKey('game')) 'a phone without the game shows no game option'
  $state.Request=$null; $state.Checks.screenon.Checked=$true; $state.Checks.gamepad.Checked=$true
  $candidate=Get-SidebarConfig $state
  Assert ($state.Checks.gamepad.Changed -and $candidate.screenon -eq '1' -and $candidate.gamepad -eq '1' -and -not $state.Request) 'game options are drafts until applied'
  $state.Checks.screenon.Checked=$false; $state.Checks.gamepad.Checked=$false
  $state.AutoRecord.Checked=$true; $script:UiPreferences=$null
  Assert ((Get-UiPreference 'autorecord' '0') -eq '1' -and -not $state.Request) 'record at start is remembered for the next launch without reconnecting'
  # A match mark: by its key or by Alt+[ (the window message the system sends for the shortcut).
  $state.Mark.PerformClick()
  Assert ($state.Status.Glyph -eq 'alert' -and -not $state.Request) 'marking without a recording explains itself'
  $script:Recording=$true; $script:RecordFile=Join-Path $testRoot 'Mirrodex-1.mp4'; $script:RecordStarted=[DateTime]::Now
  [void][MirrodexDwm]::SendMessage($form.Handle,0x0312,[IntPtr]2,$null)
  Assert ((Test-Path (Join-Path $testRoot 'Mirrodex-1.marks.txt')) -and $state.Status.Glyph -eq 'check' -and $state.Status.MxOpen.Visible) 'the shortcut marks the match in the file beside the recording'
  $script:Recording=$false; $script:RecordFile=$null
  $form.Close(); [Windows.Forms.Application]::DoEvents()
  Assert (-not $form.IsDisposed -and $form.WindowState -eq 'Minimized') 'sidebar X preserves video session and can reopen'
  $script:Locked=$null; $champion=$c.Clone(); $champion.game='1'
  $gamePanel=New-Sidebar $champion (@{Game=$true}+$device)
  try { Assert ($gamePanel.Tag.Checks.game.Checked -and $gamePanel.Tag.Lock.Checked -and -not $gamePanel.Tag.Apply.Enabled) 'a session that opens the game starts with the reconnect lock on' } finally { $gamePanel.Dispose() }
  Assert ((Get-SessionKind 1 'Failed to initialize audio/opus') -eq 'audio') 'audio errors not mistaken for video codec errors'
  # Exercise orchestration: a user request restarts without saving, and startup failure rolls back.
  $script:launches=New-Object 'Collections.Generic.List[string]'
  $script:MirrorBecameReady=$false
  function Restore-Refresh { }
  function Start-Mirror ($Scrcpy,$Adb,$Config,$Serial) {
    $script:launches.Add([string]$Config.size)
    if ($script:launches.Count -eq 1) {
      $candidate=$Config.Clone(); $candidate.size='1920'
      $script:LastSession=@{Request=@{Kind='apply';Config=$candidate}}
    } elseif ($script:launches.Count -eq 2) { throw 'simulated startup failure' }
    else { $script:LastSession=@{Code=0} }
  }
  function Show-GuideChoice { return 'back' }
  $before=(Get-FileHash $Cfg).Hash
  Start-ResilientMirror 'scrcpy' 'adb' $c 'TEST'
  Assert (($script:launches -join ',') -eq '2340,1920,2340') 'failed live change restarts prior settings exactly once'
  Assert ((Get-FileHash $Cfg).Hash -eq $before) 'failed live change never overwrites saved settings'
  $state.Request=$null; $state.Record.PerformClick()
  Assert ($state.Request.Kind -eq 'record') 'record button requests reconnection with recording'
  $script:launches.Clear(); $script:Recording=$false
  function Start-Mirror ($Scrcpy,$Adb,$Config,$Serial) {
    $script:launches.Add("$($Config.size)/$script:Recording")
    $script:LastSession=if ($script:launches.Count -eq 1) { @{Request=@{Kind='record'}} } else { @{Code=0} }
  }
  Start-ResilientMirror 'scrcpy' 'adb' $c 'TEST'
  Assert (($script:launches -join ',') -eq '2340/False,2340/True') 'record toggle restarts same settings with recording on'
  Assert ((Get-FileHash $Cfg).Hash -eq $before) 'recording never touches saved settings'
  $script:Recording=$false
  $script:launches.Clear()
  function Invoke-Guide ($Scrcpy,$Adb,$Current,$Device,$Serial) { $t=$Current.Clone(); $t.size='1600'; return $t }
  function Start-Mirror ($Scrcpy,$Adb,$Config,$Serial) {
    $script:launches.Add([string]$Config.size)
    $script:LastSession=if ($script:launches.Count -eq 1) { @{Request=@{Kind='guide'}} } else { @{Code=0} }
  }
  Start-ResilientMirror 'scrcpy' 'adb' $c 'TEST'
  Assert (($script:launches -join ',') -eq '2340,1600') 'assistant from the menu tunes, then mirroring resumes with its result'
  $script:launches.Clear()
  function Invoke-Guide { throw [OperationCanceledException]::new('closed') }
  Start-ResilientMirror 'scrcpy' 'adb' $c 'TEST'
  Assert (($script:launches -join ',') -eq '2340,2340') 'closing the assistant resumes mirroring unchanged'
  $quick=Get-QuickStartConfig $device 'TEST'; $wireless=Get-QuickStartConfig $device '192.168.0.2:5555'
  Assert ($quick.rate -eq '8M' -and $quick.buffer -eq '50' -and $wireless.buffer -eq '100') 'first run picks USB or wireless defaults without asking'
  Write-Output "PASS: $script:checks sidebar checks ($($PSVersionTable.PSVersion))"
} finally {
  if ($form) { $form.Dispose() }
  if ([IO.Path]::GetFullPath($testRoot).StartsWith([IO.Path]::GetTempPath(),[StringComparison]::OrdinalIgnoreCase) -and (Split-Path $testRoot -Leaf) -like 'mirrodex-sidebar-*') { Remove-Item -LiteralPath $testRoot -Recurse -Force }
}
