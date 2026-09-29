# 새 버전 배포하기 (GitHub Releases)

Mirrodex는 `https://github.com/iambin2/Mirrodex`의 **최신 Release**를 하루 한 번 확인해 자동 업데이트합니다.
저장소는 반드시 **Public**이어야 합니다. Private 저장소는 로그인 없이 Release를 읽을 수 없어 업데이트가 동작하지 않습니다.

## 처음 한 번: 저장소 만들기 (GitHub Desktop)

1. GitHub Desktop을 열고 `File > Options > Accounts`에서 GitHub 계정(iambin2)으로 로그인합니다.
2. `File > Add local repository`에서 이 폴더(`Mirrodex`)를 고릅니다.
   "This directory does not appear to be a Git repository"가 나오면 `create a repository`를 누릅니다.
   - Name: `Mirrodex` · Git ignore: None (이미 `.gitignore`가 있음) · License: None → `Create repository`
3. 왼쪽 Changes 목록에 **mirrodex.cfg, profiles, preferences.cfg, backup- 폴더가 없는지** 확인합니다.
   이 파일들에는 휴대폰 일련번호와 이 PC의 설정이 들어 있어 `.gitignore`로 제외해 두었습니다.
4. 아래 Summary에 `Mirrodex 2.0.0`을 적고 `Commit to main`을 누릅니다.
5. `Publish repository`를 누르고 **Keep this code private의 체크를 끕니다**(Public). `Publish repository`.

## 배포할 때마다

1. `mirrodex-ui.ps1` 맨 위의 `$script:AppVersion='2.0.0'`을 새 번호로 올립니다 (예: 2.0.1, 2.1.0).
   사용자는 이 번호가 지금 버전보다 클 때만 업데이트를 받습니다.
2. 테스트를 돌립니다: `tests` 폴더의 스크립트를 PowerShell로 실행해 모두 PASS인지 확인합니다.
3. 패키지를 만듭니다. PowerShell에서:
   ```
   powershell -ExecutionPolicy Bypass -File tools\build-release.ps1
   ```
   `dist` 폴더에 `Mirrodex-<버전>.zip`과 `Mirrodex-<버전>.zip.sha256`이 생깁니다.
4. GitHub Desktop에서 변경 사항을 Commit하고 `Push origin`을 누릅니다.
5. 웹에서 저장소 → 오른쪽 `Releases` → `Draft a new release`:
   - Choose a tag: `v<버전>` (예: `v2.0.1`) 입력 후 `Create new tag`
   - Release title: `Mirrodex <버전>`
   - 설명: 바뀐 점을 짧게 적습니다. 첫 여섯 줄이 업데이트 안내 창에 그대로 보입니다.
   - `Attach binaries`에 dist의 **zip과 sha256 두 파일**을 모두 올립니다.
   - `Set as the latest release`가 켜진 상태로 `Publish release`.

## 동작 방식과 주의

- 확인 시점: Mirrodex 실행 시 하루 한 번. 사이드 메뉴의 '업데이트 확인'은 즉시 확인하고, 설치는 다음 실행 때 묻습니다.
- 설치: zip을 내려받아 sha256과 대조한 뒤 프로그램 파일만 바꿉니다. 설정·기기 프로필·녹화·스크린샷은 그대로입니다.
  확인 값이 다르면 아무것도 바꾸지 않습니다. 다른 Mirrodex 창이 열려 있으면 설치하지 않습니다.
- 이 개발 폴더처럼 `.git`이 있는 폴더는 절대 자동 업데이트하지 않습니다(소스를 덮어쓰지 않기 위해).
- sha256은 파일이 온전히 내려받아졌는지 확인합니다. 계정이 탈취되면 zip과 sha256을 함께 바꿀 수 있으므로
  GitHub 계정에 2단계 인증을 켜 두십시오.
- 새 버전에서 파일을 지워도 사용자 PC의 옛 파일은 남습니다. 파일 이름을 바꾸면 옛 이름을 참조하는 코드가 없는지 확인하십시오.
