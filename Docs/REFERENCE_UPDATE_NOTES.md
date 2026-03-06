# Reference Update Notes

이 문서는 Xcode 26.3에 포함된 Apple 문서를 검토한 뒤, 현재 하네스에 반영한 포인트를 정리합니다.

## 이번에 반영한 변경

- `templates/Docs/AI_SKILLS/concurrency-rules.md`
  - `Sendable` 경계 검토 추가
  - synchronous nonisolated context 에서 actor-isolated API 호출 금지 명시
  - `nonisolated` async 의미를 명시적으로 검토하도록 추가
  - `preconcurrency` import 와 legacy API 억제 사용 전 점검 추가

- `templates/Docs/AI_WORKFLOWS.md`
  - Add Feature review 단계에 actor isolation / `Sendable` / legacy import 리스크 검토 추가
  - Fix Bug review 단계에 cross-actor access / non-`Sendable` value movement 검토 추가
  - Final Self-Review Checklist 에 동시성 진단 관점 항목 추가

## 주요 참고 문서

- `IDEIntelligenceChat.framework/Resources/AdditionalDocumentation/Swift-Concurrency-Updates.md`
- `usr/share/doc/swift/diagnostics/actor-isolated-call.md`
- `usr/share/doc/swift/diagnostics/sending-risks-data-race.md`
- `usr/share/doc/swift/diagnostics/sending-closure-risks-data-race.md`
- `usr/share/doc/swift/diagnostics/nonisolated-nonsending-by-default.md`
- `usr/share/doc/swift/diagnostics/preconcurrency-import.md`

## 다음 후보

- `foundation-models-rules`
  - `FoundationModels-Using-on-device-LLM-in-your-app.md` 기반
- `app-intents-rules`
  - `AppIntents-Updates.md` 기반
- `storekit-rules`
  - `StoreKit-Updates.md` 기반
- `accessibility-rules`
  - `Implementing-Assistive-Access-in-iOS.md` 기반

## 의도

이 문서의 목적은 Xcode 내부 리소스를 그대로 복제하는 것이 아니라, 하네스 규칙을 Apple의 최신 문서와 충돌하지 않게 유지하는 데 있습니다.
