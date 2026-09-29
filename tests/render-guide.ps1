. (Join-Path (Split-Path $PSScriptRoot) 'mirrodex-guide.ps1')
$form=New-GuideForm '3. 화면은 어떠셨습니까?' '가장 불편한 것 하나를 골라 주십시오. 편하게 보였다면 더 바꿀 필요가 없습니다.' @(@{Key='good';Label='잘 보입니다 · 이대로 저장하고 사용하기'},@{Key='stutter';Label='움직임이 자꾸 끊깁니다'},@{Key='blur';Label='글씨나 화면이 흐릿합니다'},@{Key='delay';Label='누른 뒤 반응이 늦습니다'},@{Key='again';Label='잘 모르겠습니다 · 화면 다시 보기'},@{Key='finish';Label='임시 사용 · 복원 · 문제 정보 저장'})
try {
  $form.Show(); [Windows.Forms.Application]::DoEvents(); $form.PerformLayout()
  $bitmap=New-Object Drawing.Bitmap($form.Width,$form.Height)
  try { $form.DrawToBitmap($bitmap, (New-Object Drawing.Rectangle(0,0,$form.Width,$form.Height))); $bitmap.Save((Join-Path $PSScriptRoot 'guide-preview.png')) } finally { $bitmap.Dispose() }
  $buttons=@($form.Controls[0].Controls | Where-Object { $_ -is [Windows.Forms.Button] })
  if ($buttons.Count -ne 7) { throw 'Missing choices' }
  $buttons[2].PerformClick()
  if ($form.Tag -ne 'blur') { throw 'Choice dispatch failed' }
  Write-Output 'GUI render and button dispatch passed'
} finally { $form.Dispose() }
