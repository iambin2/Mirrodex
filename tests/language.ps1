$ErrorActionPreference='Stop'
. (Join-Path (Split-Path $PSScriptRoot) 'mirrodex.ps1')
$script:checks=0
function Assert ($Value,$Message) { if (-not $Value) { throw $Message }; $script:checks++ }
$temp=Join-Path ([IO.Path]::GetTempPath()) ('mirrodex-language-'+[guid]::NewGuid().ToString('N'))
[void][IO.Directory]::CreateDirectory($temp)
$script:PreferencesFile=Join-Path $temp 'preferences.cfg'; $script:UiPreferences=$null
$form=$null; $panel=$null
try {
  Assert ((Get-UiLanguage) -eq 'en') 'English is the default without a saved choice'
  # Every Korean line in the app's string literals, including templates with $values, must translate.
  $allowed=@('한국어','Language / 언어','Mirrodex 도우미.lnk')
  $missing=@()
  foreach ($file in 'mirrodex.ps1','mirrodex-ui.ps1','mirrodex-guide.ps1','mirrodex-runtime.ps1','mirrodex-install.ps1','mirrodex-update.ps1') {
    # The PowerShell parser finds every string literal exactly, including templates with $values.
    $ast=[Management.Automation.Language.Parser]::ParseFile((Join-Path (Split-Path $PSScriptRoot) $file),[ref]$null,[ref]$null)
    $strings=$ast.FindAll({ param($n) ($n -is [Management.Automation.Language.StringConstantExpressionAst] -and $n.StringConstantType -ne 'BareWord') -or $n -is [Management.Automation.Language.ExpandableStringExpressionAst] },$true)
    foreach ($node in $strings) {
      $text=if ($node -is [Management.Automation.Language.ExpandableStringExpressionAst]) { $node.Extent.Text.Trim('"') } else { $node.Value }
      foreach ($line in ($text -split '`n|\n')) {
        $line=$line.Trim()
        if (-not $line -or $line -in $allowed -or $line -notmatch '[가-힣]') { continue }
        $english=(T $line) -replace "'Mirrodex 도우미'",''
        if ($english -match '[가-힣]') { $missing+="$file :: $line" }
      }
    }
  }
  # PowerShell accepts Korean letters in variable names: "$x입니다" reads a variable named x입니다. Use "$($x)입니다".
  $glued=@(foreach ($file in 'mirrodex.ps1','mirrodex-ui.ps1','mirrodex-guide.ps1','mirrodex-runtime.ps1','mirrodex-install.ps1','mirrodex-update.ps1') {
    Select-String -LiteralPath (Join-Path (Split-Path $PSScriptRoot) $file) -Pattern '\$(?:script:)?[A-Za-z_][A-Za-z0-9_]*[가-힣]' | ForEach-Object { "$file`:$($_.LineNumber)" } })
  Assert ($glued.Count -eq 0) ("variables glued to Korean text: "+($glued -join ', '))
  Assert ($missing.Count -eq 0) ("untranslated lines:`n"+($missing -join "`n"))
  Assert ((T "  미러링 시작: h265, 2340px, 60fps, 8M, 버퍼 50ms") -eq '  Mirroring: h265, 2340px, 60fps, 8M, buffer 50ms') 'runtime values survive pattern translation with indentation'
  Assert ((T "문제 정보를 저장했습니다.`nC:\x\Mirrodex-1.txt") -eq "Troubleshooting info saved.`nC:\x\Mirrodex-1.txt") 'paths pass through line by line'
  Assert ((T 'unexpected scrcpy text') -eq 'unexpected scrcpy text') 'unknown text is shown unchanged'

  $form=New-GuideForm '3. 화면은 어떠셨습니까?' '가장 불편한 것 하나를 골라 주십시오. 편하게 보였다면 더 바꿀 필요가 없습니다.' @(@{Key='good';Label='잘 보입니다 · 이대로 저장하고 사용하기'},@{Key='again';Label='잘 모르겠습니다 · 화면 다시 보기'})
  $form.Show(); [Windows.Forms.Application]::DoEvents()
  $layout=$form.MxLayout; $heading=$layout.Controls[1]; $toggle=$layout.Controls[0].Controls[2]
  Assert ($form.Text -eq 'Mirrodex Assistant' -and $heading.Text -eq '3. How did the screen look?' -and $form.CancelButton.Text -eq 'Close') 'guide opens in English'
  Assert ($toggle.Text -eq '한국어') 'toggle names the other language'
  $toggle.PerformClick(); [Windows.Forms.Application]::DoEvents()
  Assert ($heading.Text -eq '3. 화면은 어떠셨습니까?' -and $form.CancelButton.Text -eq '닫기' -and $toggle.Text -eq 'English') 'toggle relabels the open window in Korean'
  Assert ([IO.File]::ReadAllText($script:PreferencesFile).Trim() -eq 'lang=ko') 'language choice persists'
  $script:UiPreferences=$null
  Assert ((Get-UiLanguage) -eq 'ko') 'saved language is read back on next launch'
  $toggle.PerformClick(); [Windows.Forms.Application]::DoEvents()
  Assert ($heading.Text -eq '3. How did the screen look?' -and -not $form.IsDisposed -and -not $form.Tag) 'toggle back to English without closing or choosing'

  $c=@{codec='h265';encoder='x';size='2340';rate='8M';fps='60';buffer='50';arr='0';serial='T';audio='output';audiobuffer='50';requireaudio='0'}
  $panel=New-Sidebar $c @{Long=2340;Encoders='--video-codec=h265 --video-encoder=x'}; $panel.Show(); [Windows.Forms.Application]::DoEvents()
  $s=$panel.Tag
  Assert ($s.Apply.Text -eq 'Reconnect with the same settings' -and $s.Fields.audio.GetItemText($s.Fields.audio.SelectedItem) -eq 'Computer') 'sidebar and option names are English'
  $s.Fields.buffer.SelectedItem='80'
  Assert ($s.Apply.Text -eq 'Apply changes · Reconnect' -and $s.Draft.Text -eq '1 not applied yet') 'a picked value turns Apply into the English commit action'
  $panel.MxLayout.Controls[0].Controls[2].PerformClick(); [Windows.Forms.Application]::DoEvents()
  Assert ($s.Source.Text -eq '바꾸기' -and $s.Source.AccessibleName -eq '보여줄 화면 바꾸기' -and $s.Draft.Text -eq '적용하지 않은 값 1개') 'the side menu, its screen-reader names and live counts switch language in place'
  Assert ($s.Fields.audio.SelectedItem -eq '노트북' -and (Get-SidebarConfig $s).audio -eq 'output') 'translated display keeps internal option values'
  Write-Output "PASS: $script:checks language checks ($($PSVersionTable.PSVersion))"
} finally {
  if ($form) { $form.Dispose() }; if ($panel) { $panel.Dispose() }
  if ((Split-Path $temp -Leaf) -like 'mirrodex-language-*') { Remove-Item -LiteralPath $temp -Recurse -Force }
}
