---
name: Mirrodex
description: 굴절 검사 기록지 — 지금 보이는 것을 기록하고, "1 또는 2"로 한 가지씩 비교한다
colors:
  background: "#F3F4F6"
  surface: "#FFFFFF"
  text: "#15171A"
  muted: "#596069"
  rule: "#E1E4E8"
  field: "#8D949E"
  hover: "#EDEFF2"
  down: "#E1E4E8"
  selection: "#E8ECF1"
  focus: "#15171A"
  pencil: "#596069"
  ink: "#15171A"
  ink-hover: "#2B2F35"
  ink-down: "#000000"
  on-ink: "#FFFFFF"
  lamp: "#B47B0A"
  lamp-tint: "#FBF1D9"
  rec: "#D0281B"
  rec-tint: "#FCE9E7"
  success: "#1D7446"
  danger: "#B42318"
  on-danger: "#FFFFFF"
  disabled: "#ECEEF1"
  disabled-text: "#8B929B"
  background-dark: "#141517"
  surface-dark: "#1D1F22"
  text-dark: "#ECEDEF"
  muted-dark: "#A3A9B1"
  rule-dark: "#2C2F34"
  field-dark: "#6B727C"
  hover-dark: "#26292D"
  selection-dark: "#2A3038"
  ink-dark: "#ECEDEF"
  on-ink-dark: "#141517"
  lamp-dark: "#F2B93B"
  lamp-tint-dark: "#33291A"
  rec-dark: "#F2594B"
  rec-tint-dark: "#3A1D1A"
  success-dark: "#5CC28E"
  danger-dark: "#F08A7E"
typography:
  title:
    fontFamily: "Pretendard, Malgun Gothic, Segoe UI Variable Text"
    fontSize: "15pt"
    fontWeight: 600
  headline:
    fontFamily: "Pretendard, Malgun Gothic, Segoe UI Variable Text"
    fontSize: "12pt"
    fontWeight: 600
  brand:
    fontFamily: "Pretendard, Malgun Gothic, Segoe UI Variable Text"
    fontSize: "11.5pt"
    fontWeight: 600
  numeral:
    fontFamily: "Pretendard, Malgun Gothic, Segoe UI Variable Text"
    fontSize: "11pt"
    fontWeight: 600
  body:
    fontFamily: "Pretendard, Malgun Gothic, Segoe UI Variable Text"
    fontSize: "10pt"
    fontWeight: 400
    lineHeight: 1.18
  label:
    fontFamily: "Pretendard, Malgun Gothic, Segoe UI Variable Text"
    fontSize: "10pt"
    fontWeight: 500
  section:
    fontFamily: "Pretendard, Malgun Gothic, Segoe UI Variable Text"
    fontSize: "9pt"
    fontWeight: 600
  caption:
    fontFamily: "Pretendard, Malgun Gothic, Segoe UI Variable Text"
    fontSize: "9pt"
    fontWeight: 400
rounded:
  control: "6px"
  card: "8px"
  chip: "999px"
spacing:
  gap: "8px"
  inset: "12px"
  indent: "26px"
  group: "16px"
  panel: "16px"
  window: "20px"
components:
  button-primary:
    backgroundColor: "{colors.ink}"
    textColor: "{colors.on-ink}"
    rounded: "{rounded.control}"
    height: "36px"
  button-primary-hover:
    backgroundColor: "{colors.ink-hover}"
  button-secondary:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.text}"
    rounded: "{rounded.control}"
    height: "36px"
  button-danger:
    backgroundColor: "{colors.danger}"
    textColor: "{colors.on-danger}"
    rounded: "{rounded.control}"
    height: "36px"
  choice:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.text}"
    rounded: "{rounded.control}"
    height: "56px"
  choice-primary:
    backgroundColor: "{colors.ink}"
    textColor: "{colors.on-ink}"
    rounded: "{rounded.control}"
    height: "56px"
  row:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.text}"
    height: "50px"
  row-hover:
    backgroundColor: "{colors.hover}"
  key:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.text}"
    rounded: "{rounded.control}"
    height: "52px"
  key-lit:
    backgroundColor: "{colors.lamp-tint}"
  key-recording:
    backgroundColor: "{colors.rec-tint}"
  chip:
    backgroundColor: "{colors.background}"
    textColor: "{colors.text}"
    rounded: "{rounded.chip}"
    height: "22px"
  input:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.text}"
    rounded: "{rounded.control}"
    height: "36px"
---

# Mirrodex 디자인 규칙

모든 창(사이드 메뉴, 도우미, 시험 창, 선택 목록, 입력 창, 설치·업데이트 안내)은 `mirrodex-ui.ps1`의 토큰과 컴포넌트로만 만든다.
색·크기·여백 숫자를 화면 코드에 직접 쓰지 않는다. 필요한 값이 없으면 토큰을 먼저 추가하고 이 문서를 고친다.

## Overview

**디자인 철학: 화면은 휴대폰의 것이다 — Mirrodex는 지금 보이는 것과 그 상태를 기록지처럼 먼저 보여 주고, 화면을 끊거나 저장하는 행동은 결과를 미리 말한 뒤에만 하며, 바꿀 때는 한 번에 하나씩 "1 또는 2"로 비교하게 한다.**

판단이 갈릴 때는 이 순서로 정한다: ① 지금 방송·녹화 중인 화면을 놀라게 하지 않는가 → ② 사용자가 확인하지 않은 것을 저장하지 않는가 → ③ 처음 쓰는 사람이 다음 행동을 찾는가 → ④ 익숙한 사람의 속도를 늦추지 않는가.

시각 언어의 근원은 안경점의 굴절 검사다. 기록지(현재 상태를 칸마다 적은 카드)와 "1번이 나아요, 2번이 나아요?"라는 비교 의식. 장식이 아니라 이 제품의 고유한 동작(한 가지만 바꾼 현재 → 변경 → 현재 비교, 좋아졌다고 답한 것만 저장)을 그대로 화면 문법으로 옮긴 것이다.

| 원칙 | 해결하는 문제 | 규칙 | 어긋나는 예 | 판단 기준 |
|---|---|---|---|---|
| 1. 상태가 먼저 | 방송·녹화 중에 무엇이 나가는지, 녹화 중인지, 잠겼는지, 저장된 설정인지 한눈에 알 수 없었다 | 사이드 메뉴 맨 위는 '지금' 카드: 보여줄 화면(제목), 해상도·fps·전송량·압축, 기기·연결, 상태 칩(녹화 시간, 재연결 잠금, 저장됨/이번 실행만), 결과 메시지 | 상태를 버튼 색이나 흐린 한 줄에만 두기 | 1초 안에 "무엇이·녹화 중인지·잠겼는지·저장됐는지" 네 가지에 답할 수 있는가 |
| 2. 결과를 먼저 말한다 | 적용·녹화·화면 바꾸기가 화면을 다시 연결해 Discord 공유가 끊기는데 누르기 전에 알 수 없었다 | 화면을 다시 연결하는 모든 동작에 같은 ↻ 표시. 버튼 문구는 `동작 · 결과`. 잠금 중에는 ↻ 대신 자물쇠를 그리고 막는다 | 설명 없이 재연결하는 버튼, 이유 없이 회색이 된 버튼 | 모든 행동의 결과(즉시/재연결/저장)를 누르기 전에 읽을 수 있는가 |
| 3. 한 번에 하나, 1 또는 2 | 도우미 선택지가 모두 같은 버튼이라 '대답'과 '나가기'가 섞였고, "가운데 화면" 같은 기억 부담이 있었다 | 대답은 명령 링크(제목 + 결과 줄), 추천 대답만 채운 색. 나가기·복원은 '다른 선택'으로 분리. 비교는 1 · 2 · 1 렌즈 원판으로 보여 준다 | 탈출 선택지를 대답과 같은 무게로 나열 | 질문에 대한 대답과 흐름을 떠나는 선택을 구분해 읽을 수 있는가 |
| 4. 연필과 잉크 | 고른 값·적용한 값·저장한 값이 구별되지 않아 "저장"이 무엇을 저장하는지 헷갈렸다 | 고르고 적용하지 않은 값은 점선 밑줄(연필)과 개수로, 적용한 값은 실선. '저장된 설정 / 이번 실행에만 쓰는 설정' 칩. 바꾼 값이 없으면 적용 버튼은 '같은 설정으로 다시 연결' | 색만으로 변경 여부 표시 | 색을 빼도(고대비 모드) 상태가 읽히는가 |
| 5. Windows답게 | 사용자는 Windows 앱을 쓰고 있다 | 키보드만으로 모든 흐름 완료, Enter=추천 대답(파괴 동작 제외), Esc=취소, 대화상자 버튼은 오른쪽 아래 [동작] [닫기] 순서, 화면 읽기 프로그램 이름, DPI, 라이트/다크/고대비 | 머리글의 언어 버튼에 첫 포커스가 가서 Enter가 언어를 바꾸는 것 | 마우스 없이 설치부터 비교·저장까지 끝낼 수 있는가 |

**고유한 시각적 특징:** 기록지처럼 괘선(얇은 가로줄)으로 나뉜 이름/값 줄, 1 · 2 · 1 렌즈 원판, 켜짐 램프(로고 눈의 호박색), 연필 점선, 한 가지 ↻ 기호. 그림자·유리·그라데이션은 쓰지 않는다.

**절충:** 스트리밍 사용자에게 익숙한 카메라 뷰파인더 문법(REC 점, 모드 알약)보다 비교 의식을 택했다. 녹화 상태는 REC 빨강과 시간 칩으로 보완한다. 사이드 메뉴는 이전보다 약간 넓고(380px, 영어 키 문구가 잘리지 않는 폭) 정보가 많아졌지만, 접힌 상태는 1200px 화면 125%에서 한국어·영어 모두 스크롤 없이 들어가고, 키 문구는 잘리지 않는다(`tests/sidebar.ps1`이 두 언어로 확인).

## Colors

Windows 설정을 따른다: 고대비가 켜져 있으면 Windows 고대비 색, 아니면 앱 모드(라이트/다크). 화면 코드는 의미 이름만 쓴다.

| 토큰 | 라이트 | 다크 | 쓰임 |
|---|---|---|---|
| Background | #F3F4F6 | #141517 | 창 바탕, 제목 표시줄, 칩 바탕 |
| Surface | #FFFFFF | #1D1F22 | 카드, 줄, 키, 입력 |
| Text / Muted | #15171A / #596069 | #ECEDEF / #A3A9B1 | 본문 / 설명·값 읽기·섹션 이름 |
| Rule | #E1E4E8 | #2C2F34 | 괘선, 카드 테두리(장식) |
| Field | #8D949E | #6B727C | 입력·선택 칸의 경계(3:1 이상), 꺼진 램프 |
| Ink (+Hover/Down), OnInk | #15171A | #ECEDEF | 한 화면에 하나뿐인 확정 동작, 추천 대답, 켜진 렌즈 원판 |
| Lamp / LampTint | #B47B0A / #FBF1D9 | #F2B93B / #33291A | 켜짐(항상 위, 방송 잠금) — 로고의 눈 |
| Rec / RecTint | #D0281B / #FCE9E7 | #F2594B / #3A1D1A | 녹화 중에만 |
| Success | #1D7446 | #5CC28E | '저장됨'과 성공 메시지의 기호 |
| Danger (+Hover/Down) | #B42318 | #F08A7E | 오류 메시지, 제거 |
| Pencil | #596069 | #A3A9B1 | 적용 전 값의 점선 |
| Hover / Down / Selection | #EDEFF2 / #E1E4E8 / #E8ECF1 | #26292D / #2F3237 / #2A3038 | 상호작용 상태 |
| Focus | #15171A | #ECEDEF | 키보드 포커스 고리(2px) |
| Disabled / DisabledText | #ECEEF1 / #8B929B | #222428 / #636A73 | 비활성 |

- 색 전략은 절제(중립 + 잉크). 호박·빨강·초록은 상태에만 쓴다. 장식에 쓰지 않는다.
- 상태는 색만으로 나타내지 않는다: 램프는 켜지면 채운 원·꺼지면 빈 원, 잠금은 자물쇠, 적용 전은 점선, 메시지는 어조마다 다른 기호(✓ 성공, ! 오류, 시계 진행 중, ● 녹화, i 안내).
- 고대비: Window/WindowText/Highlight/HighlightText/GrayText로 대체한다. 모양으로 상태가 남는다.

## Typography

한 글꼴, 굵기로 위계. Pretendard가 있으면 두 언어 모두 Pretendard. 없으면 한국어는 맑은 고딕, 영어는 Segoe UI Variable(Windows 10은 Segoe UI) — GDI+ 대체 글꼴이 한글 간격을 벌리기 때문이다. 언어를 바꾸면 열린 창의 글꼴도 다시 적용한다. 한글은 띄어쓰기 단위 줄바꿈.

글자는 Windows가 ClearType을 쓰면 ClearType + 힌팅(Windows 기본 앱과 같은 방식), ClearType을 끈 PC에서는 회색조로 그린다(`MxTheme.Hint`). 힌팅 없는 회색조는 획이 픽셀 사이에 걸쳐 거칠게 보인다. 줄마다 시작 위치를 정수 픽셀에 맞추고, 크기 측정도 그리기와 같은 방식으로 한다(`MxTheme.Measure`).

| 역할 | 크기 | 굵기 | 쓰임 |
|---|---|---|---|
| Title | 15pt | SemiBold | 도우미 질문 (창마다 하나) |
| Headline | 12pt | SemiBold | 사이드 메뉴 '지금' 카드의 보여줄 화면 |
| Brand | 11.5pt | SemiBold | 머리글 "Mirrodex" |
| Numeral | 11pt | SemiBold | 렌즈 원판 숫자 |
| Body | 10pt | Regular | 본문, 줄 제목, 메시지, 입력, 목록 |
| Label | 10pt | Medium | 버튼, 키, 대답, 입력 이름 |
| Section | 9pt | SemiBold (Muted) | 묶음 이름 |
| Caption | 9pt | Regular (Muted) | 값 읽기, 결과 줄, 각주 |

## Layout

4px 격자, 96DPI 기준 값(창이 배율에 맞춰 한 번 확대).

- **두 개의 세로 기준선.** 테두리 있는 모양의 안쪽 여백은 12(Inset). 아이콘은 그 12에서 시작하고 글자는 12+16+10=38(Indent 26 = 아이콘 16 + 간격 10)에서 시작한다. '지금' 카드, 키, 줄, 메시지, 링크가 모두 이 두 선에 맞는다.
- **간격:** 컨트롤 사이 8, 묶음 사이 16, 섹션 위 16 / 아래 8, 제목 아래 6, 설명 아래 16. 창 안쪽 여백: 사이드 메뉴 16, 대화상자 20.
- **높이:** 버튼 36, 작은 버튼 28, 링크 26, 줄 40(결과 줄 있으면 50), 대답 44/56, 다른 선택 34/44, 키 52.
- **사이드 메뉴 순서(빈도와 위험 순):** 머리글 → 지금 카드 → 키 2×2(녹화, 스크린샷, 항상 위, 방송 잠금) → 화면(도우미, 접힌 화면 설정) → 연결(무선 전환, 다른 휴대폰) → 도움말 링크 → ↻ 설명 → X 설명. 폭 380, 높이는 내용에 맞추고 화면보다 길면 스크롤. 미러링 창 옆(오른쪽, 자리가 없으면 왼쪽)에 붙어 따라간다.
- **도우미 창:** 머리글 → 질문 → 설명 → 내용(렌즈 원판, 목록, 입력) → 대답(명령 링크) → 다른 선택 → 바닥줄 [동작] [닫기]. 폭 560, 높이는 내용에 맞춘다. 시험 창은 시험 중인 미러링 창을 가리지 않도록 그 옆에 붙는다.
- **밀도:** 작업 화면이므로 줄 높이를 늘리지 않는다. 설명은 결과 줄(두 번째 줄) 한 줄로 끝낸다.

## Elevation & Depth

그림자를 쓰지 않는다. 깊이는 두 층뿐이다: 바탕(Background) 위의 표면(Surface) + 1px 괘선. 누름·가리킴은 표면 색 변화로만 알린다. 켜진 키는 LampTint/RecTint 바탕과 램프 색 테두리로 한 층 올라온 것처럼 보인다. 대화상자와 창의 깊이는 Windows 창 그림자와 둥근 모서리(Windows 11)에 맡긴다.

## Shapes

- **픽셀 정렬:** GDI+는 정수 좌표가 픽셀 중앙이다. 선 두께는 정수 픽셀(`MxTheme.Px`), 테두리 경로는 `MxTheme.Edge`(홀수 두께는 정수, 짝수 두께는 .5 좌표), 채움은 `MxTheme.Cover`로 픽셀을 정확히 덮는다. x.5에 그린 1px 선은 회색 두 줄로 번진다. 아이콘은 상자를 정수 픽셀에 놓고 선 두께를 반올림한다.
- 모서리: 컨트롤 6, 카드 8, 칩은 완전한 알약. 이름/값 줄은 모서리 없이 위쪽 괘선만.
- 렌즈 원판: 지름 30, 현재 단계는 잉크로 채우고 숫자는 반전, 지난 단계는 굵은 테두리, 남은 단계는 Field 테두리. 원판 사이는 1.5px 선.
- 램프: 지름 8, 켜짐=채움, 꺼짐=빈 원(Field), 녹화=Rec. 녹화 중에는 0.5초 간격으로 깜박인다(움직임 끄기 설정이면 멈춤).
- 연필: 1.2px 점선 밑줄.
- 아이콘: 직접 그린 한 세트(16 격자, 1.5 둥근 선, 점만 채움). 글자 기호(●, ▾, ✓)를 아이콘으로 쓰지 않는다. 목록: record, stop, camera, pin, wifi, phone, plus, screen, app, chevron(down/up/right), reconnect, lock, check, alert, info, clock, lens, sliders, help, file, update, folder, broadcast, pencil.

## Components

| 컴포넌트 | 함수 | 규칙 |
|---|---|---|
| 버튼 | `New-UiButton` | primary(화면에 하나, 다음에 할 일) / secondary / danger / compact / link. 동사로 쓴다. 재연결하면 `-Reconnects`(↻). |
| 대답 | `New-UiButton … 'choice'` | 도우미의 대답. `제목 · 결과` → 두 줄. 첫 대답이 추천(choice-primary, Enter). 오른쪽 ›. |
| 다른 선택 | Choice에 `Variant='quiet'` | 흐름을 떠나는 선택(임시 사용, 복원, 문제 정보, 건너뛰기). '다른 선택' 아래 테두리 없는 줄. |
| 줄 | `Add-SidebarRow` | 사이드 메뉴 카드 안의 이동·열기. 아이콘 + `제목 · 설명` + ↻/›/⌄. 둘째 줄부터 위 괘선. |
| 키 | `New-UiButton … 'key'`, `New-UiToggle` | 빠른 작업. 켜고 끄는 것은 램프가 있는 진짜 체크 상자(화면 읽기에서 켬/끔), 즉시 동작은 램프 없음. |
| 칩 | `New-UiChip` | 지금 카드의 상태: 녹화 시간(rec), 재연결 잠금(lamp), 저장됨(success)/이번 실행만(neutral). 누를 수 없다. |
| 카드 | `New-UiCard` | 둥근 표면. 카드 안에 카드를 넣지 않는다(설정 줄은 괘선만). |
| 글 | `New-UiText` | title / headline / body / muted / caption / section. 선택적 기호(Glyph)는 아이콘 열에 그린다. |
| 메시지 | `Set-UiStatus` | info / success / danger / busy / rec. 기호가 어조를 전하고, 오류만 글자색도 바꾼다. 파일 경로를 넘기면 '파일 위치 열기' 링크가 나타난다. 빈 문자열이면 숨긴다. |
| 선택 칸 | `New-UiCombo` | 닫힌 모양은 직접 그리고(다크에서도 같은 모양), 목록·키보드는 Windows 그대로. 표시만 번역, 값은 유지. 적용 전이면 점선. |
| 체크 | `New-UiCheck` | 설정 줄 안의 켜기/끄기. 적용 전이면 글자에 점선. |
| 입력 | `New-UiInput` | Field 경계, 입력 중 2px Focus. 회색 안내문. 잘못된 값은 이유를 알리고 값을 남긴 채 다시 묻는다. |
| 목록 | `New-UiList` | 이름 + 보조 정보 두 줄, 괘선 구분, 고른 줄에 ✓ 기호. 검색 결과가 없으면 그렇게 말한다. 3~6줄 뒤 스크롤. 현재 값이 처음부터 선택된다. |
| 렌즈 원판 | `New-UiLensTrack` | 1 · 2 · 1 비교. 단계 안내, 비교 전 미리보기, 시험 창(남은 시간 선), 판정 창(2를 강조)에서 같은 모양. |
| 느린 작업 | `Invoke-UiBusy` | 대기 커서 + 버튼 비활성 + 시계 메시지 "…하는 중입니다" → 결과. |

### 상태

| 상태 | 표현 |
|---|---|
| 기본 | Surface + Rule 테두리 (줄은 테두리 없음) |
| 가리킴 / 누름 | Hover / Down 채움. 줄은 안쪽으로 4px 들어간 둥근 채움 |
| 포커스(키보드) | 테두리 모양 위 2px Focus 고리, 채운 버튼은 안쪽 1.5px 반전 고리. 마우스 클릭에는 안 보임(Windows 규칙) |
| 선택 / 켜짐 | 목록: Selection + ✓. 키: 틴트 + 램프 색 테두리 + 채운 램프 |
| 비활성 | DisabledText. 잠금 때문이면 자물쇠 기호. 녹화 램프 같은 상태 표시는 비활성에서도 유지 |
| 진행 중 | 대기 커서 + 시계 메시지 |
| 빈 상태 | 검색 결과 없음 안내. 메시지 줄은 비어 있으면 숨김 |
| 성공 / 오류 | ✓ 기호(초록) + 본문색 글 / ! 기호 + Danger 글. 오류는 무엇이 문제인지와 어떻게 하면 되는지 |
| 적용 전 | 점선 밑줄 + "적용하지 않은 값 N개" + 적용이 primary로 |

### 움직임

WinForms에서 움직임은 상태를 알리는 곳에만 둔다. 시험 창의 남은 시간 선(0.2초마다 줄어듦)과 녹화 램프·칩의 깜박임(0.5초)뿐이다. Windows 설정 > 접근성 > 시각 효과 > 애니메이션 효과가 꺼져 있으면 깜박임을 멈춘다(시간 선은 정보이므로 유지). 가리킴·펼치기는 즉시 바뀐다.

### 문구

- 한국어: 합쇼체(~습니다 / ~하십시오 / ~습니까?). 영어: 문장형 대소문자(제품명 제외).
- 버튼은 동사, 결과는 ` · ` 뒤에(대답·줄·키에서는 둘째 줄이 된다). 첫 ` · `만 나눈다.
- 같은 대상은 같은 이름: 도우미의 "바뀌는 값" 줄은 사이드 메뉴 설정 이름을 그대로 쓴다.
- 오류는 무엇이 문제인지와 어떻게 하면 되는지를 함께 쓴다.
- 한국어 원문이 코드의 기준이고 영어는 `mirrodex-lang.ps1`에서 표시 직전에 바꾼다. `tests/language.ps1`이 빠진 번역과 변수 붙여쓰기를 찾는다.

## Do's and Don'ts

- Do: 화면을 다시 연결하는 동작에는 항상 ↻를 붙이고, 잠금 중에는 자물쇠로 바꾼다.
- Do: 한 화면의 채운(잉크) 버튼은 하나. 바꾼 값이 없으면 사이드 메뉴에는 채운 버튼이 없다.
- Do: 상태는 모양(채움/빈 원, 점선, 기호)과 색을 함께 쓴다.
- Do: 시험 창과 사이드 메뉴는 미러링 창 옆에 둔다. 판단 중인 화면을 가리지 않는다.
- Don't: 카드 안에 카드, 모든 것을 카드로 감싸기, 그림자·유리·그라데이션.
- Don't: 흐름을 떠나는 선택(임시 사용, 복원, 문제 정보, 건너뛰기)을 대답과 같은 무게로 두기.
- Don't: 파괴 동작(제거)을 Enter 기본값으로 두기.
- Don't: 고르기만 한 값을 저장하기. 저장은 실행 중인 설정만, 명시적으로.
