# Mirrodex - Windows PowerShell 5.1 / PowerShell 7
param([ValidateSet('run','guide','setup','tune','diagnose','add','install','uninstall')][string]$Mode = 'run')

$Root = $PSScriptRoot
$Cfg = Join-Path $Root 'mirrodex.cfg'
$Recovery = Join-Path $Root 'refresh-recovery.cfg'
$script:GuideMode = $false
. (Join-Path $Root 'mirrodex-guide.ps1')
. (Join-Path $Root 'mirrodex-runtime.ps1')
. (Join-Path $Root 'mirrodex-install.ps1')
. (Join-Path $Root 'mirrodex-update.ps1')

function Say ($Text, $Color = 'Gray') { Write-Host (T $Text) -ForegroundColor $Color }
function Head ($Text) { Say "`n  $Text" Cyan; Say ('  ' + '-' * 52) DarkGray }

# Every engine and adb process is prepared here: each argument quoted, no console window, both streams redirected.
function New-ToolProcess ($File, [string[]]$Arguments) {
  $quoted = foreach ($arg in $Arguments) {
    '"' + [regex]::Replace([regex]::Replace($arg, '(\\*)"', '$1$1\"'), '(\\+)$', '$1$1') + '"'
  }
  $info = New-Object System.Diagnostics.ProcessStartInfo
  $info.FileName = $File
  $info.Arguments = $quoted -join ' '
  $info.UseShellExecute = $false
  $info.CreateNoWindow = $true
  $info.RedirectStandardOutput = $true
  $info.RedirectStandardError = $true
  $process = New-Object System.Diagnostics.Process
  $process.StartInfo = $info
  return $process
}

# Redirect both streams asynchronously: no PS 5.1 NativeCommandError and no pipe deadlock.
# Only short diagnostic commands use this helper; interactive mirroring streams directly.
function Invoke-Tool ($File, [string[]]$Arguments, [int]$Timeout = 15000) {
  $process = New-ToolProcess $File $Arguments
  try {
    if (-not $process.Start()) { throw "$File 실행 실패" }
    $stdout = $process.StandardOutput.ReadToEndAsync()
    $stderr = $process.StandardError.ReadToEndAsync()
    if (-not $process.WaitForExit($Timeout)) {
      $process.Kill()
      throw "$File 응답 시간 초과 ($Timeout ms). USB 연결을 확인해 주십시오."
    }
    return @{ Code = $process.ExitCode; Text = ($stdout.Result + "`n" + $stderr.Result).Trim() }
  } finally { $process.Dispose() }
}

# Bundled engine (scrcpy 4.1 renamed mirrodex-engine.exe + adb renamed mirrodex-adb.exe, passed to the engine via ADB, Apache-2.0, engine/LICENSE.txt): no separate install or PATH lookup.
function Get-Scrcpy {
  $path = Join-Path $Root 'engine\mirrodex-engine.exe'
  if (-not (Test-Path -LiteralPath $path) -or -not (Test-Path -LiteralPath (Join-Path $Root 'engine\mirrodex-adb.exe'))) {
    throw '화면 연결 엔진(engine 폴더)이 없습니다. 받은 ZIP 파일을 처음부터 다시 압축 해제해 주십시오.'
  }
  return $path
}

function Read-Pairs ($Path) {
  $values = @{}
  foreach ($line in [IO.File]::ReadAllLines($Path)) {
    if (-not $line.Trim() -or $line -match '^\s*#') { continue }
    if ($line -notmatch '^([a-z]+)=(.*)$') { throw "설정 형식 오류: $Path" }
    if ($values.ContainsKey($Matches[1])) { throw "중복된 설정: $($Matches[1])" }
    $values[$Matches[1]] = $Matches[2]
  }
  return $values
}

function Write-Pairs ($Path, $Values) {
  $temp = $Path + '.tmp'
  try {
    [IO.File]::WriteAllLines($temp, [string[]]@($Values.GetEnumerator() | Sort-Object Key | ForEach-Object { "$($_.Key)=$($_.Value)" }), [Text.Encoding]::ASCII)
    if ([IO.File]::Exists($Path)) { [IO.File]::Replace($temp, $Path, [NullString]::Value) }
    else { [IO.File]::Move($temp, $Path) }
  } finally { if ([IO.File]::Exists($temp)) { [IO.File]::Delete($temp) } }
}

function Get-DeviceName ($Detail, $Serial) {
  if ($Detail -match 'model:(\S+)') { return ($Matches[1] -replace '_',' ') }
  return $Serial
}
function Test-Serial ($Serial) { return ($Serial -cmatch '^[A-Za-z0-9][A-Za-z0-9._:\[\]-]{0,255}$') }

function Import-Config ($Path = $Cfg) {
  $c = Read-Pairs $Path
  # Original six-key files remain valid, including their original image settings.
  if (-not $c.ContainsKey('fps')) { $c.fps = '60' }
  if (-not $c.ContainsKey('serial')) { $c.serial = '' }
  if (-not $c.ContainsKey('encoder')) { $c.encoder = '' }
  if (-not $c.ContainsKey('arr')) { $c.arr = '0' }
  if (-not $c.ContainsKey('audio')) { $c.audio = 'output' }
  if (-not $c.ContainsKey('audiobuffer')) { $c.audiobuffer = '50' }
  if (-not $c.ContainsKey('requireaudio')) { $c.requireaudio = '0' }
  foreach ($key in $c.Keys) {
    if ($key -notin @('codec','encoder','size','rate','buffer','arr','fps','serial','audio','audiobuffer','requireaudio')) { throw "알 수 없는 설정: $key" }
  }
  if ($c.codec -cnotmatch '^(h264|h265)$') { throw 'codec은 h264 또는 h265여야 합니다.' }
  if ($c.encoder -cnotmatch '^[A-Za-z0-9._-]*$') { throw '잘못된 인코더 이름입니다.' }
  foreach ($key in @('size','fps','buffer','audiobuffer')) {
    $number = 0
    if (-not [int]::TryParse($c[$key], [ref]$number)) { throw "잘못된 숫자 설정: $key" }
    $limits = @{size=@(256,8192); fps=@(1,240); buffer=@(0,1000); audiobuffer=@(0,1000)}
    if ($number -lt $limits[$key][0] -or $number -gt $limits[$key][1]) { throw "설정 범위 초과: $key" }
  }
  if ($c.rate -cnotmatch '^[1-9][0-9]{0,8}[KM]?$') { throw '잘못된 비트레이트입니다. 예: 12M' }
  $rateValue = [double]($c.rate -replace '[KM]$', '')
  if ($c.rate.EndsWith('M')) { $rateValue *= 1000000 }
  elseif ($c.rate.EndsWith('K')) { $rateValue *= 1000 }
  if ($rateValue -lt 100000 -or $rateValue -gt 200000000) { throw '비트레이트 범위: 100K~200M' }
  if ($c.arr -cnotmatch '^[01]$') { throw 'arr은 0 또는 1이어야 합니다.' }
  if ($c.audio -cnotmatch '^(output|off)$' -or $c.requireaudio -cnotmatch '^[01]$') { throw '잘못된 오디오 설정입니다.' }
  if ($c.arr -eq '1' -and [int]$c.fps -gt 60) { throw '60Hz 고정과 60fps 초과를 동시에 사용할 수 없습니다.' }
  if ($c.serial -and -not (Test-Serial $c.serial)) { throw '잘못된 기기 식별자입니다.' }
  return $c
}

function Get-Devices ($Adb) {
  $result = Invoke-Tool $Adb @('devices','-l')
  if ($result.Code -ne 0) { throw "ADB 기기 조회 실패: $($result.Text)" }
  foreach ($line in ($result.Text -split '\r?\n')) {
    if ($line -match '^(\S+)\s+(device|unauthorized|offline)\b(.*)$') {
      $serial = $Matches[1]; $state = $Matches[2]; $detail = $Matches[3]
      if (Test-Serial $serial) { @{ Serial=$serial; State=$state; Detail=$detail } }
    }
  }
}

function Connect-Device ($Adb, $Preferred, [switch]$RequirePreferred) {
  while ($true) {
    $all=@(Get-Devices $Adb)
    $ready=@($all | Where-Object { $_.State -eq 'device' -and (-not $RequirePreferred -or $_.Serial -eq $Preferred) -and -not (Test-DeviceInUse $_.Serial) })
    $saved=@($ready | Where-Object { $_.Serial -eq $Preferred })
    if ($saved.Count -eq 1) { return $saved[0].Serial }
    if ($ready.Count -eq 1) { return $ready[0].Serial }
    if ($ready.Count -gt 1) {
      $items=@($ready | ForEach-Object { @{Key=$_.Serial;Label=(Get-DeviceName $_.Detail $_.Serial);Detail=$_.Serial} })
      $pick=Show-GuidePicker '어느 휴대폰을 연결하시겠습니까?' '연결된 기기가 여러 대입니다. 화면을 보고 싶은 휴대폰을 골라 주십시오.' $items '이 휴대폰 연결하기'
      if (-not $pick) { throw [OperationCanceledException]::new('길라잡이를 종료했습니다. 확인하지 않은 설정은 저장하지 않았습니다.') }
      return $pick
    }
    $hint="1. 휴대폰 잠금을 풀고 데이터 전송 케이블로 연결하십시오.`n2. 설정 > 휴대전화 정보 > 소프트웨어 정보에서 '빌드번호'를 7번 누르십시오.`n3. 설정 > 개발자 옵션에서 'USB 디버깅'을 켜십시오.`n4. 휴대폰에 연결 허용 창이 나오면 본인 PC인지 확인하고 허용하십시오."
    if ($RequirePreferred) { $hint="사용하던 같은 휴대폰을 다시 연결해 주십시오. 다른 휴대폰의 설정은 건드리지 않습니다.`n`n"+$hint }
    if (@($all | Where-Object { $_.State -eq 'unauthorized' }).Count) { $hint="휴대폰은 찾았지만 연결 허용이 필요합니다.`n휴대폰 잠금을 풀고 USB 디버깅 허용 창에서 본인 PC를 허용해 주십시오." }
    elseif (@($all | Where-Object { $_.State -eq 'offline' }).Count) { $hint='연결이 잠시 끊겼습니다. 케이블을 다시 꽂거나 무선 연결을 확인해 주십시오.' }
    if (@($all | Where-Object { $_.State -eq 'device' -and (Test-DeviceInUse $_.Serial) }).Count -and -not $RequirePreferred) { $hint="연결된 휴대폰은 이미 다른 Mirrodex 창에서 미러링 중입니다. 다른 휴대폰을 케이블이나 무선으로 연결하십시오.`n`n"+$hint }
    $choices=@(@{Key='retry';Label='확인했습니다 · 다시 연결 확인'})
    if (-not $RequirePreferred) { $choices+=@{Key='wireless';Label='무선으로 연결하기 · 케이블 없이';Icon='wifi'} }
    if ((Show-GuideChoice '휴대폰 연결 확인' $hint $choices) -eq 'wireless') {
      $wireless=Invoke-WirelessPairing $Adb
      if ($wireless) { return $wireless }
    }
  }
}
function Get-Encoder ($Text, $Codec) {
  foreach ($line in ($Text -split '\r?\n')) {
    if ($line -match "--video-codec=$Codec\s+--video-encoder=([A-Za-z0-9._-]+)\s+\(hw\)" -and $line -notmatch 'alias for') { return $Matches[1] }
  }
  return ''
}

# Listing encoders starts the engine on the phone (about 0.5 s, over 1 s right after plugging in). The list changes
# only with the phone's system software or the bundled engine, so its encoder lines are kept per build fingerprint
# and Mirrodex version in profiles\. -Fresh asks the phone again: for diagnostics and after an encoder failed.
function Inspect-Device ($Adb, $Scrcpy, $Serial, [switch]$Fresh) {
  $result = Invoke-Tool $Adb @('-s',$Serial,'shell','getprop ro.product.model; echo fp=$(getprop ro.build.fingerprint); wm size')
  if ($result.Code -ne 0) { throw "기기 검사 실패: $($result.Text)" }
  $lines = $result.Text -split '\r?\n'
  $sizes = [regex]::Matches($result.Text, '(?:Physical|Override) size:\s*(\d+)x(\d+)')
  if (-not $sizes.Count) { throw '기기 해상도를 읽지 못했습니다.' }
  $size = $sizes[$sizes.Count-1] # wm override wins over physical size
  $a = [int]$size.Groups[1].Value; $b = [int]$size.Groups[2].Value
  $fingerprint = [regex]::Match($result.Text, '(?m)^fp=(\S+)').Groups[1].Value
  $stamp = "$script:AppVersion $fingerprint"; $list = ''
  $cache = if ($fingerprint) { Join-Path $Root ('profiles\encoders-' + ($fingerprint -replace '[^A-Za-z0-9._-]', '_') + '.txt') }
  if ($cache -and -not $Fresh) {
    try { $saved = [IO.File]::ReadAllLines($cache); if ($saved[0] -ceq $stamp) { $list = ($saved | Select-Object -Skip 1) -join "`n" } } catch { }
  }
  if (-not $list) {
    $encoders = Invoke-Tool $Scrcpy @("--serial=$Serial",'--list-encoders') 30000
    if ($encoders.Code -ne 0) { throw "인코더 검사 실패: $($encoders.Text)" }
    $list = $encoders.Text
    # Only the encoder lines are kept: the engine's other output names the phone's serial number.
    $kept = @($list -split '\r?\n' | Where-Object { $_ -match '--(video|audio)-codec=' })
    if ($cache -and $kept.Count) {
      try {
        [void][IO.Directory]::CreateDirectory((Split-Path $cache))
        [IO.File]::WriteAllLines("$cache.tmp", [string[]](@($stamp) + $kept)); [IO.File]::Delete($cache); [IO.File]::Move("$cache.tmp", $cache)
      } catch { }
    }
  }
  return @{ Model=$lines[0]; Long=[Math]::Max($a,$b); Short=[Math]::Min($a,$b); Encoders=$list }
}

function Get-StartingConfig ($Device, $Serial, $Environment) {
  # Starting hypotheses, not benchmark results. Never infer PC decoding speed from phone model.
  $c = @{codec='h264'; encoder=(Get-Encoder $Device.Encoders 'h264'); size='1024';
    rate='8M'; buffer='50'; fps='60'; arr='0'; serial=$Serial}
  if (-not $c.encoder) {
    $hevc = Get-Encoder $Device.Encoders 'h265'
    if ($hevc) { $c.codec='h265'; $c.encoder=$hevc }
  }
  switch ($Environment) {
    'wireless' { $c.rate='6M'; $c.buffer='100' }
    'lowload' { $c.size='800'; $c.rate='4M'; $c.fps='30' }
    'usb' { }
    default { throw '알 수 없는 연결 환경입니다.' }
  }
  if (-not $c.encoder) { $c.size='800'; $c.rate='4M'; $c.fps='30' }
  $c.size = [string][Math]::Min($Device.Long, [int]$c.size)
  return $c
}

function Get-QuickStartConfig ($Device, $Serial) {
  $environment=if (Test-WirelessSerial $Serial) {'wireless'} else {'usb'}
  return (Get-StartingConfig $Device $Serial $environment)
}
function Select-Preset ($Device, $Serial, $Current = $null) {
  Head "기기: $($Device.Model) / $($Device.Short) x $($Device.Long)"
  Say '  환경에 맞는 시작값입니다. 최적값은 같은 앱에서 비교해 결정하십시오.'
  if ($Current -and $Current.serial -eq $Serial) { Say '  [0 / Enter] 현재 설정 유지 (이미 잘 동작한다면 권장)' Green }
  Say '  [1] USB 일반: 최대 1024px / 60fps / 8M / 버퍼 50ms'
  Say '  [2] 무선 연결: 최대 1024px / 60fps / 6M / 버퍼 100ms'
  Say '  [3] 낮은 부하 / 30Hz 화면: 최대 800px / 30fps / 4M / 버퍼 50ms'
  Say '  새 설정은 주사율을 강제하지 않습니다. 무선 연결은 미리 연결되어 있어야 합니다.'
  $pick = Read-Host (T '  번호 (처음 실행의 Enter: 1)')
  if ($pick -in @('', '0') -and $Current -and $Current.serial -eq $Serial) { return $Current.Clone() }
  $environment = 'usb'
  switch ($pick) {
    '2' { $environment='wireless' }
    '3' { $environment='lowload' }
    '1' { }
    '' { }
    default { throw '0~3 중 표시된 번호를 선택하십시오.' }
  }
  $c = Get-StartingConfig $Device $Serial $environment
  if (-not $c.encoder) { Say '  하드웨어 인코더를 확인하지 못해 800px/30fps 이하로 시작합니다.' Yellow }
  return $c
}

function Get-TuningCandidate ($Config, $Device, $Choice) {
  $c = $Config.Clone()
  $key = ''; $values = @(); $up = $true
  switch ($Choice) {
    '1' { $key='buffer'; $values=@(0,16,33,50,80,100,150) }
    '2' { $key='size'; $values=@(640,800,1024,1280,1600,1920,2340); $up=$false }
    '3' { $key='size'; $values=@(640,800,1024,1280,1600,1920,2340) }
    '4' { $key='buffer'; $values=@(0,16,33,50,80,100,150); $up=$false }
    '5' {
      $codec = if ($c.codec -eq 'h264') { 'h265' } else { 'h264' }
      $encoder = Get-Encoder $Device.Encoders $codec
      if (-not $encoder) { throw '비교할 코덱의 하드웨어 인코더가 없습니다.' }
      $c.codec=$codec; $c.encoder=$encoder
      return $c
    }
    '6' { $key='rate'; $values=@(1000000,2000000,4000000,6000000,8000000,12000000,16000000,20000000); $up=$false }
    '7' { $key='fps'; $values=@(24,30,45,60); $up=$false }
    '8' { $key='fps'; $values=@(24,30,45,60) }
    '9' { if ($c.arr -ne '1') { throw '이미 주사율 강제를 사용하지 않습니다.' }; $c.arr='0'; return $c }
    '10' { $key='rate'; $values=@(1000000,2000000,4000000,6000000,8000000,12000000,16000000,20000000) }
    default { throw '표시된 번호를 선택하십시오.' }
  }
  $current = [double]($c[$key] -replace '[KM]$', '')
  if ($key -eq 'rate') {
    if ($c.rate.EndsWith('M')) { $current *= 1000000 }
    elseif ($c.rate.EndsWith('K')) { $current *= 1000 }
  }
  if ($key -eq 'size') { $values = @($values | Where-Object { $_ -le $Device.Long }) }
  if ($up) { $next = @($values | Where-Object { $_ -gt $current } | Sort-Object | Select-Object -First 1) }
  else { $next = @($values | Where-Object { $_ -lt $current } | Sort-Object -Descending | Select-Object -First 1) }
  if (-not $next.Count) { throw '이 항목은 비교 범위의 끝입니다. 다른 항목을 선택하십시오.' }
  $c[$key] = [string]$next[0]
  return $c
}

function Save-Config ($Config) {
  if ($script:Context) {
    $previous=Read-Profile 'current' $Config.serial
    if ($previous) { Save-Profile 'previous' $previous }
  }
  if (Test-Path -LiteralPath $Cfg) { Copy-Item -LiteralPath $Cfg -Destination ($Cfg + '.bak') -Force }
  Write-Pairs $Cfg $Config
  Save-Profile 'current' $Config
  if ($script:Context -and -not $script:SecondaryDevice) { Write-Pairs (Join-Path $Root 'current-context.cfg') @{key=$script:Context.Key} }
}

function Compare-Config ($Scrcpy, $Adb, $Baseline, $Candidate, $Serial) {
  Say '  같은 앱/장면/스크롤을 각각 30초 동안 재현하십시오. FPS 숫자만으로 판단하지 마십시오.'
  Say '  A: 현재 설정 -> B: 한 항목 변경 -> A: 현재 설정 재확인 (총 약 90초)' Cyan
  Read-Host (T '  준비되면 Enter (실제 사용 창 크기와 모니터를 두 시험에서 같게 유지)') | Out-Null
  Start-Mirror $Scrcpy $Adb $Baseline $Serial 30
  Read-Host (T '  같은 장면으로 돌아갈 준비가 되면 Enter') | Out-Null
  Start-Mirror $Scrcpy $Adb $Candidate $Serial 30
  Read-Host (T '  마지막으로 같은 장면에서 A를 다시 확인합니다. 준비되면 Enter') | Out-Null
  Start-Mirror $Scrcpy $Adb $Baseline $Serial 30
  Say '  끊김, 글씨, 조작 지연을 함께 비교하십시오. 애매하거나 나빠졌으면 현재 설정을 유지합니다.'
  return ((Read-Host (T '  B가 두 번의 A보다 좋고 다른 불편이 없으면 1, 그 외는 Enter')) -ceq '1')
}

function Invoke-Tuning ($Scrcpy, $Adb, $Config, $Device, $Serial) {
  Head '한 항목씩 비교하기'
  Say '  [1] 끊김 완충 늘리기     [2] 해상도를 낮춰 부하 줄이기'
  Say '  [3] 해상도를 높여 글씨 개선 [4] 버퍼를 줄여 조작 지연 비교'
  Say '  [5] H.264/H.265 비교      [6] 통신량 줄이기'
  Say '  [7] 프레임 상한 낮추기    [8] 프레임 상한 올리기 (최대 60)'
  Say '  [9] 주사율 강제 끄기     [10] 비트레이트를 높여 압축 화질 개선'
  $choice = Read-Host (T '  시험할 번호 (Enter: 취소)')
  if (-not $choice) { return $Config }
  $candidate = Get-TuningCandidate $Config $Device $choice
  foreach ($key in @('codec','encoder','size','rate','buffer','fps','arr')) {
    if ($Config[$key] -ne $candidate[$key]) { Say "  $key : $($Config[$key]) -> $($candidate[$key])" Cyan }
  }
  # Trial settings live only in memory. Failure or killing the launcher cannot replace the saved baseline.
  $accepted = Compare-Config $Scrcpy $Adb $Config $candidate $Serial
  if ($accepted) { Save-Config $candidate }
  try {
    $before = (@('codec','encoder','size','rate','buffer','fps','arr') | ForEach-Object { "$($_)=$($Config[$_])" }) -join ','
    $after = (@('codec','encoder','size','rate','buffer','fps','arr') | ForEach-Object { "$($_)=$($candidate[$_])" }) -join ','
    $model = $Device.Model -replace '[\r\n\t]', ' '
    [IO.File]::AppendAllText((Join-Path $Root 'tuning-history.log'), "$(Get-Date -Format o)`t$model`taccepted=$accepted`tA:$before`tB:$after`r`n", [Text.Encoding]::UTF8)
  } catch { Say '  비교 기록을 저장하지 못했습니다. 설정 저장 여부와는 별개입니다.' Yellow }
  if ($accepted) {
    Say '  개선을 확인한 후보를 저장했습니다. 이전 설정은 mirrodex.cfg.bak에 있습니다.' Green
    return $candidate
  }
  Say '  현재 설정을 유지합니다.' Green
  return $Config
}

function Restore-Refresh ($Adb, $Serial) {
  if (-not (Test-Path -LiteralPath $Recovery)) { return }
  $saved = Read-Pairs $Recovery
  if (-not (Test-Serial $saved.serial) -or $saved.previous -cnotmatch '^[01]$') { throw '주사율 복원 파일이 손상되었습니다. refresh-recovery.cfg를 확인하십시오.' }
  if ($saved.serial -ne $Serial) { throw '이전 기기의 주사율 복원이 남아 있습니다. 해당 기기를 먼저 연결해 주십시오.' }
  $restore = Invoke-Tool $Adb @('-s',$Serial,'shell','settings','put','secure','refresh_rate_mode',$saved.previous)
  $verify = Invoke-Tool $Adb @('-s',$Serial,'shell','settings','get','secure','refresh_rate_mode')
  if ($restore.Code -ne 0 -or $verify.Code -ne 0 -or $verify.Text -ne $saved.previous) { throw '주사율 복원 실패. 기기를 다시 연결하고 실행하십시오. 복원 기록을 보존했습니다.' }
  [IO.File]::Delete($Recovery)
  Say '  이전 휴대폰 주사율 설정을 복원했습니다.' Green
}

function Get-MirrorOptions ($Config, $Serial) {
  @("--serial=$Serial", '--window-title=Mirrodex', "--video-codec=$($Config.codec)",
    "--max-size=$($Config.size)", "--max-fps=$($Config.fps)", "--video-bit-rate=$($Config.rate)",
    "--video-buffer=$($Config.buffer)")
  if ($Config.audio -eq 'off') { '--no-audio' } else { '--audio-source=output' }
  @('--turn-screen-off', '--stay-awake', '--disable-screensaver')
  if ($Config.audiobuffer -and $Config.audiobuffer -ne '50') { "--audio-buffer=$($Config.audiobuffer)" }
  if ($Config.requireaudio -eq '1' -and $Config.audio -ne 'off') { '--require-audio' }
  if ($Config.encoder) { "--video-encoder=$($Config.encoder)" }
}

function Repair-RequestedRefresh ($Adb, $Serial) {
  $path=Join-Path $Root 'refresh-repair.cfg'
  if (-not (Test-Path -LiteralPath $path)) { return }
  $repair=Read-Pairs $path
  if (-not (Test-Serial $repair.serial) -or $repair.model -ne 'SM-S948N' -or $repair.target -ne '1') { throw '주사율 복구 요청 파일을 확인해 주십시오.' }
  if ($Serial -ne $repair.serial) { return }
  $model=Invoke-Tool $Adb @('-s',$Serial,'shell','getprop','ro.product.model')
  if ($model.Code -ne 0 -or $model.Text.Trim() -ne $repair.model) { throw '요청한 갤럭시인지 확인하지 못해 주사율을 바꾸지 않았습니다.' }
  $current=Invoke-Tool $Adb @('-s',$Serial,'shell','settings','get','secure','refresh_rate_mode')
  if ($current.Code -ne 0 -or $current.Text -notmatch '^[01]$') { throw '현재 주사율 모드를 읽지 못했습니다. 복구 요청을 보존합니다.' }
  if ($current.Text -eq '0') {
    $change=Invoke-Tool $Adb @('-s',$Serial,'shell','settings','put','secure','refresh_rate_mode','1')
    if ($change.Code -ne 0) { throw '주사율 복구를 완료하지 못했습니다. 다음 연결 때 다시 확인합니다.' }
  }
  $verify=Invoke-Tool $Adb @('-s',$Serial,'shell','settings','get','secure','refresh_rate_mode')
  if ($verify.Code -ne 0 -or $verify.Text -ne '1') { throw '주사율 복구를 확인하지 못해 요청을 보존합니다.' }
  [IO.File]::Delete($path)
}

function Start-Mirror ($Scrcpy, $Adb, $Config, $Serial, [int]$TrialSeconds = 0) {
  $ErrorActionPreference = 'Stop'
  $script:LastSession=$null
  Restore-Refresh $Adb $Serial
  $options = @(Get-MirrorOptions $Config $Serial)
  if ($TrialSeconds -gt 0) { $options += @("--time-limit=$TrialSeconds", '--print-fps') }
  # Recording is sidebar-only and never saved to mirrodex.cfg. Each (re)connection writes its own file.
  # AAC keeps the MP4 audio playable in standard Windows players; Opus in MP4 is not.
  $script:RecordFile=$null
  # Sources (one app, camera) apply to real sessions only; comparisons always show the whole screen.
  if ($TrialSeconds -eq 0) { $options=@(Get-SourceOptions $script:Source $options) }
  if ($TrialSeconds -eq 0 -and $script:Recording) {
    $script:RecordFile=New-RecordPath; $script:RecordStarted=[DateTime]::Now
    $options += @("--record=$script:RecordFile")
    if ($Config.audio -ne 'off') { $options += '--audio-codec=aac' }
  }
  try {
    # Legacy arr is ignored: cap stream FPS without changing the phone display mode.
    Say "`n  미러링 시작: $($Config.codec), $($Config.size)px, $($Config.fps)fps, $($Config.rate), 버퍼 $($Config.buffer)ms" Green
    if ($script:TrialGeometry) {
      $g=$script:TrialGeometry
      $options+=@("--window-x=$($g[0])","--window-y=$($g[1])","--window-width=$($g[2])","--window-height=$($g[3])")
    } elseif ($TrialSeconds -gt 0 -and $script:Context) {
      $area=$script:Context.Screen.WorkingArea
      $options+=@("--window-x=$($area.X+40)","--window-y=$($area.Y+40)","--window-height=$([Math]::Max(200,$area.Height-120))")
    }
    $script:ActiveConfig=$Config
    $script:LastSession=Invoke-MirrorProcess $Scrcpy $options $TrialSeconds
    if ($script:RecordFile -and (Test-Path -LiteralPath $script:RecordFile)) {
      $script:LastRecording=$script:RecordFile
      Say "  녹화 파일 저장: $script:RecordFile" Green
    }
    if ($script:LastSession.Request) { return }
    if ($script:LastSession.Canceled) { throw [OperationCanceledException]::new('시험을 중단했습니다. 변경 설정은 저장하지 않았습니다.') }
    if ($script:LastSession.Code -ne 0) {
      $failure=[Exception]::new("미러링 종료 오류 ($($script:LastSession.Code))")
      $failure.Data['Kind']=$script:LastSession.Kind
      throw $failure
    }
  } finally {
    try { Restore-Refresh $Adb $Serial }
    catch {
      # Preserve the journal and offer reconnection even when cleanup failed after unplugging.
      $failure=[Exception]::new($_.Exception.Message, $_.Exception)
      $failure.Data['Kind']='connection'
      throw $failure
    }
  }
}

function New-DesktopShortcut {
  $path=Join-Path ([Environment]::GetFolderPath('Desktop')) 'Mirrodex.lnk'
  if (Test-Path -LiteralPath $path) { return }
  $shortcut = (New-Object -ComObject WScript.Shell).CreateShortcut($path)
  $shortcut.TargetPath = Join-Path $Root 'Mirrodex.bat'
  $shortcut.WorkingDirectory = $Root
  $shortcut.WindowStyle = 7
  $shortcut.IconLocation = (Join-Path $Root 'mirrodex.ico') + ',0'
  $shortcut.Description = T 'Mirrodex - 휴대폰 화면 미러링'
  $shortcut.Save()
}

function Main {
  $ErrorActionPreference = 'Stop'
  $script:GuideMode = ($Mode -eq 'guide')
  try { [Console]::OutputEncoding = New-Object Text.UTF8Encoding $false } catch { }
  $Host.UI.RawUI.WindowTitle = 'Mirrodex'
  if ($Mode -eq 'install') { Install-Mirrodex; return }
  if ($Mode -eq 'uninstall') { Uninstall-Mirrodex; return }
  if ($Mode -in @('run','guide') -and (Invoke-StartupUpdateCheck)) { return }
  Remove-LegacyAssistantShortcut
  try {
    $scrcpy = Get-Scrcpy
    $adb = Join-Path (Split-Path $scrcpy) 'mirrodex-adb.exe'
    $env:ADB = $adb
    $env:SCRCPY_ICON_DIR = $Root
    $script:EnginePath = $scrcpy
    $config = $null
    $script:SecondaryDevice = ($Mode -eq 'add')
    if (-not $script:SecondaryDevice -and (Test-Path -LiteralPath $Cfg)) {
      try { $config = Import-Config }
      catch { Say "  $($_.Exception.Message) 원본 설정을 보존하고 다시 설정합니다." Yellow }
    }
    $preferred = if ($config) { $config.serial } else { '' }
    $serial = Connect-Device $adb $preferred
    # One Mirrodex process per phone: a second window for the same phone would fight over its connection.
    if (-not (Lock-Device $serial)) {
      [void](Show-GuideChoice '이 휴대폰은 이미 미러링 중입니다' '열려 있는 Mirrodex 창을 사용하십시오. 다른 휴대폰을 보려면 메뉴의 ''다른 휴대폰 추가 연결''을 누르십시오.' @(@{Key='ok';Label='확인'}))
      return
    }
    if ($Mode -eq 'diagnose') {
      $version = Invoke-Tool $scrcpy @('--version')
      $device = Inspect-Device $adb $scrcpy $serial -Fresh
      Say $version.Text; Say "$($device.Model): $($device.Short)x$($device.Long)"; Say $device.Encoders
      if ($config) { Say ((Get-MirrorOptions $config $serial) -join ' ') }
      return
    }
    Restore-Refresh $adb $serial
    Repair-RequestedRefresh $adb $serial
    Initialize-Context $adb $serial
    if ($script:SecondaryDevice) {
      # Additional phone: its own settings file inside its environment profile.
      $script:Cfg = Join-Path $script:Context.Directory 'device.cfg'; $Cfg = $script:Cfg
      [void][IO.Directory]::CreateDirectory($script:Context.Directory)
      if (Test-Path -LiteralPath $Cfg) { try { $config = Import-Config $Cfg } catch { $config = $null } }
    } else { $config=Select-Environment $config $serial }
    # Asked once per start: every path below needs it, and listing encoders starts the engine on the phone.
    $device=Inspect-Device $adb $scrcpy $serial
    if ($script:GuideMode) {
      $config=Invoke-Guide $scrcpy $adb $config $device $serial
      New-DesktopShortcut
    } elseif ($Mode -in @('run','add') -and (-not $config -or ($config.serial -and $config.serial -ne $serial))) {
      $config=Get-QuickStartConfig $device $serial
      Save-Config $config
      if (-not $script:SecondaryDevice) { New-DesktopShortcut }
      Say '  설정 저장 완료. 다음부터 바로 실행합니다.' Green
    } elseif ($Mode -eq 'setup' -or -not $config -or $config.serial -ne $serial) {
      if ($config -and -not $config.serial -and $Mode -ne 'setup') {
        # Keep legacy preferences, but discard an encoder not present on this device.
        $config.serial = $serial
        $config.encoder = Get-Encoder $device.Encoders $config.codec
      } else { $config = Select-Preset $device $serial $config }
      Save-Config $config
      New-DesktopShortcut
      Say '  설정 저장 완료. 다음부터 바로 실행합니다.' Green
    }
    if ($Mode -eq 'tune') { $config = Invoke-Tuning $scrcpy $adb $config $device $serial }
    if ($config) {
      $script:PanelDevice=$device
      $script:SidebarEnabled=$true
      Start-ResilientMirror $scrcpy $adb $config $serial
    }
  } finally { Unlock-Devices }
}

# Dot-sourcing exposes functions for dependency-free regression tests.
if ($MyInvocation.InvocationName -ne '.') {
  try { Main }
  catch [OperationCanceledException] { Say $_.Exception.Message; exit 0 }
  catch {
    Say "`n  $($_.Exception.Message)" Red
    try { [void](Show-GuideChoice '진행을 완료하지 못했습니다' ("휴대폰 연결을 확인한 뒤 도우미를 다시 열어 주십시오. 자세한 내용:`n`n" + $_.Exception.Message) @(@{Key='ok';Label='확인하고 닫기'})) } catch { }
    exit 1
  }
}
