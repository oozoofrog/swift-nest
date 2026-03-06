# iOS AI Harness Starter

iOS/SwiftUI 프로젝트에서 AI 에이전트가 항상 같은 규칙을 읽고, 선택한 스킬만 적용하며, 프로젝트 성숙도에 따라 단계적으로 복잡도를 올릴 수 있게 해주는 템플릿 리포입니다.

Canonical GitHub repository:

`https://github.com/oozoofrog/ios-ai-harness-starter`

이 리포는 다음 문제를 풀기 위해 만들어졌습니다.

- 프로젝트마다 다른 규칙 문서를 매번 수동으로 복붙하는 문제
- 위치/HealthKit/Networking/Concurrency 같은 스킬을 작업별로 골라 쓰고 싶은 문제
- 초기엔 가볍게 시작하고, 나중에 더 엄격한 규칙과 워크플로를 추가하고 싶은 문제
- Claude Code, ChatGPT, Codex류 에이전트에 매번 긴 프롬프트를 반복 입력하는 문제

## 핵심 기능

- 템플릿 기반 문서 렌더링
- 키값 치환 (`{{PROJECT_NAME}}` 등)
- 스킬 선택 생성 (`location-rules`, `healthkit-rules` 등)
- 복잡도 프로파일 선택 (`basic`, `intermediate`, `advanced`)
- 프로젝트 루트에 `Docs/` 및 `.ai-harness/` 생성
- 에이전트 진입 프롬프트 자동 생성
- 이후 단계 업그레이드 가능

## 생성 결과

기본적으로 아래 구조를 생성합니다.

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

`Docs/` 와 `.ai-harness/` 는 이 스타터의 활성 하네스 상태이므로 버전 관리에 포함하는 것을 기본값으로 권장합니다.

## 빠른 시작

### 1) 설정 파일 복사

```bash
cp config/project.example.yaml my-project.yaml
```

### 2) 값 수정

`my-project.yaml` 안의 키를 프로젝트에 맞게 바꿉니다.

### 3) 인터랙티브 실행

```bash
python3 scripts/harness.py init --config my-project.yaml
```

### 4) 비대화식 실행

```bash
python3 scripts/harness.py init \
  --config my-project.yaml \
  --profile intermediate \
  --skills ios-architecture,swiftui-rules,concurrency-rules,testing-rules,location-rules
```

### 5) 다음 단계로 올리기

```bash
python3 scripts/harness.py upgrade --to advanced
```

## 프로파일 설명

### basic
- 최소 규칙 세트
- 작은 개인 프로젝트 / MVP 용도
- 최소 문서 + 핵심 스킬만 운영

### intermediate
- 팀 규칙/레이어 책임/자체 리뷰 강화
- 대부분의 실서비스 앱에 적합

### advanced
- 엄격한 체크리스트
- 성능/보안/프라이버시/회귀 테스트 요구 강화
- 복잡한 제품이나 장기 유지보수용

## 스킬 목록

현재 제공되는 스킬:

- `ios-architecture`
- `swiftui-rules`
- `concurrency-rules`
- `location-rules`
- `healthkit-rules`
- `networking-rules`
- `testing-rules`
- `logging-rules`

## 추천 조합

### 일반 SwiftUI 앱
- `ios-architecture`
- `swiftui-rules`
- `concurrency-rules`
- `networking-rules`
- `testing-rules`

### 러닝/운동 앱
- `ios-architecture`
- `swiftui-rules`
- `concurrency-rules`
- `location-rules`
- `healthkit-rules`
- `testing-rules`
- `logging-rules`

## 에이전트 사용 예시

생성 후 아래처럼 에이전트에게 요청합니다.

```text
먼저 Docs/AI_RULES.md, Docs/AI_WORKFLOWS.md, 관련 AI_SKILLS 문서를 읽고 적용 규칙을 요약하세요.
그 다음 최소 구현 전략, 수정 파일, 테스트 계획, 구현, 자체 리뷰 순서로 진행하세요.
```

## GitHub에 올리는 방법

이 리포를 새 GitHub 저장소로 올리려면:

```bash
git init
git add .
git commit -m "Initial AI harness starter"
git branch -M main
git remote add origin <YOUR_GITHUB_REPO_URL>
git push -u origin main
```

## 스크립트 명령

```bash
python3 scripts/harness.py list-skills
python3 scripts/harness.py list-profiles
python3 scripts/harness.py init --config my-project.yaml
python3 scripts/harness.py render-context
python3 scripts/harness.py upgrade --to intermediate
python3 scripts/extract_xcode_reference_docs.py --xcode-app /Applications/Xcode.app
```

## 생성 상태 파일

`.ai-harness/state.json` 에 현재 선택 상태가 저장됩니다.
이 파일을 기준으로 이후 업그레이드/재렌더링이 수행됩니다.
저장소 안의 경로를 가리킬 때는 상대 경로로 저장되어, 다른 머신으로 옮겨도 상태 파일이 깨지지 않게 유지됩니다.

## Optional Reference Docs

하네스 규칙을 보강할 때 참고할 수 있도록, Xcode에 포함된 Apple 문서만 별도로 추출할 수 있습니다.

```bash
make extract-xcode-docs XCODE_APP=/Applications/Xcode.app
```

이 추출은 `에이전트 프롬프트`를 다루지 않습니다. 대신 아래 두 문서군만 정리합니다.

- `IDEIntelligenceChat.framework/Resources/AdditionalDocumentation/*.md`
- `XcodeDefault.xctoolchain/usr/share/doc/swift/diagnostics/*.md` 중 하네스에 직접 도움 되는 동시성/안전성 문서

추출 결과는 `references/xcode-<version>-docs/` 아래에 생성됩니다.

- `apple-guides/`: 최신 Apple 기능/프레임워크 가이드
- `swift-diagnostics/`: Swift 동시성/격리/Sendable 관련 진단 문서
- `README.md`: 이 참조 세트의 목적과 추천 읽기 순서
- `SUMMARY.md`: 카테고리/파일 수 요약
- `MANIFEST.json`: 기계가 읽기 쉬운 인덱스

## Existing iOS Repo에 설치하기

이 스타터는 "새 템플릿 프로젝트"로만 쓰는 것이 아니라, 이미 존재하는 iOS 저장소에 하네스를 주입하는 용도로도 사용할 수 있습니다.

에이전트는 이 GitHub 링크만 전달받아도 아래 순서로 하네스를 구성하면 됩니다.

1. 이 저장소의 README를 읽고 설치 규칙을 따른다.
2. 대상 iOS 저장소 루트에 아래 파일과 폴더를 가져온다.
3. 대상 프로젝트에 맞는 `config/project.yaml`을 만든다.
4. `python3 scripts/harness.py init --config config/project.yaml ...` 를 대상 저장소 루트에서 실행한다.
5. 생성된 `Docs/` 와 `.ai-harness/` 를 커밋한다.

대상 iOS 저장소에 포함해야 하는 최소 파일:

```text
scripts/harness.py
templates/
profiles/
config/project.example.yaml
Makefile
```

권장 추가 작업:

- 기존 `.gitignore`가 `.ai-harness/` 를 무시하지 않는지 확인
- 기존 `Docs/` 가 있다면 충돌 여부를 먼저 검토
- 프로젝트 특성에 맞게 프로필과 스킬을 명시적으로 선택

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

아래 프롬프트를 그대로 에이전트에게 주면, 이 GitHub 링크만으로 대상 iOS 저장소에 하네스를 구성하는 시작점으로 사용할 수 있습니다.

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

이 프롬프트의 목적은 "에이전트가 스타터 저장소를 참조해서 현재 앱 저장소 안에 하네스를 설치"하도록 만드는 것입니다. 즉 스타터 저장소를 따로 유지하면서도, 실제 운영은 대상 iOS 프로젝트 저장소 안에서 이루어지게 합니다.

## 라이선스

원하는 라이선스로 교체하세요.
