import Foundation
import XCTest
@testable import SwiftNestCLI

final class SwiftNestCLITests: XCTestCase {
    override func tearDown() {
        SwiftNestLocalizer.configure(language: .en)
        super.tearDown()
    }

    func testInstallManagedFilesKeepsManagedPathsRelativeWhenRootUsesSymlinkedPath() throws {
        let fileManager = FileManager.default
        let actualRepositoryRoot = try makeRepositoryFixture()
        let symlinkRoot = actualRepositoryRoot.deletingLastPathComponent().appendingPathComponent("starter-link-\(UUID().uuidString)")
        try fileManager.createSymbolicLink(at: symlinkRoot, withDestinationURL: actualRepositoryRoot)

        let targetRoot = fileManager.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fileManager.createDirectory(at: targetRoot, withIntermediateDirectories: true)

        let repository = SwiftNestRepository(rootURL: symlinkRoot)
        _ = try SwiftNestCLI.installManagedFiles(
            into: targetRoot,
            force: false,
            dryRun: false,
            repository: repository
        )

        XCTAssertTrue(
            fileManager.fileExists(atPath: targetRoot.appendingPathComponent("profiles/advanced.yaml").path)
        )
        XCTAssertTrue(
            fileManager.fileExists(atPath: targetRoot.appendingPathComponent("templates/Docs/AI_RULES.md").path)
        )
        XCTAssertFalse(
            fileManager.fileExists(atPath: targetRoot.appendingPathComponent("privateprofiles/advanced.yaml").path)
        )
        XCTAssertFalse(
            fileManager.fileExists(atPath: targetRoot.appendingPathComponent("privatetemplates/Docs/AI_RULES.md").path)
        )
    }

    func testLanguageResolverPrefersExplicitArgumentAndStripsIt() throws {
        let resolved = try SwiftNestLanguageResolver.resolve(
            arguments: ["install", "--lang", "ko", "--dry-run"],
            environment: [
                "SWIFTNEST_LANG": "en",
                "LANG": "en_US.UTF-8",
            ],
            preferredLanguages: ["en-US"]
        )

        XCTAssertEqual(resolved.language, .ko)
        XCTAssertEqual(resolved.arguments, ["install", "--dry-run"])
    }

    func testLanguageResolverRejectsUnsupportedEnvironmentValue() {
        XCTAssertThrowsError(
            try SwiftNestLanguageResolver.resolve(
                arguments: ["install"],
                environment: [
                    "SWIFTNEST_LANG": "ja",
                    "LANG": "ko_KR.UTF-8",
                ],
                preferredLanguages: ["ko-KR"]
            )
        ) { error in
            guard let swiftNestError = error as? SwiftNestError else {
                XCTFail("Expected SwiftNestError")
                return
            }
            XCTAssertEqual(
                swiftNestError.message,
                "SWIFTNEST_LANG에 지원하지 않는 언어 값이 지정되었습니다: ja. 지원 값: en, ko."
            )
        }
    }

    func testInstallPromptsAndUsesCurrentGitRepositoryRootWhenTargetIsOmitted() throws {
        let assetRoot = try makeRepositoryFixture(includeStarterOnlyPaths: true)
        let targetRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: targetRoot, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(
            at: targetRoot.appendingPathComponent(".git", isDirectory: true),
            withIntermediateDirectories: true
        )

        try SwiftNestCLI.runInstall(
            parsed: ParsedArguments(values: [:], flags: [], positionals: []),
            repository: SwiftNestRepository(rootURL: assetRoot),
            currentDirectoryURL: targetRoot,
            standardInputIsTTY: { true },
            lineReader: { "y" }
        )

        XCTAssertTrue(FileManager.default.fileExists(atPath: targetRoot.appendingPathComponent("Makefile").path))
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: targetRoot.appendingPathComponent("templates/Docs/AI_RULES.md").path)
        )
    }

    func testInstallWithoutTargetUsesManagedRepositoryRootInsteadOfCurrentSubdirectory() throws {
        let assetRoot = try makeRepositoryFixture(includeStarterOnlyPaths: true)
        let targetRoot = try makeRepositoryFixture()
        let nestedDirectory = targetRoot.appendingPathComponent("Sources/Feature", isDirectory: true)
        try FileManager.default.createDirectory(at: nestedDirectory, withIntermediateDirectories: true)

        try SwiftNestCLI.runInstall(
            parsed: ParsedArguments(values: [:], flags: [], positionals: []),
            repository: SwiftNestRepository(rootURL: assetRoot),
            currentDirectoryURL: nestedDirectory
        )

        XCTAssertFalse(FileManager.default.fileExists(atPath: nestedDirectory.appendingPathComponent("Makefile").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: targetRoot.appendingPathComponent("Makefile").path))
    }

    func testInstallRequiresExplicitTargetOutsideManagedRepositoryWhenConfirmationIsUnavailable() throws {
        let assetRoot = try makeRepositoryFixture(includeStarterOnlyPaths: true)
        let targetRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: targetRoot, withIntermediateDirectories: true)
        XCTAssertThrowsError(
            try SwiftNestCLI.runInstall(
                parsed: ParsedArguments(values: [:], flags: [], positionals: []),
                repository: SwiftNestRepository(rootURL: assetRoot),
                currentDirectoryURL: targetRoot,
                standardInputIsTTY: { false }
            )
        ) { error in
            guard let swiftNestError = error as? SwiftNestError else {
                XCTFail("Expected SwiftNestError")
                return
            }
            XCTAssertEqual(swiftNestError.message, "install requires --target <path>.")
        }
    }

    func testInstallFromStarterCheckoutWithoutTargetUsesLocalizedError() throws {
        SwiftNestLocalizer.configure(language: .ko)
        let starterRoot = try makeRepositoryFixture(includeStarterOnlyPaths: true)

        XCTAssertThrowsError(
            try SwiftNestCLI.runInstall(
                parsed: ParsedArguments(values: [:], flags: [], positionals: []),
                repository: SwiftNestRepository(rootURL: starterRoot),
                currentDirectoryURL: starterRoot
            )
        ) { error in
            guard let swiftNestError = error as? SwiftNestError else {
                XCTFail("Expected SwiftNestError")
                return
            }
            XCTAssertEqual(
                swiftNestError.message,
                "SwiftNest 스타터 체크아웃에서 install을 실행할 때는 스타터 자체가 아니라 대상 앱 저장소를 갱신하도록 --target <path>가 필요합니다."
            )
        }
    }

    func testLocalizedUsageAndPromptStringsAreAvailableInKorean() {
        XCTAssertTrue(SwiftNestLocalizer.text(.usageTopLevel, language: .ko).contains("사용법"))
        XCTAssertTrue(SwiftNestLocalizer.text(.usageTopLevel, language: .ko).contains("onboard"))
        XCTAssertTrue(SwiftNestLocalizer.text(.usageOnboard, language: .ko).contains("--skill-agent <none|codex>"))
        XCTAssertTrue(SwiftNestLocalizer.text(.chooseProfileNumberPrompt, language: .ko, "2").contains("프로필 번호"))
    }

    func testCodexSkillOnboardingFollowUpStringsAreLocalized() {
        let command = "swiftnest init --config config/project.yaml --profile intermediate --skills ios-architecture --workflows add-feature,fix-bug,refactor,build,onboarding-review --skill-agent codex"
        XCTAssertTrue(
            SwiftNestLocalizer.text(.onboardingNextStepCodexSkillsNeeded, language: .en, command).contains("swiftnest init")
        )
        XCTAssertTrue(
            SwiftNestLocalizer.text(.onboardingNextStepCodexSkillsInstalled, language: .en, ".agents/skills").contains(".agents/skills")
        )
        XCTAssertTrue(
            SwiftNestLocalizer.text(.onboardingNextStepCodexSkillsNeeded, language: .en, command).contains("--skill-agent codex")
        )
        XCTAssertTrue(
            SwiftNestLocalizer.text(.onboardingNextStepCodexSkillsNeeded, language: .ko, command).contains("swiftnest init")
        )
        XCTAssertTrue(
            SwiftNestLocalizer.text(.onboardingNextStepCodexSkillsNeeded, language: .ko, command).contains("--skill-agent codex")
        )
        XCTAssertTrue(
            SwiftNestLocalizer.text(.onboardingNextStepCodexSkillsInstalled, language: .ko, ".agents/skills").contains(".agents/skills")
        )
    }

    func testCodexSkillAgentFollowUpCommandUsesExplicitInitArguments() throws {
        let fileManager = FileManager.default
        let repositoryRoot = fileManager.temporaryDirectory
            .appendingPathComponent("SwiftNest Follow Up \(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: repositoryRoot, withIntermediateDirectories: true)

        let repository = SwiftNestRepository(rootURL: repositoryRoot)
        let command = SwiftNestCLI.codexSkillAgentFollowUpCommand(
            configURL: repositoryRoot.appendingPathComponent("Config Folder/project file.yaml"),
            state: SwiftNestState(
                profile: "basic",
                skills: ["ios-architecture"],
                workflows: ["add-feature", "fix-bug", "refactor", "build", "onboarding-review", "review"],
                configPath: "Config Folder/project file.yaml",
                contextPath: ".swiftnest/rendered_context.md"
            ),
            repository: repository
        )

        XCTAssertEqual(
            command,
            "swiftnest init --config 'Config Folder/project file.yaml' --profile basic --skills ios-architecture --workflows add-feature,fix-bug,refactor,build,onboarding-review,review --skill-agent codex"
        )
    }

    func testResolveSkillAgentSelectionRejectsUnknownValue() {
        XCTAssertThrowsError(try SwiftNestCLI.validateSkillAgentSelection("claude")) { error in
            guard let swiftNestError = error as? SwiftNestError else {
                XCTFail("Expected SwiftNestError")
                return
            }
            XCTAssertEqual(swiftNestError.message, "Unknown skill agent: claude. Supported values: none, codex.")
        }
    }

    func testWorkflowRuntimeDescriptionIsLocalized() throws {
        let definition = try XCTUnwrap(SwiftNestCLI.workflowDefinitions["add-feature"])
        XCTAssertEqual(
            definition.runtimeDescription(language: .ko),
            "새 기능 또는 사용자에게 보이는 동작 추가에 사용합니다."
        )
    }

    func testResolveCLIVersionPrefersEnvironmentValue() {
        XCTAssertEqual(
            SwiftNestCLI.resolveCLIVersion(
                environment: ["SWIFTNEST_VERSION": "v9.9.9"],
                assetRootLocator: {
                    throw SwiftNestError("should not resolve asset root")
                },
                gitVersionProvider: { _ in
                    XCTFail("gitVersionProvider should not be called when SWIFTNEST_VERSION is set")
                    return nil
                }
            ),
            "v9.9.9"
        )
    }

    func testResolveCLIVersionUsesVersionFileWhenPresent() throws {
        let repositoryRoot = try makeRepositoryFixture()
        try "v1.2.3\n".write(
            to: repositoryRoot.appendingPathComponent("VERSION"),
            atomically: true,
            encoding: .utf8
        )

        XCTAssertEqual(
            SwiftNestCLI.resolveCLIVersion(
                environment: [:],
                assetRootLocator: { repositoryRoot },
                gitVersionProvider: { _ in
                    XCTFail("gitVersionProvider should not be called when VERSION exists")
                    return nil
                }
            ),
            "v1.2.3"
        )
    }

    func testRunPrintsVersionForLongFlag() throws {
        var output: [String] = []

        try SwiftNestCLI.run(
            arguments: ["--version"],
            output: { output.append($0) },
            versionResolver: { "v2.0.0" }
        )

        XCTAssertEqual(output, ["v2.0.0"])
    }

    func testRunPrintsVersionForShortFlag() throws {
        var output: [String] = []

        try SwiftNestCLI.run(
            arguments: ["-v"],
            output: { output.append($0) },
            versionResolver: { "v2.0.0" }
        )

        XCTAssertEqual(output, ["v2.0.0"])
    }

    func testOnboardingReviewWorkflowDefinitionExistsAndIsLocalized() throws {
        let definition = try XCTUnwrap(SwiftNestCLI.workflowDefinitions["onboarding-review"])

        XCTAssertFalse(definition.isDefault)
        XCTAssertEqual(definition.templatePath, "Workflows/onboarding-review.md")
        XCTAssertEqual(
            definition.runtimeDescription(language: .ko),
            "온보딩 후 실제 저장소를 기준으로 config, 선택한 스킬, 워크플로를 검토할 때 사용합니다."
        )
    }

    func testListProfileSummariesUseEnglishDescriptionsByDefault() throws {
        let summaries = try SwiftNestCLI.listProfileSummaries(
            repository: SwiftNestRepository(rootURL: try makeRepositoryFixture()),
            language: .en
        )

        XCTAssertEqual(
            summaries,
            [
                "advanced: Strict setup for complex apps and long-lived codebases.",
                "basic: Minimal setup for solo projects and MVPs.",
                "intermediate: Balanced setup for product development.",
            ]
        )
    }

    func testListProfileSummariesUseKoreanDescriptionsWhenAvailable() throws {
        let summaries = try SwiftNestCLI.listProfileSummaries(
            repository: SwiftNestRepository(rootURL: try makeRepositoryFixture()),
            language: .ko
        )

        XCTAssertEqual(
            summaries,
            [
                "advanced: 복잡한 앱과 장기 운영 코드베이스에 맞춘 엄격한 구성입니다.",
                "basic: 개인 프로젝트와 MVP에 맞춘 최소 구성입니다.",
                "intermediate: 제품 개발에 균형 있게 맞춘 구성입니다.",
            ]
        )
    }

    func testLocalizedProfileDescriptionFallsBackToEnglishWhenKoreanValueMissing() {
        let values: [String: Any] = ["description": "English only"]

        XCTAssertEqual(
            SwiftNestCLI.localizedProfileDescription(from: values, language: .ko),
            "English only"
        )
    }

    func testOnboardCreatesConfigDocsAndStateInTargetRepository() throws {
        let fileManager = FileManager.default
        let starterRoot = try makeRepositoryFixture()
        let targetRoot = fileManager.temporaryDirectory
            .appendingPathComponent("SampleApp-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: targetRoot, withIntermediateDirectories: true)
        try fileManager.createDirectory(
            at: targetRoot.appendingPathComponent("SampleApp.xcworkspace", isDirectory: true),
            withIntermediateDirectories: true
        )

        let parsed = ParsedArguments(
            values: [
                "--target": targetRoot.path,
                "--workflows": "networking,review",
            ],
            flags: ["--non-interactive"],
            positionals: []
        )

        try SwiftNestCLI.runOnboard(parsed: parsed, repository: SwiftNestRepository(rootURL: starterRoot))

        XCTAssertFalse(fileManager.fileExists(atPath: targetRoot.appendingPathComponent("swiftnest").path))
        XCTAssertFalse(fileManager.fileExists(atPath: targetRoot.appendingPathComponent("harness").path))
        XCTAssertFalse(fileManager.fileExists(atPath: targetRoot.appendingPathComponent("tools/swiftnest-cli").path))
        XCTAssertTrue(fileManager.fileExists(atPath: targetRoot.appendingPathComponent("config/project.yaml").path))
        XCTAssertTrue(fileManager.fileExists(atPath: targetRoot.appendingPathComponent("AGENTS.md").path))
        XCTAssertTrue(fileManager.fileExists(atPath: targetRoot.appendingPathComponent("Docs/AI_RULES.md").path))
        XCTAssertTrue(fileManager.fileExists(atPath: targetRoot.appendingPathComponent(".swiftnest/state.json").path))
        XCTAssertTrue(fileManager.fileExists(atPath: targetRoot.appendingPathComponent(".swiftnest/selected_skill_agent.txt").path))
        XCTAssertTrue(fileManager.fileExists(atPath: targetRoot.appendingPathComponent(".swiftnest/workflows/onboarding-review.md").path))
        XCTAssertTrue(fileManager.fileExists(atPath: targetRoot.appendingPathComponent(".swiftnest/workflows/networking.md").path))
        XCTAssertTrue(fileManager.fileExists(atPath: targetRoot.appendingPathComponent(".swiftnest/workflows/review.md").path))
        XCTAssertFalse(fileManager.fileExists(atPath: targetRoot.appendingPathComponent(".agents/skills").path))

        let configText = try String(contentsOf: targetRoot.appendingPathComponent("config/project.yaml"), encoding: .utf8)
        XCTAssertTrue(configText.contains("project_name: SampleApp"))
        XCTAssertTrue(configText.contains("build_command: xcodebuild -workspace SampleApp.xcworkspace -scheme SampleApp build"))

        let state = try JSONDecoder().decode(
            SwiftNestState.self,
            from: Data(contentsOf: targetRoot.appendingPathComponent(".swiftnest/state.json"))
        )
        XCTAssertEqual(state.dataVersion, SwiftNestCLI.currentDataVersion)
        XCTAssertEqual(state.profile, "intermediate")
        XCTAssertEqual(state.skills, ["concurrency-rules", "ios-architecture", "networking-rules", "swiftui-rules", "testing-rules"])
        XCTAssertEqual(state.workflows, ["add-feature", "fix-bug", "refactor", "build", "onboarding-review", "networking", "review"])
        XCTAssertNil(state.skillAgent)
        XCTAssertEqual(
            try String(contentsOf: targetRoot.appendingPathComponent(".swiftnest/selected_skill_agent.txt"), encoding: .utf8),
            "none\n"
        )
    }

    func testOnboardWithCodexSkillAgentCreatesRepoLocalAgentSkills() throws {
        let fileManager = FileManager.default
        let starterRoot = try makeRepositoryFixture()
        let targetRoot = fileManager.temporaryDirectory
            .appendingPathComponent("CodexSkillTarget-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: targetRoot, withIntermediateDirectories: true)

        let parsed = ParsedArguments(
            values: [
                "--target": targetRoot.path,
                "--skill-agent": "codex",
            ],
            flags: ["--non-interactive"],
            positionals: []
        )

        try SwiftNestCLI.runOnboard(parsed: parsed, repository: SwiftNestRepository(rootURL: starterRoot))

        let skillURL = targetRoot.appendingPathComponent(".agents/skills/swiftnest-ios-architecture/SKILL.md")
        XCTAssertTrue(fileManager.fileExists(atPath: skillURL.path))

        let skillText = try String(contentsOf: skillURL, encoding: .utf8)
        XCTAssertTrue(skillText.contains("name: \"swiftnest-ios-architecture\""))
        XCTAssertTrue(skillText.contains("Apply this skill whenever the task touches app structure"))

        let state = try SwiftNestRepository(rootURL: targetRoot).loadState()
        XCTAssertEqual(state.skillAgent, "codex")
        XCTAssertEqual(
            try String(contentsOf: targetRoot.appendingPathComponent(".swiftnest/selected_skill_agent.txt"), encoding: .utf8),
            "codex\n"
        )
    }

    func testOnboardCanEnableCodexSkillAgentWhenRepositoryIsAlreadyManaged() throws {
        let fileManager = FileManager.default
        let starterRoot = try makeRepositoryFixture()
        let targetRoot = fileManager.temporaryDirectory
            .appendingPathComponent("ManagedCodexEnable-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: targetRoot, withIntermediateDirectories: true)
        try fileManager.createDirectory(
            at: targetRoot.appendingPathComponent("ManagedCodexEnable.xcworkspace", isDirectory: true),
            withIntermediateDirectories: true
        )

        try SwiftNestCLI.runOnboard(
            parsed: ParsedArguments(
                values: [
                    "--target": targetRoot.path,
                    "--workflows": "review",
                ],
                flags: ["--non-interactive"],
                positionals: []
            ),
            repository: SwiftNestRepository(rootURL: starterRoot)
        )
        let initialState = try SwiftNestRepository(rootURL: targetRoot).loadState()

        try SwiftNestCLI.runOnboard(
            parsed: ParsedArguments(
                values: [
                    "--target": targetRoot.path,
                    "--skill-agent": "codex",
                ],
                flags: ["--non-interactive"],
                positionals: []
            ),
            repository: SwiftNestRepository(rootURL: starterRoot)
        )

        let updatedState = try SwiftNestRepository(rootURL: targetRoot).loadState()
        XCTAssertEqual(updatedState.profile, initialState.profile)
        XCTAssertEqual(updatedState.skills, initialState.skills)
        XCTAssertEqual(updatedState.workflows, initialState.workflows)
        XCTAssertEqual(updatedState.skillAgent, "codex")
        XCTAssertTrue(
            fileManager.fileExists(
                atPath: targetRoot.appendingPathComponent(".agents/skills/swiftnest-ios-architecture/SKILL.md").path
            )
        )
    }

    func testOnboardForcePreservesStoredSelectionsWhenOptionsAreOmitted() throws {
        let fileManager = FileManager.default
        let starterRoot = try makeRepositoryFixture()
        let targetRoot = fileManager.temporaryDirectory
            .appendingPathComponent("ManagedForcePreserve-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: targetRoot, withIntermediateDirectories: true)
        try fileManager.createDirectory(
            at: targetRoot.appendingPathComponent("ManagedForcePreserve.xcworkspace", isDirectory: true),
            withIntermediateDirectories: true
        )

        try SwiftNestCLI.runOnboard(
            parsed: ParsedArguments(
                values: [
                    "--target": targetRoot.path,
                    "--profile": "basic",
                    "--workflows": "review",
                    "--skill-agent": "codex",
                ],
                flags: ["--non-interactive"],
                positionals: []
            ),
            repository: SwiftNestRepository(rootURL: starterRoot)
        )
        let initialState = try SwiftNestRepository(rootURL: targetRoot).loadState()

        try SwiftNestCLI.runOnboard(
            parsed: ParsedArguments(
                values: ["--target": targetRoot.path],
                flags: ["--non-interactive", "--force"],
                positionals: []
            ),
            repository: SwiftNestRepository(rootURL: starterRoot)
        )

        let updatedState = try SwiftNestRepository(rootURL: targetRoot).loadState()
        XCTAssertEqual(updatedState.profile, initialState.profile)
        XCTAssertEqual(updatedState.skills, initialState.skills)
        XCTAssertEqual(updatedState.workflows, initialState.workflows)
        XCTAssertEqual(updatedState.skillAgent, initialState.skillAgent)
        XCTAssertTrue(
            fileManager.fileExists(
                atPath: targetRoot.appendingPathComponent(".agents/skills/swiftnest-ios-architecture/SKILL.md").path
            )
        )
    }

    func testOnboardProfileRefreshWithoutExplicitSkillsPreservesStoredSkillSelection() throws {
        let fileManager = FileManager.default
        let starterRoot = try makeRepositoryFixture()
        let targetRoot = fileManager.temporaryDirectory
            .appendingPathComponent("ManagedProfileRefresh-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: targetRoot, withIntermediateDirectories: true)
        try fileManager.createDirectory(
            at: targetRoot.appendingPathComponent("ManagedProfileRefresh.xcworkspace", isDirectory: true),
            withIntermediateDirectories: true
        )

        try SwiftNestCLI.runOnboard(
            parsed: ParsedArguments(
                values: [
                    "--target": targetRoot.path,
                    "--profile": "basic",
                    "--skill-agent": "codex",
                ],
                flags: ["--non-interactive"],
                positionals: []
            ),
            repository: SwiftNestRepository(rootURL: starterRoot)
        )
        let initialState = try SwiftNestRepository(rootURL: targetRoot).loadState()

        try SwiftNestCLI.runOnboard(
            parsed: ParsedArguments(
                values: [
                    "--target": targetRoot.path,
                    "--profile": "intermediate",
                ],
                flags: ["--non-interactive"],
                positionals: []
            ),
            repository: SwiftNestRepository(rootURL: starterRoot)
        )

        let updatedState = try SwiftNestRepository(rootURL: targetRoot).loadState()
        XCTAssertEqual(updatedState.profile, "intermediate")
        XCTAssertEqual(updatedState.skills, initialState.skills)
        XCTAssertEqual(updatedState.workflows, initialState.workflows)
        XCTAssertEqual(updatedState.skillAgent, initialState.skillAgent)
        XCTAssertTrue(
            fileManager.fileExists(
                atPath: targetRoot.appendingPathComponent(".agents/skills/swiftnest-ios-architecture/SKILL.md").path
            )
        )
        XCTAssertFalse(
            fileManager.fileExists(
                atPath: targetRoot.appendingPathComponent(".agents/skills/swiftnest-testing-rules/SKILL.md").path
            )
        )
        XCTAssertFalse(
            fileManager.fileExists(
                atPath: targetRoot.appendingPathComponent("Docs/AI_SKILLS/testing-rules.md").path
            )
        )
    }

    func testOnboardProfileRefreshWithoutExplicitSkillsPreservesRepoLocalCustomSkillSelection() throws {
        let fileManager = FileManager.default
        let starterRoot = try makeRepositoryFixture()
        let targetRoot = fileManager.temporaryDirectory
            .appendingPathComponent("ManagedCustomSkillRefresh-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: targetRoot, withIntermediateDirectories: true)
        try fileManager.createDirectory(
            at: targetRoot.appendingPathComponent("ManagedCustomSkillRefresh.xcworkspace", isDirectory: true),
            withIntermediateDirectories: true
        )

        try SwiftNestCLI.runOnboard(
            parsed: ParsedArguments(
                values: [
                    "--target": targetRoot.path,
                    "--profile": "basic",
                    "--skill-agent": "codex",
                ],
                flags: ["--non-interactive"],
                positionals: []
            ),
            repository: SwiftNestRepository(rootURL: starterRoot)
        )

        let repository = SwiftNestRepository(rootURL: targetRoot, assetRootURL: starterRoot)
        let customSkillContents = """
        # Custom Skill

        Use this skill whenever the repository needs custom domain guidance.
        """
        let customSkillURL = targetRoot.appendingPathComponent("Docs/AI_SKILLS/custom-skill.md")
        try customSkillContents.write(to: customSkillURL, atomically: true, encoding: .utf8)

        let customBundleContents = """
        ---
        name: "swiftnest-custom-skill"
        description: "Custom bundle"
        ---

        Hand-authored custom skill bundle.
        """
        let customBundleDirectoryURL = targetRoot.appendingPathComponent(".agents/skills/swiftnest-custom-skill", isDirectory: true)
        try fileManager.createDirectory(at: customBundleDirectoryURL, withIntermediateDirectories: true)
        let customBundleURL = customBundleDirectoryURL.appendingPathComponent("SKILL.md")
        try customBundleContents.write(to: customBundleURL, atomically: true, encoding: .utf8)

        var state = try repository.loadState()
        state.skills.append("custom-skill")
        try repository.saveState(state)

        try SwiftNestCLI.runOnboard(
            parsed: ParsedArguments(
                values: [
                    "--target": targetRoot.path,
                    "--profile": "intermediate",
                ],
                flags: ["--non-interactive"],
                positionals: []
            ),
            repository: SwiftNestRepository(rootURL: starterRoot)
        )

        let updatedState = try repository.loadState()
        XCTAssertEqual(updatedState.profile, "intermediate")
        XCTAssertEqual(updatedState.skills, ["custom-skill", "ios-architecture"])
        XCTAssertEqual(updatedState.skillAgent, "codex")
        XCTAssertEqual(try String(contentsOf: customSkillURL, encoding: .utf8), customSkillContents)
        XCTAssertEqual(try String(contentsOf: customBundleURL, encoding: .utf8), customBundleContents)
        XCTAssertEqual(
            try String(contentsOf: targetRoot.appendingPathComponent(".swiftnest/selected_skills.txt"), encoding: .utf8),
            "custom-skill\nios-architecture\n"
        )
    }

    func testOnboardProfileRefreshWithoutExplicitSkillsPreservesExplicitlyEmptyStoredSkillSelection() throws {
        let fileManager = FileManager.default
        let starterRoot = try makeRepositoryFixture()
        let targetRoot = fileManager.temporaryDirectory
            .appendingPathComponent("ManagedEmptySkillRefresh-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: targetRoot, withIntermediateDirectories: true)
        try fileManager.createDirectory(
            at: targetRoot.appendingPathComponent("ManagedEmptySkillRefresh.xcworkspace", isDirectory: true),
            withIntermediateDirectories: true
        )

        try SwiftNestCLI.runOnboard(
            parsed: ParsedArguments(
                values: [
                    "--target": targetRoot.path,
                    "--profile": "basic",
                    "--skill-agent": "codex",
                ],
                flags: ["--non-interactive"],
                positionals: []
            ),
            repository: SwiftNestRepository(rootURL: starterRoot)
        )

        let repository = SwiftNestRepository(rootURL: targetRoot, assetRootURL: starterRoot)
        var prunedState = try repository.loadState()
        prunedState.skills = []
        try repository.saveState(prunedState)

        try SwiftNestCLI.runOnboard(
            parsed: ParsedArguments(
                values: [
                    "--target": targetRoot.path,
                    "--profile": "intermediate",
                ],
                flags: ["--non-interactive"],
                positionals: []
            ),
            repository: SwiftNestRepository(rootURL: starterRoot)
        )

        let updatedState = try repository.loadState()
        XCTAssertEqual(updatedState.profile, "intermediate")
        XCTAssertEqual(updatedState.skills, [])
        XCTAssertEqual(updatedState.skillAgent, "codex")
        XCTAssertFalse(
            fileManager.fileExists(
                atPath: targetRoot.appendingPathComponent("Docs/AI_SKILLS/ios-architecture.md").path
            )
        )
        XCTAssertFalse(
            fileManager.fileExists(
                atPath: targetRoot.appendingPathComponent(".agents/skills/swiftnest-ios-architecture/SKILL.md").path
            )
        )
    }

    func testOnboardFailsWhenProfileDefaultSkillTemplateIsMissing() throws {
        let fileManager = FileManager.default
        let starterRoot = try makeRepositoryFixture()
        let targetRoot = fileManager.temporaryDirectory
            .appendingPathComponent("BrokenProfileSkills-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: targetRoot, withIntermediateDirectories: true)
        try fileManager.createDirectory(
            at: targetRoot.appendingPathComponent("BrokenProfileSkills.xcworkspace", isDirectory: true),
            withIntermediateDirectories: true
        )
        try """
        name: basic
        description: Broken packaged profile.
        default_skills:
          - ios-architecture
          - missing-skill
        """.write(
            to: starterRoot.appendingPathComponent("profiles/basic.yaml"),
            atomically: true,
            encoding: .utf8
        )

        XCTAssertThrowsError(
            try SwiftNestCLI.runOnboard(
                parsed: ParsedArguments(
                    values: [
                        "--target": targetRoot.path,
                        "--profile": "basic",
                    ],
                    flags: ["--non-interactive"],
                    positionals: []
                ),
                repository: SwiftNestRepository(rootURL: starterRoot)
            )
        ) { error in
            guard let swiftNestError = error as? SwiftNestError else {
                XCTFail("Expected SwiftNestError")
                return
            }
            XCTAssertEqual(swiftNestError.message, "Unknown skill template: missing-skill")
        }
    }

    func testOnboardWithExplicitWorkflowsOnManagedRepositoryUsesOnboardingDefaults() throws {
        let fileManager = FileManager.default
        let starterRoot = try makeRepositoryFixture()
        let targetRoot = fileManager.temporaryDirectory
            .appendingPathComponent("ManagedWorkflowRefresh-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: targetRoot, withIntermediateDirectories: true)
        try fileManager.createDirectory(
            at: targetRoot.appendingPathComponent("ManagedWorkflowRefresh.xcworkspace", isDirectory: true),
            withIntermediateDirectories: true
        )

        try SwiftNestCLI.runOnboard(
            parsed: ParsedArguments(
                values: [
                    "--target": targetRoot.path,
                    "--workflows": "review",
                ],
                flags: ["--non-interactive"],
                positionals: []
            ),
            repository: SwiftNestRepository(rootURL: starterRoot)
        )

        try SwiftNestCLI.runOnboard(
            parsed: ParsedArguments(
                values: [
                    "--target": targetRoot.path,
                    "--workflows": "networking",
                ],
                flags: ["--non-interactive"],
                positionals: []
            ),
            repository: SwiftNestRepository(rootURL: starterRoot)
        )

        let updatedState = try SwiftNestRepository(rootURL: targetRoot).loadState()
        XCTAssertEqual(
            updatedState.workflows,
            ["add-feature", "fix-bug", "refactor", "build", "onboarding-review", "networking"]
        )
        XCTAssertNil(updatedState.skillAgent)
    }

    func testOnboardPreservesExistingLegacyNamedPathsInTargetRepository() throws {
        let fileManager = FileManager.default
        let starterRoot = try makeRepositoryFixture()
        let targetRoot = fileManager.temporaryDirectory
            .appendingPathComponent("PreserveLegacyPaths-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: targetRoot, withIntermediateDirectories: true)
        try fileManager.createDirectory(
            at: targetRoot.appendingPathComponent("tools/swiftnest-cli/Sources", isDirectory: true),
            withIntermediateDirectories: true
        )
        try "# custom swiftnest\n".write(
            to: targetRoot.appendingPathComponent("swiftnest"),
            atomically: true,
            encoding: .utf8
        )
        try "# custom harness\n".write(
            to: targetRoot.appendingPathComponent("harness"),
            atomically: true,
            encoding: .utf8
        )
        try "struct CustomCLI {}\n".write(
            to: targetRoot.appendingPathComponent("tools/swiftnest-cli/Sources/CustomCLI.swift"),
            atomically: true,
            encoding: .utf8
        )

        let parsed = ParsedArguments(
            values: ["--target": targetRoot.path],
            flags: ["--non-interactive"],
            positionals: []
        )

        try SwiftNestCLI.runOnboard(parsed: parsed, repository: SwiftNestRepository(rootURL: starterRoot))

        XCTAssertEqual(
            try String(contentsOf: targetRoot.appendingPathComponent("swiftnest"), encoding: .utf8),
            "# custom swiftnest\n"
        )
        XCTAssertEqual(
            try String(contentsOf: targetRoot.appendingPathComponent("harness"), encoding: .utf8),
            "# custom harness\n"
        )
        XCTAssertTrue(
            fileManager.fileExists(
                atPath: targetRoot.appendingPathComponent("tools/swiftnest-cli/Sources/CustomCLI.swift").path
            )
        )
    }

    func testOnboardRefreshesManagedTemplatesFromGlobalAssets() throws {
        let starterRoot = try makeRepositoryFixture()
        let targetRoot = try makeRepositoryFixture(includeOnboardingReviewTemplate: false)

        let parsed = ParsedArguments(
            values: ["--target": targetRoot.path],
            flags: ["--non-interactive", "--force"],
            positionals: []
        )

        try SwiftNestCLI.runOnboard(parsed: parsed, repository: SwiftNestRepository(rootURL: starterRoot))

        let state = try SwiftNestRepository(rootURL: targetRoot).loadState()
        XCTAssertEqual(state.workflows, ["add-feature", "fix-bug", "refactor", "build", "onboarding-review"])
        XCTAssertTrue(
            FileManager.default.fileExists(
                atPath: targetRoot.appendingPathComponent(".swiftnest/workflows/onboarding-review.md").path
            )
        )
        XCTAssertTrue(
            FileManager.default.fileExists(
                atPath: targetRoot.appendingPathComponent("templates/Workflows/onboarding-review.md").path
            )
        )
    }

    func testRenderWorkflowSupportsOnboardingReviewTemplate() throws {
        let repositoryRoot = try makeRepositoryFixture()
        let repository = SwiftNestRepository(rootURL: repositoryRoot)
        let config = try HarnessDocumentLoader.loadObject(at: repositoryRoot.appendingPathComponent("config/project.example.yaml"))

        let rendered = try SwiftNestCLI.renderWorkflow(
            named: "onboarding-review",
            config: config,
            profileName: "intermediate",
            skills: ["ios-architecture", "testing-rules"],
            workflows: ["add-feature", "fix-bug", "refactor", "build", "onboarding-review"],
            repository: repository
        )

        XCTAssertTrue(rendered.contains("# Workflow: Onboarding Review"))
        XCTAssertTrue(rendered.contains("config/project.yaml"))
        XCTAssertTrue(rendered.contains("Keep `onboarding-review` available"))
    }

    func testInitKeepsOptionalWorkflowsOptInByDefault() throws {
        let repositoryRoot = try makeRepositoryFixture()
        let repository = SwiftNestRepository(rootURL: repositoryRoot)
        let configURL = repositoryRoot.appendingPathComponent("config/project.yaml")
        try String(contentsOf: repositoryRoot.appendingPathComponent("config/project.example.yaml"), encoding: .utf8)
            .write(to: configURL, atomically: true, encoding: .utf8)

        let parsed = ParsedArguments(
            values: ["--config": "config/project.yaml"],
            flags: ["--non-interactive"],
            positionals: []
        )

        try SwiftNestCLI.runInit(parsed: parsed, repository: repository)

        let state = try repository.loadState()
        XCTAssertEqual(state.workflows, ["add-feature", "fix-bug", "refactor", "build"])
    }

    func testInitCanExplicitlyAddOnboardingReviewWorkflow() throws {
        let repositoryRoot = try makeRepositoryFixture()
        let repository = SwiftNestRepository(rootURL: repositoryRoot)
        let configURL = repositoryRoot.appendingPathComponent("config/project.yaml")
        try String(contentsOf: repositoryRoot.appendingPathComponent("config/project.example.yaml"), encoding: .utf8)
            .write(to: configURL, atomically: true, encoding: .utf8)

        let parsed = ParsedArguments(
            values: [
                "--config": "config/project.yaml",
                "--workflows": "onboarding-review,review",
            ],
            flags: ["--non-interactive"],
            positionals: []
        )

        try SwiftNestCLI.runInit(parsed: parsed, repository: repository)

        let state = try repository.loadState()
        XCTAssertEqual(state.workflows, ["add-feature", "fix-bug", "refactor", "build", "onboarding-review", "review"])
        XCTAssertTrue(
            FileManager.default.fileExists(
                atPath: repositoryRoot.appendingPathComponent(".swiftnest/workflows/onboarding-review.md").path
            )
        )
    }

    func testInitResetsWorkflowSetToCoreAfterOnboard() throws {
        let fileManager = FileManager.default
        let starterRoot = try makeRepositoryFixture()
        let targetRoot = fileManager.temporaryDirectory
            .appendingPathComponent("InitPreserve-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: targetRoot, withIntermediateDirectories: true)
        try fileManager.createDirectory(
            at: targetRoot.appendingPathComponent("InitPreserve.xcworkspace", isDirectory: true),
            withIntermediateDirectories: true
        )

        let onboardParsed = ParsedArguments(
            values: ["--target": targetRoot.path],
            flags: ["--non-interactive"],
            positionals: []
        )
        try SwiftNestCLI.runOnboard(parsed: onboardParsed, repository: SwiftNestRepository(rootURL: starterRoot))

        let initParsed = ParsedArguments(
            values: ["--config": "config/project.yaml"],
            flags: ["--non-interactive"],
            positionals: []
        )
        try SwiftNestCLI.runInit(parsed: initParsed, repository: SwiftNestRepository(rootURL: targetRoot))

        let state = try SwiftNestRepository(rootURL: targetRoot).loadState()
        XCTAssertEqual(state.workflows, ["add-feature", "fix-bug", "refactor", "build"])
        XCTAssertFalse(
            fileManager.fileExists(
                atPath: targetRoot.appendingPathComponent(".swiftnest/workflows/onboarding-review.md").path
            )
        )
    }

    func testInitWithExplicitWorkflowsReplacesPreviouslyEnabledOptionalWorkflows() throws {
        let fileManager = FileManager.default
        let starterRoot = try makeRepositoryFixture()
        let targetRoot = fileManager.temporaryDirectory
            .appendingPathComponent("InitExplicit-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: targetRoot, withIntermediateDirectories: true)
        try fileManager.createDirectory(
            at: targetRoot.appendingPathComponent("InitExplicit.xcworkspace", isDirectory: true),
            withIntermediateDirectories: true
        )

        let onboardParsed = ParsedArguments(
            values: ["--target": targetRoot.path],
            flags: ["--non-interactive"],
            positionals: []
        )
        try SwiftNestCLI.runOnboard(parsed: onboardParsed, repository: SwiftNestRepository(rootURL: starterRoot))

        let initParsed = ParsedArguments(
            values: [
                "--config": "config/project.yaml",
                "--workflows": "review",
            ],
            flags: ["--non-interactive"],
            positionals: []
        )
        try SwiftNestCLI.runInit(parsed: initParsed, repository: SwiftNestRepository(rootURL: targetRoot))

        let state = try SwiftNestRepository(rootURL: targetRoot).loadState()
        XCTAssertEqual(state.workflows, ["add-feature", "fix-bug", "refactor", "build", "review"])
        XCTAssertFalse(
            fileManager.fileExists(
                atPath: targetRoot.appendingPathComponent(".swiftnest/workflows/onboarding-review.md").path
            )
        )
        XCTAssertTrue(
            fileManager.fileExists(
                atPath: targetRoot.appendingPathComponent(".swiftnest/workflows/review.md").path
            )
        )
    }

    func testInitPreservesStoredSkillAgentWhenOptionIsOmitted() throws {
        let fileManager = FileManager.default
        let starterRoot = try makeRepositoryFixture()
        let targetRoot = fileManager.temporaryDirectory
            .appendingPathComponent("InitCodexPreserve-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: targetRoot, withIntermediateDirectories: true)
        try fileManager.createDirectory(
            at: targetRoot.appendingPathComponent("InitCodexPreserve.xcworkspace", isDirectory: true),
            withIntermediateDirectories: true
        )

        try SwiftNestCLI.runOnboard(
            parsed: ParsedArguments(
                values: [
                    "--target": targetRoot.path,
                    "--skill-agent": "codex",
                ],
                flags: ["--non-interactive"],
                positionals: []
            ),
            repository: SwiftNestRepository(rootURL: starterRoot)
        )

        try SwiftNestCLI.runInit(
            parsed: ParsedArguments(
                values: ["--config": "config/project.yaml"],
                flags: ["--non-interactive"],
                positionals: []
            ),
            repository: SwiftNestRepository(rootURL: targetRoot, assetRootURL: starterRoot)
        )

        let state = try SwiftNestRepository(rootURL: targetRoot).loadState()
        XCTAssertEqual(state.skillAgent, "codex")
        XCTAssertTrue(
            fileManager.fileExists(
                atPath: targetRoot.appendingPathComponent(".agents/skills/swiftnest-ios-architecture/SKILL.md").path
            )
        )
        XCTAssertEqual(
            try String(contentsOf: targetRoot.appendingPathComponent(".swiftnest/selected_skill_agent.txt"), encoding: .utf8),
            "codex\n"
        )
    }

    func testInitCanExplicitlyClearStoredSkillAgent() throws {
        let fileManager = FileManager.default
        let starterRoot = try makeRepositoryFixture()
        let targetRoot = fileManager.temporaryDirectory
            .appendingPathComponent("InitCodexClear-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: targetRoot, withIntermediateDirectories: true)
        try fileManager.createDirectory(
            at: targetRoot.appendingPathComponent("InitCodexClear.xcworkspace", isDirectory: true),
            withIntermediateDirectories: true
        )

        try SwiftNestCLI.runOnboard(
            parsed: ParsedArguments(
                values: [
                    "--target": targetRoot.path,
                    "--skill-agent": "codex",
                ],
                flags: ["--non-interactive"],
                positionals: []
            ),
            repository: SwiftNestRepository(rootURL: starterRoot)
        )

        try SwiftNestCLI.runInit(
            parsed: ParsedArguments(
                values: [
                    "--config": "config/project.yaml",
                    "--skill-agent": "none",
                ],
                flags: ["--non-interactive"],
                positionals: []
            ),
            repository: SwiftNestRepository(rootURL: targetRoot, assetRootURL: starterRoot)
        )

        let state = try SwiftNestRepository(rootURL: targetRoot).loadState()
        XCTAssertNil(state.skillAgent)
        XCTAssertFalse(fileManager.fileExists(atPath: targetRoot.appendingPathComponent(".agents/skills").path))
        XCTAssertEqual(
            try String(contentsOf: targetRoot.appendingPathComponent(".swiftnest/selected_skill_agent.txt"), encoding: .utf8),
            "none\n"
        )
    }

    func testCleanupCodexSkillEnvironmentWithoutManifestPreservesNonGeneratedPrefixedBundles() throws {
        let fileManager = FileManager.default
        let starterRoot = try makeRepositoryFixture()
        let targetRoot = fileManager.temporaryDirectory
            .appendingPathComponent("CleanupCodexFallback-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: targetRoot, withIntermediateDirectories: true)
        try fileManager.createDirectory(
            at: targetRoot.appendingPathComponent("CleanupCodexFallback.xcworkspace", isDirectory: true),
            withIntermediateDirectories: true
        )

        try SwiftNestCLI.runOnboard(
            parsed: ParsedArguments(
                values: [
                    "--target": targetRoot.path,
                    "--skill-agent": "codex",
                ],
                flags: ["--non-interactive"],
                positionals: []
            ),
            repository: SwiftNestRepository(rootURL: starterRoot)
        )

        let repository = SwiftNestRepository(rootURL: targetRoot, assetRootURL: starterRoot)
        let customSkillDirectoryURL = repository.agentSkillsDirectoryURL.appendingPathComponent("swiftnest-custom", isDirectory: true)
        try fileManager.createDirectory(at: customSkillDirectoryURL, withIntermediateDirectories: true)
        try """
        ---
        name: "swiftnest-custom"
        description: "Custom skill"
        ---

        Hand-authored skill bundle.
        """.write(
            to: customSkillDirectoryURL.appendingPathComponent("SKILL.md"),
            atomically: true,
            encoding: .utf8
        )
        try fileManager.removeItem(at: repository.agentSkillStateDirectoryURL.appendingPathComponent("codex_manifest.json"))

        try SwiftNestCLI.cleanupCodexSkillEnvironment(repository: repository)

        XCTAssertTrue(fileManager.fileExists(atPath: customSkillDirectoryURL.appendingPathComponent("SKILL.md").path))
        XCTAssertFalse(
            fileManager.fileExists(
                atPath: repository.agentSkillsDirectoryURL.appendingPathComponent("swiftnest-ios-architecture/SKILL.md").path
            )
        )
        XCTAssertFalse(
            fileManager.fileExists(
                atPath: repository.agentSkillsDirectoryURL.appendingPathComponent("swiftnest-testing-rules/SKILL.md").path
            )
        )
    }

    func testInstallManagedFilesDoesNotDeleteLegacyNamedPaths() throws {
        let fileManager = FileManager.default
        let repositoryRoot = try makeRepositoryFixture()
        let targetRoot = fileManager.temporaryDirectory
            .appendingPathComponent("InstallPreservesLegacy-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: targetRoot, withIntermediateDirectories: true)
        try fileManager.createDirectory(
            at: targetRoot.appendingPathComponent("tools/swiftnest-cli/Sources", isDirectory: true),
            withIntermediateDirectories: true
        )
        try "# user swiftnest\n".write(
            to: targetRoot.appendingPathComponent("swiftnest"),
            atomically: true,
            encoding: .utf8
        )
        try "# user harness\n".write(
            to: targetRoot.appendingPathComponent("harness"),
            atomically: true,
            encoding: .utf8
        )
        try "struct UserCLI {}\n".write(
            to: targetRoot.appendingPathComponent("tools/swiftnest-cli/Sources/UserCLI.swift"),
            atomically: true,
            encoding: .utf8
        )

        _ = try SwiftNestCLI.installManagedFiles(
            into: targetRoot,
            force: false,
            dryRun: false,
            repository: SwiftNestRepository(rootURL: repositoryRoot)
        )

        XCTAssertEqual(
            try String(contentsOf: targetRoot.appendingPathComponent("swiftnest"), encoding: .utf8),
            "# user swiftnest\n"
        )
        XCTAssertEqual(
            try String(contentsOf: targetRoot.appendingPathComponent("harness"), encoding: .utf8),
            "# user harness\n"
        )
        XCTAssertTrue(
            fileManager.fileExists(
                atPath: targetRoot.appendingPathComponent("tools/swiftnest-cli/Sources/UserCLI.swift").path
            )
        )
        XCTAssertTrue(
            fileManager.fileExists(atPath: targetRoot.appendingPathComponent("templates/Docs/AI_RULES.md").path)
        )
    }

    func testInstallManagedFilesLeavesTargetUnchangedWhenConflictsExist() throws {
        let fileManager = FileManager.default
        let repositoryRoot = try makeRepositoryFixture()
        let targetRoot = fileManager.temporaryDirectory
            .appendingPathComponent("InstallConflict-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: targetRoot, withIntermediateDirectories: true)
        try "# conflicting makefile\n".write(
            to: targetRoot.appendingPathComponent("Makefile"),
            atomically: true,
            encoding: .utf8
        )
        try "# custom swiftnest\n".write(
            to: targetRoot.appendingPathComponent("swiftnest"),
            atomically: true,
            encoding: .utf8
        )

        XCTAssertThrowsError(
            try SwiftNestCLI.installManagedFiles(
                into: targetRoot,
                force: false,
                dryRun: false,
                repository: SwiftNestRepository(rootURL: repositoryRoot)
            )
        )

        XCTAssertEqual(
            try String(contentsOf: targetRoot.appendingPathComponent("swiftnest"), encoding: .utf8),
            "# custom swiftnest\n"
        )
        XCTAssertFalse(
            fileManager.fileExists(atPath: targetRoot.appendingPathComponent("profiles/advanced.yaml").path)
        )
        XCTAssertFalse(
            fileManager.fileExists(atPath: targetRoot.appendingPathComponent("templates/Docs/AI_RULES.md").path)
        )
    }

    func testRenderContextAutoMigratesLegacyRepositoryWithoutRemovingRepoLocalCLI() throws {
        let fileManager = FileManager.default
        let starterRoot = try makeRepositoryFixture()
        let legacyRoot = try makeRepositoryFixture()
        let repository = SwiftNestRepository(rootURL: legacyRoot, assetRootURL: starterRoot)
        let configURL = legacyRoot.appendingPathComponent("config/project.yaml")
        try String(contentsOf: legacyRoot.appendingPathComponent("config/project.example.yaml"), encoding: .utf8)
            .write(to: configURL, atomically: true, encoding: .utf8)

        let legacyStateJSON = """
        {
          "profile": "intermediate",
          "skills": ["ios-architecture", "swiftui-rules"],
          "workflows": ["add-feature", "fix-bug", "refactor", "build", "onboarding-review"],
          "config_path": "config/project.yaml",
          "context_path": ".swiftnest/rendered_context.md"
        }
        """
        try fileManager.createDirectory(at: legacyRoot.appendingPathComponent(".swiftnest"), withIntermediateDirectories: true)
        try legacyStateJSON.write(
            to: legacyRoot.appendingPathComponent(".swiftnest/state.json"),
            atomically: true,
            encoding: .utf8
        )

        try SwiftNestCLI.runRenderContext(repository: repository)

        let migratedState = try repository.loadState()
        XCTAssertEqual(migratedState.dataVersion, SwiftNestCLI.currentDataVersion)
        XCTAssertTrue(fileManager.fileExists(atPath: legacyRoot.appendingPathComponent("swiftnest").path))
        XCTAssertTrue(fileManager.fileExists(atPath: legacyRoot.appendingPathComponent("harness").path))
        XCTAssertTrue(fileManager.fileExists(atPath: legacyRoot.appendingPathComponent("tools/swiftnest-cli").path))
        XCTAssertTrue(fileManager.fileExists(atPath: legacyRoot.appendingPathComponent(".swiftnest/rendered_context.md").path))
        XCTAssertTrue(fileManager.fileExists(atPath: legacyRoot.appendingPathComponent(".swiftnest/workflows/onboarding-review.md").path))
    }

    func testRunUpgradeMigratesLegacyStateBeforeApplyingTargetProfile() throws {
        let fileManager = FileManager.default
        let starterRoot = try makeRepositoryFixture()
        let legacyRoot = try makeRepositoryFixture()
        let repository = SwiftNestRepository(rootURL: legacyRoot, assetRootURL: starterRoot)
        let configURL = legacyRoot.appendingPathComponent("config/project.yaml")
        try String(contentsOf: legacyRoot.appendingPathComponent("config/project.example.yaml"), encoding: .utf8)
            .write(to: configURL, atomically: true, encoding: .utf8)
        try fileManager.createDirectory(at: legacyRoot.appendingPathComponent(".swiftnest"), withIntermediateDirectories: true)
        try """
        {
          "profile": "basic",
          "skills": ["swiftui-rules"],
          "workflows": ["add-feature", "fix-bug", "refactor", "build"],
          "config_path": "config/project.yaml",
          "context_path": ".swiftnest/rendered_context.md"
        }
        """.write(
            to: legacyRoot.appendingPathComponent(".swiftnest/state.json"),
            atomically: true,
            encoding: .utf8
        )

        try SwiftNestCLI.runUpgrade(
            parsed: ParsedArguments(values: ["--to": "advanced"], flags: [], positionals: []),
            repository: repository
        )

        let state = try repository.loadState()
        XCTAssertEqual(state.dataVersion, SwiftNestCLI.currentDataVersion)
        XCTAssertEqual(state.profile, "advanced")
        XCTAssertEqual(state.skills, ["ios-architecture", "swiftui-rules"])
        XCTAssertTrue(fileManager.fileExists(atPath: legacyRoot.appendingPathComponent(".swiftnest/rendered_context.md").path))
    }

    func testRunUpgradePreservesCodexSkillAgentAndRefreshesAgentSkills() throws {
        let fileManager = FileManager.default
        let starterRoot = try makeRepositoryFixture()
        let repositoryRoot = try makeRepositoryFixture()
        let repository = SwiftNestRepository(rootURL: repositoryRoot, assetRootURL: starterRoot)
        let configURL = repositoryRoot.appendingPathComponent("config/project.yaml")
        try String(contentsOf: repositoryRoot.appendingPathComponent("config/project.example.yaml"), encoding: .utf8)
            .write(to: configURL, atomically: true, encoding: .utf8)

        let initialState = SwiftNestState(
            profile: "basic",
            skills: ["ios-architecture"],
            workflows: ["add-feature", "fix-bug", "refactor", "build"],
            skillAgent: "codex",
            configPath: "config/project.yaml",
            contextPath: ".swiftnest/rendered_context.md"
        )
        try repository.saveState(initialState)

        try SwiftNestCLI.runUpgrade(
            parsed: ParsedArguments(values: ["--to": "advanced"], flags: [], positionals: []),
            repository: repository
        )

        let upgradedState = try repository.loadState()
        XCTAssertEqual(upgradedState.skillAgent, "codex")
        XCTAssertTrue(
            fileManager.fileExists(
                atPath: repositoryRoot.appendingPathComponent(".agents/skills/swiftnest-ios-architecture/SKILL.md").path
            )
        )
        XCTAssertEqual(
            try String(contentsOf: repositoryRoot.appendingPathComponent(".swiftnest/selected_skill_agent.txt"), encoding: .utf8),
            "codex\n"
        )
    }

    func testLocateManagedRepositorySkipsStarterCheckoutEvenWhenAssetRootDiffers() throws {
        let assetRoot = try makeRepositoryFixture(includeStarterOnlyPaths: true)
        let otherStarterRoot = try makeRepositoryFixture(includeStarterOnlyPaths: true)

        XCTAssertThrowsError(
            try SwiftNestRepository.locateManagedRepository(
                assetRootURL: assetRoot,
                currentDirectoryPath: otherStarterRoot.path
            )
        ) { error in
            guard let swiftNestError = error as? SwiftNestError else {
                XCTFail("Expected SwiftNestError")
                return
            }
            XCTAssertEqual(
                swiftNestError.message,
                "Could not locate a SwiftNest-managed repository root from the current directory."
            )
        }
    }

    func testOnboardRequiresTargetWhenOutsideRepositoryContextAndConfirmationIsUnavailable() throws {
        let repository = SwiftNestRepository(rootURL: try makeRepositoryFixture())
        let outsideURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: outsideURL, withIntermediateDirectories: true)

        XCTAssertThrowsError(
            try SwiftNestCLI.resolveOnboardingTargetURL(
                parsed: ParsedArguments(values: [:], flags: ["--non-interactive"], positionals: []),
                repository: repository,
                currentDirectoryURL: outsideURL
            )
        ) { error in
            guard let swiftNestError = error as? SwiftNestError else {
                XCTFail("Expected SwiftNestError")
                return
            }
            XCTAssertEqual(
                swiftNestError.message,
                "onboard requires --target <path> when you are not already inside a SwiftNest-managed repository."
            )
        }
    }

    func testOnboardPromptsAndUsesGitRepositoryRootWhenTargetIsOmitted() throws {
        let repository = SwiftNestRepository(rootURL: try makeRepositoryFixture())
        let gitRoot = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let nestedDirectory = gitRoot.appendingPathComponent("App/Sources", isDirectory: true)
        try FileManager.default.createDirectory(at: nestedDirectory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(
            at: gitRoot.appendingPathComponent(".git", isDirectory: true),
            withIntermediateDirectories: true
        )
        let resolved = try SwiftNestCLI.resolveOnboardingTargetURL(
            parsed: ParsedArguments(values: [:], flags: [], positionals: []),
            repository: repository,
            currentDirectoryURL: nestedDirectory,
            standardInputIsTTY: { true },
            lineReader: { "y" }
        )

        XCTAssertEqual(resolved, gitRoot.standardizedFileURL)
    }

    func testOnboardRequiresTargetFromStarterCheckout() throws {
        let repository = SwiftNestRepository(rootURL: try makeRepositoryFixture(includeStarterOnlyPaths: true))

        XCTAssertThrowsError(
            try SwiftNestCLI.resolveOnboardingTargetURL(
                parsed: ParsedArguments(values: [:], flags: [], positionals: []),
                repository: repository,
                currentDirectoryURL: repository.rootURL
            )
        ) { error in
            guard let swiftNestError = error as? SwiftNestError else {
                XCTFail("Expected SwiftNestError")
                return
            }
            XCTAssertEqual(
                swiftNestError.message,
                "Running onboard from the SwiftNest starter checkout requires --target <path> so the target app repository is updated instead of the starter itself."
            )
        }
    }

    func testResolveOnboardingProfileThrowsWhenNoProfilesAreAvailable() throws {
        let repositoryRoot = try makeRepositoryFixture()
        let profilesURL = repositoryRoot.appendingPathComponent("profiles", isDirectory: true)
        for profileURL in try FileManager.default.contentsOfDirectory(at: profilesURL, includingPropertiesForKeys: nil) {
            try FileManager.default.removeItem(at: profileURL)
        }

        XCTAssertThrowsError(
            try SwiftNestCLI.resolveOnboardingProfile(
                parsed: ParsedArguments(values: [:], flags: ["--non-interactive"], positionals: []),
                repository: SwiftNestRepository(rootURL: repositoryRoot),
                interactive: false
            )
        ) { error in
            guard let swiftNestError = error as? SwiftNestError else {
                XCTFail("Expected SwiftNestError")
                return
            }
            XCTAssertEqual(
                swiftNestError.message,
                "No onboarding profiles are available in this SwiftNest installation."
            )
        }
    }

    func testCurrentWorkflowSetThrowsWhenStateFileIsCorrupt() throws {
        let repositoryRoot = try makeRepositoryFixture()
        let repository = SwiftNestRepository(rootURL: repositoryRoot)
        try FileManager.default.createDirectory(at: repository.stateDirectoryURL, withIntermediateDirectories: true)
        try "{ invalid json".write(
            to: repository.stateFileURL,
            atomically: true,
            encoding: .utf8
        )

        XCTAssertThrowsError(try SwiftNestCLI.currentWorkflowSet(repository: repository))
    }

    func testRunRenderContextThrowsWhenStateDataVersionIsFromFutureVersion() throws {
        let repositoryRoot = try makeRepositoryFixture()
        let repository = SwiftNestRepository(rootURL: repositoryRoot)
        let configURL = repositoryRoot.appendingPathComponent("config/project.yaml")
        try String(contentsOf: repositoryRoot.appendingPathComponent("config/project.example.yaml"), encoding: .utf8)
            .write(to: configURL, atomically: true, encoding: .utf8)
        try FileManager.default.createDirectory(at: repository.stateDirectoryURL, withIntermediateDirectories: true)
        try """
        {
          "data_version": 999,
          "profile": "intermediate",
          "skills": ["ios-architecture"],
          "workflows": ["add-feature", "fix-bug", "refactor", "build"],
          "config_path": "config/project.yaml",
          "context_path": ".swiftnest/rendered_context.md"
        }
        """.write(
            to: repository.stateFileURL,
            atomically: true,
            encoding: .utf8
        )

        XCTAssertThrowsError(try SwiftNestCLI.runRenderContext(repository: repository)) { error in
            guard let swiftNestError = error as? SwiftNestError else {
                XCTFail("Expected SwiftNestError")
                return
            }
            XCTAssertEqual(
                swiftNestError.message,
                "Repository data version 999 is newer than this SwiftNest CLI supports (\(SwiftNestCLI.currentDataVersion)). Upgrade your global swiftnest installation."
            )
        }
    }

    func testWriteDocsThrowsWhenGeneratedManifestIsCorrupt() throws {
        let repositoryRoot = try makeRepositoryFixture()
        let repository = SwiftNestRepository(rootURL: repositoryRoot)
        let docsSkillsURL = repositoryRoot.appendingPathComponent("Docs/AI_SKILLS", isDirectory: true)
        try FileManager.default.createDirectory(at: docsSkillsURL, withIntermediateDirectories: true)
        try "{ invalid manifest".write(
            to: docsSkillsURL.appendingPathComponent(".generated_manifest.json"),
            atomically: true,
            encoding: .utf8
        )
        let config = try HarnessDocumentLoader.loadObject(at: repositoryRoot.appendingPathComponent("config/project.example.yaml"))
        let context = try SwiftNestCLI.normalizeContext(config: config, profileName: "intermediate")

        XCTAssertThrowsError(
            try SwiftNestCLI.writeDocs(
                context: context,
                skills: ["ios-architecture"],
                profileName: "intermediate",
                repository: repository
            )
        )
    }

    func testRootWrapperUsesKoreanErrorWhenSwiftIsMissing() throws {
        let wrapperURL = repositoryRootURL().appendingPathComponent("swiftnest")
        let emptyBinDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: emptyBinDirectory, withIntermediateDirectories: true)

        let process = Process()
        process.executableURL = wrapperURL
        process.arguments = ["--lang", "ko", "list-skills"]
        process.currentDirectoryURL = repositoryRootURL()

        var environment = ProcessInfo.processInfo.environment
        environment["PATH"] = emptyBinDirectory.path
        process.environment = environment

        let stderrPipe = Pipe()
        process.standardError = stderrPipe

        try process.run()
        process.waitUntilExit()

        let stderrData = try stderrPipe.fileHandleForReading.readToEnd() ?? Data()
        let stderr = String(decoding: stderrData, as: UTF8.self)

        XCTAssertEqual(process.terminationStatus, 1)
        XCTAssertTrue(stderr.contains("오류: macOS에서 SwiftNest CLI를 빌드하려면 swift가 필요합니다."))
    }


    func testRootWrapperBuildsWithSingleJobByDefault() throws {
        let fileManager = FileManager.default
        let fixtureRoot = fileManager.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fileManager.createDirectory(at: fixtureRoot, withIntermediateDirectories: true)
        try fileManager.createDirectory(
            at: fixtureRoot.appendingPathComponent("tools/swiftnest-cli/Sources", isDirectory: true),
            withIntermediateDirectories: true
        )

        let wrapperSourceURL = repositoryRootURL().appendingPathComponent("swiftnest")
        let wrapperURL = fixtureRoot.appendingPathComponent("swiftnest")
        try fileManager.copyItem(at: wrapperSourceURL, to: wrapperURL)
        try fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: wrapperURL.path)
        try "// fixture\n".write(
            to: fixtureRoot.appendingPathComponent("tools/swiftnest-cli/Package.swift"),
            atomically: true,
            encoding: .utf8
        )

        let fakeBinDirectory = fixtureRoot.appendingPathComponent("fake-bin", isDirectory: true)
        try fileManager.createDirectory(at: fakeBinDirectory, withIntermediateDirectories: true)
        let loggedArgumentsURL = fixtureRoot.appendingPathComponent("swift-args.txt")
        let fakeSwiftURL = fakeBinDirectory.appendingPathComponent("swift")
        let fakeSwiftScript = """
        #!/bin/sh
        set -eu
        : "${FAKE_SWIFT_ARGS_FILE:?}"
        printf '%s\n' "$@" > "$FAKE_SWIFT_ARGS_FILE"
        package_path=""
        prev=""
        for arg in "$@"; do
          if [ "$prev" = "--package-path" ]; then
            package_path=$arg
            break
          fi
          prev=$arg
        done
        mkdir -p "$package_path/.build/release"
        cat > "$package_path/.build/release/swiftnest" <<'EOF'
        #!/bin/sh
        printf 'fake-swiftnest-ran\n'
        EOF
        chmod +x "$package_path/.build/release/swiftnest"
        """
        try fakeSwiftScript.write(to: fakeSwiftURL, atomically: true, encoding: .utf8)
        try fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: fakeSwiftURL.path)

        let process = Process()
        process.executableURL = wrapperURL
        process.arguments = ["--help"]
        process.currentDirectoryURL = fixtureRoot

        var environment = ProcessInfo.processInfo.environment
        environment["PATH"] = fakeBinDirectory.path + ":/usr/bin:/bin:/usr/sbin:/sbin"
        environment["FAKE_SWIFT_ARGS_FILE"] = loggedArgumentsURL.path
        environment.removeValue(forKey: "SWIFTNEST_BUILD_JOBS")
        process.environment = environment

        let stdoutPipe = Pipe()
        process.standardOutput = stdoutPipe

        try process.run()
        process.waitUntilExit()

        let loggedArguments = try String(contentsOf: loggedArgumentsURL, encoding: .utf8)
            .split(separator: "\n")
            .map(String.init)
        let stdoutData = try stdoutPipe.fileHandleForReading.readToEnd() ?? Data()
        let stdout = String(decoding: stdoutData, as: UTF8.self)

        XCTAssertEqual(process.terminationStatus, 0)
        XCTAssertTrue(stdout.contains("fake-swiftnest-ran"))
        XCTAssertTrue(loggedArguments.contains("--jobs"))
        XCTAssertTrue(loggedArguments.contains("1"))
    }

    func testRootWrapperPrintsBuildDiagnosticsWhenBuildFails() throws {
        let fileManager = FileManager.default
        let fixtureRoot = fileManager.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fileManager.createDirectory(at: fixtureRoot, withIntermediateDirectories: true)
        try fileManager.createDirectory(
            at: fixtureRoot.appendingPathComponent("tools/swiftnest-cli/Sources", isDirectory: true),
            withIntermediateDirectories: true
        )

        let wrapperSourceURL = repositoryRootURL().appendingPathComponent("swiftnest")
        let wrapperURL = fixtureRoot.appendingPathComponent("swiftnest")
        try fileManager.copyItem(at: wrapperSourceURL, to: wrapperURL)
        try fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: wrapperURL.path)
        try "// fixture\n".write(
            to: fixtureRoot.appendingPathComponent("tools/swiftnest-cli/Package.swift"),
            atomically: true,
            encoding: .utf8
        )

        let fakeBinDirectory = fixtureRoot.appendingPathComponent("fake-bin", isDirectory: true)
        try fileManager.createDirectory(at: fakeBinDirectory, withIntermediateDirectories: true)
        let fakeSwiftURL = fakeBinDirectory.appendingPathComponent("swift")
        let fakeSwiftScript = """
        #!/bin/sh
        echo "fake-build-stdout"
        echo "fake-build-stderr" >&2
        exit 1
        """
        try fakeSwiftScript.write(to: fakeSwiftURL, atomically: true, encoding: .utf8)
        try fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: fakeSwiftURL.path)

        let process = Process()
        process.executableURL = wrapperURL
        process.arguments = ["--help"]
        process.currentDirectoryURL = fixtureRoot

        var environment = ProcessInfo.processInfo.environment
        environment["PATH"] = fakeBinDirectory.path + ":/usr/bin:/bin:/usr/sbin:/sbin"
        process.environment = environment

        let stderrPipe = Pipe()
        process.standardError = stderrPipe
        process.standardOutput = Pipe()

        try process.run()
        process.waitUntilExit()

        let stderrData = try stderrPipe.fileHandleForReading.readToEnd() ?? Data()
        let stderr = String(decoding: stderrData, as: UTF8.self)

        XCTAssertEqual(process.terminationStatus, 1)
        XCTAssertTrue(stderr.contains("fake-build-stdout"))
        XCTAssertTrue(stderr.contains("fake-build-stderr"))
    }

    func testRootWrapperTimesOutWhileWaitingForBuildLock() throws {
        let fileManager = FileManager.default
        let fixtureRoot = fileManager.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fileManager.createDirectory(at: fixtureRoot, withIntermediateDirectories: true)
        try fileManager.createDirectory(
            at: fixtureRoot.appendingPathComponent("tools/swiftnest-cli/Sources", isDirectory: true),
            withIntermediateDirectories: true
        )

        let wrapperSourceURL = repositoryRootURL().appendingPathComponent("swiftnest")
        let wrapperURL = fixtureRoot.appendingPathComponent("swiftnest")
        try fileManager.copyItem(at: wrapperSourceURL, to: wrapperURL)
        try fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: wrapperURL.path)
        try "// fixture\n".write(
            to: fixtureRoot.appendingPathComponent("tools/swiftnest-cli/Package.swift"),
            atomically: true,
            encoding: .utf8
        )

        let lockDir = fixtureRoot.appendingPathComponent("tools/swiftnest-cli/.build/.swiftnest-build.lock", isDirectory: true)
        try fileManager.createDirectory(at: lockDir, withIntermediateDirectories: true)

        let sleeper = Process()
        sleeper.executableURL = URL(fileURLWithPath: "/bin/sh")
        sleeper.arguments = ["-c", "sleep 5"]
        try sleeper.run()
        defer {
            if sleeper.isRunning {
                sleeper.terminate()
            }
        }
        try "\(sleeper.processIdentifier)\n".write(
            to: lockDir.appendingPathComponent("pid"),
            atomically: true,
            encoding: .utf8
        )

        let process = Process()
        process.executableURL = wrapperURL
        process.arguments = ["--help"]
        process.currentDirectoryURL = fixtureRoot

        var environment = ProcessInfo.processInfo.environment
        environment["PATH"] = "/usr/bin:/bin:/usr/sbin:/sbin"
        environment["SWIFTNEST_BUILD_LOCK_TIMEOUT_SECONDS"] = "1"
        process.environment = environment

        let stderrPipe = Pipe()
        process.standardError = stderrPipe
        process.standardOutput = Pipe()

        try process.run()
        process.waitUntilExit()

        let stderrData = try stderrPipe.fileHandleForReading.readToEnd() ?? Data()
        let stderr = String(decoding: stderrData, as: UTF8.self)

        XCTAssertEqual(process.terminationStatus, 1)
        XCTAssertTrue(stderr.contains("Another SwiftNest CLI build is already in progress"))
        XCTAssertTrue(stderr.contains("timed out waiting 1s for the SwiftNest CLI build lock"))
    }

    func testOnboardingReviewTemplateCoversExpandedConfigAuditFields() throws {
        let templateURL = repositoryRootURL().appendingPathComponent("templates/Workflows/onboarding-review.md")
        let template = try String(contentsOf: templateURL, encoding: .utf8)

        XCTAssertTrue(template.contains("- `min_ios_version`"))
        XCTAssertTrue(template.contains("- `package_manager`"))
        XCTAssertTrue(template.contains("- `privacy_requirements`"))
        XCTAssertTrue(template.contains("- `healthkit_layer_name`"))
    }

    func testRootMakefilePrefersLocalWrapperWhenAvailable() throws {
        let fileManager = FileManager.default
        let fixtureRoot = fileManager.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fileManager.createDirectory(at: fixtureRoot, withIntermediateDirectories: true)

        let makefileSourceURL = repositoryRootURL().appendingPathComponent("Makefile")
        try fileManager.copyItem(at: makefileSourceURL, to: fixtureRoot.appendingPathComponent("Makefile"))

        let invokedURL = fixtureRoot.appendingPathComponent("invoked.txt")
        let wrapperURL = fixtureRoot.appendingPathComponent("swiftnest")
        let wrapperScript = """
        #!/bin/sh
        printf '%s\\n' \"$0 $*\" > \"\(invokedURL.path)\"
        """
        try wrapperScript.write(to: wrapperURL, atomically: true, encoding: .utf8)
        try fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: wrapperURL.path)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/make")
        process.arguments = ["-f", "Makefile", "list-skills"]
        process.currentDirectoryURL = fixtureRoot
        process.environment = ["PATH": "/usr/bin:/bin:/usr/sbin:/sbin"]
        process.standardOutput = Pipe()
        process.standardError = Pipe()

        try process.run()
        process.waitUntilExit()

        XCTAssertEqual(process.terminationStatus, 0)
        let invocation = try String(contentsOf: invokedURL, encoding: .utf8)
        XCTAssertTrue(invocation.contains("./swiftnest list-skills"))
    }

    func testRootMakefileFallsBackToGlobalCommandWhenLocalWrapperIsMissing() throws {
        let fileManager = FileManager.default
        let fixtureRoot = fileManager.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fileManager.createDirectory(at: fixtureRoot, withIntermediateDirectories: true)

        let makefileSourceURL = repositoryRootURL().appendingPathComponent("Makefile")
        try fileManager.copyItem(at: makefileSourceURL, to: fixtureRoot.appendingPathComponent("Makefile"))

        let fakeBinDirectory = fixtureRoot.appendingPathComponent("fake-bin", isDirectory: true)
        try fileManager.createDirectory(at: fakeBinDirectory, withIntermediateDirectories: true)
        let invokedURL = fixtureRoot.appendingPathComponent("invoked-global.txt")
        let globalCLIURL = fakeBinDirectory.appendingPathComponent("swiftnest")
        let globalScript = """
        #!/bin/sh
        printf '%s\\n' \"$0 $*\" > \"\(invokedURL.path)\"
        """
        try globalScript.write(to: globalCLIURL, atomically: true, encoding: .utf8)
        try fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: globalCLIURL.path)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/make")
        process.arguments = ["-f", "Makefile", "list-skills"]
        process.currentDirectoryURL = fixtureRoot
        process.environment = ["PATH": fakeBinDirectory.path + ":/usr/bin:/bin:/usr/sbin:/sbin"]
        process.standardOutput = Pipe()
        process.standardError = Pipe()

        try process.run()
        process.waitUntilExit()

        XCTAssertEqual(process.terminationStatus, 0)
        let invocation = try String(contentsOf: invokedURL, encoding: .utf8)
        XCTAssertTrue(invocation.contains("/swiftnest list-skills"))
    }

    func testRootWrapperNormalizesZeroPaddedBuildJobs() throws {
        let fileManager = FileManager.default
        let fixtureRoot = fileManager.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fileManager.createDirectory(at: fixtureRoot, withIntermediateDirectories: true)
        try fileManager.createDirectory(
            at: fixtureRoot.appendingPathComponent("tools/swiftnest-cli/Sources", isDirectory: true),
            withIntermediateDirectories: true
        )

        let wrapperSourceURL = repositoryRootURL().appendingPathComponent("swiftnest")
        let wrapperURL = fixtureRoot.appendingPathComponent("swiftnest")
        try fileManager.copyItem(at: wrapperSourceURL, to: wrapperURL)
        try fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: wrapperURL.path)
        try "// fixture\n".write(
            to: fixtureRoot.appendingPathComponent("tools/swiftnest-cli/Package.swift"),
            atomically: true,
            encoding: .utf8
        )

        let fakeBinDirectory = fixtureRoot.appendingPathComponent("fake-bin", isDirectory: true)
        try fileManager.createDirectory(at: fakeBinDirectory, withIntermediateDirectories: true)
        let loggedArgumentsURL = fixtureRoot.appendingPathComponent("swift-args.txt")
        let fakeSwiftURL = fakeBinDirectory.appendingPathComponent("swift")
        let fakeSwiftScript = """
        #!/bin/sh
        set -eu
        : "${FAKE_SWIFT_ARGS_FILE:?}"
        printf '%s\n' "$@" > "$FAKE_SWIFT_ARGS_FILE"
        package_path=""
        prev=""
        for arg in "$@"; do
          if [ "$prev" = "--package-path" ]; then
            package_path=$arg
            break
          fi
          prev=$arg
        done
        mkdir -p "$package_path/.build/release"
        cat > "$package_path/.build/release/swiftnest" <<'EOF'
        #!/bin/sh
        printf 'fake-swiftnest-ran\n'
        EOF
        chmod +x "$package_path/.build/release/swiftnest"
        """
        try fakeSwiftScript.write(to: fakeSwiftURL, atomically: true, encoding: .utf8)
        try fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: fakeSwiftURL.path)

        let process = Process()
        process.executableURL = wrapperURL
        process.arguments = ["--help"]
        process.currentDirectoryURL = fixtureRoot

        var environment = ProcessInfo.processInfo.environment
        environment["PATH"] = fakeBinDirectory.path + ":/usr/bin:/bin:/usr/sbin:/sbin"
        environment["FAKE_SWIFT_ARGS_FILE"] = loggedArgumentsURL.path
        environment["SWIFTNEST_BUILD_JOBS"] = "00"
        process.environment = environment
        process.standardOutput = Pipe()

        try process.run()
        process.waitUntilExit()

        let loggedArguments = try String(contentsOf: loggedArgumentsURL, encoding: .utf8)
            .split(separator: "\n")
            .map(String.init)

        XCTAssertEqual(process.terminationStatus, 0)
        XCTAssertTrue(loggedArguments.contains("--jobs"))
        XCTAssertTrue(loggedArguments.contains("1"))
        XCTAssertFalse(loggedArguments.contains("00"))
    }

    func testRootWrapperSerializesConcurrentBuilds() throws {
        let fileManager = FileManager.default
        let fixtureRoot = fileManager.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fileManager.createDirectory(at: fixtureRoot, withIntermediateDirectories: true)
        try fileManager.createDirectory(
            at: fixtureRoot.appendingPathComponent("tools/swiftnest-cli/Sources", isDirectory: true),
            withIntermediateDirectories: true
        )

        let wrapperSourceURL = repositoryRootURL().appendingPathComponent("swiftnest")
        let wrapperURL = fixtureRoot.appendingPathComponent("swiftnest")
        try fileManager.copyItem(at: wrapperSourceURL, to: wrapperURL)
        try fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: wrapperURL.path)
        try "// fixture\n".write(
            to: fixtureRoot.appendingPathComponent("tools/swiftnest-cli/Package.swift"),
            atomically: true,
            encoding: .utf8
        )

        let fakeBinDirectory = fixtureRoot.appendingPathComponent("fake-bin", isDirectory: true)
        try fileManager.createDirectory(at: fakeBinDirectory, withIntermediateDirectories: true)
        let buildLogURL = fixtureRoot.appendingPathComponent("swift-build.log")
        let fakeSwiftURL = fakeBinDirectory.appendingPathComponent("swift")
        let fakeSwiftScript = """
        #!/bin/sh
        set -eu
        : "${FAKE_SWIFT_LOG:?}"
        printf 'build-start\n' >> "$FAKE_SWIFT_LOG"
        sleep 1
        package_path=""
        prev=""
        for arg in "$@"; do
          if [ "$prev" = "--package-path" ]; then
            package_path=$arg
            break
          fi
          prev=$arg
        done
        mkdir -p "$package_path/.build/release"
        cat > "$package_path/.build/release/swiftnest" <<'EOF'
        #!/bin/sh
        printf 'fake-swiftnest-ran\n'
        EOF
        chmod +x "$package_path/.build/release/swiftnest"
        """
        try fakeSwiftScript.write(to: fakeSwiftURL, atomically: true, encoding: .utf8)
        try fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: fakeSwiftURL.path)

        var processes: [Process] = []
        for _ in 0..<4 {
            let process = Process()
            process.executableURL = wrapperURL
            process.arguments = ["--help"]
            process.currentDirectoryURL = fixtureRoot
            var environment = ProcessInfo.processInfo.environment
            environment["PATH"] = fakeBinDirectory.path + ":/usr/bin:/bin:/usr/sbin:/sbin"
            environment["FAKE_SWIFT_LOG"] = buildLogURL.path
            process.environment = environment
            let stdoutPipe = Pipe()
            process.standardOutput = stdoutPipe
            processes.append(process)
        }

        for process in processes {
            try process.run()
        }
        for process in processes {
            process.waitUntilExit()
        }

        let buildStarts = try String(contentsOf: buildLogURL, encoding: .utf8)
            .split(separator: "\n")
            .filter { $0 == "build-start" }

        XCTAssertEqual(buildStarts.count, 1)
        XCTAssertTrue(processes.allSatisfy { $0.terminationStatus == 0 })
    }

    private func makeRepositoryFixture(
        includeStarterOnlyPaths: Bool = false,
        includeOnboardingReviewTemplate: Bool = true
    ) throws -> URL {
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fileManager.createDirectory(at: root, withIntermediateDirectories: true)

        let directoryPaths = [
            "profiles",
            "resources/agents/codex/skills",
            "templates/Docs/AI_SKILLS",
            "templates/Workflows",
            "tools/swiftnest-cli/Sources",
            "tools/swiftnest-cli/Tests/SwiftNestCLITests",
            "config",
        ]
        for directoryPath in directoryPaths {
            try fileManager.createDirectory(
                at: root.appendingPathComponent(directoryPath, isDirectory: true),
                withIntermediateDirectories: true
            )
        }
        if includeStarterOnlyPaths {
            try fileManager.createDirectory(
                at: root.appendingPathComponent("packaging/homebrew", isDirectory: true),
                withIntermediateDirectories: true
            )
        }

        var filePaths = [
            "Makefile",
            "swiftnest",
            "harness",
            "config/project.example.yaml",
            "profiles/advanced.yaml",
            "profiles/basic.yaml",
            "profiles/intermediate.yaml",
            "templates/AGENTS.md",
            "templates/Docs/AI_PROMPT_ENTRY.md",
            "templates/Docs/AI_RULES.md",
            "templates/Docs/AI_WORKFLOWS.md",
            "templates/Docs/AI_SKILLS/concurrency-rules.md",
            "templates/Docs/AI_SKILLS/ios-architecture.md",
            "templates/Docs/AI_SKILLS/networking-rules.md",
            "templates/Docs/AI_SKILLS/swiftui-rules.md",
            "templates/Docs/AI_SKILLS/testing-rules.md",
            "resources/agents/codex/skills/concurrency-rules/SKILL.md",
            "resources/agents/codex/skills/ios-architecture/SKILL.md",
            "resources/agents/codex/skills/networking-rules/SKILL.md",
            "resources/agents/codex/skills/swiftui-rules/SKILL.md",
            "resources/agents/codex/skills/testing-rules/SKILL.md",
            "templates/Workflows/add-feature.md",
            "templates/Workflows/build.md",
            "templates/Workflows/fix-bug.md",
            "templates/Workflows/networking.md",
            "templates/Workflows/refactor.md",
            "templates/Workflows/review.md",
            "tools/swiftnest-cli/Package.swift",
            "tools/swiftnest-cli/Sources/SimpleDocumentLoader.swift",
            "tools/swiftnest-cli/Sources/SwiftNestCLI.swift",
            "tools/swiftnest-cli/Sources/SwiftNestLocalization.swift",
            "tools/swiftnest-cli/Sources/SwiftNestOnboarding.swift",
            "tools/swiftnest-cli/Sources/WorkflowSupport.swift",
            "tools/swiftnest-cli/Sources/main.swift",
            "tools/swiftnest-cli/Tests/SwiftNestCLITests/SwiftNestCLITests.swift",
        ]
        if includeOnboardingReviewTemplate {
            filePaths.append("templates/Workflows/onboarding-review.md")
        }
        let extendedFilePaths = includeStarterOnlyPaths
            ? filePaths + ["packaging/homebrew/swiftnest.rb.template"]
            : filePaths
        let fileContents: [String: String] = [
            "config/project.example.yaml": """
            project_name: SampleApp
            optional_watchos_line: ""
            ui_framework: SwiftUI
            architecture_style: MVVM with Repository pattern
            min_ios_version: iOS 17
            package_manager: Swift Package Manager
            test_framework: XCTest
            lint_tools: SwiftLint, SwiftFormat
            network_layer_name: APIClient + RemoteRepository
            persistence_layer_name: LocalRepository
            logging_system: OSLog
            privacy_requirements: least-privilege and privacy-safe handling
            preferred_file_line_limit: "300"
            healthkit_layer_name: HealthKitManager
            build_command: xcodebuild -scheme SampleApp build
            test_command: xcodebuild test -scheme SampleApp
            """,
            "profiles/advanced.yaml": """
            name: advanced
            description: Strict setup for complex apps and long-lived codebases.
            description_ko: 복잡한 앱과 장기 운영 코드베이스에 맞춘 엄격한 구성입니다.
            default_skills:
              - ios-architecture
            """,
            "profiles/basic.yaml": """
            name: basic
            description: Minimal setup for solo projects and MVPs.
            description_ko: 개인 프로젝트와 MVP에 맞춘 최소 구성입니다.
            default_skills:
              - ios-architecture
            """,
            "profiles/intermediate.yaml": """
            name: intermediate
            description: Balanced setup for product development.
            description_ko: 제품 개발에 균형 있게 맞춘 구성입니다.
            default_skills:
              - ios-architecture
              - swiftui-rules
              - concurrency-rules
              - networking-rules
              - testing-rules
            """,
            "templates/Docs/AI_SKILLS/concurrency-rules.md": """
            # Concurrency Rules

            Apply this skill whenever async work, task orchestration, cancellation, or actor correctness is involved.
            """,
            "templates/Docs/AI_SKILLS/ios-architecture.md": """
            # iOS Architecture Rules

            Apply this skill whenever the task touches app structure, screen composition, or responsibility boundaries.
            """,
            "templates/Docs/AI_SKILLS/networking-rules.md": """
            # Networking Rules

            Apply this skill whenever API calls, request/response modeling, retries, or remote sync behavior are involved.
            """,
            "templates/Docs/AI_SKILLS/swiftui-rules.md": """
            # SwiftUI Rules

            Apply this skill whenever the task touches SwiftUI screens or UI state.
            """,
            "templates/Docs/AI_SKILLS/testing-rules.md": """
            # Testing Rules

            Apply this skill whenever logic changes are introduced.
            """,
            "resources/agents/codex/skills/concurrency-rules/SKILL.md": """
            ---
            name: "{{SWIFTNEST_AGENT_SKILL_NAME}}"
            description: "{{SWIFTNEST_AGENT_SKILL_DESCRIPTION}}"
            ---

            <!-- Generated by SwiftNest for Codex from Docs/AI_SKILLS/{{SWIFTNEST_SOURCE_SKILL_FILE}}. Re-run swiftnest onboard, init, or upgrade after changing selected skills. -->

            {{SWIFTNEST_AGENT_SKILL_CONTENT}}
            """,
            "resources/agents/codex/skills/ios-architecture/SKILL.md": """
            ---
            name: "{{SWIFTNEST_AGENT_SKILL_NAME}}"
            description: "{{SWIFTNEST_AGENT_SKILL_DESCRIPTION}}"
            ---

            <!-- Generated by SwiftNest for Codex from Docs/AI_SKILLS/{{SWIFTNEST_SOURCE_SKILL_FILE}}. Re-run swiftnest onboard, init, or upgrade after changing selected skills. -->

            {{SWIFTNEST_AGENT_SKILL_CONTENT}}
            """,
            "resources/agents/codex/skills/networking-rules/SKILL.md": """
            ---
            name: "{{SWIFTNEST_AGENT_SKILL_NAME}}"
            description: "{{SWIFTNEST_AGENT_SKILL_DESCRIPTION}}"
            ---

            <!-- Generated by SwiftNest for Codex from Docs/AI_SKILLS/{{SWIFTNEST_SOURCE_SKILL_FILE}}. Re-run swiftnest onboard, init, or upgrade after changing selected skills. -->

            {{SWIFTNEST_AGENT_SKILL_CONTENT}}
            """,
            "resources/agents/codex/skills/swiftui-rules/SKILL.md": """
            ---
            name: "{{SWIFTNEST_AGENT_SKILL_NAME}}"
            description: "{{SWIFTNEST_AGENT_SKILL_DESCRIPTION}}"
            ---

            <!-- Generated by SwiftNest for Codex from Docs/AI_SKILLS/{{SWIFTNEST_SOURCE_SKILL_FILE}}. Re-run swiftnest onboard, init, or upgrade after changing selected skills. -->

            {{SWIFTNEST_AGENT_SKILL_CONTENT}}
            """,
            "resources/agents/codex/skills/testing-rules/SKILL.md": """
            ---
            name: "{{SWIFTNEST_AGENT_SKILL_NAME}}"
            description: "{{SWIFTNEST_AGENT_SKILL_DESCRIPTION}}"
            ---

            <!-- Generated by SwiftNest for Codex from Docs/AI_SKILLS/{{SWIFTNEST_SOURCE_SKILL_FILE}}. Re-run swiftnest onboard, init, or upgrade after changing selected skills. -->

            {{SWIFTNEST_AGENT_SKILL_CONTENT}}
            """,
            "templates/Workflows/onboarding-review.md": """
            # Workflow: Onboarding Review

            Keep `onboarding-review` available as the entry workflow for future onboarding refreshes.

            Review config/project.yaml and audit:
            - min_ios_version
            - package_manager
            - privacy_requirements
            - healthkit_layer_name
            """,
        ]

        for filePath in extendedFilePaths {
            let destinationURL = root.appendingPathComponent(filePath)
            try fileManager.createDirectory(at: destinationURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            let contents = fileContents[filePath] ?? "fixture"
            try contents.write(to: destinationURL, atomically: true, encoding: .utf8)
        }

        return root
    }

    // MARK: - effectiveOnboardingDefaultSkills reconciliation

    func testEffectiveOnboardingDefaultSkillsDropsAllStaleSkillsAndFallsBackToProfileDefaults() {
        let state = SwiftNestState(
            profile: "basic",
            skills: ["removed-skill", "renamed-skill"],
            workflows: ["add-feature"],
            configPath: "config/project.yaml",
            contextPath: ".swiftnest"
        )
        let parsed = ParsedArguments(values: [:], flags: [], positionals: [])
        let result = SwiftNestCLI.effectiveOnboardingDefaultSkills(
            parsed: parsed,
            profileDefaultSkills: ["ios-architecture", "missing-skill"],
            existingState: state,
            preservableSkillNames: ["ios-architecture", "code-review"]
        )
        XCTAssertEqual(result, ["ios-architecture", "missing-skill"])
    }

    func testEffectiveOnboardingDefaultSkillsKeepsOnlyValidStoredSkills() {
        let state = SwiftNestState(
            profile: "basic",
            skills: ["ios-architecture", "removed-skill"],
            workflows: ["add-feature"],
            configPath: "config/project.yaml",
            contextPath: ".swiftnest"
        )
        let parsed = ParsedArguments(values: [:], flags: [], positionals: [])
        let result = SwiftNestCLI.effectiveOnboardingDefaultSkills(
            parsed: parsed,
            profileDefaultSkills: ["swift-testing"],
            existingState: state,
            preservableSkillNames: ["ios-architecture", "swift-testing", "code-review"]
        )
        XCTAssertEqual(result, ["ios-architecture"])
    }

    func testEffectiveOnboardingDefaultSkillsPreservesExplicitlyEmptyStoredSkills() {
        let state = SwiftNestState(
            profile: "basic",
            skills: [],
            workflows: ["add-feature"],
            configPath: "config/project.yaml",
            contextPath: ".swiftnest"
        )
        let parsed = ParsedArguments(values: [:], flags: [], positionals: [])
        let result = SwiftNestCLI.effectiveOnboardingDefaultSkills(
            parsed: parsed,
            profileDefaultSkills: ["ios-architecture"],
            existingState: state,
            preservableSkillNames: ["ios-architecture", "code-review"]
        )
        XCTAssertEqual(result, [])
    }

    func testEffectiveOnboardingDefaultSkillsWithExplicitSkillsReturnsProfileDefaults() {
        let state = SwiftNestState(
            profile: "basic",
            skills: ["ios-architecture"],
            workflows: ["add-feature"],
            configPath: "config/project.yaml",
            contextPath: ".swiftnest"
        )
        let parsed = ParsedArguments(values: ["--skills": "ios-architecture,code-review"], flags: [], positionals: [])
        let result = SwiftNestCLI.effectiveOnboardingDefaultSkills(
            parsed: parsed,
            profileDefaultSkills: ["swift-testing"],
            existingState: state,
            preservableSkillNames: ["ios-architecture", "swift-testing", "code-review"]
        )
        XCTAssertEqual(result, ["swift-testing"])
    }

    private func repositoryRootURL() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}
