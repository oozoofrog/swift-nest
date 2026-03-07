import Foundation

enum SwiftNestLanguage: String, CaseIterable, Equatable {
    case en
    case ko

    static var supportedCodesSummary: String {
        allCases.map(\.rawValue).joined(separator: ", ")
    }

    static func normalized(from rawValue: String) -> SwiftNestLanguage? {
        let normalized = rawValue
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "_", with: "-")

        guard !normalized.isEmpty else {
            return nil
        }

        if normalized == "ko" || normalized.hasPrefix("ko-") {
            return .ko
        }
        if normalized == "en" || normalized.hasPrefix("en-") {
            return .en
        }
        return nil
    }
}

struct SwiftNestResolvedInvocation: Equatable {
    let language: SwiftNestLanguage
    let arguments: [String]
}

enum SwiftNestMessageKey: Hashable {
    case errorPrefix
    case wrapperSwiftRequired
    case homebrewBootstrapOnlyLine1
    case homebrewBootstrapOnlyLine2
    case unsupportedLanguageOption
    case unsupportedLanguageEnvironment
    case missingValueForOption
    case couldNotLocateRepositoryRoot
    case couldNotDecodeUTF8Text
    case expectedTopLevelObject
    case unknownProfile
    case noStateFile
    case unknownCommand
    case unexpectedPositionalsInstall
    case installRequiresTarget
    case targetRepositoryMustDiffer
    case previewedManagedFilesInto
    case installedManagedFilesInto
    case changedFiles
    case unchangedFiles
    case nextSteps
    case editProjectConfig
    case unexpectedPositionalsInit
    case initRequiresConfig
    case initializedSwiftNest
    case renderedContext
    case unexpectedPositionalsUpgrade
    case upgradeRequiresProfile
    case configPathNotFound
    case upgradedSwiftNest
    case currentSkills
    case unknownWorkflowSubcommand
    case workflowKindDefault
    case workflowKindOptional
    case workflowStatusEnabled
    case workflowStatusAvailable
    case workflowDescriptionAddFeature
    case workflowDescriptionFixBug
    case workflowDescriptionRefactor
    case workflowDescriptionBuild
    case workflowDescriptionPermissions
    case workflowDescriptionNetworking
    case workflowDescriptionReview
    case workflowPrintRequiresOneName
    case scaffoldedWorkflows
    case unknownWorkflow
    case unknownWorkflowName
    case unknownOption
    case unknownSkillTemplate
    case profilesHeader
    case chooseProfileNumberPrompt
    case profileChoiceOutOfRange
    case availableSkillsHeader
    case selectSkillsPrompt
    case invalidSelection
    case selectionOutOfRange
    case expectedFileButFoundDirectory
    case dryRunCopy
    case dryRunOverwrite
    case refusingOverwriteManagedFiles
    case managedPathMissingFromStarter
    case managedPathEscapedRepositoryRoot
    case warningGitignoreIgnoresAIHarness
    case warningDocsAlreadyExists
    case warningAIHarnessAlreadyExists
    case usageTopLevel
    case usageInstall
    case usageInit
    case usageUpgrade
    case usageWorkflow
    case usageWorkflowList
    case usageWorkflowPrint
    case usageWorkflowScaffold
    case usageRenderContext
    case usageListSkills
    case usageListProfiles
}

enum SwiftNestLocalizer {
    private static let languageLock = NSLock()
    private static nonisolated(unsafe) var activeLanguageStorage: SwiftNestLanguage = .en

    static var activeLanguage: SwiftNestLanguage {
        languageLock.lock()
        defer { languageLock.unlock() }
        return activeLanguageStorage
    }

    static func configure(language: SwiftNestLanguage) {
        languageLock.lock()
        activeLanguageStorage = language
        languageLock.unlock()
    }

    static func text(_ key: SwiftNestMessageKey, _ arguments: CVarArg...) -> String {
        text(key, language: activeLanguage, arguments)
    }

    static func text(_ key: SwiftNestMessageKey, language: SwiftNestLanguage, _ arguments: CVarArg...) -> String {
        text(key, language: language, arguments)
    }

    static func text(_ key: SwiftNestMessageKey, language: SwiftNestLanguage, _ arguments: [CVarArg]) -> String {
        let translations = localizedTemplates[language] ?? localizedTemplates[.en] ?? [:]
        let englishFallback = localizedTemplates[.en] ?? [:]
        let template = translations[key] ?? englishFallback[key] ?? ""
        return String(format: template, locale: Locale(identifier: "en_US_POSIX"), arguments: arguments)
    }

    private static let localizedTemplates: [SwiftNestLanguage: [SwiftNestMessageKey: String]] = [
        .en: [
            .errorPrefix: "error",
            .wrapperSwiftRequired: "swift is required to build the SwiftNest CLI on macOS.",
            .homebrewBootstrapOnlyLine1: "error: the Homebrew-installed swiftnest command only bootstraps repositories.",
            .homebrewBootstrapOnlyLine2: "Run 'swiftnest install --target <path>' first, then use './swiftnest ...' from the target repository.",
            .unsupportedLanguageOption: "Unsupported language value for --lang: %@. Supported values: %@.",
            .unsupportedLanguageEnvironment: "Unsupported language value for SWIFTNEST_LANG: %@. Supported values: %@.",
            .missingValueForOption: "Missing value for %@.",
            .couldNotLocateRepositoryRoot: "Could not locate the SwiftNest repository root.",
            .couldNotDecodeUTF8Text: "Could not decode UTF-8 text from %@.",
            .expectedTopLevelObject: "Expected a top-level object in %@.",
            .unknownProfile: "Unknown profile: %@",
            .noStateFile: "No .ai-harness/state.json found. Run init first.",
            .unknownCommand: "Unknown command: %@",
            .unexpectedPositionalsInstall: "Unexpected positional arguments for install: %@",
            .installRequiresTarget: "install requires --target <path>.",
            .targetRepositoryMustDiffer: "Target repository must be different from the starter repository root.",
            .previewedManagedFilesInto: "Previewed SwiftNest-managed files into %@",
            .installedManagedFilesInto: "Installed SwiftNest-managed files into %@",
            .changedFiles: "Changed files: %d",
            .unchangedFiles: "Unchanged files: %d",
            .nextSteps: "Next steps:",
            .editProjectConfig: "  edit config/project.yaml",
            .unexpectedPositionalsInit: "Unexpected positional arguments for init: %@",
            .initRequiresConfig: "init requires --config <path>.",
            .initializedSwiftNest: "Initialized SwiftNest with profile '%@' and skills: %@",
            .renderedContext: "Rendered context: %@",
            .unexpectedPositionalsUpgrade: "Unexpected positional arguments for upgrade: %@",
            .upgradeRequiresProfile: "upgrade requires --to <profile>.",
            .configPathNotFound: "Config path not found: %@",
            .upgradedSwiftNest: "Upgraded SwiftNest to '%@'.",
            .currentSkills: "Current skills: %@",
            .unknownWorkflowSubcommand: "Unknown workflow subcommand: %@",
            .workflowKindDefault: "default",
            .workflowKindOptional: "optional",
            .workflowStatusEnabled: "enabled",
            .workflowStatusAvailable: "available",
            .workflowDescriptionAddFeature: "Use for new features or visible behavior additions.",
            .workflowDescriptionFixBug: "Use for bug fixes and regression repairs.",
            .workflowDescriptionRefactor: "Use for structure-only changes that preserve behavior.",
            .workflowDescriptionBuild: "Use for build or test verification work.",
            .workflowDescriptionPermissions: "Use when device authorization states are part of the task.",
            .workflowDescriptionNetworking: "Use for request/response and remote repository changes.",
            .workflowDescriptionReview: "Use for findings-first code review tasks.",
            .workflowPrintRequiresOneName: "workflow print requires exactly one workflow name.",
            .scaffoldedWorkflows: "Scaffolded workflows: %@",
            .unknownWorkflow: "Unknown workflow: %@",
            .unknownWorkflowName: "Unknown workflow: %@",
            .unknownOption: "Unknown option: %@",
            .unknownSkillTemplate: "Unknown skill template: %@",
            .profilesHeader: "Profiles:",
            .chooseProfileNumberPrompt: "Choose profile number (default 1): ",
            .profileChoiceOutOfRange: "Profile choice out of range",
            .availableSkillsHeader: "Available skills:",
            .selectSkillsPrompt: "Select skills by comma-separated numbers (Enter for defaults): ",
            .invalidSelection: "Invalid selection: %@",
            .selectionOutOfRange: "Selection out of range: %@",
            .expectedFileButFoundDirectory: "Expected file but found directory at target path: %@",
            .dryRunCopy: "copy: %@",
            .dryRunOverwrite: "overwrite: %@",
            .refusingOverwriteManagedFiles: "Refusing to overwrite managed files in the target repository.\nRe-run with --force if these files should be replaced:\n%@",
            .managedPathMissingFromStarter: "Managed path is missing from starter: %@",
            .managedPathEscapedRepositoryRoot: "Managed path escaped repository root: %@",
            .warningGitignoreIgnoresAIHarness: "warning: .gitignore ignores .ai-harness/. Remove that rule before committing generated state.",
            .warningDocsAlreadyExists: "warning: Docs/ already exists. Review generated files after init before committing.",
            .warningAIHarnessAlreadyExists: "warning: .ai-harness/ already exists. Review current state before rerendering or upgrading.",
            .usageTopLevel: """
            usage: swiftnest [--lang <en|ko>] <command> [options]

            Commands:
              install        Install SwiftNest-managed files into a target repository
              init           Initialize docs from config, profile, and skills
              upgrade        Upgrade to a stricter profile
              workflow       Manage workflow scaffolds
              render-context Render the combined context bundle
              list-skills    List available skills
              list-profiles  List available profiles
            """,
            .usageInstall: "usage: swiftnest [--lang <en|ko>] install --target <path> [--force] [--dry-run]",
            .usageInit: "usage: swiftnest [--lang <en|ko>] init --config <path> [--profile <name>] [--skills <csv>] [--non-interactive]",
            .usageUpgrade: "usage: swiftnest [--lang <en|ko>] upgrade --to <profile>",
            .usageWorkflow: """
            usage: swiftnest [--lang <en|ko>] workflow <subcommand> [options]

            Subcommands:
              list                 List supported workflows and current status
              print <name>         Print one rendered workflow to stdout
              scaffold [name ...]  Regenerate current workflows or add optional workflows
            """,
            .usageWorkflowList: "usage: swiftnest [--lang <en|ko>] workflow list",
            .usageWorkflowPrint: "usage: swiftnest [--lang <en|ko>] workflow print <name>",
            .usageWorkflowScaffold: "usage: swiftnest [--lang <en|ko>] workflow scaffold [name ...]",
            .usageRenderContext: "usage: swiftnest [--lang <en|ko>] render-context",
            .usageListSkills: "usage: swiftnest [--lang <en|ko>] list-skills",
            .usageListProfiles: "usage: swiftnest [--lang <en|ko>] list-profiles",
        ],
        .ko: [
            .errorPrefix: "오류",
            .wrapperSwiftRequired: "macOS에서 SwiftNest CLI를 빌드하려면 swift가 필요합니다.",
            .homebrewBootstrapOnlyLine1: "오류: Homebrew로 설치한 swiftnest 명령은 저장소 부트스트랩 용도로만 사용할 수 있습니다.",
            .homebrewBootstrapOnlyLine2: "먼저 'swiftnest install --target <path>'를 실행한 뒤, 대상 저장소에서 './swiftnest ...'를 사용하세요.",
            .unsupportedLanguageOption: "--lang에 지원하지 않는 언어 값이 지정되었습니다: %@. 지원 값: %@.",
            .unsupportedLanguageEnvironment: "SWIFTNEST_LANG에 지원하지 않는 언어 값이 지정되었습니다: %@. 지원 값: %@.",
            .missingValueForOption: "%@ 옵션에 필요한 값이 없습니다.",
            .couldNotLocateRepositoryRoot: "SwiftNest 저장소 루트를 찾을 수 없습니다.",
            .couldNotDecodeUTF8Text: "%@에서 UTF-8 텍스트를 디코드할 수 없습니다.",
            .expectedTopLevelObject: "%@에서 최상위 객체를 기대했습니다.",
            .unknownProfile: "알 수 없는 프로필입니다: %@",
            .noStateFile: ".ai-harness/state.json을 찾을 수 없습니다. 먼저 init을 실행하세요.",
            .unknownCommand: "알 수 없는 명령입니다: %@",
            .unexpectedPositionalsInstall: "install 명령에 예상하지 못한 위치 인자가 있습니다: %@",
            .installRequiresTarget: "install 명령에는 --target <path>가 필요합니다.",
            .targetRepositoryMustDiffer: "대상 저장소는 스타터 저장소 루트와 달라야 합니다.",
            .previewedManagedFilesInto: "%@에 SwiftNest 관리 파일을 설치하는 미리보기를 실행했습니다",
            .installedManagedFilesInto: "%@에 SwiftNest 관리 파일을 설치했습니다",
            .changedFiles: "변경된 파일: %d",
            .unchangedFiles: "변경되지 않은 파일: %d",
            .nextSteps: "다음 단계:",
            .editProjectConfig: "  config/project.yaml을 편집하세요",
            .unexpectedPositionalsInit: "init 명령에 예상하지 못한 위치 인자가 있습니다: %@",
            .initRequiresConfig: "init 명령에는 --config <path>가 필요합니다.",
            .initializedSwiftNest: "프로필 '%@' 및 스킬 %@로 SwiftNest를 초기화했습니다",
            .renderedContext: "렌더링된 컨텍스트: %@",
            .unexpectedPositionalsUpgrade: "upgrade 명령에 예상하지 못한 위치 인자가 있습니다: %@",
            .upgradeRequiresProfile: "upgrade 명령에는 --to <profile>이 필요합니다.",
            .configPathNotFound: "설정 경로를 찾을 수 없습니다: %@",
            .upgradedSwiftNest: "SwiftNest를 '%@' 프로필로 업그레이드했습니다.",
            .currentSkills: "현재 스킬: %@",
            .unknownWorkflowSubcommand: "알 수 없는 workflow 하위 명령입니다: %@",
            .workflowKindDefault: "기본",
            .workflowKindOptional: "선택",
            .workflowStatusEnabled: "활성",
            .workflowStatusAvailable: "사용 가능",
            .workflowDescriptionAddFeature: "새 기능 또는 사용자에게 보이는 동작 추가에 사용합니다.",
            .workflowDescriptionFixBug: "버그 수정 및 회귀 복구에 사용합니다.",
            .workflowDescriptionRefactor: "동작 변경 없이 구조만 정리하는 작업에 사용합니다.",
            .workflowDescriptionBuild: "빌드 또는 테스트 검증 작업에 사용합니다.",
            .workflowDescriptionPermissions: "기기 권한 상태가 작업의 일부일 때 사용합니다.",
            .workflowDescriptionNetworking: "요청/응답 및 원격 저장소 변경에 사용합니다.",
            .workflowDescriptionReview: "리뷰 결과를 먼저 제시하는 코드 리뷰 작업에 사용합니다.",
            .workflowPrintRequiresOneName: "workflow print에는 정확히 하나의 workflow 이름이 필요합니다.",
            .scaffoldedWorkflows: "생성된 workflow: %@",
            .unknownWorkflow: "알 수 없는 workflow입니다: %@",
            .unknownWorkflowName: "알 수 없는 workflow입니다: %@",
            .unknownOption: "알 수 없는 옵션입니다: %@",
            .unknownSkillTemplate: "알 수 없는 스킬 템플릿입니다: %@",
            .profilesHeader: "프로필:",
            .chooseProfileNumberPrompt: "프로필 번호를 선택하세요 (기본값 1): ",
            .profileChoiceOutOfRange: "프로필 선택이 범위를 벗어났습니다",
            .availableSkillsHeader: "사용 가능한 스킬:",
            .selectSkillsPrompt: "쉼표로 구분된 번호로 스킬을 선택하세요 (Enter 입력 시 기본값 사용): ",
            .invalidSelection: "잘못된 선택입니다: %@",
            .selectionOutOfRange: "선택이 범위를 벗어났습니다: %@",
            .expectedFileButFoundDirectory: "대상 경로에서 파일이 와야 할 자리에 디렉터리가 있습니다: %@",
            .dryRunCopy: "복사 예정: %@",
            .dryRunOverwrite: "덮어쓰기 예정: %@",
            .refusingOverwriteManagedFiles: "대상 저장소의 관리 파일 덮어쓰기를 거부했습니다.\n다음 파일을 바꾸려면 --force와 함께 다시 실행하세요:\n%@",
            .managedPathMissingFromStarter: "스타터 저장소에 관리 대상 경로가 없습니다: %@",
            .managedPathEscapedRepositoryRoot: "관리 대상 경로가 저장소 루트를 벗어났습니다: %@",
            .warningGitignoreIgnoresAIHarness: "경고: .gitignore가 .ai-harness/를 무시하고 있습니다. 생성된 상태를 커밋하기 전에 해당 규칙을 제거하세요.",
            .warningDocsAlreadyExists: "경고: Docs/가 이미 존재합니다. 커밋 전에 init으로 생성된 파일을 검토하세요.",
            .warningAIHarnessAlreadyExists: "경고: .ai-harness/가 이미 존재합니다. 다시 렌더링하거나 업그레이드하기 전에 현재 상태를 검토하세요.",
            .usageTopLevel: """
            사용법: swiftnest [--lang <en|ko>] <command> [options]

            명령:
              install        대상 저장소에 SwiftNest 관리 파일 설치
              init           설정, 프로필, 스킬로 문서 초기화
              upgrade        더 엄격한 프로필로 업그레이드
              workflow       workflow 스캐폴드 관리
              render-context 통합 컨텍스트 번들 렌더링
              list-skills    사용 가능한 스킬 나열
              list-profiles  사용 가능한 프로필 나열
            """,
            .usageInstall: "사용법: swiftnest [--lang <en|ko>] install --target <path> [--force] [--dry-run]",
            .usageInit: "사용법: swiftnest [--lang <en|ko>] init --config <path> [--profile <name>] [--skills <csv>] [--non-interactive]",
            .usageUpgrade: "사용법: swiftnest [--lang <en|ko>] upgrade --to <profile>",
            .usageWorkflow: """
            사용법: swiftnest [--lang <en|ko>] workflow <subcommand> [options]

            하위 명령:
              list                 지원되는 workflow와 현재 상태 나열
              print <name>         렌더링된 workflow 하나를 stdout으로 출력
              scaffold [name ...]  현재 workflow를 다시 생성하거나 선택 workflow를 추가
            """,
            .usageWorkflowList: "사용법: swiftnest [--lang <en|ko>] workflow list",
            .usageWorkflowPrint: "사용법: swiftnest [--lang <en|ko>] workflow print <name>",
            .usageWorkflowScaffold: "사용법: swiftnest [--lang <en|ko>] workflow scaffold [name ...]",
            .usageRenderContext: "사용법: swiftnest [--lang <en|ko>] render-context",
            .usageListSkills: "사용법: swiftnest [--lang <en|ko>] list-skills",
            .usageListProfiles: "사용법: swiftnest [--lang <en|ko>] list-profiles",
        ],
    ]
}

enum SwiftNestLanguageResolver {
    static func defaultLanguage(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        preferredLanguages: [String] = Locale.preferredLanguages
    ) -> SwiftNestLanguage {
        systemLanguage(environment: environment, preferredLanguages: preferredLanguages) ?? .en
    }

    static func resolve(
        arguments: [String],
        environment: [String: String] = ProcessInfo.processInfo.environment,
        preferredLanguages: [String] = Locale.preferredLanguages
    ) throws -> SwiftNestResolvedInvocation {
        let fallbackLanguage = defaultLanguage(environment: environment, preferredLanguages: preferredLanguages)
        let (explicitLanguageValue, strippedArguments) = try extractLanguageArgument(arguments, fallbackLanguage: fallbackLanguage)

        if let explicitLanguageValue {
            guard let language = SwiftNestLanguage.normalized(from: explicitLanguageValue) else {
                throw SwiftNestError(
                    SwiftNestLocalizer.text(
                        .unsupportedLanguageOption,
                        language: fallbackLanguage,
                        explicitLanguageValue,
                        SwiftNestLanguage.supportedCodesSummary
                    )
                )
            }
            return SwiftNestResolvedInvocation(language: language, arguments: strippedArguments)
        }

        if let environmentLanguage = environment["SWIFTNEST_LANG"]?.trimmingCharacters(in: .whitespacesAndNewlines),
           !environmentLanguage.isEmpty
        {
            guard let language = SwiftNestLanguage.normalized(from: environmentLanguage) else {
                throw SwiftNestError(
                    SwiftNestLocalizer.text(
                        .unsupportedLanguageEnvironment,
                        language: fallbackLanguage,
                        environmentLanguage,
                        SwiftNestLanguage.supportedCodesSummary
                    )
                )
            }
            return SwiftNestResolvedInvocation(language: language, arguments: strippedArguments)
        }

        return SwiftNestResolvedInvocation(language: fallbackLanguage, arguments: strippedArguments)
    }

    private static func extractLanguageArgument(
        _ arguments: [String],
        fallbackLanguage: SwiftNestLanguage
    ) throws -> (String?, [String]) {
        var strippedArguments: [String] = []
        var pendingValue = false
        var explicitLanguageValue: String?

        for argument in arguments {
            if pendingValue {
                let trimmedValue = argument.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmedValue.isEmpty else {
                    throw SwiftNestError(
                        SwiftNestLocalizer.text(.missingValueForOption, language: fallbackLanguage, "--lang")
                    )
                }
                explicitLanguageValue = trimmedValue
                pendingValue = false
                continue
            }

            if argument == "--lang" {
                pendingValue = true
                continue
            }

            if argument.hasPrefix("--lang=") {
                let value = String(argument.dropFirst("--lang=".count))
                let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmedValue.isEmpty else {
                    throw SwiftNestError(
                        SwiftNestLocalizer.text(.missingValueForOption, language: fallbackLanguage, "--lang")
                    )
                }
                explicitLanguageValue = trimmedValue
                continue
            }

            strippedArguments.append(argument)
        }

        if pendingValue {
            throw SwiftNestError(
                SwiftNestLocalizer.text(.missingValueForOption, language: fallbackLanguage, "--lang")
            )
        }

        return (explicitLanguageValue, strippedArguments)
    }

    private static func systemLanguage(
        environment: [String: String],
        preferredLanguages: [String]
    ) -> SwiftNestLanguage? {
        for key in ["LC_ALL", "LC_MESSAGES", "LANG"] {
            if let rawValue = environment[key], let language = SwiftNestLanguage.normalized(from: rawValue) {
                return language
            }
        }

        for preferredLanguage in preferredLanguages {
            if let language = SwiftNestLanguage.normalized(from: preferredLanguage) {
                return language
            }
        }

        return nil
    }
}
