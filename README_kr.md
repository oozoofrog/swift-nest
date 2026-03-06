# iOS AI Harness Starter

[English](README.md) | Korean

이 저장소는 iOS 및 SwiftUI 코드베이스에 일관된 AI 작업 하네스를 설치하기 위한 스타터입니다.

프로젝트별 규칙, 워크플로, 작업 프롬프트를 생성해서 에이전트가 항상 같은 제약과 절차를 기준으로 작업할 수 있게 합니다. 이 저장소는 빌드 가능한 iOS 앱 템플릿이 아니라, 실제 앱 저장소에 적용하는 하네스 스타터입니다.

Canonical GitHub repository:

`https://github.com/oozoofrog/ios-ai-harness-starter`

## 왜 필요한가

- 프로젝트마다 AI 규칙 문서를 수동으로 복붙하는 방식은 유지되기 어렵습니다.
- 팀은 작업별로 필요한 스킬만 선택적으로 켜고 싶습니다.
- 작은 프로젝트는 가벼운 설정이 필요하고, 큰 제품은 더 엄격한 리뷰와 워크플로가 필요합니다.
- Claude Code, ChatGPT, Codex 같은 에이전트에 긴 초기 프롬프트를 반복 입력하는 일은 번거롭고 실수도 유발합니다.

## 생성 결과

하네스는 기본적으로 아래와 같은 프로젝트 문서와 상태 파일을 생성합니다.

```text
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
```

`Docs/` 와 `.ai-harness/` 는 하네스의 핵심 자산이므로 기본적으로 버전 관리에 포함하는 것을 권장합니다.

## 빠른 시작

### 1. 예제 설정 파일 복사

```bash
cp config/project.example.yaml my-project.yaml
```

### 2. 값 수정

`my-project.yaml` 안의 값을 현재 프로젝트에 맞게 수정합니다.

### 3. 인터랙티브 초기화 실행

```bash
python3 scripts/harness.py init --config my-project.yaml
```

### 4. 비대화식 초기화 실행

```bash
python3 scripts/harness.py init \
  --config my-project.yaml \
  --profile intermediate \
  --skills ios-architecture,swiftui-rules,concurrency-rules,testing-rules,location-rules
```

### 5. 나중에 더 엄격한 프로필로 업그레이드

```bash
python3 scripts/harness.py upgrade --to advanced
```

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

## 선택적 참고 문서

하네스 규칙을 보강할 때 참고할 수 있도록, Xcode에 포함된 Apple 문서만 별도로 추출할 수 있습니다.

```bash
make extract-xcode-docs XCODE_APP=/Applications/Xcode.app
```

또는:

```bash
python3 scripts/extract_xcode_reference_docs.py --xcode-app /Applications/Xcode.app
```

이 추출은 에이전트 프롬프트나 모델 메타데이터를 포함하지 않습니다. 대신 아래 두 문서군만 정리합니다.

- `IDEIntelligenceChat.framework/Resources/AdditionalDocumentation/*.md`
- Swift 동시성 및 안전성과 직접 관련된 Swift diagnostics 문서 일부

출력은 `references/xcode-<version>-docs/` 아래에 생성됩니다.

- `apple-guides/`
- `swift-diagnostics/`
- `README.md`
- `SUMMARY.md`
- `MANIFEST.json`

이 참고 문서에서 실제 하네스에 반영한 내용은 [Docs/REFERENCE_UPDATE_NOTES.md](Docs/REFERENCE_UPDATE_NOTES.md) 에 정리되어 있습니다.

## 기존 iOS 저장소에 설치하기

이 스타터는 독립 템플릿 저장소로도 쓸 수 있고, 이미 존재하는 iOS 저장소에 하네스 파일을 주입하는 소스로도 사용할 수 있습니다.

에이전트가 실제 앱 저장소에 하네스를 설치할 때의 기본 절차는 아래와 같습니다.

1. 이 README를 먼저 읽습니다.
2. 필요한 하네스 파일을 대상 저장소 루트로 복사합니다.
3. 해당 앱에 맞는 `config/project.yaml` 을 만들거나 수정합니다.
4. 적절한 프로필과 스킬을 선택합니다.
5. 대상 저장소 루트에서 초기화 스크립트를 실행합니다.
6. 생성된 `Docs/` 와 `.ai-harness/` 를 커밋합니다.

대상 저장소에 최소한 복사해야 하는 파일:

```text
scripts/harness.py
templates/
profiles/
config/project.example.yaml
Makefile
```

권장 확인 사항:

- `.gitignore` 가 `.ai-harness/` 를 무시하지 않는지 확인
- 기존 `Docs/` 디렉터리가 있으면 덮어쓰기 전에 충돌 검토
- 프로필과 스킬은 명시적으로 선택

예시 설치 흐름:

```bash
git clone https://github.com/oozoofrog/ios-ai-harness-starter.git /tmp/ios-ai-harness-starter
rsync -av \
  /tmp/ios-ai-harness-starter/scripts \
  /tmp/ios-ai-harness-starter/templates \
  /tmp/ios-ai-harness-starter/profiles \
  /tmp/ios-ai-harness-starter/config \
  /tmp/ios-ai-harness-starter/Makefile \
  /path/to/your-ios-repo/

cd /path/to/your-ios-repo
cp config/project.example.yaml config/project.yaml
python3 scripts/harness.py init \
  --config config/project.yaml \
  --profile intermediate \
  --skills ios-architecture,swiftui-rules,concurrency-rules,networking-rules,testing-rules
```

## Agent Bootstrap Prompt

아래 프롬프트를 GitHub 링크와 함께 에이전트에게 전달하면, 현재 iOS 저장소에 하네스를 설치하는 시작점으로 사용할 수 있습니다.

```text
Use this repository as the harness starter:
https://github.com/oozoofrog/ios-ai-harness-starter

Your job is to install this AI harness into the current iOS repository.

Follow this process:
1. Read the README from the starter repository first.
2. Copy the required harness files into the current repository:
   - scripts/harness.py
   - templates/
   - profiles/
   - config/project.example.yaml
   - Makefile
3. Create or update config/project.yaml for this app based on the actual project.
4. Choose an appropriate profile and skills for this codebase.
5. Run the harness initializer from the current repository root.
6. Keep Docs/ and .ai-harness/ checked into the repository.
7. Summarize the selected profile, selected skills, generated files, and any assumptions.

Constraints:
- Do not break the existing Xcode project structure.
- Do not ignore .ai-harness/.
- Prefer minimal, reviewable changes.
- If Docs/ already exists, merge carefully instead of blindly overwriting unrelated files.
```

이 프롬프트의 목적은 스타터 저장소를 하네스 파일의 소스로 활용하면서, 실제 하네스는 작업 대상 앱 저장소 안에 설치하도록 만드는 것입니다.

## 상태 파일

`.ai-harness/state.json` 은 현재 선택 상태를 저장하고, 이후 rerender 나 profile upgrade 의 기준이 됩니다.

`.ai-harness/` 의 다른 파일:

- `selected_profile.yaml`
- `selected_skills.txt`
- `rendered_context.md`

가능하면 상태 파일 안의 경로는 저장소 기준 상대 경로로 저장되어, 다른 머신으로 옮겨도 깨지지 않게 유지됩니다.

## 명령 모음

```bash
python3 scripts/harness.py list-skills
python3 scripts/harness.py list-profiles
python3 scripts/harness.py init --config my-project.yaml
python3 scripts/harness.py render-context
python3 scripts/harness.py upgrade --to intermediate
python3 scripts/extract_xcode_reference_docs.py --xcode-app /Applications/Xcode.app
```

## 자신의 사본 공개하기

이 스타터를 기반으로 자신의 사본을 공개하려면:

```bash
git init
git add .
git commit -m "Initial AI harness starter"
git branch -M main
git remote add origin <YOUR_GITHUB_REPO_URL>
git push -u origin main
```

## 라이선스

원하는 라이선스 내용으로 이 섹션을 교체하세요.
