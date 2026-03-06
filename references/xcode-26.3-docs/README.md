# Xcode 26.3 Reference Docs

이 폴더는 Xcode.app 안의 Apple 문서 중, 현재 하네스 설계에 직접 도움이 되는 자료만 골라 정리한 레퍼런스입니다.

에이전트 프롬프트, 모델 메타데이터, 내부 실행 리소스는 의도적으로 제외했습니다.

## 포함한 소스

- `/Volumes/eyedisk/Applications/Xcode.app/Contents/PlugIns/IDEIntelligenceChat.framework/Versions/A/Resources/AdditionalDocumentation`
- `/Volumes/eyedisk/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/share/doc/swift/diagnostics`

## 왜 유용한가

- `concurrency-rules`를 Swift 6.2 진단 관점으로 더 구체화할 수 있습니다.
- 새 스킬 후보를 평가할 때 Apple이 실제로 강조하는 API/패턴을 참고할 수 있습니다.
- 하네스의 self-review 체크리스트를 Apple의 최신 경고/진단 언어와 맞출 수 있습니다.

## 먼저 읽을 파일

- `apple-guides/app-capabilities/FoundationModels-Using-on-device-LLM-in-your-app.md`
- `apple-guides/app-capabilities/AppIntents-Updates.md`
- `apple-guides/accessibility-and-language/Swift-Concurrency-Updates.md`
- `swift-diagnostics/actor-isolation/actor-isolated-call.md`
- `swift-diagnostics/sendable-and-safety/sending-risks-data-race.md`

## 구조

- `apple-guides/`: 기능/프레임워크 가이드
- `swift-diagnostics/`: 동시성, 격리, Sendable, 안전성 관련 진단 문서
- `SUMMARY.md`: 카테고리별 개요
- `MANIFEST.json`: 파일 인덱스
