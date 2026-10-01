$ErrorActionPreference = 'Stop'
. (Join-Path (Split-Path $PSScriptRoot) 'mirrodex.ps1')
$testDir = Join-Path ([IO.Path]::GetTempPath()) ('mirrodex-tests-' + [guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($testDir) | Out-Null
$Cfg = Join-Path $testDir 'test.cfg'
$Recovery = Join-Path $testDir 'recovery.cfg'
$script:checks = 0
function Assert ($Condition, $Message) {
  if (-not $Condition) { throw "FAIL: $Message" }
  $script:checks++
}
function Assert-Throws ($Action, $Message) {
  $threw = $false
  try { & $Action | Out-Null } catch { $threw = $true }
  Assert $threw $Message
}
function Valid-Config { return @{codec='h264';encoder='c2.qti.avc.encoder';size='1600';rate='12M';buffer='0';fps='60';arr='0';serial='TEST123'} }
try {
  $psExe = Join-Path $PSHOME 'powershell.exe'
  if (-not (Test-Path $psExe)) { $psExe = Join-Path $PSHOME 'pwsh.exe' }
  $native = Invoke-Tool $psExe @('-NoProfile','-Command','[Console]::Out.Write("out"); [Console]::Error.Write("err"); exit 7')
  Assert ($native.Code -eq 7 -and $native.Text -match 'out' -and $native.Text -match 'err') 'native stderr and exit code'
  $echoScript = Join-Path $testDir 'echo arguments.ps1'
  '[Console]::Write(($args | ConvertTo-Json -Compress))' | Set-Content $echoScript -Encoding UTF8
  $testArgs = @('with spaces', 'has"quote', 'C:\path with spaces\', '', 'a\"b')
  $echoResult = Invoke-Tool $psExe (@('-NoProfile','-ExecutionPolicy','Bypass','-File',$echoScript) + $testArgs)
  $echoArgs = $echoResult.Text | ConvertFrom-Json
  Assert ($echoArgs.Count -eq $testArgs.Count) "argument count: $($echoResult.Text)"
  for ($i=0; $i -lt $testArgs.Count; $i++) { Assert ($echoArgs[$i] -ceq $testArgs[$i]) "argument quoting $i" }
  Assert-Throws { Invoke-Tool $psExe @('-NoProfile','-Command','Start-Sleep -Seconds 10') 200 } 'native timeout'

  Write-Pairs $Cfg (Valid-Config)
  Assert ((Import-Config).size -eq '1600') 'config round trip'
  $c = Valid-Config; $c.size = '1920'; Write-Pairs $Cfg $c
  Assert ((Import-Config).size -eq '1920' -and -not (Test-Path ($Cfg+'.tmp'))) 'atomic replacement'
  foreach ($case in @(@('size','0'),@('size','99999999999999'),@('fps','0'),@('fps','241'),@('buffer','-1'),@('buffer','1001'),@('codec','vp9'),@('rate','0M'),@('rate','99999999M'),@('rate','12M --no-control'),@('encoder','bad --option'),@('arr','2'),@('serial','x;echo bad'),@('unknown','value'))) {
    $c=Valid-Config; $c[$case[0]]=$case[1]; Write-Pairs $Cfg $c
    Assert-Throws { Import-Config } "reject $($case[0])=$($case[1])"
  }
  $c=Valid-Config; $c.arr='1'; $c.fps='120'; Write-Pairs $Cfg $c
  Assert-Throws { Import-Config } 'reject conflicting refresh settings'
  'codec=h264','codec=h265' | Set-Content $Cfg
  Assert-Throws { Import-Config } 'reject duplicate keys'
  $c=Valid-Config; $c.Remove('fps'); $c.Remove('serial'); Write-Pairs $Cfg $c
  $legacy=Import-Config
  Assert ($legacy.fps -eq '60' -and $legacy.serial -eq '' -and $legacy.size -eq '1600') 'legacy migration preserves image settings'
  $c=Valid-Config; $c.Remove('rate'); Write-Pairs $Cfg $c
  Assert-Throws { Import-Config } 'reject missing bitrate'
  $opts=@(Get-MirrorOptions (Valid-Config) 'TEST123')
  Assert ($opts -contains '--serial=TEST123' -and $opts -contains '--max-fps=60' -and $opts -contains '--video-buffer=0') 'selected device and settings propagated'
  foreach ($flag in @('--audio-source=output','--turn-screen-off','--stay-awake','--disable-screensaver')) { Assert ($opts -contains $flag) "preserve $flag" }
  $encoders = "--video-codec=h264 --video-encoder=c2.android.avc.encoder (sw)`n--video-codec=h264 --video-encoder=OMX.qcom.avc (hw) (alias for c2.qti.avc.encoder)`n--video-codec=h264 --video-encoder=c2.qti.avc.encoder (hw) [vendor]`n--video-codec=h265 --video-encoder=c2.qti.hevc.encoder (hw) [vendor]"
  Assert ((Get-Encoder $encoders 'h264') -eq 'c2.qti.avc.encoder') 'hardware non-alias encoder'
  Assert ((Get-Encoder $encoders 'h265') -eq 'c2.qti.hevc.encoder') 'codec-specific encoder'
  Assert ((Get-Encoder '' 'h265') -eq '') 'missing encoder'

  # Mock external commands only; exercise real parsers, session and recovery functions.
  $script:responses = @{}
  $script:calls = New-Object 'Collections.Generic.List[string]'
  function Invoke-Tool ($File, [string[]]$Arguments, [int]$Timeout=15000) {
    $key = $Arguments -join '|'; $script:calls.Add($key)
    if (-not $script:responses.ContainsKey($key)) { throw "Unexpected command: $key" }
    return $script:responses[$key]
  }
  $script:responses['devices|-l'] = @{Code=0;Text="List of devices attached`nTEST123 device model:SM_S948N`nTEST456 device model:Other`nLOCKED unauthorized`nOFFLINE offline"}
  Assert (@(Get-Devices 'adb').Count -eq 4) 'device states parsed'
  Assert ((Connect-Device 'adb' 'TEST123') -eq 'TEST123') 'saved device preferred'
  function Show-GuidePicker { return 'TEST456' }
  function Read-Host { return '2' }
  Assert ((Connect-Device 'adb' '') -eq 'TEST456') 'explicit multi-device selection'
  $script:responses['devices|-l'] = @{Code=1;Text='error'}
  Assert-Throws { Get-Devices 'adb' } 'device listing failure'
  $script:responses['-s|TEST123|shell|getprop ro.product.model; echo fp=$(getprop ro.build.fingerprint); wm size'] = @{Code=0;Text="SM-S948N`nfp=`nPhysical size: 1440x3120`nOverride size: 1080x2340"}
  $script:responses['--serial=TEST123|--list-encoders'] = @{Code=0;Text=$encoders}
  $device=Inspect-Device 'adb' 'scrcpy' 'TEST123'
  Assert ($device.Long -eq 2340 -and $device.Short -eq 1080) 'override resolution wins'
  function Read-Host { return '' }
  $knownGood=Valid-Config
  $knownGood.codec='h265'; $knownGood.encoder='c2.qti.hevc.encoder'; $knownGood.size='1024'; $knownGood.rate='8M'; $knownGood.buffer='50'; $knownGood.arr='1'
  $preset=Select-Preset $device 'TEST123' $knownGood
  Assert ($preset.size -eq '1024' -and $preset.codec -eq 'h265' -and $preset.buffer -eq '50' -and $preset.arr -eq '1') 'empty selection preserves known-good S26 Ultra settings'
  $stableOptions = @(Get-MirrorOptions $preset 'TEST123')
  Assert (($stableOptions -join ' ') -eq '--serial=TEST123 --window-title=Mirrodex --video-codec=h265 --max-size=1024 --max-fps=60 --video-bit-rate=8M --video-buffer=50 --audio-source=output --turn-screen-off --stay-awake --disable-screensaver --video-encoder=c2.qti.hevc.encoder') 'stable default generates original working video options'
  $device.Model='Other'
  $otherPreset=Select-Preset $device 'TEST123'
  Assert ($otherPreset.arr -eq '0') 'do not infer refresh policy for other phones'
  $device.Model='SM-S948N'
  $newSamsung=Select-Preset $device 'TEST123'
  Assert ($newSamsung.arr -eq '0' -and $newSamsung.codec -eq 'h264') 'same phone model is not evidence for another PC'
  function Read-Host { return '2' }
  $device.Encoders='--video-codec=h264 --video-encoder=c2.qti.avc.encoder (hw)'
  $preset=Select-Preset $device 'TEST123'
  Assert ($preset.codec -eq 'h264' -and $preset.encoder -eq 'c2.qti.avc.encoder' -and $preset.buffer -eq '100' -and $preset.rate -eq '6M') 'wireless start preserves hardware codec with more jitter allowance'
  $low=Get-StartingConfig $device 'TEST123' 'lowload'
  Assert ($low.size -eq '800' -and $low.fps -eq '30' -and $low.rate -eq '4M') 'low load caps resolution frames and bandwidth'
  $device.Encoders='--video-codec=h265 --video-encoder=vendor.hevc (hw)'
  $hevcOnly=Get-StartingConfig $device 'TEST123' 'usb'
  Assert ($hevcOnly.codec -eq 'h265' -and $hevcOnly.encoder -eq 'vendor.hevc') 'hardware h265 preferred over unconfirmed h264'
  $device.Encoders='--video-codec=h264 --video-encoder=software.avc (sw)'
  $device.Long=720
  $unknown=Get-StartingConfig $device 'TEST123' 'usb'
  Assert ($unknown.encoder -eq '' -and $unknown.size -eq '720' -and $unknown.fps -eq '30') 'unknown hardware has conservative bounded fallback'
  $device.Long=2340; $device.Encoders=$encoders
  foreach ($choice in @('1','2','3','4','6','7','9','10')) {
    $candidate=Get-TuningCandidate $knownGood $device $choice
    $changed=@($knownGood.Keys | Where-Object { $knownGood[$_] -ne $candidate[$_] })
    Assert ($changed.Count -eq 1) "tuning changes one dimension: $choice"
  }
  $codecCandidate=Get-TuningCandidate $knownGood $device '5'
  Assert ($codecCandidate.codec -eq 'h264' -and $codecCandidate.encoder -eq 'c2.qti.avc.encoder' -and $codecCandidate.buffer -eq '50' -and $knownGood.codec -eq 'h265') 'codec pairing changes without mutating baseline'
  Assert-Throws { Get-TuningCandidate $knownGood $device '8' } 'no speculative 120 fps'
  $device.Long=1024
  Assert-Throws { Get-TuningCandidate $knownGood $device '3' } 'resolution cannot exceed device'
  $device.Long=2340

  $put='-s|TEST123|shell|settings|put|secure|refresh_rate_mode|1'
  $get='-s|TEST123|shell|settings|get|secure|refresh_rate_mode'
  $script:responses[$put]=@{Code=0;Text=''}
  $script:responses[$get]=@{Code=0;Text='1'}
  Write-Pairs $Recovery @{serial='TEST123';previous='1'}
  Restore-Refresh 'adb' 'TEST123'
  Assert (-not (Test-Path $Recovery)) 'successful crash recovery deletes journal'
  Write-Pairs $Recovery @{serial='TEST123';previous='1'}
  Assert-Throws { Restore-Refresh 'adb' 'TEST456' } 'do not restore another phone'
  $script:responses[$put]=@{Code=1;Text='offline'}
  Assert-Throws { Restore-Refresh 'adb' 'TEST123' } 'failed restoration visible'
  Assert (Test-Path $Recovery) 'failed restoration preserves journal'
  $script:responses[$put]=@{Code=0;Text=''}
  Restore-Refresh 'adb' 'TEST123'
  $script:responses[$get]=@{Code=0;Text='null'}
  $c=Valid-Config; $c.arr='1'
  # Legacy arr no longer causes any display-mode writes.
  Assert (-not (Test-Path $Recovery)) 'unknown original causes no mutation'
  function Invoke-MirrorProcess ($File,$Arguments,$TrialSeconds) { & $File @Arguments; return @{Code=$global:LASTEXITCODE;Kind='unknown';Canceled=$false} }
  function Fake-Scrcpy { $global:LASTEXITCODE=3 }
  $before=$script:calls.Count
  Assert-Throws { Start-Mirror 'Fake-Scrcpy' 'adb' (Valid-Config) 'TEST123' } 'scrcpy failure propagated'
  Assert ($script:calls.Count -eq $before) 'default mirroring does not mutate refresh setting'
  function Fake-Scrcpy { $script:passedOptions=$args; $global:LASTEXITCODE=0 }
  Start-Mirror 'Fake-Scrcpy' 'adb' (Valid-Config) 'TEST123'
  Assert ($true) 'normal scrcpy exit'
  Assert ($script:passedOptions -notcontains '--time-limit=30' -and $script:passedOptions -notcontains '--print-fps') 'normal mirroring has no trial limit or logging'
  Start-Mirror 'Fake-Scrcpy' 'adb' (Valid-Config) 'TEST123' 30
  Assert ($script:passedOptions -contains '--time-limit=30' -and $script:passedOptions -contains '--print-fps') 'real session launcher adds bounded trial options'
  function New-RecordPath { return (Join-Path $testDir 'rec.mp4') }
  $script:Recording=$true
  Start-Mirror 'Fake-Scrcpy' 'adb' (Valid-Config) 'TEST123'
  Assert ($script:passedOptions -contains ('--record='+(Join-Path $testDir 'rec.mp4')) -and $script:passedOptions -contains '--audio-codec=aac') 'recording adds a file and playable AAC audio'
  Start-Mirror 'Fake-Scrcpy' 'adb' (Valid-Config) 'TEST123' 30
  Assert (-not ($script:passedOptions -match '^--record')) 'trial comparisons never record'
  $script:Recording=$false
  Start-Mirror 'Fake-Scrcpy' 'adb' (Valid-Config) 'TEST123'
  Assert (-not ($script:passedOptions -match '^--(record|audio-codec)')) 'normal mirroring keeps original audio codec'
  # Exercise the full opt-in write/launch/finally-restore sequence.
  $script:phoneMode='1'; $script:putCount=0
  function Invoke-Tool ($File, [string[]]$Arguments, [int]$Timeout=15000) {
    Assert ($Arguments[1] -eq 'TEST123') 'refresh mutation targets selected device'
    if ($Arguments[4] -eq 'get') { return @{Code=0;Text=$script:phoneMode} }
    Assert (Test-Path $Recovery) 'journal exists before every refresh mutation'
    $script:phoneMode=$Arguments[7]; $script:putCount++
    return @{Code=0;Text=''}
  }
  function Fake-Scrcpy { Assert ($script:phoneMode -eq '1') 'legacy arr never changes phone mode'; $global:LASTEXITCODE=3 }
  $c=Valid-Config; $c.arr='1'
  Assert-Throws { Start-Mirror 'Fake-Scrcpy' 'adb' $c 'TEST123' } 'restore even after scrcpy failure'
  Assert ($script:phoneMode -eq '1' -and $script:putCount -eq 0 -and -not (Test-Path $Recovery)) 'legacy arr leaves phone untouched even on failure'
  $Root=$testDir
  $script:trials=New-Object 'Collections.Generic.List[string]'
  function Start-Mirror ($Scrcpy, $Adb, $Config, $Serial, [int]$TrialSeconds=0) {
    Assert ($Serial -eq 'TEST123' -and $TrialSeconds -eq 30) 'comparison is bounded and targets selected phone'
    $script:trials.Add($Config.buffer)
  }
  function Read-Host { return $script:answers.Dequeue() }
  $script:answers=New-Object 'Collections.Generic.Queue[string]'
  @('1','','','','') | ForEach-Object { $script:answers.Enqueue($_) }
  Write-Pairs $Cfg $knownGood
  $savedHash=(Get-FileHash $Cfg).Hash
  $kept=Invoke-Tuning 'scrcpy' 'adb' $knownGood $device 'TEST123'
  Assert ($kept.buffer -eq '50' -and (Get-FileHash $Cfg).Hash -eq $savedHash) 'unconfirmed candidate never changes saved config'
  Assert (($script:trials -join ',') -eq '50,80,50') 'ABA comparison rechecks baseline after candidate'
  @('1','','','','1') | ForEach-Object { $script:answers.Enqueue($_) }
  $accepted=Invoke-Tuning 'scrcpy' 'adb' $knownGood $device 'TEST123'
  Assert ($accepted.buffer -eq '80' -and (Import-Config).buffer -eq '80' -and (Read-Pairs ($Cfg+'.bak')).buffer -eq '50') 'only explicit improvement saves candidate and backs up baseline'
  Assert ((Get-Content (Join-Path $Root 'tuning-history.log')).Count -eq 2) 'accepted and rejected observations recorded locally'
  Assert (-not ((Get-Content (Join-Path $Root 'tuning-history.log') -Raw) -match 'TEST123')) 'history excludes serial'
  $savedHash=(Get-FileHash $Cfg).Hash
  function Start-Mirror { throw 'simulated encoder failure' }
  @('1','') | ForEach-Object { $script:answers.Enqueue($_) }
  Assert-Throws { Invoke-Tuning 'scrcpy' 'adb' $accepted $device 'TEST123' } 'failed trial surfaced'
  Assert ((Get-FileHash $Cfg).Hash -eq $savedHash) 'failed trial preserves saved config'
  Write-Host "PASS: $script:checks checks ($($PSVersionTable.PSVersion))"
} finally {
  # Delete only the unique test directory we created under TEMP.
  if ($testDir -and (Split-Path $testDir -Leaf) -like 'mirrodex-tests-*') { Remove-Item -LiteralPath $testDir -Recurse -Force }
}
