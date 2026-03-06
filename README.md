# iOS AI Harness Starter

iOS/SwiftUI 프로젝트에서 AI 에이전트가 항상 같은 규칙을 읽고, 선택한 스킬만 적용하며, 프로젝트 성숙도에 따라 단계적으로 복잡도를 올릴 수 있게 해주는 템플릿 리포입니다.

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
```

## 생성 상태 파일

`.ai-harness/state.json` 에 현재 선택 상태가 저장됩니다.
이 파일을 기준으로 이후 업그레이드/재렌더링이 수행됩니다.
저장소 안의 경로를 가리킬 때는 상대 경로로 저장되어, 다른 머신으로 옮겨도 상태 파일이 깨지지 않게 유지됩니다.

## 라이선스

원하는 라이선스로 교체하세요.
