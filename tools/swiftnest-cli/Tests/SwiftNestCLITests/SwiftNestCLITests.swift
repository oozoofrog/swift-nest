import Foundation
import XCTest
@testable import SwiftNestCLI

final class SwiftNestCLITests: XCTestCase {
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
        for filePath in filePaths {
            let destinationURL = root.appendingPathComponent(filePath)
            try fileManager.createDirectory(at: destinationURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try "fixture".write(to: destinationURL, atomically: true, encoding: .utf8)
        }

        return root
    }
}
