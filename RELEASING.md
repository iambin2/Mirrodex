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

## 처음 한 번: GitHub CLI 준비

Release는 GitHub CLI(`gh`)로 만듭니다. ZIP이 10MB를 넘어 파일을 빠뜨리기 쉬운 웹 화면 대신 명령 하나로 올립니다.

1. 설치합니다. PowerShell에서:
   ```
   winget install --id GitHub.cli -e --source winget
   ```
2. **새 터미널을 열고** 로그인합니다. 설치 전에 열려 있던 터미널은 `gh`를 찾지 못합니다
   (그 터미널에서는 `& "C:\Program Files\GitHub CLI\gh.exe"`로 전체 경로를 씁니다).
   ```
   gh auth login --hostname github.com --git-protocol https --web
   ```
   화면에 나오는 8자리 코드를 브라우저(https://github.com/login/device)에 입력하고 iambin2 계정으로 승인합니다.
   터미널에 로그인 완료가 나올 때까지 명령을 끄지 마십시오. 도중에 끄면 로그인이 저장되지 않습니다.
3. `gh auth status`에 `Logged in to github.com account iambin2`가 보이면 준비가 끝난 것입니다. 이 PC에서는 다시 로그인할 필요가 없습니다.

## 배포할 때마다

아래에서 `<버전>`은 새 번호(예: 2.1.3)로 바꿔 씁니다.

1. `mirrodex-ui.ps1` 맨 위의 `$script:AppVersion` 값을 새 번호로 올립니다.
   사용자는 이 번호가 지금 버전보다 클 때만 업데이트를 받습니다.
2. 테스트를 돌립니다: `tests` 폴더의 스크립트를 PowerShell로 실행해 모두 PASS인지 확인합니다.
3. REVIEW.md 등 문서를 먼저 마무리합니다. 문서도 ZIP에 들어가므로, 패키지를 만든 뒤에 고치면 올린 ZIP과 저장소가 달라집니다.
4. 패키지를 만듭니다.
   ```
   powershell -ExecutionPolicy Bypass -File tools\build-release.ps1
   ```
   `dist` 폴더에 `Mirrodex-<버전>.zip`과 `Mirrodex-<버전>.zip.sha256`이 생깁니다.
   가능하면 ZIP을 임시 폴더에 풀어 실제 휴대폰으로 한 번 실행해 봅니다.
5. Commit하고, 태그를 만들고, 둘 다 Push합니다(Commit과 Push는 GitHub Desktop으로 해도 됩니다).
   ```
   git commit -am "Mirrodex <버전>"
   git tag -a v<버전> -m "Mirrodex <버전>"
   git push origin main v<버전>
   ```
6. 설명을 `dist\release-notes-<버전>.md`에 적습니다. 한국어 세 줄, 이어서 영어 세 줄로 바뀐 점을 씁니다.
   **첫 여섯 줄이 업데이트 안내 창에 그대로 보입니다.** 파일은 UTF-8로 저장합니다.
7. Release를 만들고 게시합니다. zip과 sha256 **두 파일을 모두** 적어야 합니다.
   ```
   gh release create v<버전> dist\Mirrodex-<버전>.zip dist\Mirrodex-<버전>.zip.sha256 --title "Mirrodex <버전>" --notes-file dist\release-notes-<버전>.md --latest --verify-tag
   ```
8. 확인합니다. 아래 명령이 zip과 sha256 두 이름을 보여 주고, `gh release list`에서 새 버전에 `Latest`가 붙어 있어야 합니다.
   ```
   gh release view v<버전> --json assets --jq ".assets[].name"
   ```

## 동작 방식과 주의

- 최신 Release에 zip과 sha256이 **둘 다** 붙어 있어야 합니다. 하나라도 없으면 앱은 그 Release를 무시하고 아무에게도 업데이트를 알리지 않습니다.
  (v2.1.0은 파일 없이 게시됐고 v2.1.1은 태그만 있었기 때문에, 2.1.2 이전에는 자동 업데이트가 동작하지 않았습니다.)
- 확인 시점: Mirrodex 실행 시 하루 한 번. 사이드 메뉴의 '업데이트 확인'은 즉시 확인하고, 설치는 다음 실행 때 묻습니다.
- 설치: zip을 내려받아 sha256과 대조한 뒤 프로그램 파일만 바꿉니다. 설정·기기 프로필·녹화·스크린샷은 그대로입니다.
  확인 값이 다르면 아무것도 바꾸지 않습니다. 다른 Mirrodex 창이 열려 있으면 설치하지 않습니다.
- 이 개발 폴더처럼 `.git`이 있는 폴더는 절대 자동 업데이트하지 않습니다(소스를 덮어쓰지 않기 위해).
- sha256은 파일이 온전히 내려받아졌는지 확인합니다. 계정이 탈취되면 zip과 sha256을 함께 바꿀 수 있으므로
  GitHub 계정에 2단계 인증을 켜 두십시오.
- 새 버전에서 파일을 지워도 사용자 PC의 옛 파일은 남습니다. 파일 이름을 바꾸면 옛 이름을 참조하는 코드가 없는지 확인하십시오.
