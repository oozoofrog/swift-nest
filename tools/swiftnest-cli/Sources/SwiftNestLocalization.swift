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
    case couldNotLocateAssetRoot
    case couldNotLocateRepositoryRoot
    case couldNotDecodeUTF8Text
    case expectedTopLevelObject
    case unknownProfile
    case noProfilesAvailable
    case noStateFile
    case unknownCommand
    case unexpectedPositionalsOnboard
    case onboardingRequiresTargetOutsideRepository
    case onboardingStarterCheckoutRequiresTarget
    case onboardingStarted
    case onboardingStarterPath
    case onboardingTargetPath
    case onboardingManagedFilesReady
    case onboardingCreatedConfig
    case onboardingUsingExistingConfig
    case onboardingAlreadyCompleted
    case onboardingCurrentProfile
    case onboardingCurrentSkills
    case onboardingCurrentWorkflows
    case onboardingUseForceToRerun
    case onboardingCompleted
    case onboardingConfigReady
    case onboardingGeneratedFilesHeader
    case onboardingHowAgentsUseThisHeader
    case onboardingHowAgentsUseThisLine1
    case onboardingHowAgentsUseThisLine2
    case onboardingNextStepsHeader
    case onboardingNextStepReviewConfig
    case onboardingNextStepReviewAgents
    case onboardingNextStepReviewWorkflow
    case onboardingNextStepReviewGoals
    case onboardingNextStepAgentRoot
    case onboardingConfigPromptHeader
    case onboardingPromptProjectName
    case onboardingPromptWatchCompanion
    case onboardingPromptUIFramework
    case onboardingPromptArchitectureStyle
    case onboardingPromptNetworkLayerName
    case onboardingPromptPersistenceLayerName
    case onboardingPromptLoggingSystem
    case onboardingPromptBuildCommand
    case onboardingPromptTestCommand
    case onboardingPromptBooleanRetry
    case onboardingSkillSummaryFallback
    case unexpectedPositionalsInstall
    case installStarterCheckoutRequiresTarget
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
    case stateDataVersionTooNew
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
    case workflowDescriptionOnboardingReview
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
    case availableWorkflowsHeader
    case selectSkillsPrompt
    case selectWorkflowsPrompt
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
    case usageOnboard
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
            .homebrewBootstrapOnlyLine2: "Run 'swiftnest onboard --target <path>' or 'swiftnest install --target <path>' first, then use './swiftnest ...' from the target repository.",
            .unsupportedLanguageOption: "Unsupported language value for --lang: %@. Supported values: %@.",
            .unsupportedLanguageEnvironment: "Unsupported language value for SWIFTNEST_LANG: %@. Supported values: %@.",
            .missingValueForOption: "Missing value for %@.",
            .couldNotLocateAssetRoot: "Could not locate the SwiftNest asset root.",
            .couldNotLocateRepositoryRoot: "Could not locate a SwiftNest-managed repository root from the current directory.",
            .couldNotDecodeUTF8Text: "Could not decode UTF-8 text from %@.",
            .expectedTopLevelObject: "Expected a top-level object in %@.",
            .unknownProfile: "Unknown profile: %@",
            .noProfilesAvailable: "No onboarding profiles are available in this SwiftNest installation.",
            .noStateFile: "No .swiftnest/state.json found. Run init first.",
            .unknownCommand: "Unknown command: %@",
            .unexpectedPositionalsOnboard: "Unexpected positional arguments for onboard: %@",
            .onboardingRequiresTargetOutsideRepository: "onboard requires --target <path> when you are not already inside a SwiftNest-managed repository.",
            .onboardingStarterCheckoutRequiresTarget: "Running onboard from the SwiftNest starter checkout requires --target <path> so the target app repository is updated instead of the starter itself.",
            .onboardingStarted: "Starting SwiftNest onboarding for %@",
            .onboardingStarterPath: "SwiftNest assets: %@",
            .onboardingTargetPath: "Target repository: %@",
            .onboardingManagedFilesReady: "SwiftNest-managed files are already present in %@",
            .onboardingCreatedConfig: "Created onboarding config: %@",
            .onboardingUsingExistingConfig: "Using existing onboarding config: %@",
            .onboardingAlreadyCompleted: "SwiftNest is already onboarded in %@.",
            .onboardingCurrentProfile: "Profile: %@",
            .onboardingCurrentSkills: "Skills: %@",
            .onboardingCurrentWorkflows: "Workflows: %@",
            .onboardingUseForceToRerun: "Re-run with --force to regenerate docs and state.",
            .onboardingCompleted: "SwiftNest onboarding completed for %@.",
            .onboardingConfigReady: "Config file: %@",
            .onboardingGeneratedFilesHeader: "Generated files:",
            .onboardingHowAgentsUseThisHeader: "How agents use this setup:",
            .onboardingHowAgentsUseThisLine1: "- Agents should read AGENTS.md first, then follow Docs/AI_RULES.md, Docs/AI_WORKFLOWS.md, and Docs/AI_SKILLS/*.",
            .onboardingHowAgentsUseThisLine2: "- The rendered context and workflow files under .swiftnest/ keep later agent runs aligned with the selected profile and workflows.",
            .onboardingNextStepsHeader: "Recommended next steps:",
            .onboardingNextStepReviewConfig: "- Review %@ and adjust project-specific values if needed.",
            .onboardingNextStepReviewAgents: "- Review AGENTS.md to confirm the generated operating instructions.",
            .onboardingNextStepReviewWorkflow: "- Ask your AI agent to start with .swiftnest/workflows/onboarding-review.md.",
            .onboardingNextStepReviewGoals: "- That review should verify config/project.yaml, selected skills, and workflows against the real repository.",
            .onboardingNextStepAgentRoot: "- Start your AI task from %@ so the global swiftnest command and generated docs are available.",
            .onboardingConfigPromptHeader: "Create config/project.yaml for this repository. Press Enter to accept inferred defaults.",
            .onboardingPromptProjectName: "Project name",
            .onboardingPromptWatchCompanion: "Include a watchOS companion line",
            .onboardingPromptUIFramework: "UI framework",
            .onboardingPromptArchitectureStyle: "Architecture style",
            .onboardingPromptNetworkLayerName: "Networking boundary",
            .onboardingPromptPersistenceLayerName: "Persistence boundary",
            .onboardingPromptLoggingSystem: "Logging system",
            .onboardingPromptBuildCommand: "Build command",
            .onboardingPromptTestCommand: "Test command",
            .onboardingPromptBooleanRetry: "Please answer with yes or no.",
            .onboardingSkillSummaryFallback: "Review the generated skill file for details.",
            .unexpectedPositionalsInstall: "Unexpected positional arguments for install: %@",
            .installStarterCheckoutRequiresTarget: "Running install from the SwiftNest starter checkout requires --target <path> so the target app repository is updated instead of the starter itself.",
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
            .stateDataVersionTooNew: "Repository data version %d is newer than this SwiftNest CLI supports (%d). Upgrade your global swiftnest installation.",
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
            .workflowDescriptionOnboardingReview: "Use after onboarding to verify config, selected skills, and workflows against the real repository.",
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
            .chooseProfileNumberPrompt: "Choose profile number (default %@): ",
            .profileChoiceOutOfRange: "Profile choice out of range",
            .availableSkillsHeader: "Available skills:",
            .availableWorkflowsHeader: "Available workflows:",
            .selectSkillsPrompt: "Select skills by comma-separated numbers (Enter for defaults): ",
            .selectWorkflowsPrompt: "Select optional workflows by comma-separated numbers (Enter for defaults): ",
            .invalidSelection: "Invalid selection: %@",
            .selectionOutOfRange: "Selection out of range: %@",
            .expectedFileButFoundDirectory: "Expected file but found directory at target path: %@",
            .dryRunCopy: "copy: %@",
            .dryRunOverwrite: "overwrite: %@",
            .refusingOverwriteManagedFiles: "Refusing to overwrite managed files in the target repository.\nRe-run with --force if these files should be replaced:\n%@",
            .managedPathMissingFromStarter: "Managed path is missing from starter: %@",
            .managedPathEscapedRepositoryRoot: "Managed path escaped repository root: %@",
            .warningGitignoreIgnoresAIHarness: "warning: .gitignore ignores .swiftnest/. Remove that rule before committing generated state.",
            .warningDocsAlreadyExists: "warning: Docs/ already exists. Review generated files after init before committing.",
            .warningAIHarnessAlreadyExists: "warning: .swiftnest/ already exists. Review current state before rerendering or upgrading.",
            .usageTopLevel: """
            usage: swiftnest [--lang <en|ko>] <command> [options]

            Commands:
              onboard        Install, configure, and initialize SwiftNest for a repository
              install        Install SwiftNest-managed files into a target repository
              init           Initialize docs from config, profile, and skills
              upgrade        Upgrade to a stricter profile
              workflow       Manage workflow scaffolds
              render-context Render the combined context bundle
              list-skills    List available skills
              list-profiles  List available profiles
            """,
            .usageOnboard: "usage: swiftnest [--lang <en|ko>] onboard [--target <path>] [--config <path>] [--profile <name>] [--skills <csv>] [--workflows <csv>] [--non-interactive] [--force]",
            .usageInstall: "usage: swiftnest [--lang <en|ko>] install [--target <path>] [--force] [--dry-run]",
            .usageInit: "usage: swiftnest [--lang <en|ko>] init --config <path> [--profile <name>] [--skills <csv>] [--workflows <csv>] [--non-interactive]",
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
            .homebrewBootstrapOnlyLine2: "먼저 'swiftnest onboard --target <path>' 또는 'swiftnest install --target <path>'를 실행한 뒤, 대상 저장소에서 './swiftnest ...'를 사용하세요.",
            .unsupportedLanguageOption: "--lang에 지원하지 않는 언어 값이 지정되었습니다: %@. 지원 값: %@.",
            .unsupportedLanguageEnvironment: "SWIFTNEST_LANG에 지원하지 않는 언어 값이 지정되었습니다: %@. 지원 값: %@.",
            .missingValueForOption: "%@ 옵션에 필요한 값이 없습니다.",
            .couldNotLocateAssetRoot: "SwiftNest 자산 루트를 찾을 수 없습니다.",
            .couldNotLocateRepositoryRoot: "현재 디렉터리에서 SwiftNest 관리 저장소 루트를 찾을 수 없습니다.",
            .couldNotDecodeUTF8Text: "%@에서 UTF-8 텍스트를 디코드할 수 없습니다.",
            .expectedTopLevelObject: "%@에서 최상위 객체를 기대했습니다.",
            .unknownProfile: "알 수 없는 프로필입니다: %@",
            .noProfilesAvailable: "현재 SwiftNest 설치에서 사용할 수 있는 온보딩 프로필이 없습니다.",
            .noStateFile: ".swiftnest/state.json을 찾을 수 없습니다. 먼저 init을 실행하세요.",
            .unknownCommand: "알 수 없는 명령입니다: %@",
            .unexpectedPositionalsOnboard: "onboard 명령에 예상하지 못한 위치 인자가 있습니다: %@",
            .onboardingRequiresTargetOutsideRepository: "아직 SwiftNest가 설치되지 않은 위치에서 onboard를 실행하려면 --target <path>가 필요합니다.",
            .onboardingStarterCheckoutRequiresTarget: "SwiftNest 스타터 체크아웃에서 onboard를 실행할 때는 스타터 자체가 아니라 대상 앱 저장소를 갱신하도록 --target <path>가 필요합니다.",
            .onboardingStarted: "%@에 대한 SwiftNest 온보딩을 시작합니다",
            .onboardingStarterPath: "SwiftNest 자산 경로: %@",
            .onboardingTargetPath: "대상 저장소: %@",
            .onboardingManagedFilesReady: "%@에는 이미 SwiftNest 관리 파일이 있습니다",
            .onboardingCreatedConfig: "온보딩 설정 파일을 만들었습니다: %@",
            .onboardingUsingExistingConfig: "기존 온보딩 설정 파일을 사용합니다: %@",
            .onboardingAlreadyCompleted: "%@에는 이미 SwiftNest 온보딩이 완료되어 있습니다.",
            .onboardingCurrentProfile: "프로필: %@",
            .onboardingCurrentSkills: "스킬: %@",
            .onboardingCurrentWorkflows: "워크플로: %@",
            .onboardingUseForceToRerun: "--force와 함께 다시 실행하면 문서와 상태를 다시 생성합니다.",
            .onboardingCompleted: "%@에 대한 SwiftNest 온보딩을 완료했습니다.",
            .onboardingConfigReady: "설정 파일: %@",
            .onboardingGeneratedFilesHeader: "생성된 파일:",
            .onboardingHowAgentsUseThisHeader: "에이전트는 이 구성을 이렇게 사용합니다:",
            .onboardingHowAgentsUseThisLine1: "- 에이전트는 먼저 AGENTS.md를 읽고, 이어서 Docs/AI_RULES.md, Docs/AI_WORKFLOWS.md, Docs/AI_SKILLS/*를 따릅니다.",
            .onboardingHowAgentsUseThisLine2: "- .swiftnest/ 아래의 rendered context와 workflow 파일이 이후 작업을 선택한 프로필과 워크플로에 맞춰 정렬합니다.",
            .onboardingNextStepsHeader: "권장 다음 단계:",
            .onboardingNextStepReviewConfig: "- %@를 열어 프로젝트별 값을 검토하거나 수정하세요.",
            .onboardingNextStepReviewAgents: "- 생성된 운영 지침이 맞는지 AGENTS.md를 검토하세요.",
            .onboardingNextStepReviewWorkflow: "- AI 에이전트에게 .swiftnest/workflows/onboarding-review.md부터 시작하라고 요청하세요.",
            .onboardingNextStepReviewGoals: "- 그 검토에서는 config/project.yaml, 선택한 스킬, 워크플로가 실제 저장소와 맞는지 확인해야 합니다.",
            .onboardingNextStepAgentRoot: "- %@ 루트에서 AI 작업을 시작하면 전역 swiftnest 명령과 생성된 문서를 바로 사용할 수 있습니다.",
            .onboardingConfigPromptHeader: "이 저장소용 config/project.yaml을 만듭니다. Enter를 누르면 추론한 기본값을 사용합니다.",
            .onboardingPromptProjectName: "프로젝트 이름",
            .onboardingPromptWatchCompanion: "watchOS companion 라인 포함",
            .onboardingPromptUIFramework: "UI 프레임워크",
            .onboardingPromptArchitectureStyle: "아키텍처 스타일",
            .onboardingPromptNetworkLayerName: "네트워크 경계",
            .onboardingPromptPersistenceLayerName: "영속성 경계",
            .onboardingPromptLoggingSystem: "로깅 시스템",
            .onboardingPromptBuildCommand: "빌드 명령",
            .onboardingPromptTestCommand: "테스트 명령",
            .onboardingPromptBooleanRetry: "예 또는 아니오로 답해주세요.",
            .onboardingSkillSummaryFallback: "자세한 내용은 생성된 스킬 문서를 확인하세요.",
            .unexpectedPositionalsInstall: "install 명령에 예상하지 못한 위치 인자가 있습니다: %@",
            .installStarterCheckoutRequiresTarget: "SwiftNest 스타터 체크아웃에서 install을 실행할 때는 스타터 자체가 아니라 대상 앱 저장소를 갱신하도록 --target <path>가 필요합니다.",
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
            .stateDataVersionTooNew: "저장소 데이터 버전 %d가 현재 SwiftNest CLI가 지원하는 버전(%d)보다 높습니다. 전역 swiftnest 설치를 업그레이드하세요.",
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
            .workflowDescriptionOnboardingReview: "온보딩 후 실제 저장소를 기준으로 config, 선택한 스킬, 워크플로를 검토할 때 사용합니다.",
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
            .chooseProfileNumberPrompt: "프로필 번호를 선택하세요 (기본값 %@): ",
            .profileChoiceOutOfRange: "프로필 선택이 범위를 벗어났습니다",
            .availableSkillsHeader: "사용 가능한 스킬:",
            .availableWorkflowsHeader: "사용 가능한 워크플로:",
            .selectSkillsPrompt: "쉼표로 구분된 번호로 스킬을 선택하세요 (Enter 입력 시 기본값 사용): ",
            .selectWorkflowsPrompt: "쉼표로 구분된 번호로 워크플로를 선택하세요 (Enter 입력 시 기본값 사용): ",
            .invalidSelection: "잘못된 선택입니다: %@",
            .selectionOutOfRange: "선택이 범위를 벗어났습니다: %@",
            .expectedFileButFoundDirectory: "대상 경로에서 파일이 와야 할 자리에 디렉터리가 있습니다: %@",
            .dryRunCopy: "복사 예정: %@",
            .dryRunOverwrite: "덮어쓰기 예정: %@",
            .refusingOverwriteManagedFiles: "대상 저장소의 관리 파일 덮어쓰기를 거부했습니다.\n다음 파일을 바꾸려면 --force와 함께 다시 실행하세요:\n%@",
            .managedPathMissingFromStarter: "스타터 저장소에 관리 대상 경로가 없습니다: %@",
            .managedPathEscapedRepositoryRoot: "관리 대상 경로가 저장소 루트를 벗어났습니다: %@",
            .warningGitignoreIgnoresAIHarness: "경고: .gitignore가 .swiftnest/를 무시하고 있습니다. 생성된 상태를 커밋하기 전에 해당 규칙을 제거하세요.",
            .warningDocsAlreadyExists: "경고: Docs/가 이미 존재합니다. 커밋 전에 init으로 생성된 파일을 검토하세요.",
            .warningAIHarnessAlreadyExists: "경고: .swiftnest/가 이미 존재합니다. 다시 렌더링하거나 업그레이드하기 전에 현재 상태를 검토하세요.",
            .usageTopLevel: """
            사용법: swiftnest [--lang <en|ko>] <command> [options]

            명령:
              onboard        저장소에 SwiftNest를 설치, 설정, 초기화
              install        대상 저장소에 SwiftNest 관리 파일 설치
              init           설정, 프로필, 스킬로 문서 초기화
              upgrade        더 엄격한 프로필로 업그레이드
              workflow       workflow 스캐폴드 관리
              render-context 통합 컨텍스트 번들 렌더링
              list-skills    사용 가능한 스킬 나열
              list-profiles  사용 가능한 프로필 나열
            """,
            .usageOnboard: "사용법: swiftnest [--lang <en|ko>] onboard [--target <path>] [--config <path>] [--profile <name>] [--skills <csv>] [--workflows <csv>] [--non-interactive] [--force]",
            .usageInstall: "사용법: swiftnest [--lang <en|ko>] install [--target <path>] [--force] [--dry-run]",
            .usageInit: "사용법: swiftnest [--lang <en|ko>] init --config <path> [--profile <name>] [--skills <csv>] [--workflows <csv>] [--non-interactive]",
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
