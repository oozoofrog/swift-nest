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
        XCTAssertTrue(SwiftNestLocalizer.text(.chooseProfileNumberPrompt, language: .ko).contains("프로필 번호"))
    }

    func testWorkflowRuntimeDescriptionIsLocalized() throws {
        let definition = try XCTUnwrap(SwiftNestCLI.workflowDefinitions["add-feature"])
        XCTAssertEqual(
            definition.runtimeDescription(language: .ko),
            "새 기능 또는 사용자에게 보이는 동작 추가에 사용합니다."
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

    private func makeRepositoryFixture() throws -> URL {
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

        let filePaths = [
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
            "templates/Docs/AI_SKILLS/ios-architecture.md",
            "templates/Workflows/add-feature.md",
            "templates/Workflows/build.md",
            "templates/Workflows/fix-bug.md",
            "templates/Workflows/refactor.md",
            "tools/swiftnest-cli/Package.swift",
            "tools/swiftnest-cli/Sources/SimpleDocumentLoader.swift",
            "tools/swiftnest-cli/Sources/SwiftNestCLI.swift",
            "tools/swiftnest-cli/Sources/WorkflowSupport.swift",
            "tools/swiftnest-cli/Sources/main.swift",
            "tools/swiftnest-cli/Tests/SwiftNestCLITests/SwiftNestCLITests.swift",
        ]
        let fileContents: [String: String] = [
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
            """,
        ]

        for filePath in filePaths {
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
