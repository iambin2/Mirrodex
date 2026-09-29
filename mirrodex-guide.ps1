# Native Windows guide. Loaded without opening a window; UI assemblies load on demand.
. (Join-Path $PSScriptRoot 'mirrodex-ui.ps1')
# Every assistant screen is one pattern: header, question, explanation, optional content (lens track, list, fields),
# then the answers as command links with the recommended one filled, then "other options" (quiet), then the footer.
# A dialog with a single action puts it in the footer like any Windows dialog: [action] [Close], right-aligned.
function New-GuideForm ($Title, $Text, $Choices, $Content=@(), [switch]$Closable) {
  Add-Type -AssemblyName System.Windows.Forms
  Add-Type -AssemblyName System.Drawing
  [Windows.Forms.Application]::EnableVisualStyles()
  $form = New-Object Windows.Forms.Form
  Set-UiText $form 'Mirrodex 도우미'
  $form | Add-Member -NotePropertyName MxGuide -NotePropertyValue $true
  $form.StartPosition = 'CenterScreen'; $form.MaximizeBox = $false
  Set-ModernForm $form
  $form.ClientSize = New-Object Drawing.Size(560, 420)
  $form.MinimumSize = New-Object Drawing.Size(360,240)
  $width=560-2*$script:UiSpace.Window
  $layout = New-UiLayout $form
  Add-BrandHeader $layout
  $layout.Controls.Add((New-UiText $Title 'title' $width))
  $layout.Controls.Add((New-UiText $Text 'body' $width))
  foreach ($control in @($Content)) { $layout.Controls.Add($control) }
  $choices=@($Choices | Where-Object { $_ })
  $quiet=@($choices | Where-Object { $_.Variant -eq 'quiet' })
  $answers=@($choices | Where-Object { $_.Variant -ne 'quiet' })
  $buttons=@(); $footer=@()
  if ($choices.Count -eq 1 -and -not $quiet.Count) {
    $choice=$choices[0]
    $button=New-UiButton $choice.Label $choice.Key $(if ($choice.Variant) { $choice.Variant } else { 'primary' }) ([string]$choice.Icon)
    $button.AutoSize=$true; $button.AutoSizeMode='GrowAndShrink'
    $buttons+=$button; $footer+=$button
  } else {
    foreach ($choice in $answers) {
      $variant=switch ($choice.Variant) { 'danger' {'danger'} 'secondary' {'choice'} default { if ($buttons.Count) {'choice'} else {'choice-primary'} } }
      $button=New-UiButton $choice.Label $choice.Key $variant ([string]$choice.Icon) $(if ($variant -eq 'danger') {''} else {'chevron-right'})
      $button.Dock='Top'
      $layout.Controls.Add($button); $buttons+=$button
    }
    if ($quiet.Count) {
      $layout.Controls.Add((New-UiText '다른 선택' 'section'))
      foreach ($choice in $quiet) {
        $button=New-UiButton $choice.Label $choice.Key 'quiet' ([string]$choice.Icon)
        $button.Dock='Top'; $button.Margin=New-UiPadding 0 0 0 2
        $layout.Controls.Add($button); $buttons+=$button
      }
    }
  }
  foreach ($button in $buttons) { $button.Add_Click({ $this.FindForm().Tag=[string]$this.Tag; $this.FindForm().Close() }) }
  # Enter answers with the recommended choice, never with a destructive one; focus starts there, not on the header.
  if ($buttons.Count -and $buttons[0].Variant -ne 'danger') { $form.AcceptButton=$buttons[0]; $form | Add-Member -NotePropertyName MxFocus -NotePropertyValue $buttons[0] }
  if ($choices.Count -gt 1 -or $Closable) {
    $close=New-UiButton '닫기' '' 'secondary'
    $close.AutoSize=$true; $close.AutoSizeMode='GrowAndShrink'
    $close.DialogResult=[Windows.Forms.DialogResult]::Cancel
    $form.CancelButton=$close; $footer+=$close
    if (-not $form.AcceptButton) { $form | Add-Member -NotePropertyName MxFocus -NotePropertyValue $close -Force }
  } else {
    # One action only: a second 'Close' button would read as a second answer. Esc and the title bar X still cancel.
    $form.KeyPreview=$true
    $form.Add_KeyDown({ if ($_.KeyCode -eq 'Escape') { $this.Close() } })
  }
  if ($footer.Count) {
    $bar=New-Object Windows.Forms.TableLayoutPanel
    $bar.AutoSize=$true; $bar.Dock='Top'; $bar.RowCount=1; $bar.ColumnCount=$footer.Count+1
    $bar.Margin=New-UiPadding 0 $script:UiSpace.Gap 0 0
    [void]$bar.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle('Percent',100)))
    for ($i=0; $i -lt $footer.Count; $i++) {
      [void]$bar.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle('AutoSize')))
      $footer[$i].Margin=New-UiPadding $script:UiSpace.Gap 0 0 0
      $bar.Controls.Add($footer[$i],$i+1,0)
    }
    $bar | Add-Member -NotePropertyName MxFooter -NotePropertyValue $true
    $layout.Controls.Add($bar)
  }
  $layout.RowCount=$layout.Controls.Count
  for ($i=0;$i -lt $layout.RowCount;$i++) { [void]$layout.RowStyles.Add((New-Object Windows.Forms.RowStyle('AutoSize'))) }
  $form.Add_Shown({ Fit-GuideContent $this; if ($this.PSObject.Properties['MxFocus'] -and $this.MxFocus) { $this.ActiveControl=$this.MxFocus } })
  Complete-UiForm $form
  return $form
}

function Fit-GuideContent ($Form) {
  # Measure after native DPI scaling, including header, button margins and the footer.
  $layout=$Form.MxLayout; $scroll=$layout.Parent
  $area=[Windows.Forms.Screen]::FromControl($Form).WorkingArea
  $Form.MaximumSize=$area.Size
  $layout.PerformLayout()
  $width=$scroll.ClientSize.Width+$(if ($scroll.VerticalScroll.Visible) { [Windows.Forms.SystemInformation]::VerticalScrollBarWidth } else { 0 })
  $preferred=$layout.GetPreferredSize((New-Object Drawing.Size($width,0)))
  $chrome=$Form.Height-$Form.ClientSize.Height
  $height=[Math]::Min($preferred.Height+16,$area.Height-$chrome-32)
  # Height only, so a scrollbar shown before fitting never narrows the dialog.
  $Form.Height=[Math]::Max(200,$height)+$chrome
  $layout.PerformLayout()
  if ($Form.StartPosition -ne 'Manual') { $Form.Top=[Math]::Max($area.Top,$area.Top+[int](($area.Height-$Form.Height)/2)) }
}

function Show-GuideChoice ($Title, $Text, $Choices, [switch]$Closable, $Content=@()) {
  $form=New-GuideForm $Title $Text $Choices $Content -Closable:$Closable
  try {
    [void]$form.ShowDialog()
    if (-not $form.Tag) { throw [OperationCanceledException]::new('길라잡이를 종료했습니다. 확인하지 않은 설정은 저장하지 않았습니다.') }
    return [string]$form.Tag
  } finally { $form.Dispose() }
}

# List picker: optional search field above the list; double-click or Enter picks. Returns the key, or $null if closed.
# The current choice (Selected) starts highlighted, so Enter keeps what is already there.
function New-GuidePicker ($Title, $Text, $Items, [string]$Action, [switch]$Search, [string]$Selected='') {
  $content=@()
  if ($Search) { $filter=New-UiInput '' '이름으로 찾기' '이름으로 찾기'; $content+=$filter }
  $list=New-UiList @($Items | ForEach-Object { if ($_.Detail) { "$(T $_.Label)`t$(T $_.Detail)" } else { T $_.Label } })
  $list | Add-Member -NotePropertyName MxItems -NotePropertyValue @($Items)
  $list | Add-Member -NotePropertyName MxVisible -NotePropertyValue @($Items)
  if (@($Items).Count) { $list.SelectedIndex=[Math]::Max(0,[array]::IndexOf([string[]]@($Items | ForEach-Object { [string]$_.Key }),$Selected)) }
  $list.Add_DoubleClick({ if ($this.SelectedIndex -ge 0) { $f=$this.FindForm(); $f.Tag='pick'; $f.Close() } })
  # The list sits in a ruled card; an empty search says so instead of showing a blank box.
  $frame=New-UiCard 1
  $frame.AutoSize=$false; $frame.Margin=New-UiPadding 0 0 0 $script:UiSpace.Body
  $empty=New-UiText '찾는 이름이 없습니다. 다른 글자로 찾아 보십시오.' 'caption'
  $empty.Margin=New-UiPadding 11 10 11 10; $empty.Visible=$false
  $list | Add-Member -NotePropertyName MxEmpty -NotePropertyValue $empty
  $frame.Controls.Add($empty); $frame.Controls.Add($list)
  [void]$frame.RowStyles.Add((New-Object Windows.Forms.RowStyle('AutoSize'))); [void]$frame.RowStyles.Add((New-Object Windows.Forms.RowStyle('Percent',100)))
  if ($Search) {
    $filter.Input | Add-Member -NotePropertyName MxList -NotePropertyValue $list
    $filter.Input.Add_TextChanged({
      $l=$this.MxList; $q=$this.Text.Trim()
      $l.MxVisible=@($l.MxItems | Where-Object { -not $q -or (T $_.Label) -like "*$q*" -or [string]$_.Detail -like "*$q*" -or $_.Label -like "*$q*" })
      $l.BeginUpdate(); $l.Items.Clear()
      foreach ($item in $l.MxVisible) { [void]$l.Items.Add($(if ($item.Detail) { "$(T $item.Label)`t$(T $item.Detail)" } else { T $item.Label })) }
      if ($l.Items.Count) { $l.SelectedIndex=0 }; $l.EndUpdate()
      $l.MxEmpty.Visible=-not $l.Items.Count
    })
  }
  $content+=$frame
  $form=New-GuideForm $Title $Text @(@{Key='pick';Label=$Action}) $content -Closable
  # Rows are measured after DPI scaling (ItemHeight is already in device pixels): 3 to 6 rows, then it scrolls.
  $frame.Height=[Math]::Min(6,[Math]::Max(3,@($Items).Count))*$list.ItemHeight+2*$frame.Padding.Top
  $form | Add-Member -NotePropertyName MxList -NotePropertyValue $list
  # Typing starts in the search field; without one, arrow keys move in the list.
  $form | Add-Member -NotePropertyName MxFocus -NotePropertyValue $(if ($Search) { $filter.Input } else { $list }) -Force
  return $form
}
function Show-GuidePicker ($Title, $Text, $Items, [string]$Action, [switch]$Search, [string]$Selected='') {
  $form=New-GuidePicker $Title $Text $Items $Action -Search:$Search -Selected $Selected
  try {
    [void]$form.ShowDialog()
    $list=$form.MxList
    if ($form.Tag -ne 'pick' -or $list.SelectedIndex -lt 0) { return $null }
    return [string]@($list.MxVisible)[$list.SelectedIndex].Key
  } finally { $form.Dispose() }
}
# Field form: labeled inputs, one primary action. Returns @{key=value}, or $null if closed.
function Show-GuideInput ($Title, $Text, $Fields, [string]$Action) {
  $content=@(); $inputs=@{}
  foreach ($field in $Fields) {
    $label=New-UiText $field.Label 'body'; Set-UiFont $label 'Label'; $label.Margin=New-UiPadding 0 0 0 6
    $input=New-UiInput ([string]$field.Value) ([string]$field.Placeholder) $field.Label
    $input.Margin=New-UiPadding 0 0 0 $script:UiSpace.Inset
    $content+=$label; $content+=$input; $inputs[$field.Key]=$input.Input
  }
  $content[-1].Margin=New-UiPadding 0 0 0 $script:UiSpace.Body
  $form=New-GuideForm $Title $Text @(@{Key='ok';Label=$Action}) $content -Closable
  $form | Add-Member -NotePropertyName MxFocus -NotePropertyValue $inputs[$Fields[0].Key] -Force
  try {
    [void]$form.ShowDialog()
    if ($form.Tag -ne 'ok') { return $null }
    $values=@{}; foreach ($key in $inputs.Keys) { $values[$key]=$inputs[$key].Text.Trim() }
    return $values
  } finally { $form.Dispose() }
}
# The trial window: the phase as a lens disc (1 · 2 · 1) and the time left as a draining line.
# The first check and 'watch again' compare nothing, so they show only the time line.
function New-TrialForm ([int]$Seconds) {
  $phase=[array]::IndexOf([string[]]@('현재 화면','바꿔 본 화면','현재 화면 다시 보기'),[string]$script:TrialLabel)
  $track=if ($phase -ge 0) { New-UiLensTrack $phase -1 -Timer } else { New-UiLensTrack -Timer -NoDiscs }
  $track.TimeText=T "약 $($Seconds)초 남았습니다"
  $form=New-GuideForm $script:TrialLabel '같은 앱을 움직여 보십시오. 시간이 끝나면 안내로 돌아옵니다. 도중에 닫으면 변경 설정은 채택하지 않습니다.' @(@{Key='stop';Label='시험 중단 · 설정 유지';Variant='secondary'}) @($track)
  $form | Add-Member -NotePropertyName MxTrack -NotePropertyValue $track
  return $form
}
# What one comparison changes, in the side menu's own names (for people who know the numbers; the assistant never asks).
function Get-ConfigChangeLines ($Before, $After) {
  $names=@{size='화면 선명도 · 긴 변 px';fps='프레임 상한 · fps';rate='화질 · 전송량';buffer='영상 완충 · ms';codec='화면 압축 방식'}
  foreach ($key in @('size','fps','rate','buffer','codec')) {
    if ([string]$Before[$key] -ne [string]$After[$key]) { "$($names[$key]): $($Before[$key]) → $($After[$key])" }
  }
}

function Get-GuideCandidate ($Config, $Device, $Symptom, $Tried) {
  $steps = switch ($Symptom) {
    'stutter' { @('1','2','5','7','6') }
    'blur' { @('3','10','5') }
    'delay' { @('4','5','2') }
    default { throw '알 수 없는 증상입니다.' }
  }
  foreach ($step in $steps) {
    try { $candidate=Get-TuningCandidate $Config $Device $step } catch { continue }
    $signature=(@('codec','encoder','size','rate','buffer','fps','arr') | ForEach-Object { $candidate[$_] }) -join '|'
    if ($Tried.Add($signature)) {
      $explanation = switch ($step) {
        '1' { '화면을 조금 기다렸다가 고르게 보여주는 방법을 시험합니다. 조작 반응도 함께 확인해 주십시오.' }
        '2' { '화면 처리량을 조금 줄여 봅니다. 글씨가 읽기 불편해지지 않는지도 확인해 주십시오.' }
        '3' { '글씨를 조금 더 선명하게 보여주는 방법을 시험합니다. 움직임이 끊기지 않는지도 확인해 주십시오.' }
        '4' { '화면을 기다리는 시간을 줄여 봅니다. 움직임이 더 끊기지 않는지도 확인해 주십시오.' }
        '5' { '휴대폰이 화면을 보내는 방식을 바꿔 봅니다. 부드러움과 반응을 함께 확인해 주십시오.' }
        '6' { '보내는 정보량을 줄여 봅니다. 글씨와 영상이 흐려지지 않는지도 확인해 주십시오.' }
        '7' { '컴퓨터와 휴대폰이 처리하는 양을 줄여 봅니다. 움직임이 덜 자연스러울 수 있습니다.' }
        '10' { '화면의 세부 내용을 더 많이 보내 봅니다. 움직임이 끊기지 않는지도 확인해 주십시오.' }
      }
      return @{Config=$candidate; Explanation=$explanation}
    }
  }
  return $null
}

function Compare-GuideConfig ($Scrcpy, $Adb, $Baseline, $Candidate, $Serial) {
  $phases=@('현재 화면','바꿔 본 화면','현재 화면 다시 보기')
  for ($i=0; $i -lt 3; $i++) {
    $phase=$phases[$i]
    $pick=Show-GuideChoice $phase "같은 앱에서 같은 동작을 해 보십시오. 시험 창의 크기와 위치를 이어서 사용합니다.`n`n30초 뒤 안내로 돌아옵니다. 시간이 부족하면 짧게 시험하거나 비교를 건너뛸 수 있습니다." @(@{Key='start';Label='준비 완료 · 30초 보기'},@{Key='short';Label='10초만 보기'},@{Key='skip';Label='비교 건너뛰기 · 현재 설정 유지';Variant='quiet'}) -Content @(New-UiLensTrack $i)
    if ($pick -eq 'skip') { return $false }
    $seconds=if ($pick -eq 'short') { 10 } else { 30 }
    $script:TrialLabel=$phase
    $trial = if ($phase -eq '바꿔 본 화면') { $Candidate } else { $Baseline }
    Start-Mirror $Scrcpy $Adb $trial $Serial $seconds
  }
  $answer=Show-GuideChoice '어느 쪽이 더 편하셨습니까?' '2번 바꿔 본 화면이 앞뒤의 1번 현재 화면보다 좋았습니까? 글씨·움직임·반응 중 다른 불편이 생겼다면 현재 화면을 유지하십시오.' @(
    @{Key='keep';Label='비슷하거나 판단하기 어렵습니다 · 현재 설정 유지'},
    @{Key='better';Label='바꿔 본 화면이 더 좋습니다 · 이 설정 저장'},
    @{Key='worse';Label='바꿔 본 화면이 더 불편합니다 · 현재 설정 유지'}) -Content @(New-UiLensTrack -1 1)
  return ($answer -eq 'better')
}

function Get-GuideExitChoices ($Serial) {
  @(@{Key='temporary';Label='저장하지 않고 지금 설정으로 사용'},@{Key='export';Label='문제 정보 저장하고 종료'})
  if (Read-Profile 'good' $Serial) { @{Key='restore';Label='정상 동작했던 설정으로 복원'} }
  if (Read-PreviousConfig $Serial) { @{Key='undo';Label='직전 설정 변경 취소'} }
}
function Complete-Guide ($Action, $Config, $Serial) {
  switch ($Action) {
    'export' { Show-Diagnostics $Config; return $null }
    'restore' { $restored=Read-Profile 'good' $Serial; if (-not $restored) { throw '이 환경의 정상 설정이 없습니다.' }; Save-Config $restored; return $restored }
    'undo' { $restored=Read-PreviousConfig $Serial; if (-not $restored) { throw '이 환경의 직전 설정이 없습니다.' }; Save-Config $restored; return $restored }
    'temporary' { return $Config }
  }
}

function Invoke-Guide ($Scrcpy, $Adb, $Current, $Device, $Serial) {
  $best=$null
  if ($Current -and $Current.serial -eq $Serial) { $best=$Current.Clone() }
  if (-not $best) {
    $environment=Show-GuideChoice '1. 어떻게 연결하셨습니까?' '잘 모르겠으면 첫 번째를 선택하십시오. 기기에 맞는 화면 설정은 도우미가 준비합니다.' @(
      @{Key='usb';Label='케이블로 연결했습니다 · 잘 모르겠으면 선택'},
      @{Key='wireless';Label='이미 무선으로 연결해 사용 중입니다'},
      @{Key='lowload';Label='컴퓨터가 오래되었거나 가볍게 사용하고 싶습니다'})
    $best=Get-StartingConfig $Device $Serial $environment
  }
  $saved=($Current -and $Current.serial -eq $Serial)
  # Leaving without a trial is possible but secondary: the exits sit under 'other options'.
  $exits=@(Get-GuideExitChoices $Serial | ForEach-Object { $_.Variant='quiet'; $_ })
  $entry=Show-GuideChoice '2. 휴대폰 화면 확인' "30초 동안 평소 쓰는 앱을 움직여 보십시오. 휴대폰 자체 화면은 꺼질 수 있습니다. 시험 화면이 닫히면 이 안내로 돌아옵니다." (@(@{Key='start';Label='30초 동안 화면 보기'})+$exits)
  if ($entry -ne 'start') { return (Complete-Guide $entry $best $Serial) }
  $attempts=0; $alternateUsed=$false
  $script:TrialLabel='현재 화면'
  while ($true) {
    try { Start-Mirror $Scrcpy $Adb $best $Serial 30; break }
    catch [OperationCanceledException] { throw }
    catch {
      Say $_.Exception.Message Yellow
      if (Test-Path -LiteralPath $Recovery) { throw }
      $kind=$_.Exception.Data['Kind']; $alternate=$null
      if ($kind -eq 'encoder' -and -not $alternateUsed -and $attempts -lt 2) { $alternate=Get-AlternativeEncoder $best $Device }
      $action=Get-RecoveryChoice $kind ([bool]$alternate) ($attempts -lt 2)
      if ($action -eq 'export') { Show-Diagnostics $best; return $null }
      if ($action -eq 'alternate') { $best=$alternate; $saved=$false; $alternateUsed=$true }
      else { [void](Connect-Device $Adb $Serial -RequirePreferred) }
      $attempts++
    }
  }
  $tried=New-Object 'Collections.Generic.HashSet[string]'
  $initialSignature=(@('codec','encoder','size','rate','buffer','fps','arr') | ForEach-Object { $best[$_] }) -join '|'
  [void]$tried.Add($initialSignature)
  $comparisons=0
  while ($true) {
    $symptom=Show-GuideChoice '3. 화면은 어떠셨습니까?' '가장 불편한 것 하나를 골라 주십시오. 편하게 보였다면 더 바꿀 필요가 없습니다.' @(
      @{Key='good';Label='잘 보입니다 · 이대로 저장하고 사용하기'},
      @{Key='stutter';Label='움직임이 자꾸 끊깁니다'},
      @{Key='blur';Label='글씨나 화면이 흐릿합니다'},
      @{Key='delay';Label='누른 뒤 반응이 늦습니다'},
      @{Key='again';Label='잘 모르겠습니다 · 화면 다시 보기'},
      @{Key='finish';Label='다른 방법으로 마치기 · 임시 사용, 복원, 문제 정보 저장';Variant='quiet'})
    if ($symptom -eq 'finish') {
      $action=Show-GuideChoice '어떻게 마치시겠습니까?' '확인하지 않은 설정은 저장하지 않고 사용할 수 있습니다. 정상 설정은 직접 지정했을 때만 바뀝니다.' (@(Get-GuideExitChoices $Serial)+@(@{Key='pin';Label='현재 화면을 정상 설정으로 지정하고 사용'}))
      if ($action -eq 'pin') { Save-Config $best; Save-Profile 'good' $best; return $best }
      return (Complete-Guide $action $best $Serial)
    }
    if ($symptom -eq 'good') {
      if (-not $saved) { Save-Config $best }
      if (-not (Read-Profile 'good' $Serial)) { Save-Profile 'good' $best }
      [void](Show-GuideChoice '준비가 완료되었습니다' "다음부터는 Mirrodex를 누르면 바로 시작합니다.`n`n마우스로 누르거나 끌어서 휴대폰을 조작하십시오. 끝낼 때는 미러링 창의 X를 누르십시오.`n`n불편해지면 미러링 옆 메뉴의 '도우미로 화면 맞추기'를 누르십시오." @(@{Key='done';Label='미러링 시작하기'}))
      return $best
    }
    if ($symptom -eq 'again') { Start-Mirror $Scrcpy $Adb $best $Serial 30; continue }
    $next=Get-GuideCandidate $best $Device $symptom $tried
    if (-not $next -or $comparisons -ge 5) {
      $action=Show-GuideChoice '이번 비교를 마쳤습니다' "최대 다섯 가지를 비교했습니다. 완벽한 설정을 찾았다는 뜻은 아닙니다.`n`n케이블을 PC에 직접 꽂고, 무선이면 공유기 가까이 이동해 보십시오. 휴대폰 자체에서도 끊기는지 확인해 주십시오." @(Get-GuideExitChoices $Serial)
      return (Complete-Guide $action $best $Serial)
    }
    $changes=New-UiText (@(Get-ConfigChangeLines $best $next.Config) -join "`n") 'caption' 520
    $changes.Margin=New-UiPadding 0 0 0 $script:UiSpace.Body
    [void](Show-GuideChoice '한 가지 설정만 바꿔 비교합니다' ($next.Explanation + "`n`n현재 → 변경 → 현재 화면을 30초씩 보여드립니다. 좋아졌다고 선택하기 전에는 저장하지 않습니다.") @(@{Key='compare';Label='약 90초 동안 비교하기'}) -Content @((New-UiLensTrack),$changes))
    $comparisons++
    try { $better=Compare-GuideConfig $Scrcpy $Adb $best $next.Config $Serial }
    catch [OperationCanceledException] { throw }
    catch {
      Say $_.Exception.Message Yellow
      if (Test-Path -LiteralPath $Recovery) { throw }
      [void](Show-GuideChoice '시험이 완료되지 않았습니다' '휴대폰 연결을 확인해 주십시오. 시험하던 설정은 저장하지 않았습니다. 현재 설정으로 돌아갑니다.' @(@{Key='back';Label='현재 설정 유지하기'}))
      continue
    }
    if ($better) { Save-Config $next.Config; $best=$next.Config; $saved=$true }
  }
}
