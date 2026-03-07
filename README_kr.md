# SwiftNest

[English](README.md) | Korean

이 저장소는 iOS 및 SwiftUI 코드베이스에 일관된 agent workflow setup을 설치하기 위한 스타터입니다.

프로젝트별 규칙, 워크플로, 작업 프롬프트, Codex 진입점을 생성해서 에이전트가 항상 같은 제약과 절차를 기준으로 작업할 수 있게 합니다. 이 저장소는 빌드 가능한 iOS 앱 템플릿이 아니라, 실제 앱 저장소에 적용하는 스타터입니다.

Canonical GitHub repository:

`https://github.com/oozoofrog/swift-nest`

## 왜 필요한가

- 프로젝트마다 AI 규칙 문서를 수동으로 복붙하는 방식은 유지되기 어렵습니다.
- 팀은 작업별로 필요한 스킬만 선택적으로 켜고 싶습니다.
- 작은 프로젝트는 가벼운 설정이 필요하고, 큰 제품은 더 엄격한 리뷰와 워크플로가 필요합니다.
- Claude Code, ChatGPT, Codex 같은 에이전트에 긴 초기 프롬프트를 반복 입력하는 일은 번거롭고 실수도 유발합니다.

## 생성 결과

SwiftNest는 기본적으로 아래와 같은 프로젝트 문서와 상태 파일을 생성합니다.

```text
AGENTS.md
Docs/
  AI_RULES.md
  AI_WORKFLOWS.md
  AI_PROMPT_ENTRY.md
  AI_SKILLS/
    ...selected skills...
.ai-harness/
  state.json
  selected_profile.yaml
  selected_skills.txt
  rendered_context.md
  workflows/
    add-feature.md
    fix-bug.md
    refactor.md
    build.md
```

`Docs/` 와 `.ai-harness/` 는 하네스의 핵심 자산이므로 기본적으로 버전 관리에 포함하는 것을 권장합니다.

`./swiftnest` shell entrypoint 는 첫 실행 시 로컬 macOS Swift 바이너리를 빌드하므로 Python runtime 이 필요하지 않습니다.

## GitHub 링크만 전달된 에이전트 설치 흐름

에이전트가 이 GitHub 링크만 받은 경우, 기대하는 설치 순서는 아래와 같습니다.

1. 이 스타터를 임시 디렉터리에 clone 또는 download 합니다.
2. 스타터 체크아웃에서 `onboard` 로 대상 앱 저장소에 SwiftNest를 설치합니다.
3. 대상 저장소 안의 `config/project.yaml`, `AGENTS.md`, `Docs/` 생성 결과를 검토합니다.
4. 대상 저장소 루트에서 에이전트 작업을 시작합니다.
5. 대상 저장소에서 생성된 `Docs/` 와 `.ai-harness/` 를 커밋합니다.

예시:

```bash
git clone https://github.com/oozoofrog/swift-nest.git /tmp/swift-nest
/tmp/swift-nest/swiftnest onboard \
  --target /path/to/current-ios-repo \
  --non-interactive
```

첫 실행 시 `tools/swiftnest-cli/.build/` 아래에 로컬 Swift 바이너리를 빌드합니다. 다른 저장소에 SwiftNest를 설치하는 것이 목적이라면, 스타터 체크아웃 안에서 `./swiftnest onboard` 나 `./swiftnest init` 를 실행하면 안 됩니다.

## Homebrew 패키징

SwiftNest는 별도 tap 저장소(예: `oozoofrog/homebrew-swiftnest`)에서 사용할 Homebrew 패키징 자산을 `packaging/homebrew/` 아래에 함께 제공합니다.

권장 릴리즈 흐름:

1. 이 저장소에서 Git tag를 만들고 push 합니다.
2. GitHub에서 해당 tag source archive를 내려받고 SHA256을 계산합니다.
3. `packaging/homebrew/render_formula.sh` 로 `packaging/homebrew/swiftnest.rb.template` 를 tap 저장소의 `Formula/swiftnest.rb` 로 렌더링합니다.
4. 렌더링된 formula를 tap 저장소에 커밋하고 push 합니다.
5. `brew install swiftnest` 와 `brew test swiftnest` 로 배포 결과를 확인합니다.

기능 개발 이후 end-to-end 배포 마무리 순서는 `AGENTS.md` 를 기준으로 진행합니다.

tap 이 공개된 이후 기대하는 설치 흐름은 아래와 같습니다.

```bash
brew tap oozoofrog/swiftnest https://github.com/oozoofrog/homebrew-swiftnest
brew install swiftnest
swiftnest onboard --target /path/to/current-ios-repo
```

Homebrew로 설치된 전역 `swiftnest` 는 bootstrap 용도에 맞춰 설계됩니다. 현재 디렉터리에 repo-local `./swiftnest` 가 이미 있다면, tap wrapper 는 그 로컬 엔트리포인트로 위임해서 이후 명령이 계속 저장소 복사본을 기준으로 실행되게 해야 합니다.

repo-local `./swiftnest` 스크립트는 첫 실행 시 여전히 로컬 macOS Swift 바이너리를 빌드하므로, 대상 저장소에서도 macOS Swift toolchain 이 필요합니다.

## 빠른 시작

이 섹션은 현재 저장소에 이미 하네스 관리 파일이 들어 있고, macOS Swift toolchain 을 사용할 수 있다고 가정합니다.

### 1. 온보딩 실행

```bash
./swiftnest onboard
```

### 2. 비대화식 온보딩 실행

```bash
./swiftnest onboard \
  --config config/project.yaml \
  --profile intermediate \
  --skills ios-architecture,swiftui-rules,concurrency-rules,testing-rules,location-rules \
  --workflows permissions,review \
  --non-interactive
```

### 3. 더 세밀한 제어가 필요할 때 하위 명령 사용

```bash
cp config/project.example.yaml config/project.yaml
./swiftnest init --config config/project.yaml
```

### 4. 이후 rerender 또는 upgrade

```bash
./swiftnest render-context
./swiftnest upgrade --to advanced
./swiftnest workflow list
./swiftnest workflow scaffold permissions review
```

`upgrade` 는 기존 `.ai-harness/state.json` 이 있어야 하므로 먼저 `init` 을 실행해야 합니다.

## 사용 시나리오

### 1. 빈 저장소에서 하네스를 처음부터 구성하는 경우

저장소가 비어 있거나, 앱 구조가 완성되기 전에 먼저 SwiftNest 기준을 세우고 싶을 때 적합합니다.

권장 흐름:

1. 새 저장소를 만들거나 빈 저장소 루트로 이동합니다.
2. 이 스타터를 임시 디렉터리에 clone 합니다.
3. `onboard` 로 새 저장소에 SwiftNest를 설치하고 설정 및 문서 생성을 한 번에 진행합니다.
4. `config/project.yaml` 과 생성된 `AGENTS.md` 를 검토합니다.
5. 필요하다면 가벼운 프로필과 작은 스킬 세트로 온보딩을 다시 실행합니다.
6. 생성된 `Docs/` 와 `.ai-harness/` 를 커밋합니다.

예시:

```bash
mkdir MyNewApp
cd MyNewApp
git init

git clone https://github.com/oozoofrog/swift-nest.git /tmp/swift-nest
/tmp/swift-nest/swiftnest onboard --target "$PWD"
```

### 2. 이미 존재하는 iOS 프로젝트 상태에 맞춰 하네스를 적용하는 경우

기존 앱 구조, 프레임워크, 권한, 테스트 방식, 네이밍 규칙을 기준으로 SwiftNest를 맞추고 싶을 때 사용합니다.

권장 흐름:

1. 현재 프로젝트의 아키텍처, 프레임워크 사용, 권한 영역, 테스트 스타일을 먼저 확인합니다.
2. 저장소 루트에 `onboard` 를 실행해서 SwiftNest 설치, 설정 기본값 생성, 문서 초기화를 함께 수행합니다.
3. 실제 프로젝트 상태를 반영하도록 `config/project.yaml` 을 검토합니다.
4. 현재 코드베이스에 맞는 프로필, 스킬, 워크플로를 필요에 따라 명시합니다.
5. 생성된 문서가 현재 프로젝트 관습과 맞는지 검토하고 커밋합니다.

예시:

```bash
cd /path/to/existing-ios-repo

git clone https://github.com/oozoofrog/swift-nest.git /tmp/swift-nest
/tmp/swift-nest/swiftnest onboard \
  --target "$PWD" \
  --profile intermediate \
  --skills ios-architecture,swiftui-rules,concurrency-rules,networking-rules,testing-rules \
  --workflows networking,review
```

프로젝트에 위치 권한, HealthKit, 구조화 로그가 이미 중요하게 들어가 있다면 해당 스킬도 초기화 시점에 함께 추가하는 것이 좋습니다. `permissions`, `networking`, `review` 같은 optional workflow scaffold는 이후 `./swiftnest workflow scaffold ...`로 추가합니다.

### 3. 하네스를 먼저 도입하고 이후 더 발전시켜 적용하는 경우

처음에는 가볍게 도입하고, 프로젝트가 커지면서 점진적으로 더 엄격한 기준으로 발전시키고 싶을 때 적합합니다.

권장 흐름:

1. SwiftNest를 한 번 설치한 뒤 `basic` 또는 `intermediate` 로 온보딩합니다.
2. 일정 기간 팀이 실제로 SwiftNest를 사용하게 둡니다.
3. 새 도메인이 코드베이스에 생기면 스킬을 추가합니다.
4. 리뷰 기준을 강화할 필요가 생기면 프로필을 업그레이드합니다.
5. 선택 상태가 바뀔 때마다 SwiftNest 상태를 다시 생성하고 커밋합니다.

예시:

```bash
./swiftnest onboard \
  --profile basic \
  --skills ios-architecture,swiftui-rules,testing-rules \
  --non-interactive

./swiftnest upgrade --to intermediate
./swiftnest upgrade --to advanced
./swiftnest render-context
```

이 방식에서는 `.ai-harness/state.json` 이 이후 rerender 와 upgrade 를 이어주는 기준점 역할을 합니다.

optional workflow는 기본 비활성입니다. `init` 를 다시 실행하면 workflow 세트는 기본 core workflow로 초기화됩니다.

## 관리 대상 파일

설치기는 아래 하네스 관리 파일만 복사합니다.

```text
Makefile
config/project.example.yaml
swiftnest
harness
profiles/
templates/
tools/swiftnest-cli/Package.swift
tools/swiftnest-cli/Sources/
tools/swiftnest-cli/Tests/
```

대상 저장소에 같은 경로의 파일이 이미 있고 내용이 다르면, `--force` 없이는 설치가 중단됩니다.

`tools/swiftnest-cli/.build/` 아래의 로컬 빌드 산출물은 관리 대상 파일이 아니며 계속 ignore 상태여야 합니다.

`harness`는 `swiftnest`로 전달하는 호환 shim으로 남아 있습니다.

## 프로필

### `basic`

- 최소 규칙 세트
- 개인 프로젝트와 MVP에 적합
- 프로세스 오버헤드를 낮게 유지

### `intermediate`

- 제품 개발용 균형형 기본값
- self-review 와 회귀 테스트 기대치를 강화
- 대부분의 실서비스 앱에 적합

### `advanced`

- 장기 유지보수용 엄격한 리뷰 프로필
- 리스크, 프라이버시, 성능, 상태 전이에 대한 요구 강화
- 전달 형식과 검토 기준이 더 엄격함

## 사용 가능한 스킬

- `ios-architecture`
- `swiftui-rules`
- `concurrency-rules`
- `location-rules`
- `healthkit-rules`
- `networking-rules`
- `testing-rules`
- `logging-rules`

### 일반적인 SwiftUI 앱 추천 조합

- `ios-architecture`
- `swiftui-rules`
- `concurrency-rules`
- `networking-rules`
- `testing-rules`

### 러닝 또는 피트니스 앱 추천 조합

- `ios-architecture`
- `swiftui-rules`
- `concurrency-rules`
- `location-rules`
- `healthkit-rules`
- `testing-rules`
- `logging-rules`

## Agent Bootstrap Prompt

아래 프롬프트를 GitHub 링크와 함께 에이전트에게 전달할 수 있습니다.

```text
Use this repository as the SwiftNest starter:
https://github.com/oozoofrog/swift-nest

Your job is to install SwiftNest into the current iOS repository.

Follow this process:
1. Clone or download the starter repository into a temporary directory.
2. Read the README from the starter repository first.
3. From the starter checkout, run:
   ./swiftnest onboard --target <CURRENT_REPOSITORY_ROOT>
4. Review config/project.yaml so it reflects the actual project state.
5. Review the generated AGENTS.md, Docs/, and .ai-harness/ output.
6. If needed, rerun ./swiftnest onboard or ./swiftnest init with explicit profile, skills, or workflows.
7. Keep Docs/ and .ai-harness/ checked into the repository.
8. Summarize the selected profile, selected skills, generated files, and any assumptions.

Constraints:
- Do not run ./swiftnest onboard or ./swiftnest init from the starter checkout when the goal is to modify the current repository.
- Do not break the existing Xcode project structure.
- Do not ignore .ai-harness/.
- Prefer minimal, reviewable changes.
- If Docs/ already exists, merge carefully instead of blindly overwriting unrelated files.
- If .ai-harness/state.json already exists, treat it as the current harness state before rerendering or upgrading.
```

이 프롬프트의 목적은 스타터 저장소를 SwiftNest 파일의 소스로 활용하면서, 실제 설정은 작업 대상 앱 저장소 안에 설치하도록 만드는 것입니다.

## 상태 파일

`.ai-harness/state.json` 은 현재 선택 상태를 저장하고, 이후 rerender 나 profile upgrade 의 기준이 됩니다.

`.ai-harness/` 의 다른 파일:

- `selected_profile.yaml`
- `selected_skills.txt`
- `rendered_context.md`
- `workflows/*.md`

가능하면 상태 파일 안의 경로는 저장소 기준 상대 경로로 저장되어, 다른 머신으로 옮겨도 SwiftNest가 깨지지 않게 유지됩니다.

## 명령 모음

스타터 체크아웃 또는 이미 SwiftNest 관리 파일이 들어 있는 저장소에서:

```bash
./swiftnest onboard --target /path/to/app-repo
make onboard TARGET=/path/to/app-repo
./swiftnest install --target /path/to/app-repo
make install-swiftnest TARGET=/path/to/app-repo
```

SwiftNest가 이미 설치된 저장소에서:

```bash
./swiftnest onboard
make onboard CONFIG=config/project.yaml
./swiftnest list-skills
./swiftnest list-profiles
./swiftnest init --config config/project.yaml --workflows permissions,review
./swiftnest workflow list
./swiftnest workflow print add-feature
./swiftnest workflow scaffold permissions review
./swiftnest render-context
./swiftnest upgrade --to intermediate
make init CONFIG=config/project.yaml
make context
make upgrade PROFILE=advanced
```

런타임 출력 언어는 전역 옵션이나 환경변수로 고를 수 있습니다.

```bash
./swiftnest --lang ko --help
SWIFTNEST_LANG=ko ./swiftnest list-profiles
```

## 자신의 사본 공개하기

이 스타터를 기반으로 자신의 사본을 공개하려면:

```bash
git init
git add .
git commit -m "Initial SwiftNest starter"
git branch -M main
git remote add origin <YOUR_GITHUB_REPO_URL>
git push -u origin main
```

## 라이선스

원하는 라이선스 내용으로 이 섹션을 교체하세요.
