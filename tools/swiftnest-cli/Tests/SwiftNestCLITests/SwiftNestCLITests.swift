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

    func testInstallRequiresTargetMessageUsesLocalizedRuntimeLanguage() throws {
        SwiftNestLocalizer.configure(language: .ko)

        XCTAssertThrowsError(
            try SwiftNestCLI.runInstall(
                parsed: ParsedArguments(values: [:], flags: [], positionals: []),
                repository: SwiftNestRepository(rootURL: try makeRepositoryFixture())
            )
        ) { error in
            guard let swiftNestError = error as? SwiftNestError else {
                XCTFail("Expected SwiftNestError")
                return
            }
            XCTAssertEqual(swiftNestError.message, "install 명령에는 --target <path>가 필요합니다.")
        }
    }

    func testLocalizedUsageAndPromptStringsAreAvailableInKorean() {
        XCTAssertTrue(SwiftNestLocalizer.text(.usageTopLevel, language: .ko).contains("사용법"))
        XCTAssertTrue(SwiftNestLocalizer.text(.usageTopLevel, language: .ko).contains("onboard"))
        XCTAssertTrue(SwiftNestLocalizer.text(.chooseProfileNumberPrompt, language: .ko, "2").contains("프로필 번호"))
    }

    func testWorkflowRuntimeDescriptionIsLocalized() throws {
        let definition = try XCTUnwrap(SwiftNestCLI.workflowDefinitions["add-feature"])
        XCTAssertEqual(
            definition.runtimeDescription(language: .ko),
            "새 기능 또는 사용자에게 보이는 동작 추가에 사용합니다."
        )
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
        XCTAssertTrue(fileManager.fileExists(atPath: targetRoot.appendingPathComponent(".ai-harness/state.json").path))
        XCTAssertTrue(fileManager.fileExists(atPath: targetRoot.appendingPathComponent(".ai-harness/workflows/onboarding-review.md").path))
        XCTAssertTrue(fileManager.fileExists(atPath: targetRoot.appendingPathComponent(".ai-harness/workflows/networking.md").path))
        XCTAssertTrue(fileManager.fileExists(atPath: targetRoot.appendingPathComponent(".ai-harness/workflows/review.md").path))

        let configText = try String(contentsOf: targetRoot.appendingPathComponent("config/project.yaml"), encoding: .utf8)
        XCTAssertTrue(configText.contains("project_name: SampleApp"))
        XCTAssertTrue(configText.contains("build_command: xcodebuild -workspace SampleApp.xcworkspace -scheme SampleApp build"))

        let state = try JSONDecoder().decode(
            SwiftNestState.self,
            from: Data(contentsOf: targetRoot.appendingPathComponent(".ai-harness/state.json"))
        )
        XCTAssertEqual(state.dataVersion, SwiftNestCLI.currentDataVersion)
        XCTAssertEqual(state.profile, "intermediate")
        XCTAssertEqual(state.skills, ["concurrency-rules", "ios-architecture", "networking-rules", "swiftui-rules", "testing-rules"])
        XCTAssertEqual(state.workflows, ["add-feature", "fix-bug", "refactor", "build", "onboarding-review", "networking", "review"])
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
                atPath: targetRoot.appendingPathComponent(".ai-harness/workflows/onboarding-review.md").path
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
                atPath: repositoryRoot.appendingPathComponent(".ai-harness/workflows/onboarding-review.md").path
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
                atPath: targetRoot.appendingPathComponent(".ai-harness/workflows/onboarding-review.md").path
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
                atPath: targetRoot.appendingPathComponent(".ai-harness/workflows/onboarding-review.md").path
            )
        )
        XCTAssertTrue(
            fileManager.fileExists(
                atPath: targetRoot.appendingPathComponent(".ai-harness/workflows/review.md").path
            )
        )
    }

    func testRenderContextAutoMigratesLegacyRepositoryAndRemovesRepoLocalCLI() throws {
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
          "context_path": ".ai-harness/rendered_context.md"
        }
        """
        try fileManager.createDirectory(at: legacyRoot.appendingPathComponent(".ai-harness"), withIntermediateDirectories: true)
        try legacyStateJSON.write(
            to: legacyRoot.appendingPathComponent(".ai-harness/state.json"),
            atomically: true,
            encoding: .utf8
        )

        try SwiftNestCLI.runRenderContext(repository: repository)

        let migratedState = try repository.loadState()
        XCTAssertEqual(migratedState.dataVersion, SwiftNestCLI.currentDataVersion)
        XCTAssertFalse(fileManager.fileExists(atPath: legacyRoot.appendingPathComponent("swiftnest").path))
        XCTAssertFalse(fileManager.fileExists(atPath: legacyRoot.appendingPathComponent("harness").path))
        XCTAssertFalse(fileManager.fileExists(atPath: legacyRoot.appendingPathComponent("tools/swiftnest-cli").path))
        XCTAssertTrue(fileManager.fileExists(atPath: legacyRoot.appendingPathComponent(".ai-harness/rendered_context.md").path))
        XCTAssertTrue(fileManager.fileExists(atPath: legacyRoot.appendingPathComponent(".ai-harness/workflows/onboarding-review.md").path))
    }

    func testOnboardRequiresTargetWhenOutsideRepositoryContext() throws {
        let repository = SwiftNestRepository(rootURL: try makeRepositoryFixture())
        let outsideURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: outsideURL, withIntermediateDirectories: true)

        XCTAssertThrowsError(
            try SwiftNestCLI.resolveOnboardingTargetURL(
                parsed: ParsedArguments(values: [:], flags: [], positionals: []),
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
            "templates/Workflows/onboarding-review.md": """
            # Workflow: Onboarding Review

            Keep `onboarding-review` available as the entry workflow for future onboarding refreshes.

            Review config/project.yaml and the selected workflows.
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

    private func repositoryRootURL() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}
